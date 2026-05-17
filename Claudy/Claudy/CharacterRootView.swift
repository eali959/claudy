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
    @State private var demoManager = DemoModeManager()
    @State private var showHelp = false
    @State private var showDonate = false
    @State private var showFocusAdder = false
    @State private var focusAdderDefaultType: FocusToolAdderSheet.ToolType = .reminder
    @State private var showScratchpad = false
    @State private var showLocalLLMSetup = false
    @State private var showVoiceMode = false
    @AppStorage(DefaultsKeys.characterOpacity)   private var characterOpacity: Double = 1.0
    @AppStorage(DefaultsKeys.timerBadgeScale)    private var timerBadgeScale: Double = 1.0

    var body: some View {
        CharacterSceneView(
            characterViewModel: characterViewModel,
            chatViewModel: chatViewModel,
            demoManager: demoManager,
            showReactionLog: $showReactionLog,
            characterOpacity: characterOpacity,
            timerBadgeScale: timerBadgeScale,
            onTap: handleTap,
            onDoubleTap: handleDoubleTap,
            onDragBegan: {
                windowManager.beginDrag()
                characterViewModel.resetIdleTimer()
                // V5.3 — Pleasure pose: eyes close (like being petted), mouth
                // stays at current shape.  Replaces the previous .excited
                // setState which triggered a big-smile + bounce that looked
                // overdone during a drag.  Matches 2D Claudy's drag joy face.
                characterViewModel.onDragBegin()
            },
            onDragChanged: { windowManager.updateDrag(translation: $0) },
            onDragEnded: {
                windowManager.endDrag()
                // V5.3 — Open eyes + brief tickle reaction (subtle wiggle).
                characterViewModel.onDragEnd()
            },
            onAddQuickAlarm: addQuickAlarm,
            onShowFocusAdder: { type in focusAdderDefaultType = type; showFocusAdder = true },
            onShowHelp: { showHelp = true },
            onShowDonate: { showDonate = true },
            onShowScratchpad: { showScratchpad = true }
        )
        // V4 — matrix-rain glitch overlay used during the 2D→3D demo transition
        .overlay {
            if demoManager.showMatrixGlitch {
                MatrixGlitchOverlay(intensity: 1.0)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.30), value: demoManager.showMatrixGlitch)
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
        .modifier(VoiceAndLocalLLMSheets(
            showLocalLLMSetup: $showLocalLLMSetup,
            showVoiceMode: $showVoiceMode,
            chatViewModel: chatViewModel,
            characterViewModel: characterViewModel
        ))
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
            demoManager.start(.v1)
        }
        .modifier(VoiceTriggerHooks(
            showLocalLLMSetup: $showLocalLLMSetup,
            showVoiceMode: $showVoiceMode,
            characterViewModel: characterViewModel,
            chatViewModel: chatViewModel
        ))
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
        .onReceive(NotificationCenter.default.publisher(for: .claudyLocalFallback)) { note in
            let from = (note.userInfo?["from"] as? String) ?? "local"
            let to   = (note.userInfo?["to"]   as? String) ?? "cloud"
            characterViewModel.showBubbleDirect(
                "\(from.capitalized) offline — using \(to.capitalized).",
                duration: 5
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
            demoManager.prepare(character: characterViewModel, chat: chatViewModel, windowManager: windowManager)
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
        // Tap while sleeping → wake up (don't open chat until a second tap)
        if characterViewModel.animationState == .sleeping {
            characterViewModel.setState(.idle)
            return
        }
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

    // Extracted to keep `body` under the type-checker's complexity budget.
    private struct VoiceAndLocalLLMSheets: ViewModifier {
        @Binding var showLocalLLMSetup: Bool
        @Binding var showVoiceMode: Bool
        let chatViewModel: ChatViewModel
        let characterViewModel: CharacterViewModel
        func body(content: Content) -> some View {
            content
                .sheet(isPresented: $showLocalLLMSetup) {
                    LocalLLMSetupSheet(isPresented: $showLocalLLMSetup)
                }
                .sheet(isPresented: $showVoiceMode) {
                    VoiceModeSheet(
                        isPresented: $showVoiceMode,
                        chatViewModel: chatViewModel,
                        characterViewModel: characterViewModel
                    )
                }
        }
    }

    private struct VoiceTriggerHooks: ViewModifier {
        @Binding var showLocalLLMSetup: Bool
        @Binding var showVoiceMode: Bool
        let characterViewModel: CharacterViewModel
        let chatViewModel:      ChatViewModel       // V4 — needed for voice-loop transcript send
        func body(content: Content) -> some View {
            content
                .onReceive(NotificationCenter.default.publisher(for: .claudyShowLocalLLMSetup)) { _ in
                    showLocalLLMSetup = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .claudyShowVoiceMode)) { _ in
                    // V4: compact overlay panel docked BELOW Claudy (not full sheet).
                    VoiceOverlayController.shared.toggle()
                }
                .onReceive(NotificationCenter.default.publisher(for: .claudyVoiceDidStartSpeaking)) { _ in
                    characterViewModel.setTalking()
                }
                .onReceive(NotificationCenter.default.publisher(for: .claudyVoiceDidFinishSpeaking)) { _ in
                    characterViewModel.stopTalking()
                }
                .onReceive(NotificationCenter.default.publisher(for: .claudyVoiceStateChanged)) { note in
                    guard let s = note.object as? VoiceModeManager.VoiceCharacterState else { return }
                    switch s {
                    case .listening: characterViewModel.setVoiceListening()
                    case .thinking:  characterViewModel.setThinking()
                    case .speaking:  characterViewModel.setVoiceSpeaking()
                    case .off:       characterViewModel.endVoiceMode()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .claudyVoiceTranscriptReady)) { note in
                    // V4 voice-mode: transcript ready → push into chat & send.
                    guard let text = note.object as? String, !text.isEmpty else { return }
                    chatViewModel.inputText = text
                    chatViewModel.isOpen = true
                    chatViewModel.send()
                }
                .onChange(of: chatViewModel.isStreaming) { _, streaming in
                    // V4 voice-mode: when chat finishes streaming, speak the
                    // last assistant reply via TTS so Claudy actually answers.
                    let mgr = VoiceModeManager.shared
                    guard mgr.isVoiceModeActive, !streaming, mgr.isChatProcessing else { return }
                    mgr.isChatProcessing = false
                    if let last = chatViewModel.messages.last,
                       last.role == .assistant,
                       !last.content.isEmpty {
                        VoiceManager.shared.speak(last.content)
                    }
                }
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
