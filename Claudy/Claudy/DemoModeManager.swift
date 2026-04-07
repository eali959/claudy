import AppKit
import SwiftUI
import OSLog

/// Scripted demo mode for promotional screen recordings.
/// Supports two variants:
///   - .v1 — Original ~32-second sequence (Shift+Option+D or right-click → V1 Demo)
///   - .v2 — Extended ~55-second sequence with side labels (Shift+Option+V or right-click → V2 Demo)
///
/// Both variants run from a single manager instance.
@Observable
@MainActor
final class DemoModeManager {

    // MARK: - Demo variant

    enum DemoVariant { case v1, v2 }

    // MARK: - Observable state (drives UI in CharacterRootView / CharacterSceneView)

    var isRunning = false

    /// Floating annotation shown to the right of Claud-y during V2 scenes. Nil during V1 and when not running.
    var sideLabel: SideLabel? = nil

    struct SideLabel: Equatable {
        let title: String
        let items: [String]
        var activeItem: String? = nil
    }

    // MARK: - Internals

    private var demoTask:    Task<Void, Never>?
    private var keyHoldTask: Task<Void, Never>?

    @ObservationIgnored nonisolated(unsafe) private var v1ShortcutMonitor: Any?
    @ObservationIgnored nonisolated(unsafe) private var v2ShortcutMonitor: Any?
    @ObservationIgnored nonisolated(unsafe) private var interruptMonitor: Any?

    private weak var character: CharacterViewModel?
    private weak var chat:      ChatViewModel?

    private var savedMode: BehaviorMode = .normal

    private let logger = Logger(subsystem: "com.claudy", category: "Demo")

    // MARK: - Setup

    /// Wire up model refs and keyboard shortcut monitors.
    /// Call once from CharacterRootView.onAppear.
    func prepare(character: CharacterViewModel, chat: ChatViewModel) {
        self.character = character
        self.chat      = chat
        setupShortcutMonitors()
    }

    private func setupShortcutMonitors() {
        // V1: Hold Shift+Option+D for 1 second
        guard v1ShortcutMonitor == nil else { return }
        v1ShortcutMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            Task { @MainActor [weak self] in self?.handleV1ShortcutEvent(event) }
        }
        if v1ShortcutMonitor == nil {
            logger.warning("Input Monitoring not granted - V1 demo keyboard shortcut disabled.")
        }

