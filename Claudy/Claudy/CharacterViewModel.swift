import Foundation
import CoreGraphics
import Observation

// MARK: - MoodContext

enum MoodContext {
    case postBuildSuccess
    case postBuildFail
    case lateNight          // after midnight, when idle
    case npmRunning
    case zoomActive
    case vibeCoding
}

/// Central state and behaviour coordinator for the Claud-y character.
///
/// Owns animation state, speech bubble queue, blink loop, mute state, and the Pomodoro timer.
/// Monitor objects (idle, clipboard, keyboard, context, system events) are injected post-init
/// via `setup(windowManager:)` once the window is ready.
///
/// Speech bubbles go through a rate-limited queue: ambient bubbles respect `effectiveCooldown`
/// and `maxQueueDepth`, while direct bubbles (system messages) bypass both guards.
@MainActor
@Observable
final class CharacterViewModel {
    // MARK: - Observable state
    var animationState: CharacterAnimationState = .idle
    var isChatOpen = false
    var isBlinking = false
    var irisOffset: CGPoint = .zero
    var tickleIntensity: TickleIntensity = .none
    var isHovered = false
    var speechBubbleText: String? = nil
    var isMuted: Bool = UserDefaults.standard.bool(forKey: "IsMuted")
    var isFocusModeActive: Bool = false
    var showConfetti: Bool = false

    // MARK: - @ObservationIgnored internals
    @ObservationIgnored private(set) var tickleManager: TickleManager!
    @ObservationIgnored private var idleMonitor: IdleMonitor!
    @ObservationIgnored private var clipboardMonitor: ClipboardMonitor!
    @ObservationIgnored private var appContextMonitor: AppContextMonitor!
    @ObservationIgnored private(set) var pomodoroManager: PomodoroManager!

    @ObservationIgnored private var contextMonitor: ContextMonitor?
    @ObservationIgnored private var keyboardMonitor: KeyboardMonitor?
    @ObservationIgnored private var systemEventMonitor: SystemEventMonitor?

    @ObservationIgnored private var blinkTask: Task<Void, Never>?
    @ObservationIgnored private var speechTask: Task<Void, Never>?
    @ObservationIgnored private var queueDrainTask: Task<Void, Never>?
    @ObservationIgnored private var confettiTask: Task<Void, Never>?

    @ObservationIgnored private var baseState: CharacterAnimationState = .idle
    /// State to restore once a speech bubble's lip-sync ends.
    @ObservationIgnored private var preBubbleState: CharacterAnimationState = .idle

    // MARK: - Bubble queue + 45s rate limit
    private struct BubbleItem {
        let text: String
        let duration: TimeInterval
    }
    @ObservationIgnored private var bubbleQueue: [BubbleItem] = []
    @ObservationIgnored private var lastUnpromptedBubbleTime: Date = .distantPast
    private let baseBubbleCooldown: TimeInterval = 45
    private var effectiveCooldown: TimeInterval {
        let level = UserDefaults.standard.integer(forKey: "ChattinessLevel")
        let l = level < 1 ? 3 : min(level, 5)   // clamp to 1-5, default 3
        let multipliers: [Int: Double] = [1: 3.0, 2: 1.75, 3: 1.0, 4: 0.6, 5: 0.3]
        return baseBubbleCooldown * (multipliers[l] ?? 1.0)
    }
    private var maxQueueDepth: Int {
        let level = UserDefaults.standard.integer(forKey: "ChattinessLevel")
        let l = level < 1 ? 3 : min(level, 5)
        if l <= 2 { return 1 }
        if l <= 3 { return 3 }
        return 5
    }

    // MARK: - Reaction log
    private(set) var reactionLog: [(Date, String)] = []

    // MARK: - Init

