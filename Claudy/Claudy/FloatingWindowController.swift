import AppKit
import SwiftUI
import OSLog

@MainActor
final class FloatingWindowController: NSWindowController {
    let windowManager: WindowManager
    private let logger = Logger(subsystem: "com.claudy", category: "FloatingWindow")

    init() {
        let charSize   = WindowManager.characterSize
        // Panel is always full height (character + max chat area).
        // SwiftUI controls how much of the chat area is visible - no setFrame needed for resize.
        let fullHeight = charSize + WindowManager.maxChatHeight

        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: WindowManager.chatWidth, height: fullHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel    = true
        panel.level              = .floating
        panel.backgroundColor    = .clear
        panel.isOpaque           = false
        panel.hasShadow          = false
        panel.ignoresMouseEvents = false
        panel.isMovable          = false  // drag handled in SwiftUI
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.becomesKeyOnlyIfNeeded = true

        let wm = WindowManager()
        wm.window = panel

        let rootView = CharacterRootView()
            .environment(wm)
            .environment(PersonalityManager.shared)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.layer?.backgroundColor = .clear
        panel.contentView = hostingView

        windowManager = wm
        super.init(window: panel)

        wm.restorePosition()
        // Bind the character panel to the voice overlay so it can position
        // itself directly below Claud-y when invoked.
        VoiceOverlayController.shared.bindCharacterPanel(panel)
        logger.info("FloatingWindow ready - size \(WindowManager.chatWidth)×\(fullHeight)")
    }

    required init?(coder: NSCoder) { fatalError("Not supported") }

    func savePosition() { windowManager.savePosition() }
}
