import AppKit

/// Transparent, non-activating floating panel that hosts the Claud-y character.
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)
        // Critical for live mouse-tracking inside the SCNView — without
        // this the panel never delivers mouseMoved events even when a
        // tracking area is configured with `.activeAlways`.
        self.acceptsMouseMovedEvents = true
    }

    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)
    }
}
