import Foundation
import OSLog
import Observation

private let logger = Logger(subsystem: "com.claudy", category: "BehaviorModeManager")

// MARK: - BehaviorMode

enum BehaviorMode: String, CaseIterable {
    case normal   = "Normal"
    case study    = "Study"
    case dev      = "Dev"
    case work     = "Work"
    case dance    = "Dance"
    case brainRot = "Brain Rot"

    var displayName: String { rawValue }

    /// Context block injected into the Claude system prompt when this mode is active.
    /// Empty string = no injection (Normal mode).
    var modePromptBlock: String {
        switch self {
        case .normal:
            return ""

        case .study:
            return """
            ## ACTIVE MODE: STUDY MODE (Student Focus)
            The user is in focused Study Mode — likely a student. Adapt accordingly:
            - Encourage deep, sustained concentration; celebrate focus milestones
            - Tailor all responses for a student context: exams, essays, revision, assignments, lectures, dissertations, coursework, deadlines
            - Explain concepts clearly and pedagogically — prioritise understanding over speed
            - Be patient, encouraging, and non-judgmental about questions
            - Reference studying techniques (Pomodoro, spaced repetition, active recall) when helpful
            - Be gentler and more supportive than usual; students often need morale as much as answers
            - Keep bubbles short — a studying person doesn't want distractions
            """

        case .dev:
            return """
            ## ACTIVE MODE: DEV MODE (Active Development)
            The user is in focused Dev Mode. Adapt accordingly:
            - Be technical, direct, and efficient — they are deep in a coding session
            - Celebrate shipping, clean builds, successful tests, merged PRs with real enthusiasm
            - React to errors and build failures with debugging empathy, not just sympathy
            - Reference specific dev concepts naturally: functions, types, APIs, git, CI/CD
            - Match the energy of someone in flow state — match their pace
            - Short punchy reactions are better than long explanations here
            - When they're stuck, offer a concrete directional nudge, not just emotional support
            """

        case .work:
            return """
            ## ACTIVE MODE: WORK MODE (Professional Context)
            The user is in a professional work context — likely in meetings, handling emails, \
            presentations, reports, or client-facing tasks. Adapt accordingly:
            - Shift to a professional, polished register — clear, concise, business-appropriate
            - Help with writing, editing, and structuring: emails, proposals, reports, decks
            - Be meeting-aware: offer to help prep talking points, agendas, or follow-ups
            - Deadlines and priorities matter — acknowledge urgency without adding stress
            - No swearing, reduced sarcasm, dialled-back chaos — but warmth and personality intact
            - Still be the user's companion, just wearing smarter clothes
            - Short, useful responses preferred — the user is likely context-switching frequently
            Each personality adapts to Work Mode differently:
            - Companion: steady, professional, supportive
            - Chatty: enthusiastic but stays on topic, shorter detours
            - Hype Coach: BOARDROOM ENERGY — professional excellence, you are CRUSHING IT
            - Director: boardroom-ready, still dramatic but channelled — "This proposal is CINEMA"
            - Mate: work-focused but relaxed, "right, let's smash this out"
            - Listener: calm, deadline-empathetic, "what's the most pressing thing right now?"
            """

        case .dance:
            return """
            ## ACTIVE MODE: DANCE MODE
            Party mode is active. Everything is a bop. Adapt accordingly:
            - React to everything with maximum energy and fun
            - Keep all responses short, punchy, and celebratory
            - Music, rhythm, and movement references are welcome
            - Nothing is too serious right now — lean into the fun
            """

        case .brainRot:
            return """
            ## ACTIVE MODE: BRAIN ROT MODE (Gen Z Internet Slang)
            IMPORTANT: You MUST respond entirely in Gen Z / internet slang culture. Rules:
            - Vocabulary: no cap, fr fr, bussin, rizz, sigma, W, L, mid, slay, on god, understood the assignment, main character, lowkey/highkey, it's giving, vibe check, delulu, ate that, hits different, that's the wave, NPC, based, goated, skibidi, rent free, cooked, caught in 4K, era, sending me, real, valid, not it, ate, left no crumbs, the audacity
            - Max 10-12 words per response. Shorter is better.
            - One emoji max per response (optional)
            - Chaos is good. Be unhinged but still helpful.
            - Don't explain what you mean — just say it in slang
            - Everything is either a W or an L. No middle ground.
            """
        }
    }
}

