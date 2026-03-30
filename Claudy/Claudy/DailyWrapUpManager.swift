import Foundation
import OSLog

// MARK: - DailyWrapUpManager

/// Fires a personality-flavoured end-of-day summary at a configurable time (default 6 pm).
/// Summarises Pomodoros completed and total focus time from FocusStatsManager.
/// Uses the local reaction library for wrap-up messages to avoid a stray API call.
@MainActor
final class DailyWrapUpManager {
    private weak var viewModel: CharacterViewModel?
    private var checkTask: Task<Void, Never>?
    private var lastWrapUpDateKey: String = ""
    private let logger = Logger(subsystem: "com.claudy", category: "DailyWrapUp")

    // Hour at which the wrap-up fires (24h, default 18 = 6 pm)
    var wrapUpHour: Int {
        get { UserDefaults.standard.object(forKey: "WrapUpHour") != nil
              ? UserDefaults.standard.integer(forKey: "WrapUpHour") : 18 }
        set { UserDefaults.standard.set(newValue, forKey: "WrapUpHour") }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private var todayKey: String { Self.dateFormatter.string(from: Date()) }

    init(viewModel: CharacterViewModel) {
        self.viewModel = viewModel
        lastWrapUpDateKey = UserDefaults.standard.string(forKey: "LastWrapUpDate") ?? ""
        startLoop()
    }

    // MARK: - Loop

    private func startLoop() {
        checkTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                self?.checkWrapUp()
            }
        }
    }

    private func checkWrapUp() {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: Date())
        guard hour == wrapUpHour, lastWrapUpDateKey != todayKey else { return }
        guard FocusStatsManager.shared.pomodorosToday > 0 else { return }
        lastWrapUpDateKey = todayKey
        UserDefaults.standard.set(todayKey, forKey: "LastWrapUpDate")
        fire()
    }

    // MARK: - Message

    private func fire() {
        let stats = FocusStatsManager.shared
        let poms  = stats.pomodorosToday
        let time  = stats.focusTimeDisplay
        let msg   = buildMessage(pomodoros: poms, focusTime: time)
        logger.info("Daily wrap-up firing — \(poms) Pomodoros, \(time)")
        viewModel?.wave()
        viewModel?.showBubbleDirect(msg, duration: 10)
    }

    private func buildMessage(pomodoros: Int, focusTime: String) -> String {
        let mode        = viewModel?.behaviorModeManager?.currentMode ?? .normal
        let personality = PersonalityManager.shared.currentMode

        switch personality {
        case .director:
            let lines = [
                "That's a WRAP for today. \(pomodoros) sessions. \(focusTime) of actual work. Absolutely STELLAR. Go rest, we shoot again tomorrow.",
                "Day's done. \(pomodoros) Pomodoros. \(focusTime) on the clock. I've seen lesser performances. This was not one of them."
            ]
            return lines.randomElement()!
        case .hypeCoach:
            let lines = [
                "\(pomodoros) SESSIONS. \(focusTime) OF PURE FOCUS. That's not just a day — that's a STATEMENT. You showed UP.",
                "End of day recap: YOU CRUSHED IT. \(pomodoros) Pomodoros. \(focusTime) of locked-in work. Now go REST like a champion."
            ]
            return lines.randomElement()!
        case .mate:
            let lines = [
                "\(pomodoros) sessions. \(focusTime). Yeah nah, solid day.",
                "Right. \(pomodoros) Pomodoros, \(focusTime) focused. Could've been worse."
            ]
            return lines.randomElement()!
        case .listener:
            let lines = [
                "You did \(pomodoros) focus sessions today — \(focusTime) of real work. How are you feeling? That's worth acknowledging.",
                "End of day: \(pomodoros) Pomodoros, \(focusTime) focused. You showed up. That matters."
            ]
            return lines.randomElement()!
        case .chatty:
            let lines = [
                "So okay, here's the thing — you did \(pomodoros) focus sessions today, which is \(focusTime) of actual concentrated work, and I just want to say, that's genuinely impressive.",
                "\(pomodoros) sessions! \(focusTime) of focus! Which reminds me — you should probably eat something if you haven't, because brains need fuel, and also great work today."
            ]
            return lines.randomElement()!
        default:
            // Companion + custom, plus override for BrainRot mode
            if mode == .brainRot {
                let lines = [
                    "\(pomodoros) Pomodoros fr fr 🔥 that's \(focusTime) of genuine grind no cap. rest up bestie",
                    "wrap it up king/queen 👑 \(pomodoros) sessions and \(focusTime) of focus?? you ate that"
                ]
                return lines.randomElement()!
            }
            let lines = [
                "\(pomodoros) focus session\(pomodoros == 1 ? "" : "s") today — \(focusTime) of solid work. Good day.",
                "Day done. \(pomodoros) Pomodoro\(pomodoros == 1 ? "" : "s"), \(focusTime) of focus. You should feel good about that."
            ]
            return lines.randomElement()!
        }
    }
}
