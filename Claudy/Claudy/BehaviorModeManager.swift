import Foundation
import OSLog
import Observation

private let logger = Logger(subsystem: "com.claudy", category: "BehaviorModeManager")

// MARK: - BehaviorMode

enum BehaviorMode: String, CaseIterable {
    case normal = "Normal"
    case study  = "Study"
    case dev    = "Dev"

    var displayName: String { rawValue }
}

// MARK: - BehaviorModeManager

/// Manages Study Mode and Dev Mode — two focused behavioural overlays that change
/// how Claud-y reacts and how often she speaks.
///
/// **Study Mode** — quieter (3× cooldown), session milestones at 25/50/90 min,
/// idle "stuck?" nudges after 8 min, gentle browser-switch reminders.
///
/// **Dev Mode** — chattier (0.75× cooldown), flow-state celebration after 20 min
/// of sustained activity, debugging empathy after 7 min idle, extra build confetti.
@MainActor
@Observable
final class BehaviorModeManager {

    private(set) var currentMode: BehaviorMode = .normal

    @ObservationIgnored private weak var viewModel: CharacterViewModel?

    // Async timers
    @ObservationIgnored private var milestoneTask: Task<Void, Never>?
    @ObservationIgnored private var idleWatchTask: Task<Void, Never>?
    @ObservationIgnored private var flowStateTask: Task<Void, Never>?

