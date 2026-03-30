import Foundation
import OSLog

// MARK: - BreakNudgeManager

/// Tracks net active time during a session and nudges the user to take a break
/// after configurable thresholds (default: 90 min, 2 h, 3 h).
///
/// "Active" means at least one keyboard/mouse event observed within the last 5 minutes.
/// A gap longer than 5 minutes resets the continuous streak (the user stepped away).
///
/// Fired messages bypass the ambient rate-limit so they always appear regardless of mute
/// or chattiness settings — they're intentional welfare checks, not chatter.
@MainActor
final class BreakNudgeManager {
    private weak var viewModel: CharacterViewModel?
    private let logger = Logger(subsystem: "com.claudy", category: "BreakNudge")

    // MARK: - State

    /// Total seconds of continuous screen time this streak
    private var continuousSeconds: Int = 0
    /// Time of the last observed activity event
    private var lastActivityTime: Date = Date()
    /// Which thresholds have already fired this streak
    private var firedThresholds: Set<Int> = []
    /// Background check loop
    private var checkTask: Task<Void, Never>?

    // MARK: - Config (in minutes, settable from SettingsView later if desired)
    private let thresholds: [Int] = [90, 120, 180]   // minutes

    // MARK: - Init

    init(viewModel: CharacterViewModel) {
        self.viewModel = viewModel
        startLoop()
    }

    // MARK: - Activity pulse (call on every keyboard / mouse event)

    func recordActivity() {
        let now = Date()
        let gap = now.timeIntervalSince(lastActivityTime)

        // Gap > 5 minutes → considered a break, reset streak
        if gap > 5 * 60 {
            continuousSeconds = 0
            firedThresholds.removeAll()
            logger.debug("Break detected (gap \(Int(gap))s) — streak reset")
        }
        lastActivityTime = now
    }

    // MARK: - Loop

    private func startLoop() {
        checkTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                self?.tick()
            }
        }
    }

    private func tick() {
        let now = Date()
        let gap = now.timeIntervalSince(lastActivityTime)

        // Only count active minutes (gap < 5 min means still active)
        guard gap < 5 * 60 else { return }
        continuousSeconds += 60

        let minutes = continuousSeconds / 60
        for threshold in thresholds where !firedThresholds.contains(threshold) && minutes >= threshold {
            firedThresholds.insert(threshold)
            fire(at: threshold)
        }
    }

    // MARK: - Messages

    private func fire(at minutes: Int) {
        logger.info("Break nudge firing at \(minutes)min")
        let msg = message(for: minutes)
        viewModel?.wave()
        viewModel?.showBubbleDirect(msg, duration: 8)
    }

    private func message(for minutes: Int) -> String {
        let mode = viewModel?.behaviorModeManager?.currentMode ?? .normal
        switch minutes {
        case 90:
            switch mode {
            case .brainRot:
                return ["no cap you been grinding for 90 min bestie 😭 touch grass rn",
                        "bro you deadass been at this for an hour and a half?? stand up fr"].randomElement()!
            case .study:
                return ["You've been studying for 90 minutes. Your brain needs a rest to consolidate what you've learned.",
                        "90 minutes of studying — take a proper break. Even 10 minutes helps retention."].randomElement()!
            case .dev:
                return ["90 minutes of deep work. Step away for 10 — your next solution will come faster if you do.",
                        "Hour and a half in. Take a break. The bugs will still be there when you get back."].randomElement()!
            default:
                return ["Hey — you've been at this for 90 minutes. How about a quick break?",
                        "90 minutes straight. Stand up, stretch, grab some water. I'll still be here."].randomElement()!
            }
        case 120:
            switch mode {
            case .brainRot:
                return ["BRO. TWO HOURS. your back is cooked fr fr 💀 get up rn no debate",
                        "two hours of screen time and you still haven't moved?? we love the grind but pls 😭"].randomElement()!
            case .study:
                return ["Two hours! Seriously impressive focus. Now rest — memory consolidation happens during breaks.",
                        "You've studied for two hours straight. Your brain is full. Take 15 minutes."].randomElement()!
            case .dev:
                return ["Two hours in the zone — that's rare. But your eyes need a break and so does your back.",
                        "Two hours. Go outside for 5 minutes. No screens. The code will thank you."].randomElement()!
            default:
                return ["Two hours. I'm starting to worry about you a little. Please take a break.",
                        "Two hours at the screen. This is me genuinely asking — are you okay? Water?"].randomElement()!
            }
        default: // 180+
            switch mode {
            case .brainRot:
                return ["THREE HOURS ??? bro are you actually okay ??? this ain't it 😭😭",
                        "3 hours no break??? we love dedication but your spine is NOT it rn"].randomElement()!
            case .study:
                return ["Three hours of continuous studying. I'm a little concerned. Please step away.",
                        "You've been studying for three hours. A proper break isn't optional now — it's necessary."].randomElement()!
            case .dev:
                return ["Three hours straight. I've seen people solve bugs faster after proper rest. Please step away.",
                        "Three hours. Whatever you're building will still be there in 20 minutes. Please take a break."].randomElement()!
            default:
                return ["Three hours. I'm not asking anymore, I'm telling you — please take a break. 🙏",
                        "Three hours at the screen. I care about you more than the code. Please step away."].randomElement()!
            }
        }
    }

    // MARK: - Expose for stats

    var continuousMinutes: Int { continuousSeconds / 60 }
}
