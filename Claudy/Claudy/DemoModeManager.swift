import AppKit
import SwiftUI
import OSLog

/// Scripted demo mode for promotional screen recordings.
/// Runs a self-contained ~32-second sequence with no API calls.
///
/// Activation:
///   - Right-click Claud-y -> Start Demo
///   - Hold Shift + Option + D for 1 second
///   - Developer > Start Demo Mode (debug builds only)
@Observable
@MainActor
final class DemoModeManager {

    // MARK: - Observable state (drives UI in CharacterRootView)
    var isRunning = false

    // MARK: - Internals
    private var demoTask:    Task<Void, Never>?
    private var keyHoldTask: Task<Void, Never>?

    @ObservationIgnored nonisolated(unsafe) private var shortcutMonitor: Any?
    @ObservationIgnored nonisolated(unsafe) private var interruptMonitor: Any?

    private weak var character: CharacterViewModel?
    private weak var chat:      ChatViewModel?

    private let logger = Logger(subsystem: "com.claudy", category: "Demo")

    // MARK: - Setup

    /// Wire up model refs and the keyboard shortcut global monitor.
    /// Call once from CharacterRootView.onAppear.
    func prepare(character: CharacterViewModel, chat: ChatViewModel) {
        self.character = character
        self.chat      = chat
        setupShortcutMonitor()
    }

    private func setupShortcutMonitor() {
        guard shortcutMonitor == nil else { return }
        shortcutMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            Task { @MainActor [weak self] in self?.handleShortcutEvent(event) }
        }
        if shortcutMonitor == nil {
            logger.warning("Input Monitoring not granted - demo keyboard shortcut disabled. Use Developer menu instead.")
        }
    }

    private func handleShortcutEvent(_ event: NSEvent) {
        let flags     = event.modifierFlags
        let isShift   = flags.contains(.shift)
        let isOption  = flags.contains(.option)
        let isD       = event.charactersIgnoringModifiers?.lowercased() == "d"

        if event.type == .keyDown && isShift && isOption && isD && !isRunning {
            guard keyHoldTask == nil else { return }
            keyHoldTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1.0))
                guard !Task.isCancelled, self?.isRunning == false else { return }
                self?.start()
            }
        } else if event.type == .keyUp {
            keyHoldTask?.cancel()
            keyHoldTask = nil
        }
    }

    // MARK: - Start / Stop

    func start() {
        guard !isRunning, let character, let chat else {
            logger.warning("Demo start called but not ready - isRunning=\(self.isRunning), character=\(self.character != nil), chat=\(self.chat != nil)")
            return
        }
        logger.info("Demo mode starting")
        isRunning = true
        stopInterruptMonitor()
        startInterruptMonitor()
        DemoMusicPlayer.shared.play()

        demoTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.runSequence(character: character, chat: chat)
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

    // MARK: - Demo sequence

    private func runSequence(character: CharacterViewModel, chat: ChatViewModel) async {

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

    // MARK: - Helpers

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
