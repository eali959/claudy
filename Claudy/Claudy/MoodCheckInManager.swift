import Foundation
import OSLog

// MARK: - MoodCheckInManager

/// Periodically asks the user how they're doing (every 2 hours of active time).
/// The check-in appears as a speech bubble. The user can tap it to respond via chat,
/// or dismiss it — both are fine.
///
/// If the user says they're struggling (chat keyword detection), CharacterViewModel
/// can call `recordStrugglingSignal()` to put Claud-y into a more supportive mode
/// for the rest of the session.
@MainActor
final class MoodCheckInManager {
    private weak var viewModel: CharacterViewModel?
    private var activeSeconds: Int = 0
    private var lastCheckInTime: Date = .distantPast
    private var checkTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.claudy", category: "MoodCheckIn")

    // Gap between check-ins (seconds of active time)
    private let checkInIntervalSeconds: Int = 2 * 60 * 60  // 2 hours

    // If the user signals they're struggling, give extra warmth for this many seconds
    private var supportModeUntil: Date = .distantPast
    var isInSupportMode: Bool { Date() < supportModeUntil }

    init(viewModel: CharacterViewModel) {
        self.viewModel = viewModel
        startLoop()
    }

    // MARK: - Activity pulse (call from BreakNudgeManager or KeyboardMonitor)

    func recordActivity() {
        activeSeconds += 60   // incremented each minute by the loop below
    }

    // MARK: - Struggling signal (called by CharacterViewModel on negative chat keywords)

    func recordStrugglingSignal() {
        supportModeUntil = Date().addingTimeInterval(30 * 60)  // 30 min support mode
        logger.info("Support mode activated for 30 min")
        let msg = supportMessage()
        viewModel?.wave()
        viewModel?.showBubbleDirect(msg, duration: 8)
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
        // Only count if actually active
        let timeSinceLastCheckIn = Date().timeIntervalSince(lastCheckInTime)
        guard timeSinceLastCheckIn > Double(checkInIntervalSeconds) else { return }

        // Don't check in if already in a conversation, muted, or focus mode
        if viewModel?.isChatOpen == true { return }
        if viewModel?.isMuted == true { return }
        if viewModel?.isFocusModeActive == true { return }

        activeSeconds += 60
        guard activeSeconds >= checkInIntervalSeconds else { return }

        activeSeconds = 0
        lastCheckInTime = Date()
        fireCheckIn()
    }

    // MARK: - Check-in message

    private func fireCheckIn() {
        let msg = checkInMessage()
        logger.info("Mood check-in firing")
        viewModel?.wave()
        viewModel?.showBubbleDirect(msg, duration: 10)
    }

    private func checkInMessage() -> String {
        let personality = PersonalityManager.shared.currentMode
        switch personality {
        case .listener:
            return ["Hey — just checking in. How are you actually doing?",
                    "It's been a while. How are you feeling? No rush, just asking."].randomElement()!
        case .hypeCoach:
            return ["HEY. Checking in. You good? You better be GREAT.",
                    "Pause. How are you feeling right now? Honest answer."].randomElement()!
        case .director:
            return ["Right, I need a status report. How are YOU doing? Not the code. YOU.",
                    "Scene break. How is the human doing right now?"].randomElement()!
        case .mate:
            return ["You alright?",
                    "How ya going?"].randomElement()!
        case .chatty:
            return ["Okay so I've been thinking — and this happens every couple hours — how are you actually doing? Like genuinely.",
                    "Random check-in! How are you? And I mean actually, not just 'fine'."].randomElement()!
        default:
            return ["Hey — how are you doing? Just checking in.",
                    "Quick check-in: how are you feeling?"].randomElement()!
        }
    }

    private func supportMessage() -> String {
        let personality = PersonalityManager.shared.currentMode
        switch personality {
        case .listener:
            return ["I hear that. Whatever's going on — it's okay not to be okay. I'm here.",
                    "That sounds hard. You don't have to push through alone."].randomElement()!
        case .hypeCoach:
            return ["Hey. Whatever's hard right now — you've handled hard things before. You WILL handle this.",
                    "Struggling is part of it. The fact you're still here means you're not done."].randomElement()!
        case .mate:
            return ["Ah yeah nah. That sucks. You'll be alright though.",
                    "Could be worse. Not saying it's not bad. Just — you'll get through it."].randomElement()!
        default:
            return ["I've got you. We'll figure it out together.",
                    "It's okay to find things hard. Take a breath. I'm here."].randomElement()!
        }
    }
}
