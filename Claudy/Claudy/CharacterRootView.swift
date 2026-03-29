import SwiftUI
import AppKit

/// Root view hosted inside the floating NSPanel.
struct CharacterRootView: View {
    @Environment(WindowManager.self) private var windowManager
    @State private var chatViewModel = ChatViewModel()
    @State private var characterViewModel = CharacterViewModel()

    @State private var showReactionLog = false
    @State private var demoManager = DemoModeManager()
    @State private var showHelp = false
    @State private var showDonate = false
    @AppStorage("CharacterOpacity")   private var characterOpacity: Double = 1.0
    @AppStorage("TimerBadgeScale")    private var timerBadgeScale: Double = 1.0

    var body: some View {
        characterScene
        .onAppear {
            characterViewModel.setup(windowManager: windowManager)
            demoManager.prepare(character: characterViewModel, chat: chatViewModel)
        }
        .onChange(of: chatViewModel.isOpen) { _, open in
            // Keep CharacterViewModel in sync so it can suppress ambient bubbles
            characterViewModel.isChatOpen = open
        }
        .onChange(of: chatViewModel.isTyping) { _, thinking in
            if thinking {
                characterViewModel.setThinking()
            } else if !chatViewModel.isStreaming {
                // Local reply finished - return to idle
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
        // Help popover (triggered from context menu Help item)
        .popover(isPresented: $showHelp, arrowEdge: .top) {
            HelpView()
        }
        .popover(isPresented: $showDonate, arrowEdge: .top) {
            DonatePopoverView()
        }
        // Reaction log popover
        .popover(isPresented: $showReactionLog, arrowEdge: .top) {
            ReactionLogView(entries: characterViewModel.reactionLog) {
                showReactionLog = false
            }
        }
    }

    // MARK: - Scene (extracted to help Swift type-checker with large modifier chain)

    private var characterScene: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // Chat panel
                if chatViewModel.isOpen {
                    ChatView(viewModel: chatViewModel)
                        .frame(width: WindowManager.chatWidth, height: windowManager.chatHeight)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal:   .move(edge: .bottom).combined(with: .opacity)
                        ))
                }

