import AppKit
import IOKit.ps
import OSLog

/// Watches for app crashes, screenshots, and battery level changes.
@MainActor
final class SystemEventMonitor {
    private weak var viewModel: CharacterViewModel?
    private let logger = Logger(subsystem: "com.claudy", category: "SystemEventMonitor")

    @ObservationIgnored private var observerTask: Task<Void, Never>?

    // Crash cooldown
    private var lastCrashReaction: Date?
    private let crashCooldown: TimeInterval = 60

    // Battery state
    private var lastBatteryWarningLevel: Int? = nil

    init(viewModel: CharacterViewModel) {
        self.viewModel = viewModel
        startObserving()
    }

    deinit { observerTask?.cancel() }

    // MARK: - Start

    private func startObserving() {
        observerTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self?.observeAppTerminations() }
                group.addTask { await self?.observeScreenshots() }
                group.addTask { await self?.observePowerSource() }
            }
        }
    }

    // MARK: - App crash detection

    private func observeAppTerminations() async {
        let notifications = NSWorkspace.shared.notificationCenter
            .notifications(named: NSWorkspace.didTerminateApplicationNotification)
        for await note in notifications {
            guard !Task.isCancelled else { return }
            await handleTermination(note)
        }
    }

    private func handleTermination(_ note: Notification) async {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else { return }
        guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        guard app.icon != nil else { return }  // ignore daemons

        let now = Date()
        if let last = lastCrashReaction, now.timeIntervalSince(last) < crashCooldown { return }
        lastCrashReaction = now

        let name = app.localizedName ?? "something"
        let base = ReactionLibraryService.shared.reaction(for: .appCrash)
        let msg  = base.isEmpty ? "RIP \(name)." : base.replacingOccurrences(of: "something", with: name)
        viewModel?.showSpeechBubble(msg, duration: 4)
        viewModel?.beSurprised()
    }

    // MARK: - Screenshot detection

    private func observeScreenshots() async {
        let notifications = DistributedNotificationCenter.default()
            .notifications(named: Notification.Name("com.apple.screencaptured"))
        for await _ in notifications {
            guard !Task.isCancelled else { return }
            handleScreenshot()
        }
    }

    private func handleScreenshot() {
        let msg = ReactionLibraryService.shared.reaction(for: .screenshot)
        if !msg.isEmpty { viewModel?.showSpeechBubble(msg, duration: 3) }
        viewModel?.nod()
    }

    // MARK: - Battery monitoring

    private func observePowerSource() async {
        while !Task.isCancelled {
            checkBattery()
            try? await Task.sleep(for: .seconds(60))
        }
    }

    private func checkBattery() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else { return }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue()
                    as? [String: Any] else { continue }
            guard (desc[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
            guard (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSBatteryPowerValue else {
                lastBatteryWarningLevel = nil; continue
            }
            guard let capacity = desc[kIOPSCurrentCapacityKey] as? Int else { continue }

            let threshold = capacity <= 10 ? 10 : capacity <= 20 ? 20 : -1
            guard threshold > 0, lastBatteryWarningLevel != threshold else {
                if threshold < 0 { lastBatteryWarningLevel = nil }
                continue
            }
            lastBatteryWarningLevel = threshold

            let msg = ReactionLibraryService.shared.reaction(for: .batteryLow)
            if !msg.isEmpty { viewModel?.showSpeechBubble(msg, duration: 5) }
            if capacity <= 10 { viewModel?.beSurprised() }
        }
    }
}
