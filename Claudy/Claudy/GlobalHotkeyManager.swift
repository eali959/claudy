import AppKit
import OSLog

// MARK: - GlobalHotkeyManager

/// Registers a global keyboard shortcut (default: ⌘⇧Space) that toggles the Claud-y chat
/// panel from any application, without requiring focus.
///
/// Uses NSEvent global monitor — works without Accessibility permission on macOS 14+
/// for key-down events as long as the app is not sandboxed.
/// The shortcut can be disabled via `isEnabled` (persisted in UserDefaults).
@MainActor
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    private var monitor: Any?
    private let logger = Logger(subsystem: "com.claudy", category: "GlobalHotkey")

    // MARK: - Settings

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: DefaultsKeys.globalHotkeyEnabled) }
        set {
            UserDefaults.standard.set(newValue, forKey: DefaultsKeys.globalHotkeyEnabled)
            refresh()
            logger.info("Global hotkey \(newValue ? "enabled" : "disabled")")
        }
    }

    // MARK: - Lifecycle

    private init() {
        // V5.10 — Default OFF for new installs.  Registering a global key
        // monitor (`addGlobalMonitorForEvents` for `.keyDown`) triggers the
        // macOS Input Monitoring permission prompt on first launch — scary
        // and unexpected for new users.  They can now opt-in via Settings
        // → General → "Global hotkey (⌘⇧Space)".  Existing users who already
        // had it enabled keep their setting.
        if UserDefaults.standard.object(forKey: DefaultsKeys.globalHotkeyEnabled) == nil {
            UserDefaults.standard.set(false, forKey: DefaultsKeys.globalHotkeyEnabled)
        }
        refresh()
    }

    func refresh() {
        removeMonitor()
        guard isEnabled else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleKeyEvent(event)
            }
        }
    }

    private func removeMonitor() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    // MARK: - Key matching

    /// Matches ⌘⇧Space (keyCode 49).
    private func handleKeyEvent(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard event.keyCode == 49, flags == [.command, .shift] else { return }
        NotificationCenter.default.post(name: .claudyToggleChat, object: nil)
        logger.debug("Global hotkey fired — toggling chat")
    }
}
