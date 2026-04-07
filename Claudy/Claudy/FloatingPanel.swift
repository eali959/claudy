import AppKit

/// Transparent, non-activating floating panel that hosts the Claud-y character.
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func rightMouseDown(with event: NSEvent) {
        // Activate the app so submenu tracking works correctly on this non-activating panel.
        // Without this, submenus dismiss immediately when the mouse moves into them.
        NSApp.activate(ignoringOtherApps: true)
        super.rightMouseDown(with: event)
    }
}