    // Tracking
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
        case .normal: return 1.0
        case .study:  return 3.0
        case .dev:    return 0.75
        }
    }

    // MARK: - Activation

    func activate(_ mode: BehaviorMode) {
        guard mode != currentMode else { return }
        let previous = currentMode
        cancelAllTimers()
        currentMode = mode
        modeStartTime = Date()
        lastActivityTime = Date()
        logger.info("BehaviorMode \(previous.rawValue) → \(mode.rawValue)")

        switch mode {
        case .normal: onReturnToNormal(from: previous)
        case .study:  activateStudyMode()
        case .dev:    activateDevMode()
        }
    }

    func deactivate() { activate(.normal) }

    // MARK: - Activity hook — called from CharacterViewModel.resetIdleTimer()

    func onActivity() {
        lastActivityTime = Date()
    }

    // MARK: - App switch hook — called from AppContextMonitor.handleActivation()

    func onAppSwitch(bundleID: String) {
        guard currentMode == .study else { return }
        let lower = bundleID.lowercased()
        let isBrowser = lower.contains("safari") || lower.contains("chrome")
                     || lower.contains("firefox") || lower.contains("arc")
                     || lower.contains("brave")   || lower.contains("opera")
                     || lower.contains("vivaldi")
        guard isBrowser else { return }

        let nudges = [
            "Still in study mode. Just checking.",
            "Quick look or full detour? I'm not judging. Mostly.",
            "Browser open. Timer still running. Up to you.",
            "Is that research or a rabbit hole? Rhetorical.",
            "Study mode is still on. The session doesn't care about that tab.",
        ]
        viewModel?.showBubbleDirect(nudges.randomElement()!, duration: 5)
    }

    // MARK: - Build complete hook — called from AppContextMonitor

    func onBuildComplete() {
        guard currentMode == .dev else { return }
        if Bool.random() { viewModel?.triggerConfetti() }
    }

    // MARK: - Private: cancel

    private func cancelAllTimers() {
        milestoneTask?.cancel(); milestoneTask = nil
        idleWatchTask?.cancel(); idleWatchTask = nil
        flowStateTask?.cancel(); flowStateTask = nil
    }

    // MARK: - Return to Normal

    private func onReturnToNormal(from previous: BehaviorMode) {
        let lines: [BehaviorMode: [String]] = [
            .study: [
                "Study mode off. You did the thing. Take a break.",
                "Session done. Rest. You earned it.",
                "Study mode off. Go eat something. Seriously.",
            ],
            .dev: [
                "Dev mode off. Step away. Even for five minutes.",
                "Build session over. Good work today.",
                "Dev mode off. Go touch some grass.",
            ],
        ]
        if let pool = lines[previous] {
            viewModel?.showBubbleDirect(pool.randomElement()!, duration: 5)
            viewModel?.wave()
        }
    }

    // MARK: - Study Mode

    private func activateStudyMode() {
        let starts = [
            "Study mode on. I'll stay out of your way. You focus.",
            "Going quiet for study mode. I'm here if you need me.",
            "Heads down. Study mode activated. Three hours. Let's go.",
            "Study mode. I'll keep the interruptions to a minimum. Promise.",
        ]
        viewModel?.setState(.vibing)
        viewModel?.showBubbleDirect(starts.randomElement()!, duration: 5)

        startStudyMilestones()
        startStudyIdleWatch()
    }

    private func startStudyMilestones() {
        // Three milestones: 25 min, 50 min, 90 min from session start.
        // Uses sequential sleep rather than absolute Date math so it
        // stays correct even if the machine sleeps between milestones.
        let milestones: [(TimeInterval, String)] = [
            (25 * 60, "25 minutes in. Solid start. Keep going."),
            (25 * 60, "You're at 50 minutes. This is the zone. Stay here."),
            (40 * 60, "90 minutes of focus. That's genuinely impressive. You can stop whenever you want — but you probably won't."),
        ]

        milestoneTask = Task { @MainActor [weak self] in
            for (delay, message) in milestones {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                guard self?.currentMode == .study else { return }
                self?.viewModel?.showBubbleDirect(message, duration: 7)
                self?.viewModel?.wave()
            }
        }
    }

    private func startStudyIdleWatch() {
        let idleThreshold: TimeInterval = 8 * 60
        let pollInterval:  TimeInterval = 60

        let stuckLines = [
            "Eight minutes quiet. Stuck on something? Ask me.",
            "You've been still for a while. Good thinking or a blocker?",
            "Long pause. I'm here if you hit a wall.",
            "Nothing happening. Working through it in your head, or need a hand?",
            "Long idle. If it's a hard problem, talk it out. I'm right here.",
        ]

        idleWatchTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(pollInterval))
                guard !Task.isCancelled else { return }
                guard self?.currentMode == .study else { return }
                guard let self else { return }
                let idle = Date().timeIntervalSince(self.lastActivityTime)
                if idle >= idleThreshold {
                    self.viewModel?.showBubbleDirect(stuckLines.randomElement()!, duration: 6)
                    // Reset to avoid firing again immediately
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
            "Dev mode on. More reactions, more energy, more celebrating the wins.",
        ]
        viewModel?.celebrate()
        viewModel?.showBubbleDirect(starts.randomElement()!, duration: 5)

        startFlowStateDetection()
        startDevIdleWatch()
    }

    private func startFlowStateDetection() {
        // Fires once at 20 min if the developer has been recently active.
        flowStateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(20 * 60))
            guard !Task.isCancelled else { return }
            guard self?.currentMode == .dev else { return }
            // Only celebrate if they've been active in the last 5 min
            guard let self,
                  Date().timeIntervalSince(self.lastActivityTime) < 5 * 60 else { return }

            let flowLines = [
                "Twenty minutes of pure dev. You're in the zone. I can feel it.",
                "Flow state detected. Don't stop. Don't open Slack. Don't you dare.",
                "20 minutes in and going. This is the good stuff. Keep it up.",
                "Flow state achieved. I'm celebrating quietly on your behalf.",
            ]
            self.viewModel?.showBubbleDirect(flowLines.randomElement()!, duration: 6)
            self.viewModel?.triggerConfetti()
        }
    }

    private func startDevIdleWatch() {
        let idleThreshold: TimeInterval = 7 * 60
        let pollInterval:  TimeInterval = 60

        let debugLines = [
            "Seven minutes quiet. Debugging in your head or actually stuck?",
            "Long pause. The bug is there. You'll find it. You always do.",
            "Rubber duck time? I'm right here. Talk me through it.",
            "Silent for a while. I believe in you. The bug does not stand a chance.",
            "If you've been staring at the same line for seven minutes, that's the one.",
            "Long idle in dev mode. Either you're thinking very hard or the bug has won temporarily.",
        ]

        idleWatchTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(pollInterval))
                guard !Task.isCancelled else { return }
                guard self?.currentMode == .dev else { return }
                guard let self else { return }
                let idle = Date().timeIntervalSince(self.lastActivityTime)
                if idle >= idleThreshold {
                    self.viewModel?.showBubbleDirect(debugLines.randomElement()!, duration: 6)
                    self.viewModel?.beConfused()
                    // Reset to avoid spamming
                    self.lastActivityTime = Date()
                }
            }
        }
    }
}
