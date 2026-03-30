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
    @State private var showFocusAdder = false
    @State private var focusAdderDefaultType: FocusToolAdderSheet.ToolType = .reminder
    @State private var showScratchpad = false
    @AppStorage("CharacterOpacity")   private var characterOpacity: Double = 1.0
    @AppStorage("TimerBadgeScale")    private var timerBadgeScale: Double = 1.0

    var body: some View {
        characterScene
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
        // Quick-action button — contextual prompt for the frontmost app
        .overlay(alignment: .top) {
            if let action = QuickActionManager.shared.currentAction {
                Button {
                    QuickActionManager.shared.actionTapped()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: action.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(action.label)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(Color(red: 0.784, green: 0.361, blue: 0.220).opacity(0.92))
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8, anchor: .top).combined(with: .opacity),
                    removal:   .scale(scale: 0.8, anchor: .top).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: QuickActionManager.shared.currentAction?.label)
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

        // ── Personality ──────────────────────────────────────────────────────
        Menu {
            ForEach(PersonalityMode.allCases, id: \.self) { mode in
                Button {
                    guard mode != PersonalityManager.shared.currentMode else { return }
                    PersonalityManager.shared.currentMode = mode
                    chatViewModel.announcePersonalityChange(to: mode)
                } label: {
                    Label(
                        mode.displayName,
                        systemImage: PersonalityManager.shared.currentMode == mode
                            ? "checkmark" : personalityIcon(mode)
                    )
                }
            }
        } label: { Label("Personality", systemImage: "theatermasks") }

        // ── Mode ─────────────────────────────────────────────────────────────
        Menu {
            ForEach(BehaviorMode.allCases, id: \.self) { mode in
                Button {
                    characterViewModel.behaviorModeManager.activate(mode)
                } label: {
                    Label(
                        mode.displayName,
                        systemImage: characterViewModel.behaviorModeManager.currentMode == mode
                            ? "checkmark" : modeIcon(mode)
                    )
                }
            }
        } label: { Label("Mode", systemImage: "dial.high") }

        // ── Size ─────────────────────────────────────────────────────────────
        Menu {
            ForEach(WindowManager.SizePreset.allCases, id: \.self) { preset in
                Button {
                    windowManager.sizePreset = preset
                } label: {
                    Label(
                        preset.displayName,
                        systemImage: windowManager.sizePreset == preset ? "checkmark" : "circle"
                    )
                }
            }
        } label: { Label("Size", systemImage: "arrow.up.left.and.arrow.down.right") }

        Divider()

        // ── Focus Tools ───────────────────────────────────────────────────────
        let pom: PomodoroManager = characterViewModel.pomodoroManager
        Menu {

            // — Pomodoro —
            switch pom.state {
            case .idle, .complete:
                Menu {
                    Button { pom.selectedPreset = .short;   pom.start() } label: { Label("Short — 15 min",   systemImage: "15.circle") }
                    Button { pom.selectedPreset = .classic; pom.start() } label: { Label("Classic — 25 min", systemImage: "25.circle") }
                    Button { pom.selectedPreset = .long;    pom.start() } label: { Label("Long — 45 min",    systemImage: "45.circle") }
                    Button { pom.selectedPreset = .deep;    pom.start() } label: { Label("Deep — 60 min",    systemImage: "60.circle") }
                    Divider()
                    Button { pom.selectedPreset = .custom;  pom.start() } label: { Label("Custom — \(pom.customMinutes) min", systemImage: "slider.horizontal.3") }
                } label: { Label("Start Pomodoro", systemImage: "timer") }
            case .running:
                Button { pom.pause() } label: { Label("Pause  (\(pom.displayTime))", systemImage: "pause.circle.fill") }
                Button { pom.stop()  } label: { Label("Stop Timer",                  systemImage: "stop.circle") }
            case .paused:
                Button { pom.resume() } label: { Label("Resume  (\(pom.displayTime))", systemImage: "play.circle.fill") }
                Button { pom.stop()   } label: { Label("Stop Timer",                   systemImage: "stop.circle") }
            }

            Divider()

            // — Alarm —
            Menu {
                Button { addQuickAlarm(minutes: 5)   } label: { Label("In 5 minutes",  systemImage: "5.circle") }
                Button { addQuickAlarm(minutes: 10)  } label: { Label("In 10 minutes", systemImage: "10.circle") }
                Button { addQuickAlarm(minutes: 15)  } label: { Label("In 15 minutes", systemImage: "15.circle") }
                Button { addQuickAlarm(minutes: 30)  } label: { Label("In 30 minutes", systemImage: "30.circle") }
                Button { addQuickAlarm(minutes: 60)  } label: { Label("In 1 hour",     systemImage: "1.circle") }
                Button { addQuickAlarm(minutes: 120) } label: { Label("In 2 hours",    systemImage: "2.circle") }
                Button { addQuickAlarm(minutes: 240) } label: { Label("In 4 hours",    systemImage: "4.circle") }
                Divider()
                Button {
                    focusAdderDefaultType = .alarm
                    showFocusAdder = true
                } label: { Label("Set Custom Alarm…", systemImage: "alarm.waves.left.and.right") }
            } label: { Label("Set Alarm", systemImage: "alarm") }

            // — Reminders —
            let pending = characterViewModel.alarmReminderManager.reminders.filter { !$0.fired }
            Menu {
                Button {
                    focusAdderDefaultType = .reminder
                    showFocusAdder = true
                } label: { Label("New Reminder…", systemImage: "plus.circle.fill") }

                if !pending.isEmpty {
                    Divider()
                    ForEach(pending) { reminder in
                        let timeStr: String = {
                            let f = DateFormatter()
                            f.timeStyle = .short
                            f.dateStyle = reminder.fireDate.timeIntervalSinceNow > 86400 ? .short : .none
                            return f.string(from: reminder.fireDate)
                        }()
                        Button {
                            characterViewModel.alarmReminderManager.remove(id: reminder.id)
                        } label: {
                            Label("\(timeStr) — \(reminder.title)", systemImage: "xmark.circle")
                        }
                    }
                    Divider()
                    Button {
                        characterViewModel.alarmReminderManager.clearFired()
                        for r in pending { characterViewModel.alarmReminderManager.remove(id: r.id) }
                    } label: { Label("Clear All", systemImage: "trash") }
                }
            } label: {
                Label(
                    pending.isEmpty ? "Reminders" : "Reminders  (\(pending.count))",
                    systemImage: "checklist"
                )
            }

            // — Stats footer —
            let stats = FocusStatsManager.shared
            if stats.pomodorosToday > 0 {
                Divider()
                Text(stats.summaryLine)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

        } label: { Label("Focus Tools", systemImage: "target") }

        Divider()

        // ── Quick Launch ──────────────────────────────────────────────────────
        let shortcuts = QuickLaunchManager.shared.shortcuts
        if !shortcuts.isEmpty {
            Menu {
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
            } label: { Label("Launch", systemImage: "bolt") }
            Divider()
        }

        // ── Actions ───────────────────────────────────────────────────────────
        Button {
            windowManager.resetPosition()
        } label: { Label("Reset Position", systemImage: "arrow.clockwise") }

        Button {
            if characterViewModel.animationState == .sleeping {
                characterViewModel.setState(.idle)
            } else {
                characterViewModel.setState(.sleeping)
            }
        } label: {
            Label(
                characterViewModel.animationState == .sleeping ? "Wake Up" : "Sleep",
                systemImage: characterViewModel.animationState == .sleeping ? "sun.max" : "moon.zzz"
            )
        }

        Button {
            characterViewModel.setMuted(!characterViewModel.isMuted)
        } label: {
            Label(
                characterViewModel.isMuted ? "Unmute" : "Mute",
                systemImage: characterViewModel.isMuted ? "speaker.wave.2" : "speaker.slash"
            )
        }
        .keyboardShortcut("m", modifiers: .option)

        Button {
            characterViewModel.roastMe()
        } label: { Label("Roast Me", systemImage: "flame") }
        .disabled(characterViewModel.roastModeManager.isRoasting)

        Button {
            if demoManager.isRunning { demoManager.stop() } else { demoManager.start() }
        } label: {
            Label(
                demoManager.isRunning ? "Stop Demo" : "Start Demo",
                systemImage: demoManager.isRunning ? "stop.circle" : "play.rectangle"
            )
        }

        Divider()

        // ── Settings & help ───────────────────────────────────────────────────
        Button {
            NotificationCenter.default.post(name: .claudyOpenSettings, object: nil)
        } label: { Label("Settings…", systemImage: "gear") }

        Button { showScratchpad = true } label: { Label("Scratchpad", systemImage: "note.text") }

        Button { showHelp = true } label: { Label("Help", systemImage: "questionmark.circle") }

        Button { showDonate = true } label: { Label("Support Claud-y…", systemImage: "heart") }

        Divider()

        Button("Quit Claud-y", role: .destructive) {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Context menu helpers

    private func addQuickAlarm(minutes: Int) {
        let fireDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        let label = minutes < 60
            ? "Alarm — \(minutes) min"
            : "Alarm — \(minutes / 60) hr"
        characterViewModel.alarmReminderManager.add(title: label, fireDate: fireDate)
    }

    private func personalityIcon(_ mode: PersonalityMode) -> String {
        switch mode {
        case .companion:  return "heart"
        case .chatty:     return "bubble.left.and.bubble.right"
        case .hypeCoach:  return "bolt.fill"
        case .director:   return "megaphone"
        case .mate:       return "hand.wave"
        case .listener:   return "ear"
        case .custom:     return "pencil"
        }
    }

    private func modeIcon(_ mode: BehaviorMode) -> String {
        switch mode {
        case .normal:   return "circle"
        case .study:    return "book"
        case .dev:      return "terminal"
        case .work:     return "briefcase"
        case .dance:    return "music.note"
        case .brainRot: return "brain.head.profile"
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

// MARK: - FocusToolAdderSheet

private struct FocusToolAdderSheet: View {
    enum ToolType: String, CaseIterable {
        case alarm    = "Alarm"
        case reminder = "Reminder"
    }

    @Binding var isPresented: Bool
    let manager: AlarmReminderManager

    @State private var toolType: ToolType
    @State private var title: String = ""
    @State private var date: Date = Date().addingTimeInterval(30 * 60)

    init(isPresented: Binding<Bool>, manager: AlarmReminderManager, defaultType: ToolType = .reminder) {
        self._isPresented = isPresented
        self.manager = manager
        self._toolType = State(initialValue: defaultType)
    }

    private var isAlarm: Bool { toolType == .alarm }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: isAlarm ? "alarm.fill" : "checklist")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.784, green: 0.361, blue: 0.220))
                Text(isAlarm ? "Set Alarm" : "New Reminder")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                // Type picker
                Picker("", selection: $toolType) {
                    ForEach(ToolType.allCases, id: \.self) { t in
                        Label(t.rawValue, systemImage: t == .alarm ? "alarm" : "checklist")
                            .tag(t)
                    }
                }
                .pickerStyle(.segmented)

                // Title field
                VStack(alignment: .leading, spacing: 4) {
                    Text(isAlarm ? "Label (optional)" : "What to remind you")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField(isAlarm ? "e.g. Stand up, check build…" : "e.g. Review PR, call back…", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }

                // Date / time picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("When")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }

                // Confirm button
                Button {
                    let label = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let finalTitle = label.isEmpty
                        ? (isAlarm ? "Alarm" : "Reminder")
                        : label
                    manager.add(title: finalTitle, fireDate: date)
                    isPresented = false
                } label: {
                    Label(isAlarm ? "Set Alarm" : "Set Reminder",
                          systemImage: isAlarm ? "alarm.fill" : "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.784, green: 0.361, blue: 0.220))
                .disabled(!isAlarm && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 280)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - ScratchpadSheet

private struct ScratchpadSheet: View {
    @Binding var isPresented: Bool
    @State private var newNoteText: String = ""
    @State private var editingID: UUID? = nil

    private let manager = ScratchpadManager.shared
    private let orange  = Color(red: 0.784, green: 0.361, blue: 0.220)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(orange)
                Text("Scratchpad")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            Divider()

            // New note input
            HStack(spacing: 8) {
                TextField("Jot something down…", text: $newNoteText, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit { commitNewNote() }
                Button {
                    commitNewNote()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : orange)
                }
                .buttonStyle(.plain)
                .disabled(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Notes list
            if manager.notes.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 28))
                        .foregroundStyle(.quaternary)
                    Text("No notes yet.\nJot something above.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(manager.notes) { note in
                            NoteRow(note: note, manager: manager)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 260)
            }
        }
        .frame(width: 300)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func commitNewNote() {
        let text = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        manager.addNote(text)
        newNoteText = ""
    }
}

private struct NoteRow: View {
    let note: ScratchpadNote
    let manager: ScratchpadManager
    @State private var isEditing = false
    @State private var editText: String = ""
    private let orange = Color(red: 0.784, green: 0.361, blue: 0.220)

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if note.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(orange)
                    .padding(.top, 3)
            }

            if isEditing {
                TextField("", text: $editText, axis: .vertical)
                    .lineLimit(1...5)
                    .font(.system(size: 12))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { commitEdit() }
            } else {
                Text(note.text)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture(count: 2) {
                        editText = note.text
                        isEditing = true
                    }
            }

            Spacer(minLength: 0)

            Menu {
                Button {
                    manager.togglePin(id: note.id)
                } label: {
                    Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
                }
                Button {
                    editText = note.text
                    isEditing = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive) {
                    manager.deleteNote(id: note.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(4)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(note.isPinned ? orange.opacity(0.06) : Color.clear)
    }

    private func commitEdit() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { manager.updateNote(id: note.id, text: trimmed) }
        isEditing = false
    }
}