                // Character + speech bubble + timer badge
                VStack(spacing: 4) {

                    // Speech bubble - sits in its own layout row above the character
                    if let bubble = characterViewModel.speechBubbleText {
                        SpeechBubbleView(text: bubble) {
                            characterViewModel.dismissBubble()
                        }
                        .padding(.bottom, 2)
                        .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .bottom)))
                        .zIndex(10)
                    }

                    // Character
                    ZStack {
                        ClaudyCharacterView(
                            animationState:  characterViewModel.animationState,
                            isBlinking:      characterViewModel.isBlinking,
                            irisOffset:      characterViewModel.irisOffset,
                            tickleIntensity: characterViewModel.tickleIntensity,
                            danceMove:       characterViewModel.danceModeManager.currentMove,
                            onTap:           handleTap,
                            onDoubleTap:     handleDoubleTap,
                            onDragBegan:     { windowManager.beginDrag(); characterViewModel.resetIdleTimer() },
                            onDragChanged:   { windowManager.updateDrag(translation: $0) },
                            onDragEnded:     windowManager.endDrag
                        )
                        .frame(width: WindowManager.characterSize, height: WindowManager.characterSize)
                        .scaleEffect(windowManager.characterScale)
                        .opacity(characterOpacity)
                        .accessibilityLabel("Claud-y")
                        .accessibilityValue(characterViewModel.animationState.accessibilityDescription)
                        .accessibilityHint("Tap to \(chatViewModel.isOpen ? "close" : "open") chat. Long press for reaction history.")
                        .accessibilityAddTraits(.isButton)
                        .overlay(alignment: .bottomTrailing) {
                            HStack(spacing: 2) {
                                if characterViewModel.isFocusModeActive {
                                    Text("🌙").font(.system(size: 12)).opacity(0.4)
                                }
                                if characterViewModel.isMuted {
                                    Text("🔇").font(.system(size: 12)).opacity(0.4)
                                }
                            }
                            .offset(x: -2, y: -2)
                            .allowsHitTesting(false)
                        }
                        .onHover { hovering in
                            characterViewModel.isHovered = hovering
                            if hovering {
                                characterViewModel.tickleManager.startHoverTimer()
                            } else {
                                characterViewModel.tickleManager.resetTickle()
                            }
                        }
                        // Long-press 3s reveals reaction log
                        .onLongPressGesture(minimumDuration: 3.0, maximumDistance: 20) {
                            showReactionLog = true
                        }
                        .contextMenu { characterContextMenu }

                        // Confetti overlay
                        if characterViewModel.showConfetti {
                            ConfettiView()
                                .offset(y: -30)
                                .transition(.opacity)
                                .zIndex(20)
                        }
                    } // ZStack (character)

                    // Timer badge - sits below the character body, never overlaps anything
                    if characterViewModel.pomodoroManager.state != .idle {
                        PomodoroTimerBadge(manager: characterViewModel.pomodoroManager)
                            .scaleEffect(timerBadgeScale)
                            .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .top)))
                            .onTapGesture(count: 2) {
                                guard !demoManager.isRunning else { demoManager.stop(); return }
                                characterViewModel.pomodoroManager.stop()
                                characterViewModel.showBubbleDirect("Timer reset.", duration: 3)
                            }
                            .onTapGesture(count: 1) {
                                guard !demoManager.isRunning else { demoManager.stop(); return }
                                let pom: PomodoroManager = characterViewModel.pomodoroManager
                                switch pom.state {
                                case .idle, .complete: pom.start()
                                case .running:         pom.pause()
                                case .paused:          pom.resume()
                                }
                            }
                    }

                } // VStack (bubble + character + badge)
            }
        }
        // DEMO pill - top-left corner, visible only during demo
        .overlay(alignment: .topLeading) {
            if demoManager.isRunning {
                Text("DEMO")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 5))
                    .opacity(0.55)
                    .padding(10)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        // Demo interrupt - any tap or drag while demo is running stops it immediately
        .overlay {
            if demoManager.isRunning {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { demoManager.stop() }
                    .gesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { _ in demoManager.stop() }
                    )
                    .allowsHitTesting(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(.clear)
        .animation(.spring(response: 0.35, dampingFraction: 0.8),
                   value: characterViewModel.speechBubbleText != nil)
        .animation(.easeInOut(duration: 0.3), value: characterViewModel.showConfetti)
    }

    // MARK: - Context menu (right-click on character)

    @ViewBuilder
    private var characterContextMenu: some View {
        // Personality
        Menu("Personality") {
            ForEach(PersonalityMode.allCases, id: \.self) { mode in
                Button(mode.displayName) {
                    guard mode != PersonalityManager.shared.currentMode else { return }
                    PersonalityManager.shared.currentMode = mode
                    chatViewModel.announcePersonalityChange(to: mode)
                }
            }
        }

        Menu("Size") {
            ForEach(WindowManager.SizePreset.allCases, id: \.self) { preset in
                Button {
                    windowManager.sizePreset = preset
                } label: {
                    Label(preset.displayName,
                          systemImage: windowManager.sizePreset == preset ? "checkmark" : "")
                }
            }
        }

        Divider()

        // Focus Timer - submenu when idle (pick duration + start), inline controls when active
        let pom: PomodoroManager = characterViewModel.pomodoroManager
        switch pom.state {
        case .idle, .complete:
            Menu("▶ Focus Timer") {
                Button("Short - 15 min")   { pom.selectedPreset = .short;   pom.start() }
                Button("Classic - 25 min") { pom.selectedPreset = .classic; pom.start() }
                Button("Long - 45 min")    { pom.selectedPreset = .long;    pom.start() }
                Button("Deep - 60 min")    { pom.selectedPreset = .deep;    pom.start() }
                Divider()
                Button("Custom - \(pom.customMinutes) min") {
                    pom.selectedPreset = .custom
                    pom.start()
                }
            }
        case .running:
            Button("⏸  Pause Timer  (\(pom.displayTime))") { pom.pause() }
            Button("⏹  Stop Timer") { pom.stop() }
        case .paused:
            Button("▶  Resume Timer  (\(pom.displayTime))") { pom.resume() }
            Button("⏹  Stop Timer") { pom.stop() }
        }

        Divider()

        let shortcuts = QuickLaunchManager.shared.shortcuts
        if !shortcuts.isEmpty {
            Menu("Launch") {
                ForEach(shortcuts) { shortcut in
                    let key = shortcut.shortcutKey.first
                    if let key {
                        Button(shortcut.name) {
                            QuickLaunchManager.shared.launch(shortcut)
                            characterViewModel.beSurprised()
                        }
                        .keyboardShortcut(KeyEquivalent(key), modifiers: .command)
                    } else {
                        Button(shortcut.name) {
                            QuickLaunchManager.shared.launch(shortcut)
                            characterViewModel.beSurprised()
                        }
                    }
                }
            }
            Divider()
        }

        Button("Reset Position") {
            windowManager.resetPosition()
        }

        Button(characterViewModel.animationState == .sleeping ? "Wake Up" : "Sleep") {
            if characterViewModel.animationState == .sleeping {
                characterViewModel.setState(.idle)
            } else {
                characterViewModel.setState(.sleeping)
            }
        }

        Button(characterViewModel.isMuted ? "Unmute" : "Mute") {
            characterViewModel.setMuted(!characterViewModel.isMuted)
        }
        .keyboardShortcut("m", modifiers: .option)

        Button(characterViewModel.danceModeManager.isActive ? "Stop Dancing" : "Dance Mode") {
            if characterViewModel.danceModeManager.isActive {
                characterViewModel.stopDanceMode()
            } else {
                characterViewModel.startDanceMode()
            }
        }

        Button(characterViewModel.roastModeManager.isRoasting ? "Roasting..." : "Roast Me") {
            characterViewModel.roastMe()
        }
        .disabled(characterViewModel.roastModeManager.isRoasting)

        Button(demoManager.isRunning ? "Stop Demo" : "Start Demo") {
            if demoManager.isRunning { demoManager.stop() } else { demoManager.start() }
        }

        Divider()

        Button("Settings…") {
            NotificationCenter.default.post(name: .claudyOpenSettings, object: nil)
        }

        Button("Help") {
            showHelp = true
        }

        Button("Support Claud-y...") {
            showDonate = true
        }

        Divider()

        Button("Quit Claud-y", role: .destructive) {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Donate popover

    private struct DonatePopoverView: View {
        private let orange = Color(red: 0.784, green: 0.361, blue: 0.220)

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("☕")
                        .font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("If Claud-y made your day a bit better...")
                            .font(.system(size: 13, weight: .semibold))
                        Text("It's free. It'll stay free. But coffee is fuel.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    if let url = URL(string: "https://ko-fi.com/ealiii") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Support on Ko-fi")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .background(orange, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Text("Ko-fi accepts any amount, one-time or recurring.\nNo account needed.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(width: 260)
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
}
