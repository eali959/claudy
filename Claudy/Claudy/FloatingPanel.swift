import AppKit

/// Transparent, non-activating floating panel that hosts the Claud-y character.
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func rightMouseDown(with event: NSEvent) {
        // Non-activating panels suppress cursor visibility during submenu tracking.
        // Unhiding here ensures the pointer stays visible when navigating submenus.
        NSCursor.unhide()
        super.rightMouseDown(with: event)
    }
}
