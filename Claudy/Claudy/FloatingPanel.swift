import AppKit

/// Transparent, non-activating floating panel that hosts the Claud-y character.
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    private var menuTrackingObserver: Any?

    override func rightMouseDown(with event: NSEvent) {
        NSCursor.unhide()

        // Non-activating panels interfere with submenu tracking — mouse movements
        // over the panel cause submenus to dismiss prematurely. Ignoring mouse events
        // during menu tracking prevents this; the menu NSWindow handles its own events.
        ignoresMouseEvents = true
        menuTrackingObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.didEndTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.ignoresMouseEvents = false
            if let obs = self?.menuTrackingObserver {
                NotificationCenter.default.removeObserver(obs)
                self?.menuTrackingObserver = nil
            }
        }

        super.rightMouseDown(with: event)
    }
}