        // V2: Hold Shift+Option+V for 1 second
        v2ShortcutMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            Task { @MainActor [weak self] in self?.handleV2ShortcutEvent(event) }
        }
    }

    private func handleV1ShortcutEvent(_ event: NSEvent) {
        let flags     = event.modifierFlags
        let isShift   = flags.contains(.shift)
        let isOption  = flags.contains(.option)
        let isD       = event.charactersIgnoringModifiers?.lowercased() == "d"

        if event.type == .keyDown && isShift && isOption && isD && !isRunning {
            guard keyHoldTask == nil else { return }
            keyHoldTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1.0))
                guard !Task.isCancelled, self?.isRunning == false else { return }
                self?.start(.v1)
            }
        } else if event.type == .keyUp {
            keyHoldTask?.cancel()
            keyHoldTask = nil
        }
    }

    private func handleV2ShortcutEvent(_ event: NSEvent) {
        let flags    = event.modifierFlags
        let isShift  = flags.contains(.shift)
        let isOption = flags.contains(.option)
        let isV      = event.charactersIgnoringModifiers?.lowercased() == "v"

        if event.type == .keyDown && isShift && isOption && isV && !isRunning {
            guard keyHoldTask == nil else { return }
            keyHoldTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1.0))
                guard !Task.isCancelled, self?.isRunning == false else { return }
                self?.start(.v2)
            }
        } else if event.type == .keyUp {
            keyHoldTask?.cancel()
            keyHoldTask = nil
        }
    }

    // MARK: - Start / Stop

    func start(_ variant: DemoVariant = .v1) {
        guard !isRunning, let character, let chat else {
            logger.warning("Demo start called but not ready - isRunning=\(self.isRunning), character=\(self.character != nil), chat=\(self.chat != nil)")
            return
        }
        logger.info("Demo mode starting (\(variant == .v1 ? "V1" : "V2"))")
        if variant == .v2 { savedMode = character.behaviorModeManager.currentMode }
        isRunning = true
        stopInterruptMonitor()
        startInterruptMonitor()
        DemoMusicPlayer.shared.play()

        demoTask = Task { @MainActor [weak self] in
            guard let self else { return }
            switch variant {
            case .v1: await self.runV1Sequence(character: character, chat: chat)
            case .v2: await self.runV2Sequence(character: character, chat: chat)
            }
            if self.isRunning { self.stop() }
        }
    }

    func stop() {
        demoTask?.cancel()
        demoTask = nil
        stopInterruptMonitor()
        DemoMusicPlayer.shared.fadeOutAndStop()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { chat?.isOpen = false }
        character?.dismissBubble()
        character?.pomodoroManager.stop()
        withAnimation(.easeInOut(duration: 0.25)) { character?.irisOffset = .zero }
        character?.setState(.idle)
        chat?.removeDemoMessages()
        character?.behaviorModeManager.activate(savedMode)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { sideLabel = nil }

        isRunning = false
        logger.info("Demo mode stopped")
    }

    // MARK: - Interrupt monitoring

    private func startInterruptMonitor() {
        guard interruptMonitor == nil else { return }
        interruptMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self?.isRunning == true else { return }
                self?.stop()
            }
        }
    }

    private func stopInterruptMonitor() {
        if let m = interruptMonitor { NSEvent.removeMonitor(m) }
        interruptMonitor = nil
    }

    // MARK: - V2 side label helpers

    private func showLabel(_ title: String, items: [String], active: String? = nil) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            sideLabel = SideLabel(title: title, items: items, activeItem: active)
        }
    }

    private func highlightItem(_ item: String) {
        guard let current = sideLabel else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            sideLabel = SideLabel(title: current.title, items: current.items, activeItem: item)
        }
    }

    private func hideLabel() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { sideLabel = nil }
    }

    // MARK: - V1 Demo sequence (~32 seconds)

    private func runV1Sequence(character: CharacterViewModel, chat: ChatViewModel) async {

        // ── Beat 1 - 0.0s: Wave + name melody + first hello ─────────────────
        character.wave()
        character.sayName()                       // plays "Claud-y" two-tone melody
        guard await wait(0.45) else { return }    // let the name tones ring out first
        character.showBubbleDirect("Oh! Hello.", duration: 1.8)

        look(character, x: 10, y: -3)
        guard await wait(0.55) else { return }
        look(character, x: -10, y: 2)
        guard await wait(0.55) else { return }
        lookCenter(character)
        guard await wait(1.0) else { return }

        // ── Beat 2 - 2.1s: Self-aware comedic beat ──────────────────────────
        character.showBubbleDirect("...I've been practising that.", duration: 3.0)
        guard await wait(3.8) else { return }   // extra pause for comedic beat to land

        // ── Beat 3 - 5.9s: Introduction ─────────────────────────────────────
        character.setTalking()
        character.showBubbleDirect(
            "I watch what you build. Celebrate the wins. Never mention the 200-line functions.",
            duration: 6.5   // long enough to read comfortably
        )
        look(character, x: 6, y: -3)
        guard await wait(1.6) else { return }
        look(character, x: -7, y: 2)
        guard await wait(1.6) else { return }
        lookCenter(character)
        guard await wait(1.4) else { return }
        character.stopTalking()
        guard await wait(0.9) else { return }

        // ── Beat 4 - 9.2s: Build failure ────────────────────────────────────
        character.facepalm()
        look(character, x: 4, y: 7)
        character.showBubbleDirect(
            "Build failed. 47 errors. The compiler is having opinions again.",
            duration: 3.5
        )
        guard await wait(2.5) else { return }
        lookCenter(character)
        character.setState(.idle)
        guard await wait(0.5) else { return }

        // ── Beat 5 - 12.2s: Clean build ─────────────────────────────────────
        character.celebrate()
        character.triggerConfetti()
        character.showBubbleDirect("Clean build. Do not. Touch. Anything.", duration: 3.5)
        look(character, x: 0, y: -9)
        guard await wait(0.55) else { return }
        look(character, x: 9, y: 0)
        guard await wait(0.45) else { return }
        lookCenter(character)
        character.nod()
        guard await wait(0.5) else { return }
        character.setState(.idle)
        guard await wait(1.4) else { return }

        // ── Beat 6 - 15.6s: Open chat ───────────────────────────────────────
        look(character, x: 0, y: 8)
        guard await wait(0.3) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { chat.isOpen = true }
        lookCenter(character)
        guard await wait(0.7) else { return }

        // ── Beat 7 - 16.6s: Chat exchange ───────────────────────────────────
        chat.injectMessage("I've been staring at this bug for an hour", role: .user)
        guard await wait(0.7) else { return }

        character.setThinking()
        look(character, x: -6, y: -6)
        guard await wait(1.3) else { return }

        chat.injectMessage(
            "One hour means you're close. What does the error actually say?",
            role: .assistant
        )
        character.setTalking()
        lookCenter(character)
        guard await wait(1.6) else { return }
        character.stopTalking()
        guard await wait(0.5) else { return }

        chat.injectMessage("oh it was a missing comma", role: .user)
        guard await wait(0.4) else { return }

        character.beSurprised()
        guard await wait(0.25) else { return }
        character.facepalm()
        guard await wait(0.45) else { return }
        character.celebrate()
        character.triggerConfetti()

        chat.injectMessage("It's always a comma. Ship it.", role: .assistant)
        look(character, x: 0, y: -8)
        guard await wait(0.9) else { return }
        lookCenter(character)
        character.stopTalking()
        guard await wait(0.9) else { return }

        // ── Beat 8 - 24.4s: Close chat ──────────────────────────────────────
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { chat.isOpen = false }
        guard await wait(0.5) else { return }
        character.setState(.idle)

        // Start the focus timer so the badge is visible during the mention
        character.pomodoroManager.selectedPreset = .classic
        character.pomodoroManager.start()

        look(character, x: 7, y: 0)
        character.showBubbleDirect(
            "Seven personalities. A focus timer. Right-click to explore.",
            duration: 4.5
        )
        guard await wait(0.8) else { return }
        lookCenter(character)
        guard await wait(3.0) else { return }

        // ── Beat 9 - 28.7s: Warm bookend ────────────────────────────────────
        character.wave()
        character.showBubbleDirect("I'll be here.", duration: 3.5)
        guard await wait(0.7) else { return }
        lookCenter(character)

        // Slow double blink - lingering goodbye
        guard await wait(0.8) else { return }
        character.isBlinking = true
        guard await wait(0.35) else { return }
        character.isBlinking = false
        guard await wait(0.45) else { return }
        character.isBlinking = true
        guard await wait(0.35) else { return }
        character.isBlinking = false

        guard await wait(1.0) else { return }

        // ── Wind down - 32.0s ────────────────────────────────────────────────
        character.setState(.sleeping)
        guard await wait(0.8) else { return }
        character.setState(.idle)
        // stop() called by the Task completion guard in start()
    }

    // MARK: - V2 Demo sequence (~55 seconds)

    private func runV2Sequence(character: CharacterViewModel, chat: ChatViewModel) async {

        // ── Scene 1 — Intro ──────────────────────────────────────────────────
        // 0.0s
        character.wave()
        SoundManager.shared.play(.bubblePop)
        character.showBubbleDirect("Hey. I'm Claud-y.", duration: 4.0)
        look(character, x: 8, y: -4)
        guard await wait(0.7) else { return }
        look(character, x: -8, y: 3)
        guard await wait(0.6) else { return }
        lookCenter(character)
        guard await wait(2.5) else { return }

        // 3.8s
        SoundManager.shared.play(.bubblePop)
        character.showBubbleDirect(
            "Seven personalities. Six modes.\nThree AIs. I've been busy.",
            duration: 5.5
        )
        guard await wait(6.0) else { return }

        // ── Scene 2 — All 6 Modes ─────────────────────────────────────────────
        // ~10s
        let allModes = ["Normal", "Study", "Dev", "Work", "Dance", "Brain Rot"]
        showLabel("6 Modes", items: allModes, active: "Normal")
        guard await wait(0.6) else { return }

        // Brain Rot
        character.behaviorModeManager.activate(.brainRot)
        highlightItem("Brain Rot")
        character.setState(.celebrating, duration: 0.6)
        SoundManager.shared.play(.bubblePop)
        character.showBubbleDirect(
            "bestie ur code is BUSSIN\nno cap fr 🔥  W coder energy",
            duration: 5.0
        )
        guard await wait(5.5) else { return }

        // Study
        character.behaviorModeManager.activate(.study)
        highlightItem("Study")
        character.setTalking()
        SoundManager.shared.play(.bubblePop)
        character.showBubbleDirect(
            "Deep work session.\nPomodoro helps consolidate memory — let's go.",
            duration: 4.5
        )
        look(character, x: -5, y: -3)
        guard await wait(2.5) else { return }
        lookCenter(character)
        guard await wait(2.5) else { return }
        character.stopTalking()

        // Dev
        character.behaviorModeManager.activate(.dev)
        highlightItem("Dev")
        SoundManager.shared.play(.bubblePop)
        character.showBubbleDirect(
            "Flow state detected. 19 minutes in.\nDon't you dare open Twitter.",
            duration: 4.5
        )
        guard await wait(5.0) else { return }

        // Work
        character.behaviorModeManager.activate(.work)
        highlightItem("Work")
        SoundManager.shared.play(.bubblePop)
        character.showBubbleDirect(
            "Zoom call in 10.\nDeck looks solid. You've got this.",
            duration: 4.0
        )
        guard await wait(4.5) else { return }

        // Dance — moment of joy, no bubble needed
        character.behaviorModeManager.activate(.dance)
        highlightItem("Dance")
        character.setState(.dancing)
        guard await wait(2.5) else { return }
        character.setState(.idle)

        // Back to Normal
        character.behaviorModeManager.activate(.normal)
        highlightItem("Normal")
        guard await wait(0.6) else { return }
        hideLabel()
        guard await wait(0.5) else { return }

        // ── Scene 3 — Focus Tools ─────────────────────────────────────────────
        // ~36s
        showLabel("Focus Tools", items: ["Pomodoro", "Alarms", "Break Nudges"], active: "Pomodoro")
        character.pomodoroManager.selectedPreset = .classic
        character.pomodoroManager.start()
        SoundManager.shared.play(.cleanBuild)
        guard await wait(0.6) else { return }
        character.showBubbleDirect("25-minute focus session started.", duration: 4.0)
        character.nod()
        guard await wait(4.5) else { return }

        highlightItem("Break Nudges")
        SoundManager.shared.play(.bubblePop)
        character.showBubbleDirect(
            "I'll nudge you at 90 minutes\nif you forget to breathe.",
            duration: 4.5
        )
        guard await wait(5.0) else { return }
        hideLabel()
        character.pomodoroManager.stop()
        guard await wait(0.4) else { return }

        // ── Scene 4 — AI Chat + 3 Providers ──────────────────────────────────
        // ~46s
        showLabel("AI Chat", items: ["Claude", "ChatGPT", "Gemini"])
        look(character, x: 0, y: 8)
        guard await wait(0.3) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { chat.isOpen = true }
        SoundManager.shared.play(.chatOpen)
        lookCenter(character)
        guard await wait(1.0) else { return }

        chat.injectMessage("I've been staring at this bug for two hours", role: .user)
        guard await wait(0.8) else { return }

        character.setThinking()
        look(character, x: -6, y: -6)
        guard await wait(1.8) else { return }

        chat.injectMessage(
            "Step away for five minutes.\nThe answer is already in your head — it just hasn't surfaced yet.",
            role: .assistant
        )
        character.setTalking()
        SoundManager.shared.play(.bubblePop)
        lookCenter(character)
        guard await wait(5.0) else { return }
        character.stopTalking()
        guard await wait(0.5) else { return }

        chat.injectMessage("...you were right", role: .user)
        guard await wait(0.5) else { return }

        character.beSurprised()
        guard await wait(0.3) else { return }
        character.celebrate()
        character.triggerConfetti()
        SoundManager.shared.play(.celebrate)
        chat.injectMessage("Always am. Now commit it and go outside.", role: .assistant)
        look(character, x: 0, y: -8)
        guard await wait(0.8) else { return }
        lookCenter(character)
        character.stopTalking()
        guard await wait(3.5) else { return }

        hideLabel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { chat.isOpen = false }
        guard await wait(0.5) else { return }

        // ── Scene 5 — CTA ─────────────────────────────────────────────────────
        // ~63s
        showLabel("Free. Forever.", items: ["No account", "No API key", "No setup"])
        character.setState(.idle)
        character.wave()
        SoundManager.shared.play(.bubblePop)
        character.showBubbleDirect(
            "No subscription. No account.\nNo API key needed to start.",
            duration: 5.5
        )
        guard await wait(1.0) else { return }
        lookCenter(character)
        guard await wait(5.0) else { return }

        SoundManager.shared.play(.bubblePop)
        character.showBubbleDirect("Just you and me.", duration: 4.0)

        // Slow double blink — warm goodbye
        guard await wait(1.2) else { return }
        character.isBlinking = true
        guard await wait(0.38) else { return }
        character.isBlinking = false
        guard await wait(0.48) else { return }
        character.isBlinking = true
        guard await wait(0.38) else { return }
        character.isBlinking = false

        guard await wait(1.2) else { return }

        // ── Wind down ──────────────────────────────────────────────────────────
        hideLabel()
        character.setState(.sleeping)
        guard await wait(0.8) else { return }
        character.setState(.idle)
    }

    // MARK: - Shared helpers

    private func look(_ character: CharacterViewModel, x: CGFloat, y: CGFloat) {
        withAnimation(.easeInOut(duration: 0.25)) {
            character.irisOffset = CGPoint(x: x, y: y)
        }
    }

    private func lookCenter(_ character: CharacterViewModel) {
        withAnimation(.easeInOut(duration: 0.2)) {
            character.irisOffset = .zero
        }
    }

    /// Cancellation-safe sleep. Returns false if task was cancelled or demo was stopped.
    private func wait(_ seconds: Double) async -> Bool {
        guard isRunning else { return false }
        do {
            try await Task.sleep(for: .seconds(seconds))
            return isRunning && !Task.isCancelled
        } catch {
            return false
        }
    }
}