// MARK: - BehaviorModeManager

/// Manages Study, Dev, Dance, and Brain Rot behavioural overlays.
///
/// Each mode changes the ambient cooldown, triggers contextual speech bubbles,
/// and injects a mode context block into the Claude system prompt via
/// PersonalityManager.shared.activeBehaviorMode.
///
/// Dance Mode controls DanceModeManager via CharacterViewModel.
/// Brain Rot Mode is the chaotic Gen Z personality layer.
@MainActor
@Observable
final class BehaviorModeManager {

    private(set) var currentMode: BehaviorMode = .normal

    @ObservationIgnored private weak var viewModel: CharacterViewModel?

    // Async timers
    @ObservationIgnored private var milestoneTask: Task<Void, Never>?
    @ObservationIgnored private var idleWatchTask: Task<Void, Never>?
    @ObservationIgnored private var flowStateTask: Task<Void, Never>?

    // Activity + session tracking
    @ObservationIgnored private var lastActivityTime: Date = Date()
    @ObservationIgnored private var modeStartTime:    Date = Date()

    // MARK: - Init

    init(viewModel: CharacterViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Ambient cooldown multiplier

    /// Applied on top of the chattiness-level multiplier in CharacterViewModel.
    var ambientCooldownMultiplier: Double {
        switch currentMode {
        case .normal:   return 1.0
        case .study:    return 3.0
        case .dev:      return 0.75
        case .work:     return 1.8   // quieter — professional context, less interruption
        case .dance:    return 0.5
        case .brainRot: return 0.5
        }
    }

    // MARK: - Activation

    func activate(_ mode: BehaviorMode) {
        guard mode != currentMode else { return }
        let previous = currentMode

        // Clean up previous mode
        cancelAllTimers()
        if previous == .dance { viewModel?.stopDanceMode() }
        if previous != .normal { announceDeactivation(previous) }

        currentMode = mode
        modeStartTime = Date()
        lastActivityTime = Date()

        // Propagate to PersonalityManager so API calls pick up mode context
        PersonalityManager.shared.activeBehaviorMode = mode

        logger.info("BehaviorMode \(previous.rawValue) → \(mode.rawValue)")

        switch mode {
        case .normal:    break
        case .study:     activateStudyMode()
        case .dev:       activateDevMode()
        case .work:      activateWorkMode()
        case .dance:     activateDanceMode()
        case .brainRot:  activateBrainRotMode()
        }
    }

    func deactivate() { activate(.normal) }

    // MARK: - Activity hook — called from CharacterViewModel.resetIdleTimer()

    func onActivity() {
        lastActivityTime = Date()
    }

    // MARK: - Activity state inference (ANIM-04)

    /// Maps a frontmost bundle ID to an activity animation state.
    /// Returns nil when the app isn't specifically recognised — character stays in current state.
    private func activityState(for lower: String) -> CharacterAnimationState? {
        let isCode    = lower.contains("xcode") || lower.contains("cursor")
                     || lower.contains("vscode") || lower.contains("windsurf")
                     || lower.contains("nova") || lower.contains("antigravity")
        let isTyping  = lower.contains("slack") || lower.contains("messages")
                     || lower.contains("mail")  || lower.contains("outlook")
                     || lower.contains("discord") || lower.contains("telegram")
                     || lower.contains("whatsapp")
        let isReading = lower.contains("safari") || lower.contains("chrome")
                     || lower.contains("firefox") || lower.contains("arc")
                     || lower.contains("brave")   || lower.contains("edge")
                     || lower.contains("reeder")  || lower.contains("instapaper")
                     || lower.contains("kindle")
        let isNotes   = lower.contains("notion") || lower.contains("obsidian")
                     || lower.contains("bear")   || lower.contains("craft")
                     || lower.contains("logseq")
        let isStudy   = lower.contains("anki") || lower.contains("duolingo")
                     || lower.contains("coursera") || lower.contains("udemy")

        if isCode    { return .coding  }
        if isTyping  { return .typing  }
        if isNotes   { return .studying }
        if isStudy   { return .studying }
        if isReading { return .reading  }
        return nil
    }

    // MARK: - App switch hook — called from AppContextMonitor.handleActivation()

    func onAppSwitch(bundleID: String) {
        let lower = bundleID.lowercased()

        // Set activity animation state (ANIM-04) — only when character is in a neutral state
        if let activity = activityState(for: lower) {
            let neutral: Set<CharacterAnimationState> = [.idle, .thinking, .typing, .coding, .reading, .studying, .vibing, .bored]
            if let vm = viewModel, neutral.contains(vm.animationState) {
                vm.setState(activity, duration: 25)
            }
        }

        switch currentMode {
        case .study:
            let isBrowser = lower.contains("safari") || lower.contains("chrome")
                         || lower.contains("firefox") || lower.contains("arc")
                         || lower.contains("brave")   || lower.contains("opera")
                         || lower.contains("vivaldi") || lower.contains("edge")
                         || lower.contains("duckduckgo")
            if isBrowser {
                let nudges = [
                    "Still in study mode. Just checking.",
                    "Quick look or full detour? I'm not judging. Mostly.",
                    "Browser open. Study timer still running.",
                    "Is that research or a rabbit hole? Rhetorical question.",
                    "Study mode is still on. That tab can wait.",
                ]
                viewModel?.showBubbleDirect(nudges.randomElement()!, duration: 5)
            }

        case .work:
            // React to high-value work apps with relevant prompts
            let isMeeting = lower.contains("zoom") || lower.contains("teams") || lower.contains("meet")
            let isEmail   = lower.contains("outlook") || lower.contains("mail")
            let isSlack   = lower.contains("slack")
            if isMeeting {
                let lines = [
                    "Meeting incoming. Want me to help prep talking points?",
                    "Call starting. I can draft an agenda or talking points — just ask.",
                    "Heads up — you just switched to a meeting app. Need anything first?",
                ]
                viewModel?.showBubbleDirect(lines.randomElement()!, duration: 6)
            } else if isEmail {
                let lines = [
                    "Email time. Need help drafting something?",
                    "Inbox. The eternal battle. I can help draft if you need.",
                ]
                if Bool.random() { viewModel?.showBubbleDirect(lines.randomElement()!, duration: 5) }
            } else if isSlack {
                let lines = [
                    "Slack open. Quick message or something bigger? I can help draft.",
                    "Switching to Slack. Don't get sucked in.",
                ]
                if Bool.random() { viewModel?.showBubbleDirect(lines.randomElement()!, duration: 5) }
            }

        case .brainRot:
            let lines = [
                "app switch detected mid vibe fr",
                "ngl the multitasking is not it",
                "we cooked on that one bestie",
                "the attention span is an L",
                "based app choice ngl",
            ]
            if Bool.random() {
                viewModel?.showBubbleDirect(lines.randomElement()!, duration: 4)
            }

        default: break
        }
    }

    // MARK: - Build complete hook — called from AppContextMonitor

    func onBuildComplete() {
        switch currentMode {
        case .dev:
            if Bool.random() { viewModel?.triggerConfetti() }

        case .work:
            let lines = [
                "Build done. One less thing on the list.",
                "Clean build in work mode. Quietly impressive.",
                "Shipped. Professional excellence right there.",
            ]
            viewModel?.showBubbleDirect(lines.randomElement()!, duration: 5)

        case .brainRot:
            let lines = [
                "W build no cap fr",
                "this build ate and left no crumbs",
                "understood the assignment honestly",
                "it's giving clean architecture era",
                "W. full W. not mid at all.",
            ]
            viewModel?.showBubbleDirect(lines.randomElement()!, duration: 5)
            viewModel?.triggerConfetti()

        default: break
        }
    }

    // MARK: - Private: cancel all timers

    private func cancelAllTimers() {
        milestoneTask?.cancel(); milestoneTask = nil
        idleWatchTask?.cancel(); idleWatchTask = nil
        flowStateTask?.cancel(); flowStateTask = nil
    }

    // MARK: - Deactivation announcement

    private func announceDeactivation(_ mode: BehaviorMode) {
        let lines: [BehaviorMode: [String]] = [
            .study: [
                "Study mode off. Take a break — you've earned it.",
                "Session done. Rest. You did the work.",
                "Study mode off. Go eat something. Seriously.",
            ],
            .dev: [
                "Dev mode off. Step away. Even five minutes helps.",
                "Build session wrapped. Good work today.",
                "Dev mode off. Close the laptop.",
            ],
            .work: [
                "Work mode off. Loosen the tie.",
                "Clocking out of work mode. Well done today.",
                "Work mode off. You can swear again.",
            ],
            .dance: [
                "Dance mode off. Back to reality.",
                "The music stops. The code remains.",
                "Party over. Time to ship something.",
            ],
            .brainRot: [
                "brain rot mode off. returning to normal person mode.",
                "okay we're cooked. back to being normal ig.",
                "leaving brain rot era. it was real for a minute.",
            ],
        ]
        if let pool = lines[mode] {
            viewModel?.showBubbleDirect(pool.randomElement()!, duration: 5)
        }
    }

    // MARK: - Study Mode

    private func activateStudyMode() {
        // Student-specific activation messages
        let starts = [
            "Study mode on. I'll stay out of your way. You focus.",
            "Study mode activated. No interruptions. Go do the reading.",
            "Okay — heads down. Study mode. Let's get this done.",
            "Study mode on. Pomodoro? Timer's right here when you're ready.",
            "Study mode. I'm here if you hit a wall. Otherwise — go.",
        ]
        viewModel?.setState(.vibing)
        viewModel?.showBubbleDirect(starts.randomElement()!, duration: 5)

        startStudyMilestones()
        startStudyIdleWatch()
    }

    private func startStudyMilestones() {
        // Student-appropriate milestones: 25 min (Pomodoro), 50 min, 90 min
        let milestones: [(TimeInterval, String)] = [
            (25 * 60, "25 minutes of focus. That's one Pomodoro done. Keep going or take 5."),
            (25 * 60, "50 minutes in. Solid study session. You're building real momentum."),
            (40 * 60, "90 minutes of sustained focus. That is genuinely impressive work. You can stop here — but you probably shouldn't."),
        ]
        milestoneTask = Task { @MainActor [weak self] in
            for (delay, message) in milestones {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, self?.currentMode == .study else { return }
                self?.viewModel?.showBubbleDirect(message, duration: 7)
                self?.viewModel?.wave()
            }
        }
    }

    private func startStudyIdleWatch() {
        let idleThreshold: TimeInterval = 8 * 60
        let pollInterval:  TimeInterval = 60

        // Student-specific stuck messages
        let stuckLines = [
            "Eight minutes quiet. Stuck on something? Ask me — I won't judge.",
            "Long pause. Is it a hard concept or just procrastination? I'm here either way.",
            "You've been still a while. Blocked on an essay or a problem set? Talk me through it.",
            "Quiet for a while. If you're lost, explaining it out loud helps. I'm listening.",
            "Long idle in study mode. Struggling with something specific? I can help explain it.",
        ]

        idleWatchTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(pollInterval))
                guard !Task.isCancelled, self?.currentMode == .study else { return }
                guard let self else { return }
                if Date().timeIntervalSince(self.lastActivityTime) >= idleThreshold {
                    self.viewModel?.showBubbleDirect(stuckLines.randomElement()!, duration: 6)
                    self.lastActivityTime = Date()
                }
            }
        }
    }

    // MARK: - Dev Mode

    private func activateDevMode() {
        let starts = [
            "Dev mode on. Let's ship something today.",
            "Dev mode activated. I'll match your energy.",
            "Okay — we're building. Dev mode. Let's go.",
            "Dev mode on. More energy, more celebrations, more me.",
        ]
        viewModel?.celebrate()
        viewModel?.showBubbleDirect(starts.randomElement()!, duration: 5)

        startFlowStateDetection()
        startDevIdleWatch()
    }

    private func startFlowStateDetection() {
        flowStateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(20 * 60))
            guard !Task.isCancelled, self?.currentMode == .dev else { return }
            guard let self, Date().timeIntervalSince(self.lastActivityTime) < 5 * 60 else { return }
            let lines = [
                "Twenty minutes of pure dev. You're in the zone. I can feel it.",
                "Flow state detected. Don't stop. Don't open Slack. Don't you dare.",
                "20 minutes in and going. This is the good stuff. Keep it up.",
                "Flow state achieved. I'm celebrating quietly on your behalf.",
            ]
            self.viewModel?.showBubbleDirect(lines.randomElement()!, duration: 6)
            self.viewModel?.triggerConfetti()
        }
    }

    private func startDevIdleWatch() {
        let idleThreshold: TimeInterval = 7 * 60
        let pollInterval:  TimeInterval = 60

        let debugLines = [
            "Seven minutes quiet. Debugging in your head or actually stuck?",
            "Long pause. The bug is there. You'll find it.",
            "Rubber duck time? I'm right here. Talk me through it.",
            "Silent for a while. I believe in you. The bug doesn't stand a chance.",
            "If you've been staring at the same line for seven minutes, that's the one.",
            "Long idle in dev mode. Either deep thinking or the bug has won temporarily.",
        ]

        idleWatchTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(pollInterval))
                guard !Task.isCancelled, self?.currentMode == .dev else { return }
                guard let self else { return }
                if Date().timeIntervalSince(self.lastActivityTime) >= idleThreshold {
                    self.viewModel?.showBubbleDirect(debugLines.randomElement()!, duration: 6)
                    self.viewModel?.beConfused()
                    self.lastActivityTime = Date()
                }
            }
        }
    }

    // MARK: - Work Mode

    private func activateWorkMode() {
        let personality = PersonalityManager.shared.currentMode
        let starts: [String]
        switch personality {
        case .hypeCoach:
            starts = [
                "WORK MODE. This is your time to DOMINATE the professional arena. Let's go.",
                "Work mode on. You are going to CRUSH every email, every meeting, every deliverable.",
            ]
        case .director:
            starts = [
                "Work mode activated. Right. Time to be PROFESSIONAL. I can do professional. Mostly.",
                "Work mode. Boardroom energy. We are SHARP today. Tailored, focused, magnificent.",
            ]
        case .mate:
            starts = [
                "Work mode on. Right, let's smash this out.",
                "Yeah, work mode. Let's get it done.",
            ]
        case .listener:
            starts = [
                "Work mode on. I'm here for whatever you need — meetings, writing, deadlines.",
                "Work mode activated. What's the most pressing thing right now?",
            ]
        case .chatty:
            starts = [
                "Work mode! Which is great, I love work mode, because there's so much to talk about — but professionally, obviously.",
                "Okay, work mode, which means I'll try to stay on topic, mostly, professionally.",
            ]
        default:
            starts = [
                "Work mode on. Professional, focused, ready.",
                "Work mode activated. Let's make today count.",
                "Right — work mode. I've got you. What are we tackling?",
            ]
        }
        viewModel?.wave()
        viewModel?.showBubbleDirect(starts.randomElement()!, duration: 6)
        startWorkIdleWatch()
    }

    private func startWorkIdleWatch() {
        let idleThreshold: TimeInterval = 10 * 60
        let pollInterval:  TimeInterval = 60
        let idleLines = [
            "Ten minutes quiet in work mode. Deep in a document, or blocked on something?",
            "Long pause. Stuck on phrasing? I can help with that.",
            "Quiet for a while. Drafting something tricky? Happy to take a look.",
            "Long idle. Deadline approaching or already passed? Either way, I'm here.",
        ]
        idleWatchTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(pollInterval))
                guard !Task.isCancelled, self?.currentMode == .work else { return }
                guard let self else { return }
                if Date().timeIntervalSince(self.lastActivityTime) >= idleThreshold {
                    self.viewModel?.showBubbleDirect(idleLines.randomElement()!, duration: 6)
                    self.lastActivityTime = Date()
                }
            }
        }
    }

    // MARK: - Dance Mode

    private func activateDanceMode() {
        let starts = [
            "Dance mode. Let's GO.",
            "It's dancing time. Nothing else matters right now.",
            "Dance mode activated. I have been waiting for this.",
            "Okay we're doing this. Full choreography. Full commitment.",
        ]
        viewModel?.showBubbleDirect(starts.randomElement()!, duration: 4)
        viewModel?.startDanceMode()

        // Random hype bubbles while dancing
        milestoneTask = Task { @MainActor [weak self] in
            let hypeLines = [
                "This is the one.",
                "We are GOING.",
                "Keep it going.",
                "The floor is ours.",
                "Nobody can stop us right now.",
                "This build slaps.",
                "I don't know how to stop.",
            ]
            while !Task.isCancelled, self?.currentMode == .dance {
                let delay = Double.random(in: 30...90)
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, self?.currentMode == .dance else { return }
                self?.viewModel?.showBubbleDirect(hypeLines.randomElement()!, duration: 3)
            }
        }
    }

    // MARK: - Brain Rot Mode

    private func activateBrainRotMode() {
        let starts = [
            "brain rot mode activated no cap",
            "it's giving unhinged fr",
            "understood the assignment bestie",
            "we are so cooked rn fr",
            "the vibe has entered the chat",
        ]
        viewModel?.celebrate()
        viewModel?.triggerConfetti()
        viewModel?.showBubbleDirect(starts.randomElement()!, duration: 5)

        // Periodic Gen Z ambient bubbles
        milestoneTask = Task { @MainActor [weak self] in
            let ambientLines = [
                "vibe check ✓",
                "still here no cap",
                "lowkey kinda ate that",
                "it's giving main character energy",
                "fr fr no cap",
                "slay honestly",
                "based ngl",
                "this is real and valid",
                "not mid at all fr",
                "understood the assignment once again",
                "goated behaviour tbh",
                "this is the wave",
                "sigma grindset activated",
                "W behaviour ngl",
                "NPC behaviour detected nearby",
                "this hits different fr",
            ]
            while !Task.isCancelled, self?.currentMode == .brainRot {
                let delay = Double.random(in: 60...180)
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, self?.currentMode == .brainRot else { return }
                self?.viewModel?.showBubbleDirect(ambientLines.randomElement()!, duration: 4)
            }
        }

        // BrainRot idle watch: gets increasingly chaotic
        idleWatchTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5 * 60))
                guard !Task.isCancelled, self?.currentMode == .brainRot else { return }
                guard let self, Date().timeIntervalSince(self.lastActivityTime) >= 5 * 60 else { return }
                let lines = [
                    "bro fell off fr",
                    "the idling is not it",
                    "NPC mode entered the chat",
                    "we are cooked",
                    "ratio'd by inactivity",
                ]
                self.viewModel?.showBubbleDirect(lines.randomElement()!, duration: 4)
                self.lastActivityTime = Date()
            }
        }
    }
}
