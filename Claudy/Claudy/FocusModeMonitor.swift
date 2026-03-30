import AppKit
import OSLog

// MARK: - FocusModeMonitor

/// Listens for macOS Focus / Do Not Disturb changes via distributed notifications and
/// sets `CharacterViewModel.isFocusModeActive` accordingly.
///
/// When Focus is active:
///   - `showSpeechBubble` already gates ambient bubbles (4-in-5 chance suppressed)
///   - The 🌙 badge appears on the character
///   - Claud-y shows a brief acknowledgement on activation
///
/// Also listens for screen lock/unlock so Claud-y stays quiet while the screen is locked.
@MainActor
final class FocusModeMonitor {
    private weak var viewModel: CharacterViewModel?
    private let logger = Logger(subsystem: "com.claudy", category: "FocusMode")

    init(viewModel: CharacterViewModel) {
        self.viewModel = viewModel
        registerObservers()
    }

    // MARK: - Registration

    private func registerObservers() {
        let dnc = DistributedNotificationCenter.default()

        // macOS Focus / DND (works on macOS 12–15, distributed by NotificationCenter daemon)
        dnc.addObserver(self, selector: #selector(focusDidStart),
                        name: NSNotification.Name("com.apple.notificationcenterui.dndstart"),
                        object: nil, suspensionBehavior: .deliverImmediately)
        dnc.addObserver(self, selector: #selector(focusDidEnd),
                        name: NSNotification.Name("com.apple.notificationcenterui.dndend"),
                        object: nil, suspensionBehavior: .deliverImmediately)

        // Screen lock / unlock (reliable on all modern macOS)
        dnc.addObserver(self, selector: #selector(screenLocked),
                        name: NSNotification.Name("com.apple.screenIsLocked"),
                        object: nil, suspensionBehavior: .deliverImmediately)
        dnc.addObserver(self, selector: #selector(screenUnlocked),
                        name: NSNotification.Name("com.apple.screenIsUnlocked"),
                        object: nil, suspensionBehavior: .deliverImmediately)

        // Also catch display sleep via workspace
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(displaySleep),
            name: NSWorkspace.screensDidSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(displayWake),
            name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    // MARK: - Handlers

    @objc private func focusDidStart(_ n: Notification) {
        Task { @MainActor [weak self] in
            self?.viewModel?.isFocusModeActive = true
            self?.logger.info("macOS Focus on — Claud-y going quiet")
            self?.viewModel?.showBubbleDirect("Focus mode on. I'll be quiet. 🤫", duration: 4)
        }
    }

    @objc private func focusDidEnd(_ n: Notification) {
        Task { @MainActor [weak self] in
            self?.viewModel?.isFocusModeActive = false
            self?.logger.info("macOS Focus ended — Claud-y resuming")
        }
    }

    @objc private func screenLocked(_ n: Notification) {
        Task { @MainActor [weak self] in
            self?.viewModel?.isFocusModeActive = true
        }
    }

    @objc private func screenUnlocked(_ n: Notification) {
        Task { @MainActor [weak self] in
            self?.viewModel?.isFocusModeActive = false
        }
    }

    @objc private func displaySleep(_ n: Notification) {
        Task { @MainActor [weak self] in
            self?.viewModel?.isFocusModeActive = true
        }
    }

    @objc private func displayWake(_ n: Notification) {
        Task { @MainActor [weak self] in
            self?.viewModel?.isFocusModeActive = false
        }
    }
}
