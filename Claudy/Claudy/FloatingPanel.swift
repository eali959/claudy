import AppKit

/// Transparent, non-activating floating panel that hosts the Claud-y character.
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
