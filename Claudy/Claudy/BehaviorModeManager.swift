import Foundation
import OSLog
import Observation

private let logger = Logger(subsystem: "com.claudy", category: "BehaviorModeManager")

// MARK: - BehaviorMode

enum BehaviorMode: String, CaseIterable {
    case normal   = "Normal"
    case study    = "Study"
    case dev      = "Dev"
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
        case .dance:    return 0.5   // very chatty during dance
        case .brainRot: return 0.5   // gen z never shuts up
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
        case .dance:     activateDanceMode()
        case .brainRot:  activateBrainRotMode()
        }
    }

    func deactivate() { activate(.normal) }

    // MARK: - Activity hook — called from CharacterViewModel.resetIdleTimer()

    func onActivity() {
        lastActivityTime = Date()
    }

    // MARK: - App switch hook — called from AppContextMonitor.handleActivation()

    func onAppSwitch(bundleID: String) {
        let lower = bundleID.lowercased()

        switch currentMode {
        case .study:
            let isBrowser = lower.contains("safari") || lower.contains("chrome")
                         || lower.contains("firefox") || lower.contains("arc")
                         || lower.contains("brave")   || lower.contains("opera")
                         || lower.contains("vivaldi")
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
