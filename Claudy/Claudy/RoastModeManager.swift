import Foundation
import OSLog
import Observation

private let logger = Logger(subsystem: "com.claudy", category: "RoastModeManager")

// MARK: - RoastModeManager

/// Orchestrates the Roast Me feature.
///
/// Sequence: size you up (facepalm) → compose (thinking) → deliver (talking + bubble) →
/// celebrate own genius (celebrating + confetti).
///
/// Uses the Claude API to generate a personalised roast if a key is available.
/// Falls back to a curated pool of 15 developer roasts otherwise.
@MainActor
@Observable
final class RoastModeManager {

    private(set) var isRoasting: Bool = false

    @ObservationIgnored private weak var viewModel: CharacterViewModel?
    @ObservationIgnored private var roastTask: Task<Void, Never>?

    // MARK: - Local roast pool

    private let localRoasts: [String] = [
        "Your commit history says 'fixed stuff' three times in a row. That's not version control, that's a cry for help.",
        "Four spaces or tabs? You've been arguing with yourself about this for six years. Pick one. Any one.",
        "I saw you Cmd+Z fourteen times just now. We both know that's not going to fix it.",
        "You have three Stack Overflow tabs open to the same question. The answer isn't getting better.",
        "That variable is called 'temp2'. The original 'temp' is still there. So is 'temp_final'. Bold.",
        "You've been 'almost done' for two hours. Riveting.",
        "The comment says 'don't touch this'. You're about to touch it. I can see it in your eyes.",
        "Your folder has a folder called 'New Folder (2)'. Inside it is 'New Folder'. We need to talk.",
        "You just wrote a TODO comment. That TODO is going to outlive you.",
        "You copy-pasted that without reading it. I watched you do it. You didn't even scroll.",
        "Friday deploy. Bold. Unhinged. Extremely on-brand for you.",
        "That function is 340 lines long and does seven different things. You'll refactor it 'later'.",
        "You just pushed to main. Directly. No PR. No review. Just vibes.",
        "The test suite is passing because you commented out the failing tests. Iconic work.",
        "Your function is called 'data'. It returns data about data. From a variable also called 'data'.",
    ]

    // MARK: - Init

    init(viewModel: CharacterViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Public API

    func startRoast() {
        guard !isRoasting else { return }
        isRoasting = true
        roastTask = Task { await runRoastSequence() }
        logger.info("Roast sequence started")
    }

    // MARK: - Sequence

    private func runRoastSequence() async {
        guard let vm = viewModel else { isRoasting = false; return }

        // Phase 1: Sizing you up
        vm.setState(.facepalm)
        try? await Task.sleep(for: .milliseconds(900))

        // Phase 2: Composing the roast
        vm.setThinking()
        let roast = await generateRoast()
        try? await Task.sleep(for: .milliseconds(500))

        // Phase 3: Deliver
        vm.setTalking()
        vm.showBubbleDirect(roast, duration: 9.0)
        try? await Task.sleep(for: .milliseconds(700))

        // Phase 4: Absolutely delighted with itself
        vm.setState(.celebrating)
        vm.triggerConfetti()
        try? await Task.sleep(for: .seconds(3.5))

        vm.stopTalking()
        isRoasting = false
        logger.info("Roast sequence complete")
    }

    // MARK: - Roast generation

    private func generateRoast() async -> String {
        // Try the Claude API first for a personalised roast
        let context = buildContext()
        let systemPrompt = """
        You are Claud-y in Roast Mode. You are a tiny orange desktop creature who has been watching this developer all day. \
        Roast them in ONE sharp, funny, affectionate sentence. Be specific. Be biting. Be brilliant. \
        Do not use em dashes. Do not explain the joke. Max 28 words. Just the roast.
        """
        let prompt = "Context: \(context). Roast them."

        if let apiRoast = await ClaudeAPIService.shared.singleMessage(prompt, systemPrompt: systemPrompt) {
            // Strip surrounding quotes if the model wraps the response
            let clean = apiRoast.trimmingCharacters(in: .init(charactersIn: "\"'"))
            if !clean.isEmpty { return clean }
        }

        // Fallback: curated local pool
        return localRoasts.randomElement() ?? localRoasts[0]
    }

    private func buildContext() -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let weekday = calendar.component(.weekday, from: Date())

        let dayName: String
        switch weekday {
        case 1: dayName = "Sunday"
        case 2: dayName = "Monday"
        case 3: dayName = "Tuesday"
        case 4: dayName = "Wednesday"
        case 5: dayName = "Thursday"
        case 6: dayName = "Friday"
        case 7: dayName = "Saturday"
        default: dayName = "today"
        }

        let timeDesc: String
        switch hour {
        case 0...4:  timeDesc = "it is \(hour)am and they are still coding"
        case 5...8:  timeDesc = "they started coding before most people are awake"
        case 9...11: timeDesc = "it is a \(dayName) morning"
        case 12...13: timeDesc = "it is lunchtime on \(dayName) and they are still coding"
        case 14...17: timeDesc = "it is a \(dayName) afternoon"
        case 18...20: timeDesc = "it is evening and they are still at their desk"
        case 21...23: timeDesc = "it is late \(dayName) evening and they refuse to stop"
        default:     timeDesc = "it is \(dayName)"
        }

        let dayNote = weekday == 6 ? " It is Friday — if they deploy today, roast that specifically." : ""
        let nightNote = (hour >= 22 || hour <= 4) ? " They are coding in the middle of the night." : ""

        return "\(timeDesc).\(dayNote)\(nightNote)"
    }
}
