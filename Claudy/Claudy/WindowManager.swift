import AppKit
import Observation

/// Manages the floating NSPanel's position, size preset, and drag behaviour.
///
/// Exposes `characterScale` derived from the active `SizePreset` and persists both the chosen
/// preset and the last window origin to UserDefaults. `beginDrag` / `updateDrag` / `endDrag`
/// translate SwiftUI drag deltas into window frame mutations via AppKit.
@MainActor
@Observable
final class WindowManager {
    weak var window: NSWindow?

    private(set) var isDragging = false
    private var dragMouseStart: CGPoint = .zero   // screen coords at drag start
    private var dragWindowStart: CGPoint = .zero  // window origin at drag start

    // MARK: - Layout constants

    static let chatWidth: CGFloat     = 300
    static let minChatHeight: CGFloat = 200
    static let maxChatHeight: CGFloat = 600

    /// Base character panel size - the NSPanel is sized to this at launch.
    static let characterSize: CGFloat = 150

    // MARK: - Character size preset (Small / Medium / Large)

    enum SizePreset: String, CaseIterable {
        case small = "small", medium = "medium", large = "large"

        var displayName: String {
            switch self {
            case .small:  return "Small"
            case .medium: return "Medium"
            case .large:  return "Large"
            }
        }

        /// Scale applied to ClaudyCharacterView (relative to the panel's fixed frame).
        var scale: CGFloat {
            switch self {
            case .small:  return 0.60
            case .medium: return 0.80
            case .large:  return 1.00
            }
        }
    }

    var sizePreset: SizePreset = {
        let saved = UserDefaults.standard.string(forKey: DefaultsKeys.characterSizePreset) ?? ""
        return SizePreset(rawValue: saved) ?? .medium
    }() {
        didSet {
            UserDefaults.standard.set(sizePreset.rawValue, forKey: DefaultsKeys.characterSizePreset)
        }
    }

    var characterScale: CGFloat { sizePreset.scale }

    // MARK: - Dynamic chat height (persisted)

    var chatHeight: CGFloat = {
        let saved = UserDefaults.standard.double(forKey: DefaultsKeys.claudyChatHeight)
        return saved > 0 ? CGFloat(saved) : 320
    }() {
        didSet {
            UserDefaults.standard.set(Double(chatHeight), forKey: DefaultsKeys.claudyChatHeight)
        }
    }

    // MARK: - Drag
    // Uses NSEvent.mouseLocation (screen coordinates) so the calculation is
    // independent of the window's position - SwiftUI translation is ignored.

    func beginDrag() {
        isDragging = true
        dragMouseStart  = NSEvent.mouseLocation
        dragWindowStart = window?.frame.origin ?? .zero
    }

    func updateDrag(translation _: CGSize) {
        guard isDragging, let window else { return }
        let mouse = NSEvent.mouseLocation
        window.setFrameOrigin(CGPoint(
            x: dragWindowStart.x + (mouse.x - dragMouseStart.x),
            y: dragWindowStart.y + (mouse.y - dragMouseStart.y)
        ))
    }

    func endDrag() {
        isDragging = false
        savePosition()
    }

    // MARK: - Chat resize

    func adjustChatHeight(to proposed: CGFloat) {
        chatHeight = min(Self.maxChatHeight, max(Self.minChatHeight, proposed))
    }

    // MARK: - Position persistence

    func savePosition() {
        guard let origin = window?.frame.origin else { return }
        UserDefaults.standard.set([Double(origin.x), Double(origin.y)], forKey: DefaultsKeys.characterWindowOrigin)
    }

    func restorePosition() {
        guard let window else { return }
        if let saved = UserDefaults.standard.array(forKey: DefaultsKeys.characterWindowOrigin) as? [Double],
           saved.count == 2 {
            let origin = CGPoint(x: saved[0], y: saved[1])
            // Validate the panel rect (not just the origin point) is still on a screen.
            let panelRect = CGRect(origin: origin, size: window.frame.size)
            let isOnScreen = NSScreen.screens.contains {
                $0.visibleFrame.intersects(panelRect) &&
                $0.visibleFrame.contains(CGPoint(x: panelRect.midX, y: panelRect.midY))
            }
            if isOnScreen {
                window.setFrameOrigin(origin)
                return
            }
        }
        resetPosition()
    }

    func resetPosition() {
        guard let window else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        let f = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        // Keep the panel fully within the visible screen area.
        // 20pt margin from the right edge; 80pt up from the dock so the character sits
        // in the bottom-right corner without being clipped.
        let origin = CGPoint(x: f.maxX - Self.chatWidth - 20, y: f.minY + 80)
        window.setFrameOrigin(origin)
        UserDefaults.standard.removeObject(forKey: DefaultsKeys.characterWindowOrigin)
    }
}
