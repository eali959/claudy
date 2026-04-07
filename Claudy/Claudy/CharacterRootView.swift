import SwiftUI
import AppKit

/// Root view hosted inside the floating NSPanel.
/// Owns all @State, notification wiring (.onReceive/.onChange), and sheet/popover presentation.
/// Rendering is delegated to CharacterSceneView — this view is a thin notification/state orchestrator.
struct CharacterRootView: View {
    @Environment(WindowManager.self) private var windowManager
    @State private var chatViewModel = ChatViewModel()
    @State private var characterViewModel = CharacterViewModel()

    @State private var showReactionLog = false
    @State private var demoManager   = DemoModeManager()
    @State private var v2DemoManager = V2DemoModeManager()
    @State private var showHelp = false
    @State private var showDonate = false
    @State private var showFocusAdder = false
    @State private var focusAdderDefaultType: FocusToolAdderSheet.ToolType = .reminder
    @State private var showScratchpad = false
    @AppStorage(DefaultsKeys.characterOpacity)   private var characterOpacity: Double = 1.0
    @AppStorage(DefaultsKeys.timerBadgeScale)    private var timerBadgeScale: Double = 1.0

    var body: some View {
        CharacterSceneView(
            characterViewModel: characterViewModel,
            chatViewModel: chatViewModel,
            demoManager: demoManager,
            v2DemoManager: v2DemoManager,
            showReactionLog: $showReactionLog,
            characterOpacity: characterOpacity,
            timerBadgeScale: timerBadgeScale,
            onTap: handleTap,
            onDoubleTap: handleDoubleTap,
            onDragBegan: { windowManager.beginDrag(); characterViewModel.resetIdleTimer() },
            onDragChanged: { windowManager.updateDrag(translation: $0) },
            onDragEnded: windowManager.endDrag,
            onAddQuickAlarm: addQuickAlarm,
            onShowFocusAdder: { type in focusAdderDefaultType = type; showFocusAdder = true },
            onShowHelp: { showHelp = true },
            onShowDonate: { showDonate = true },
            onShowScratchpad: { showScratchpad = true }
        )
        .sheet(isPresented: $showFocusAdder) {
            FocusToolAdderSheet(
                isPresented: $showFocusAdder,
                manager: characterViewModel.alarmReminderManager,
                defaultType: focusAdderDefaultType
            )
        }
        .sheet(isPresented: $showScratchpad) {
            ScratchpadSheet(isPresented: $showScratchpad)
        }
        .popover(isPresented: $showHelp, arrowEdge: .top) {
            HelpView()
        }
        .popover(isPresented: $showDonate, arrowEdge: .top) {
            DonatePopoverView()
        }
        .popover(isPresented: $showReactionLog, arrowEdge: .top) {
            ReactionLogView(entries: characterViewModel.reactionLog) {
                showReactionLog = false
            }
        }
        // MARK: - Notification wiring (ALL .onReceive stay here — never in sub-views)
        .onReceive(NotificationCenter.default.publisher(for: .claudyToggleChat)) { _ in
            let opening = !chatViewModel.isOpen
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                chatViewModel.isOpen = opening
            }
            if opening {
                SoundManager.shared.play(.chatOpen)
                characterViewModel.setState(.idle)
                windowManager.window?.makeKey()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .claudyQuickActionFired)) { note in
            guard let prompt = note.userInfo?["prompt"] as? String else { return }
            chatViewModel.inputText = prompt
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                chatViewModel.isOpen = true
            }
            SoundManager.shared.play(.chatOpen)
            windowManager.window?.makeKey()
        }
        .onReceive(NotificationCenter.default.publisher(for: .claudyStartDemo)) { _ in
            demoManager.start()
        }
        .onReceive(NotificationCenter.default.publisher(for: .claudyContextTrimmed)) { _ in
            characterViewModel.showBubbleDirect(
                "Long session - I've trimmed some earlier context to keep things sharp.",
                duration: 5
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .claudyAPICodeBlock)) { _ in
            let pool = [
                "There's the code. Let me know if it does what you need.",
                "Code block incoming. Copy button is right there.",
                "Here's what I'd try. Run it carefully."
            ]
            characterViewModel.showBubbleDirect(pool.randomElement() ?? pool[0], duration: 4)
        }
        .onReceive(NotificationCenter.default.publisher(for: .claudyAPILongResponse)) { _ in
            characterViewModel.setState(.celebrating, duration: 0.8)
        }
        .onReceive(NotificationCenter.default.publisher(for: .claudyLongConversation)) { _ in
            characterViewModel.showBubbleDirect(
                "We've been at this a while. How's it going really?",
                duration: 6
            )
        }
        // MARK: - State change observation (ALL .onChange stay here — never in sub-views)
        .onChange(of: chatViewModel.isOpen) { _, open in
            characterViewModel.isChatOpen = open
        }
        .onChange(of: chatViewModel.isTyping) { _, thinking in
            if thinking {
                characterViewModel.setThinking()
            } else if !chatViewModel.isStreaming {
                characterViewModel.stopTalking()
            }
        }
        .onChange(of: chatViewModel.isStreaming) { _, streaming in
            characterViewModel.setState(streaming ? .talking : .idle)
        }
        .onChange(of: chatViewModel.messages.count) { _, _ in
            characterViewModel.resetIdleTimer()
        }
        .onChange(of: characterViewModel.speechBubbleText) { _, newText in
            if let text = newText {
                AccessibilityNotification.Announcement(text).post()
            }
        }
        .onAppear {
            characterViewModel.setup(windowManager: windowManager)
            demoManager.prepare(character: characterViewModel, chat: chatViewModel)
            v2DemoManager.prepare(character: characterViewModel, chat: chatViewModel)
        }
    }

    // MARK: - Tap / Double-tap

    private func handleDoubleTap() {
        characterViewModel.resetIdleTimer()
        characterViewModel.beSurprised()
        SoundManager.shared.play(.chatOpen)
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            characterViewModel.celebrate()
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            chatViewModel.isOpen = true
        }
        windowManager.window?.makeKey()
    }

    private func handleTap() {
        characterViewModel.resetIdleTimer()
        let opening = !chatViewModel.isOpen
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            chatViewModel.isOpen = opening
        }
        if opening {
            SoundManager.shared.play(.chatOpen)
            characterViewModel.setState(.idle)
            windowManager.window?.makeKey()
        }
    }

    private func addQuickAlarm(_ minutes: Int) {
        let fireDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        let label = minutes < 60
            ? "Alarm — \(minutes) min"
            : "Alarm — \(minutes / 60) hr"
        characterViewModel.alarmReminderManager.add(title: label, fireDate: fireDate)
    }
}
