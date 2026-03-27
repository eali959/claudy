import AppKit
import OSLog

/// Watches global keyboard events and triggers character reactions.
/// Requires Input Monitoring permission (user prompted by macOS on first use).
@MainActor
final class KeyboardMonitor {
    private weak var viewModel: CharacterViewModel?
    private let logger = Logger(subsystem: "com.claudy", category: "KeyboardMonitor")

    @ObservationIgnored nonisolated(unsafe) private var keyDownMonitor: Any?
    @ObservationIgnored nonisolated(unsafe) private var flagsMonitor: Any?

    // MARK: - Typing burst detection
    private var keyTimestamps: [Date] = []
    private var burstTask: Task<Void, Never>?
    private var burstTriggered = false

    // MARK: - CMD+Z undo streak
    private var undoTimestamps: [Date] = []

    // MARK: - Idle-after-typing detection
    private var lastKeyTime: Date?
    private var idleAfterTypingTask: Task<Void, Never>?

    // MARK: - Caps Lock
    private var capsLockOn = false

    init(viewModel: CharacterViewModel) {
        self.viewModel = viewModel
        startMonitoring()
    }

    deinit {
        let km = keyDownMonitor
        let fm = flagsMonitor
        Task { @MainActor in
            if let km { NSEvent.removeMonitor(km) }
            if let fm { NSEvent.removeMonitor(fm) }
        }
    }

    // MARK: - Start

    private func startMonitoring() {
        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor [weak self] in self?.handleKeyDown(event) }
        }
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor [weak self] in self?.handleFlagsChanged(event) }
        }
        if keyDownMonitor == nil {
            logger.warning("Input Monitoring permission not granted - keyboard reactions disabled")
        }
    }

    // MARK: - Key down

    private func handleKeyDown(_ event: NSEvent) {
        let now = Date()
        lastKeyTime = now

        idleAfterTypingTask?.cancel()
        idleAfterTypingTask = Task {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            self.handleTypingIdle()
        }

        keyTimestamps.append(now)
        keyTimestamps = keyTimestamps.filter { now.timeIntervalSince($0) <= 5 }

        detectBurst()
        detectShortcuts(event)
    }

    // MARK: - Burst detection (>4 keys/sec for 3 s)

    private func detectBurst() {
        let now = Date()
        let recentCount = keyTimestamps.filter { now.timeIntervalSince($0) <= 1.0 }.count
        guard recentCount > 4 else {
            if !burstTriggered { burstTask?.cancel(); burstTask = nil }
            return
        }
        guard burstTask == nil else { return }
        burstTriggered = false
        burstTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, !self.burstTriggered else { return }
            self.triggerTypingBurst()
        }
    }

    private func triggerTypingBurst() {
        burstTriggered = true
        burstTask = nil
        viewModel?.celebrate()
        let msg = ReactionLibraryService.shared.reaction(for: .typingBurst)
        if !msg.isEmpty { viewModel?.showSpeechBubble(msg, duration: 4) }
        viewModel?.resetIdleTimer()
    }

    // MARK: - Shortcuts

    private func detectShortcuts(_ event: NSEvent) {
        let mods = event.modifierFlags
        let isCmdOnly = mods.contains(.command) && !mods.contains(.shift)
                         && !mods.contains(.option) && !mods.contains(.control)
        guard isCmdOnly else { return }
        switch event.keyCode {
        case 6: handleUndoStreak()   // Z
        case 1: handleSave()         // S
        default: break
        }
    }

    // MARK: - CMD+Z undo streak (>3 in 2 s)

    private func handleUndoStreak() {
        let now = Date()
        undoTimestamps.append(now)
        undoTimestamps = undoTimestamps.filter { now.timeIntervalSince($0) <= 2 }
        guard undoTimestamps.count > 3 else { return }
        undoTimestamps.removeAll()

        viewModel?.beConfused()
        let msg = ReactionLibraryService.shared.reaction(for: .cmdZSpam)
        if !msg.isEmpty { viewModel?.showSpeechBubble(msg, duration: 5) }
        viewModel?.resetIdleTimer()
    }

    // MARK: - CMD+S save

    private func handleSave() {
        viewModel?.nod()
        let msg = ReactionLibraryService.shared.reaction(for: .cmdS)
        if !msg.isEmpty { viewModel?.showSpeechBubble(msg, duration: 3) }
        viewModel?.resetIdleTimer()
    }

    // MARK: - Typing idle (30 s after last key)

    private func handleTypingIdle() {
        guard lastKeyTime != nil else { return }
        idleAfterTypingTask = nil
        let msg = ReactionLibraryService.shared.reaction(for: .typingPause)
        if !msg.isEmpty { viewModel?.showSpeechBubble(msg, duration: 4) }
    }

    // MARK: - Caps Lock toggle

    private func handleFlagsChanged(_ event: NSEvent) {
        let newCapsState = event.modifierFlags.contains(.capsLock)
        guard newCapsState != capsLockOn else { return }
        capsLockOn = newCapsState
        if capsLockOn {
            viewModel?.beSurprised()
            let msg = ReactionLibraryService.shared.reaction(for: .capsLock)
            if !msg.isEmpty { viewModel?.showSpeechBubble(msg, duration: 3) }
        }
        viewModel?.resetIdleTimer()
    }
}