    init() {
        tickleManager     = TickleManager(viewModel: self)
        idleMonitor       = IdleMonitor(viewModel: self)
        clipboardMonitor  = ClipboardMonitor(viewModel: self)
        appContextMonitor = AppContextMonitor(viewModel: self)
        pomodoroManager   = PomodoroManager(viewModel: self)
        startBlinkLoop()

        NotificationCenter.default.addObserver(
            forName: .claudyChatSendTapped,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.setState(.surprised, duration: 0.2)
                try? await Task.sleep(for: .milliseconds(220))
                self?.setThinking()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .claudyPersonalitySwitched,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.setState(.surprised, duration: 0.3)
            }
        }
    }

    // MARK: - Setup (call once WindowManager is ready)

    /// Wires up monitors that depend on the floating window being available.
    /// Must be called exactly once from CharacterRootView.onAppear.
    func setup(windowManager: WindowManager) {
        guard contextMonitor == nil else { return }
        contextMonitor     = ContextMonitor(viewModel: self, windowManager: windowManager)
        keyboardMonitor    = KeyboardMonitor(viewModel: self)
        systemEventMonitor = SystemEventMonitor(viewModel: self)
    }

    // MARK: - State helpers

    func setState(_ state: CharacterAnimationState, duration: TimeInterval? = nil) {
        animationState = state
        if let duration {
            Task {
                try? await Task.sleep(for: .seconds(duration))
                if animationState == state { animationState = baseState }
            }
        }
    }

    func setThinking() { baseState = .thinking; setState(.thinking) }
    func setTalking()  { baseState = .talking;  setState(.talking) }
    func stopTalking() { baseState = .idle;     setState(.idle) }

    func celebrate()   { setState(.celebrating, duration: 3.0) }
    func beConfused()  { setState(.confused,    duration: 2.5) }
    func beSurprised() { setState(.surprised,   duration: 1.5) }
    func nod()         { setState(.celebrating, duration: 0.5) }
    func wave()        { setState(.waving,      duration: 2.0) }
    func facepalm()    { setState(.facepalm,    duration: 2.5) }
    func sayName()     { MumbleEngine.shared.speakName() }

    // MARK: - Mood system

    func applyMood(for context: MoodContext) {
        switch context {
        case .postBuildSuccess:
            celebrate()
            triggerConfetti()
            SoundManager.shared.play(.cleanBuild)
        case .postBuildFail:
            facepalm()
        case .lateNight:
            if animationState == .idle { setState(.drowsy) }
        case .npmRunning:
            if animationState == .idle || animationState == .drowsy { setState(.thinking) }
        case .zoomActive:
            if animationState == .idle || animationState == .drowsy { setState(.alert) }
        case .vibeCoding:
            celebrate()
        }
    }

    // MARK: - Confetti

    func triggerConfetti() {
        confettiTask?.cancel()
        showConfetti = true
        SoundManager.shared.play(.celebrate)
        confettiTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }   // Bug fix: don't hide on re-trigger
            showConfetti = false
        }
    }

    // MARK: - Idle reset

    func resetIdleTimer() { idleMonitor.resetActivity() }

    // MARK: - Mute

    func setMuted(_ muted: Bool) {
        isMuted = muted
        UserDefaults.standard.set(muted, forKey: "IsMuted")
        if muted {
            // Slow blink to acknowledge mute
            Task { @MainActor in
                self.isBlinking = true
                try? await Task.sleep(for: .milliseconds(300))
                self.isBlinking = false
            }
        } else {
            // Excited wiggle on unmute
            setState(.tickled, duration: 0.4)
            let text = ReactionLibraryService.shared.reaction(for: .muteOff)
            if !text.isEmpty { displayBubble(text, duration: 4.0) }
        }
    }

    // MARK: - Speech bubble API

    func showBubbleDirect(_ text: String, duration: TimeInterval = 5.0) {
        displayBubble(text, duration: duration)
    }

    func showSpeechBubble(_ text: String, duration: TimeInterval = 5.0) {
        guard !isMuted else { return }
        // Suppress ambient bubbles while the chat window is open - they'd appear
        // behind or beside the chat panel and feel like noise. showBubbleDirect()
        // bypasses this check for intentional system messages (e.g. timer reset).
        guard !isChatOpen else { return }
        if isFocusModeActive, Int.random(in: 0...4) != 0 { return }
        let now = Date()
        let elapsed = now.timeIntervalSince(lastUnpromptedBubbleTime)

        if speechBubbleText == nil && elapsed >= effectiveCooldown {
            displayBubble(text, duration: duration)
            return
        }

        if bubbleQueue.count < maxQueueDepth {
            bubbleQueue.append(BubbleItem(text: text, duration: duration))
            scheduleQueueDrain()
        }
    }

    func dismissBubble() {
        speechTask?.cancel()
        speechTask = nil
        speechBubbleText = nil
        MumbleEngine.shared.stop()
        // Restore state if we had switched to .talking for the bubble
        if Self.ambientStates.contains(preBubbleState) && animationState == .talking {
            animationState = preBubbleState
        }
        drainQueue()
    }

    // States where a speech bubble should trigger talking mouth animation.
    private static let ambientStates: Set<CharacterAnimationState> = [.idle, .alert, .drowsy, .waving]

    private func displayBubble(_ text: String, duration: TimeInterval) {
        lastUnpromptedBubbleTime = Date()
        speechTask?.cancel()
        speechBubbleText = text
        SoundManager.shared.play(.bubblePop)
        MumbleEngine.shared.speak(text)

        reactionLog.append((Date(), text))
        if reactionLog.count > 50 { reactionLog.removeFirst() }

        // Activate lip-sync mouth for ambient states (idle, alert, drowsy, waving).
        // States like celebrating, confused, thinking, facepalm keep their own expression.
        let startedTalking = Self.ambientStates.contains(animationState)
        if startedTalking {
            preBubbleState = animationState
            animationState = .talking
        }

        speechTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            if self.speechBubbleText == text {
                self.speechBubbleText = nil
                // Restore state only if we're the ones who set it to .talking
                if startedTalking && self.animationState == .talking {
                    self.animationState = self.preBubbleState
                }
                self.drainQueue()
            }
        }
    }

    private func drainQueue() {
        guard !bubbleQueue.isEmpty else { return }
        let next = bubbleQueue.removeFirst()
        queueDrainTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self.queueDrainTask = nil
            self.displayBubble(next.text, duration: next.duration)
            // Bug fix: if more items are waiting, keep the drain pipeline alive.
            // Without this, items queued after the last drain task was created
            // could be stranded if nothing else triggers another drain.
            if !self.bubbleQueue.isEmpty { self.scheduleQueueDrain() }
        }
    }

    private func scheduleQueueDrain() {
        guard queueDrainTask == nil else { return }
        let remaining = effectiveCooldown - Date().timeIntervalSince(lastUnpromptedBubbleTime)
        let delay = max(1, remaining)
        queueDrainTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            self.queueDrainTask = nil
            self.drainQueue()
        }
    }

    // MARK: - Tickle sync

    func syncTickleState(_ tickleState: TickleState) {
        switch tickleState {
        case .none:
            tickleIntensity = .none
            if animationState == .alert || animationState == .tickled || animationState == .surprised {
                animationState = baseState
            }
        case .hover:
            tickleIntensity = .none
            if animationState == .idle || animationState == .drowsy { animationState = .alert }
        case .lightTickle:
            tickleIntensity = .light
            if animationState == .idle || animationState == .alert || animationState == .drowsy {
                animationState = .tickled
            }
        case .fullTickle:
            tickleIntensity = .full
            if animationState == .idle || animationState == .alert ||
               animationState == .tickled || animationState == .drowsy {
                animationState = .tickled
            }
        case .startled:
            tickleIntensity = .none
            setState(.surprised, duration: 0.4)
        }
    }

    // MARK: - Blink loop

    private func startBlinkLoop() {
        blinkTask = Task { [weak self] in
            while !Task.isCancelled {
                guard self != nil else { return }
                let interval = Double.random(in: 2...6)
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled, self != nil else { return }
                await self?.blink()
            }
        }
    }

    private func blink() async {
        guard animationState != .sleeping && animationState != .drowsy else { return }
        isBlinking = true
        try? await Task.sleep(for: .milliseconds(120))
        isBlinking = false
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let claudyChatSendTapped      = Notification.Name("claudyChatSendTapped")
    static let claudyPersonalitySwitched = Notification.Name("claudyPersonalitySwitched")
    static let claudyStartDemo           = Notification.Name("claudyStartDemo")
    static let claudyOpenSettings        = Notification.Name("claudyOpenSettings")
    static let claudyContextTrimmed      = Notification.Name("claudyContextTrimmed")
    static let claudyAPICodeBlock        = Notification.Name("claudyAPICodeBlock")
    static let claudyAPILongResponse     = Notification.Name("claudyAPILongResponse")
    static let claudyLongConversation    = Notification.Name("claudyLongConversation")
}
