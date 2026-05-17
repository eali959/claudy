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
    var isMuted: Bool = UserDefaults.standard.bool(forKey: DefaultsKeys.isMuted)
    var isFocusModeActive: Bool = false
    var showConfetti: Bool = false
    /// V4 — incremented every trigger so SwiftUI re-creates the burst
    /// view (forces ConfettiBurst3D's @State to re-randomise pieces).
    var confettiTriggerID: Int = 0
    
    // 3D View properties
    var weatherCondition: WeatherCondition = .unknown
    var spotifyPlaying: Bool = false
    var spotifyGenre: SpotifyGenre = .unknown

    // MARK: - @ObservationIgnored internals
    @ObservationIgnored private(set) var tickleManager: TickleManager!
    @ObservationIgnored private var idleMonitor: IdleMonitor!
    @ObservationIgnored private var clipboardMonitor: ClipboardMonitor!
    @ObservationIgnored private var appContextMonitor: AppContextMonitor!
    @ObservationIgnored private(set) var pomodoroManager: PomodoroManager!
    @ObservationIgnored private(set) var behaviorModeManager: BehaviorModeManager!
    @ObservationIgnored private(set) var alarmReminderManager: AlarmReminderManager!
    @ObservationIgnored private var holidayTask: Task<Void, Never>?
    @ObservationIgnored private(set) var breakNudgeManager: BreakNudgeManager!
    @ObservationIgnored private var focusModeMonitor: FocusModeMonitor!
    @ObservationIgnored private(set) var moodCheckInManager: MoodCheckInManager!
    @ObservationIgnored private(set) var dailyWrapUpManager: DailyWrapUpManager!

    @ObservationIgnored private var contextMonitor: ContextMonitor?
    @ObservationIgnored private var keyboardMonitor: KeyboardMonitor?
    @ObservationIgnored private var systemEventMonitor: SystemEventMonitor?
    @ObservationIgnored private(set) var spotifyMonitor: SpotifyMonitor?
    @ObservationIgnored private(set) var tamagotchiManager: TamagotchiManager!
    @ObservationIgnored private(set) var walkManager: WalkManager?
    @ObservationIgnored private(set) var weatherMonitor: WeatherContextMonitor?
    @ObservationIgnored private(set) var appWatcher: AppWatcher!
    @ObservationIgnored private(set) var careScoreTracker: CareScoreTracker!
    @ObservationIgnored private(set) var spotifyBPMReactor: SpotifyBPMReactor!
    @ObservationIgnored private(set) var personalityExporter: PersonalityExporter!

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
        let level = UserDefaults.standard.integer(forKey: DefaultsKeys.chattinessLevel)
        let l = level < 1 ? 3 : min(level, 5)   // clamp to 1-5, default 3
        let multipliers: [Int: Double] = [1: 3.0, 2: 1.75, 3: 1.0, 4: 0.6, 5: 0.3]
        let chattiness = baseBubbleCooldown * (multipliers[l] ?? 1.0)
        return chattiness * (behaviorModeManager?.ambientCooldownMultiplier ?? 1.0)
    }
    private var maxQueueDepth: Int {
        let level = UserDefaults.standard.integer(forKey: DefaultsKeys.chattinessLevel)
        let l = level < 1 ? 3 : min(level, 5)
        if l <= 2 { return 1 }
        if l <= 3 { return 3 }
        return 5
    }

    // MARK: - Reaction log
    private(set) var reactionLog: [(Date, String)] = []

    // MARK: - Init

    init() {
        tickleManager        = TickleManager(viewModel: self)
        idleMonitor          = IdleMonitor(viewModel: self)
        clipboardMonitor     = ClipboardMonitor(viewModel: self)
        appContextMonitor    = AppContextMonitor(viewModel: self)
        pomodoroManager      = PomodoroManager(viewModel: self)
        roastModeManager     = RoastModeManager(viewModel: self)
        behaviorModeManager  = BehaviorModeManager(viewModel: self)
        alarmReminderManager = AlarmReminderManager(viewModel: self)
        breakNudgeManager    = BreakNudgeManager(viewModel: self)
        focusModeMonitor     = FocusModeMonitor(viewModel: self)
        moodCheckInManager   = MoodCheckInManager(viewModel: self)
        dailyWrapUpManager   = DailyWrapUpManager(viewModel: self)
        tamagotchiManager    = TamagotchiManager(viewModel: self)
        appWatcher           = AppWatcher(viewModel: self)
        careScoreTracker     = CareScoreTracker()
        spotifyBPMReactor    = SpotifyBPMReactor(viewModel: self)
        personalityExporter  = PersonalityExporter()
        checkHolidayOnLaunch()
        GlobalHotkeyManager.shared.refresh()
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

        NotificationCenter.default.addObserver(
            forName: .claudyLanguageChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let lang = notification.object as? AppLanguage else { return }
            Task { @MainActor [weak self] in
                self?.wave()
                try? await Task.sleep(for: .milliseconds(300))
                self?.showBubbleDirect(lang.switchAcknowledgment, duration: 4)
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
        spotifyMonitor     = SpotifyMonitor(viewModel: self)
        walkManager        = WalkManager(viewModel: self, windowManager: windowManager)
        weatherMonitor     = WeatherContextMonitor(viewModel: self)
        appWatcher.start()
        SeasonalThemeEngine.shared.startUpdating()
        // Apply seasonal accessory hint on first launch if no accessory is set
        if SeasonalThemeEngine.shared.isEnabled,
           CharacterAccessory.active == .none,
           SeasonalThemeEngine.shared.sessionAccessoryHint != .none {
            CharacterAccessory.active = SeasonalThemeEngine.shared.sessionAccessoryHint
        }
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
    /// V4 voice-mode poses — listening (alert), speaking (talking), end (idle).
    func setVoiceListening() { baseState = .alert;   setState(.alert) }
    func setVoiceSpeaking()  { baseState = .talking; setState(.talking) }
    func endVoiceMode()      { baseState = .idle;    setState(.idle) }

    func celebrate()   { setState(.celebrating, duration: 3.0) }
    func beConfused()  { setState(.confused,    duration: 2.5) }
    func beSurprised() { setState(.surprised,   duration: 1.5) }
    func nod()         { setState(.celebrating, duration: 0.5) }
    func wave()        { setState(.waving,      duration: 2.0) }
    func facepalm()    { setState(.facepalm,    duration: 2.5) }
    func sayName()     { MumbleEngine.shared.speakName() }

    // MARK: - Dance mode

    var danceModeManager = DanceModeManager()

    func startDanceMode() {
        baseState = .dancing
        setState(.dancing)
        danceModeManager.start()
    }

    func stopDanceMode() {
        danceModeManager.stop()
        baseState = .idle
        setState(.idle)
    }

    // MARK: - Roast mode

    @ObservationIgnored private(set) var roastModeManager: RoastModeManager!

    func roastMe() {
        roastModeManager.startRoast()
    }

    // MARK: - Spotify reactions

    /// Called when Spotify starts playing a new track.
    func onSpotifyTrackChanged(track: String, artist: String, genre: SpotifyGenre) {
        spotifyPlaying = true
        spotifyGenre = genre
        spotifyBPMReactor.applyGenres([genre.bpmKeyword])
        // Build a short speech bubble
        let bubble: String
        switch genre {
        case .metal:
            let lines = [
                "Oh we are DOING this. \(artist). Let's go.",
                "\(track)? Absolute weapon of a track.",
                "Right. Headbanging commences immediately.",
            ]
            bubble = lines.randomElement()!
            setState(.headbanging)
            baseState = .headbanging

        case .electronic:
            let lines = [
                "\(artist) just dropped. Dance mode activated.",
                "This is my song. This is literally my song.",
                "Oh the beat just hit. We're dancing.",
            ]
            bubble = lines.randomElement()!
            startDanceMode()

        case .hiphop:
            let lines = [
                "\(track). Good taste. Very good taste.",
                "\(artist) on the aux? Respectable.",
                "Okay we're vibing. I see you.",
            ]
            bubble = lines.randomElement()!
            startDanceMode()

        case .lofi:
            let lines = [
                "Lo-fi mode activated. Deep focus. Let's build something.",
                "\(track). This is the one.",
                "Okay. Headphones on. World off. Let's go.",
            ]
            bubble = lines.randomElement()!
            setState(.vibing)
            baseState = .vibing

        case .classical:
            let lines = [
                "\(artist). Good. The brain works better with structure.",
                "Classical. You're in 'solving a hard problem' mode. I respect it.",
                "Okay we're being serious today. I can do serious.",
            ]
            bubble = lines.randomElement()!
            setState(.thinking)
            baseState = .idle

        case .country:
            let lines = [
                "\(track)? Bold choice. No notes.",
                "Country mode. I'm not judging. I'm a little judging.",
                "We're doing country. Okay. Fine. Whatever makes the code compile.",
            ]
            bubble = lines.randomElement()!
            wave()

        case .rnb:
            let lines = [
                "\(artist). Smooth. The code's going to write itself.",
                "R&B hours. Productive hours. Proven correlation.",
                "\(track). Okay. I feel this. We feel this.",
            ]
            bubble = lines.randomElement()!
            setState(.celebrating, duration: 2.5)

        case .pop:
            let lines = [
                "\(track). Okay, no shame, this is a banger.",
                "\(artist) in the session. Valid.",
                "Pop hours. Productivity correlation unclear but we're here for it.",
            ]
            bubble = lines.randomElement()!
            celebrate()

        case .unknown:
            let lines = [
                "\(track) just came on. I don't know this one but I'm into it.",
                "Oh. New track. Listening.",
                "\(artist). Interesting choice. Tell me more.",
            ]
            bubble = lines.randomElement()!
            setState(.alert, duration: 2.0)
        }

        showBubbleDirect(bubble, duration: 5.0)
    }

    /// Called when Spotify is paused or stopped.
    func onSpotifyPaused() {
        spotifyPlaying = false
        spotifyBPMReactor.stopDanceBursts()
        // Only react if we put the character in a music-driven state
        if animationState == .headbanging || animationState == .vibing {
            baseState = .idle
            setState(.idle)
        }
        if danceModeManager.isActive { stopDanceMode() }
    }

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
        confettiTriggerID &+= 1   // V4 — re-id so SwiftUI re-builds burst
        showConfetti = true
        SoundManager.shared.play(.celebrate)
        confettiTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }   // Bug fix: don't hide on re-trigger
            showConfetti = false
        }
    }

    // MARK: - Idle reset

    func resetIdleTimer() {
        idleMonitor.resetActivity()
        behaviorModeManager?.onActivity()
        breakNudgeManager?.recordActivity()
        moodCheckInManager?.recordActivity()
    }

    // MARK: - Reminder parsing (call from chat before sending to API)

    /// Attempts to parse and schedule a reminder from a user's chat message.
    /// Returns true if a reminder was created (so the chat can add context to the API call).
    @discardableResult
    func parseReminderFromChat(_ text: String) -> Bool {
        let lower = text.lowercased()
        let hasKeyword = lower.contains("remind me") || lower.contains("set a reminder")
                      || lower.contains("set an alarm") || lower.contains("alarm for")
        guard hasKeyword else { return false }
        return alarmReminderManager.parseAndSchedule(from: text) != nil
    }

    // MARK: - Holiday check

    private func checkHolidayOnLaunch() {
        holidayTask = Task { @MainActor [weak self] in
            // Small delay so the greeting fires first and holiday feels like a separate moment
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            if let holiday = HolidayCalendar.shared.holidayToday() {
                self?.wave()
                self?.showBubbleDirect(holiday.messages.randomElement() ?? holiday.name, duration: 8)
            }
        }
    }

    // MARK: - Mute

    func setMuted(_ muted: Bool) {
        isMuted = muted
        UserDefaults.standard.set(muted, forKey: DefaultsKeys.isMuted)
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
    private static let ambientStates: Set<CharacterAnimationState> = [.idle, .alert, .drowsy, .waving, .vibing]

    private func displayBubble(_ text: String, duration: TimeInterval) {
        lastUnpromptedBubbleTime = Date()
        speechTask?.cancel()
        speechBubbleText = text
        SoundManager.shared.play(.bubblePop)
        MumbleEngine.shared.speak(text)

        reactionLog.append((Date(), text))
        if reactionLog.count > 50 { reactionLog.removeFirst() }
        careScoreTracker.recordInteraction()

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
        // V5.3 — also skip auto-blink while being dragged.  isHeldClosedEyes
        // already keeps the eyes closed; firing isBlinking on/off in the
        // background just creates fight conditions in observers.
        guard !isHeldClosedEyes else { return }
        isBlinking = true
        try? await Task.sleep(for: .milliseconds(120))
        isBlinking = false
    }

    // MARK: - Drag (pleasure pose)
    //
    // V5.3 — When Claudy is picked up and dragged, 2D Claudy closes his eyes
    // in pleasure (like being petted).  3D used to fire .excited which mapped
    // to a big-smile + body-bounce that looked overdone.  These two methods
    // match the 2D behaviour: eyes closed, mouth at default size, no body
    // animation kicked off — just a gentle "being held" pose.

    /// Persistent "eyes held closed" flag — separate from `isBlinking` (which
    /// is owned by the auto-blink loop).  When true, both 2D and 3D views
    /// render eyes closed regardless of the auto-blink state.  Without this
    /// separation, the auto-blink loop unblinks the eyes for ~120 ms every
    /// few seconds during a drag — flashing the iris and catchlights for
    /// a fraction of a second.  This flag overrides that.
    var isHeldClosedEyes: Bool = false

    /// Effective signal that should drive both views' "eyes closed" rendering.
    /// Computes the OR of the auto-blink signal and the held-closed signal so
    /// either source can close the eyes, without one fighting the other.
    var effectiveBlinking: Bool { isBlinking || isHeldClosedEyes }

    /// Called when the user begins dragging Claudy.  Closes eyes (pleasure)
    /// and keeps the current mouth shape — no animation state change so the
    /// big celebrate bounce doesn't fire.
    func onDragBegin() {
        // Hold eyes closed for the full drag duration.  This survives the
        // auto-blink loop's periodic on/off cycle (which would otherwise
        // briefly unblink the eyes mid-drag and flash the iris).
        isHeldClosedEyes = true
        // Keep the current animation state (don't fire .excited which triggers
        // the big celebrate animation + larger smile).
    }

    /// Called when the user releases Claudy.  Opens eyes again and gives a
    /// brief happy moment (subtle, not a full celebrate).
    func onDragEnd() {
        isHeldClosedEyes = false
        // Brief tickle reaction — a tiny wiggle, much subtler than .excited.
        setState(.tickled, duration: 0.3)
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let claudyChatSendTapped      = Notification.Name("claudyChatSendTapped")
    static let claudyPersonalitySwitched = Notification.Name("claudyPersonalitySwitched")
    static let claudyLanguageChanged     = Notification.Name("claudyLanguageChanged")
    static let claudyStartDemo           = Notification.Name("claudyStartDemo")
    static let claudyOpenSettings        = Notification.Name("claudyOpenSettings")
    static let claudyContextTrimmed      = Notification.Name("claudyContextTrimmed")
    static let claudyAPICodeBlock        = Notification.Name("claudyAPICodeBlock")
    static let claudyAPILongResponse     = Notification.Name("claudyAPILongResponse")
    static let claudyLongConversation    = Notification.Name("claudyLongConversation")
    /// Fired by GlobalHotkeyManager (⌘⇧Space) — CharacterRootView toggles chat.
    static let claudyToggleChat          = Notification.Name("claudyToggleChat")
    /// Fired by QuickActionManager when the user taps a contextual button.
    /// userInfo["prompt"]: String — pre-fill value for the chat input.
    static let claudyQuickActionFired    = Notification.Name("claudyQuickActionFired")
    /// Open the local-LLM setup wizard. Posted from menu / Settings.
    static let claudyShowLocalLLMSetup   = Notification.Name("claudyShowLocalLLMSetup")
    /// Open Voice Mode sheet. Posted from menu / chat header / global hotkey.
    static let claudyShowVoiceMode       = Notification.Name("claudyShowVoiceMode")
    /// V5.10 — Posted when user toggles "Keyboard reactions" in Settings, so
    /// KeyboardMonitor can install / remove its NSEvent monitor at runtime
    /// without an app restart.
    static let claudyKeyboardReactionsToggled = Notification.Name("claudyKeyboardReactionsToggled")
    /// V4 — VoiceModeManager state changed; object payload is the new
    /// VoiceModeManager.VoiceCharacterState.
    static let claudyVoiceStateChanged   = Notification.Name("claudyVoiceStateChanged")
    /// V4 — Voice transcript ready to be sent to chat; object payload
    /// is the transcript String.
    static let claudyVoiceTranscriptReady = Notification.Name("claudyVoiceTranscriptReady")
}
