import AppKit
import Observation
import OSLog

// MARK: - AppWatcher (Section 6)
//
// Polls NSWorkspace.shared.frontmostApplication every 5 seconds.
// When a mapped app is detected and the current Focus Mode differs,
// shows a toast suggestion — once per app per session.
//
// Enabled via Settings > Behaviour > "React to active app" (off by default).

@MainActor
@Observable
final class AppWatcher {

    // MARK: - State

    var pendingSuggestion: AppSuggestion? = nil

    // MARK: - Config

    var isEnabled: Bool = UserDefaults.standard.bool(forKey: DefaultsKeys.reactToActiveApp) {
        didSet { UserDefaults.standard.set(isEnabled, forKey: DefaultsKeys.reactToActiveApp) }
    }

    // MARK: - Private

    private weak var viewModel: CharacterViewModel?
    @ObservationIgnored private nonisolated(unsafe) var timer: Timer?
    /// Bundle IDs already suggested this session — never repeat.
    private var seenThisSession: Set<String> = []
    private let logger = Logger(subsystem: "com.claudy", category: "AppWatcher")

    // MARK: - Bundle ID → Focus Mode map

    static let bundleToMode: [String: BehaviorMode] = [
        // Dev
        "com.apple.dt.Xcode":        .dev,
        "com.microsoft.VSCode":      .dev,
        "com.sublimetext.4":         .dev,
        "com.sublimetext.3":         .dev,
        "com.todesktop.230313mzl4w4u53": .dev,  // Cursor
        "com.exosphere.windsurf":    .dev,
        // Work
        "us.zoom.xos":               .work,
        "com.microsoft.teams":       .work,
        "com.apple.FaceTime":        .work,
        "com.microsoft.teams2":      .work,
    ]

    // MARK: - Init / deinit

    init(viewModel: CharacterViewModel) {
        self.viewModel = viewModel
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Start / stop

    func start() {
        guard isEnabled else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Poll

    private func poll() {
        guard isEnabled else { return }
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }

        // Check prefix match (e.g. "com.sublimetext.*")
        let mappedMode: BehaviorMode? = Self.bundleToMode[bundleID]
            ?? Self.bundleToMode.first(where: { bundleID.hasPrefix($0.key) })?.value

        guard let targetMode = mappedMode else { return }
        guard !seenThisSession.contains(bundleID) else { return }

        // Only suggest if current mode is different
        let currentMode = PersonalityManager.shared.activeBehaviorMode
        guard currentMode != targetMode else { return }

        seenThisSession.insert(bundleID)
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "this app"
        let suggestion = AppSuggestion(
            appName: appName,
            bundleID: bundleID,
            targetMode: targetMode
        )
        pendingSuggestion = suggestion
        viewModel?.showBubbleDirect(suggestion.toastMessage, duration: 6)
        logger.debug("App suggestion: \(appName) → \(targetMode.rawValue)")
    }

    func dismissSuggestion() {
        pendingSuggestion = nil
    }

    func acceptSuggestion() {
        if let mode = pendingSuggestion?.targetMode {
            viewModel?.behaviorModeManager?.activate(mode)
        }
        pendingSuggestion = nil
    }
}

// MARK: - AppSuggestion

struct AppSuggestion: Sendable, Equatable {
    let appName: String
    let bundleID: String
    let targetMode: BehaviorMode

    var toastMessage: String {
        "Looks like you're in \(appName) — switch to \(targetMode.displayName)?"}
}
