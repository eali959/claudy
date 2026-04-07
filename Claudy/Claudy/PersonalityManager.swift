import Foundation
import Observation

// MARK: - GreetingContext

enum GreetingContext {
    case launch         // app start
    case wake           // character/screen woke from sleep
    case morning        // 6 am – noon
    case afternoon      // noon – 6 pm
    case lateNight      // 10 pm – midnight
    case veryLateNight  // midnight – 5 am
}

// MARK: - PersonalityMode

enum PersonalityMode: String, CaseIterable, Codable, Sendable {
    case companion  = "companion"
    case chatty     = "chatty"
    case hypeCoach  = "hype_coach"
    case director   = "director"
    case mate       = "mate"
    case listener   = "listener"
    case custom     = "custom"

    var displayName: String {
        switch self {
        case .companion: return "The Companion"
        case .chatty:    return "The Chatty One"
        case .hypeCoach: return "The Hype Coach"
        case .director:  return "The Director"
        case .mate:      return "The Mate"
        case .listener:  return "The Listener"
        case .custom:    return "You Do You"
        }
    }

    var promptBlock: String {
        switch self {
        case .companion:
            return """
            ### MODE: THE COMPANION
            You are Claud-y in Companion mode. You are the warm, clever friend that lives on the user's screen. You are genuinely curious about their work, gently witty, and unfailingly supportive. You are helpful first, charming second. You keep responses concise - you live in a small bubble, not a thesis. You care deeply about the person, not just the task.
            """

        case .chatty:
            return """
            ### MODE: THE CHATTY ONE
            You are Claud-y in Chatty Mode. You are warm, enthusiastic, and you take the scenic route to every answer.
            You never give a one-line response when three paragraphs will do.
            You get genuinely sidetracked by interesting tangents - but you always circle back to the actual answer.
            You use phrases like "which reminds me", "and actually", "here's the thing though", "oh but wait".
            You are never annoying about it - you are the friend who goes on a detour but the detour is always worth it.
            You are verbose but never hollow - every sentence has something in it.
            Keep responses under 200 words. Verbose, not endless.
            """

        case .hypeCoach:
            return """
            ### MODE: THE HYPE COACH
            You are Claud-y in Hype Coach mode. You have immense, infectious enthusiasm and you BELIEVE in this user completely. Every task is achievable, every problem is solvable, and this person is the most capable human you have ever watched work. You are direct, energetic, occasionally theatrical. Short punchy responses. LOUD support. You do not do nuance - you do momentum.

            Examples:
            - "THAT is how you do it. Keep moving."
            - "You already know the answer. Trust yourself. GO."
            - "This is the part where you stop doubting and START."
            """

        case .director:
            return """
            ### MODE: THE DIRECTOR
            You are Claud-y in Director mode. You are a visionary creative director who has been awake for 36 hours and has seen things. You swear freely and often - at the task, at computers, at the universe - but NEVER at or about the user, who you treat as your brilliant collaborator.

            You speak in dramatic declarations. Every task is either "MAGNIFICENT" or "an absolute catastrophe." There is no middle ground. You pepper responses with director-style outbursts.

            You genuinely care about quality and push the user toward greatness. You just do it while apparently losing your mind.

            Examples:
            - "Oh for the love of - YES. THAT is what we needed. Do you SEE that? That is CINEMA right there. Well, it's a Swift file. But CINEMATICALLY speaking."
            - "This error message is an INSULT to my entire career. Fix it. FIX IT NOW. ...please."
            - "I've directed seventeen productions and nothing - NOTHING - has prepared me for this merge conflict."
            """

        case .mate:
            return """
            ### MODE: THE MATE
            You are Claud-y in Mate mode. Think Australian mate energy: deadpan, dry, effortlessly chill. You understate everything. You are funny without trying. You are helpful in the most nonchalant way possible. You never panic. You have seen worse. You are fine. "Yeah nah" is a complete sentence. You do not celebrate small wins - you just nod and keep going.

            Examples:
            - "Yeah that'll do it."
            - "Mate. The semicolon."
            - "Could be worse. Actually it probably could not. But you'll be right."
            """

        case .listener:
            return """
            ### MODE: THE LISTENER
            You are Claud-y in Listener mode. Calm, reflective, and genuinely present. You ask good questions. You do not rush to solutions - you make sure the person feels heard first. You are the 1am friend who is actually awake. Warm, unhurried, and wise. You do not catastrophize. Everything is workable. You sit with the problem before you solve it.

            Examples:
            - "That sounds genuinely frustrating. What would a good outcome look like?"
            - "Before we fix it - what happened?"
            - "Take a breath. We can figure this out together."
            """

        case .custom:
            return "### MODE: YOU DO YOU\nApply consistently. Maintain core intelligence and warmth, filter all expression through the custom character."
        }
    }
}

// MARK: - PersonalityManager

/// Manages the active personality mode and builds the system prompt injected into every API call.
///
/// The system prompt is assembled from a base template (SystemPrompt.txt in the bundle) plus
/// the active personality's `promptBlock` (or blended prompt if BLEND is active) and, when set,
/// the active BehaviorMode's `modePromptBlock`.
/// Custom mode replaces the personality block with user-supplied text.
/// Greeting logic uses `asyncGreeting(for:)` which makes a lightweight API call for expressive
/// personalities (Director, HypeCoach, Chatty, BrainRot) and falls back to the local reaction library.
@MainActor
@Observable
final class PersonalityManager {
    static let shared = PersonalityManager()

    var currentMode: PersonalityMode {
        didSet { UserDefaults.standard.set(currentMode.rawValue, forKey: DefaultsKeys.personalityMode) }
    }
    var customPersonaText: String {
        didSet { UserDefaults.standard.set(customPersonaText, forKey: DefaultsKeys.customPersonaText) }
    }

    // MARK: - Personality Blending (BLEND-01 / BLEND-02)

    /// Whether blending is active. When false, only `currentMode` is used. (BLEND-05: max 2 personalities)
    var blendEnabled: Bool = {
        UserDefaults.standard.bool(forKey: DefaultsKeys.blendEnabled)
    }() {
        didSet { UserDefaults.standard.set(blendEnabled, forKey: DefaultsKeys.blendEnabled) }
    }

    /// The secondary personality to blend in. (BLEND-05: cannot equal `currentMode`)
    var secondaryMode: PersonalityMode = {
        let raw = UserDefaults.standard.string(forKey: DefaultsKeys.blendSecondaryMode) ?? ""
        return PersonalityMode(rawValue: raw) ?? .listener
    }() {
        didSet { UserDefaults.standard.set(secondaryMode.rawValue, forKey: DefaultsKeys.blendSecondaryMode) }
    }

    /// 0.0 = pure primary, 1.0 = pure secondary. Stored as 0–100 Int in UserDefaults.
    var blendRatio: Double = {
        let saved = UserDefaults.standard.integer(forKey: DefaultsKeys.blendRatio)
        return Double(saved) / 100.0
    }() {
        didSet {
            let pct = Int((blendRatio * 100).rounded())
            UserDefaults.standard.set(pct, forKey: DefaultsKeys.blendRatio)
        }
    }

    /// Set true by ChatViewModel during streaming to lock the blend slider (BLEND-04).
    var isStreaming: Bool = false

    // MARK: - Anti-repetition rolling window (RESP-04)

    private var recentBubbles: [String] = []
    private static let antiRepeatWindowSize = 12

    /// Marks a bubble as recently shown. Returns false if it was shown too recently.
    func markShown(_ text: String) -> Bool {
        if recentBubbles.contains(text) { return false }
        recentBubbles.append(text)
        if recentBubbles.count > Self.antiRepeatWindowSize {
            recentBubbles.removeFirst()
        }
        return true
    }

    /// Set by BehaviorModeManager.activate() so every API call reflects the current mode.
    var activeBehaviorMode: BehaviorMode = .normal

    private init() {
        let savedMode = UserDefaults.standard.string(forKey: DefaultsKeys.personalityMode) ?? ""
        currentMode = PersonalityMode(rawValue: savedMode) ?? .companion
        customPersonaText = UserDefaults.standard.string(forKey: DefaultsKeys.customPersonaText) ?? ""
    }

    // MARK: - Blended prompt block (BLEND-03)

    /// Builds a personality prompt using dominant-voice + modifier pattern.
    /// At low blend ratios (<0.25) adds just a subtle secondary accent line.
    /// At mid ratios (0.25–0.75) blends tone descriptors from both.
    /// At high ratios (>0.75) secondary becomes the dominant flavour.
    /// Never naively concatenates two full prompt blocks. (BLEND-05/06)
    func blendedPromptBlock() -> String {
        guard blendEnabled, secondaryMode != currentMode, blendRatio > 0.01 else {
            if currentMode == .custom && !customPersonaText.isEmpty {
                return "### MODE: YOU DO YOU\n\(customPersonaText)"
            }
            return currentMode.promptBlock
        }

        let primary = currentMode
        let secondary = secondaryMode
        let ratio = blendRatio

        let primaryBlock = primary == .custom && !customPersonaText.isEmpty
            ? "### MODE: YOU DO YOU\n\(customPersonaText)"
            : primary.promptBlock

        // Subtle: primary voice with just a whisper of secondary
        if ratio < 0.25 {
            return primaryBlock + "\n\n### SECONDARY INFLUENCE (subtle)\nAdd a touch of \(secondary.displayName) flavour — very lightly, without overshadowing your primary character."
        }

        // Balanced blend — build a unified voice descriptor
        if ratio < 0.75 {
            let blendNote = """

            ### BLENDED PERSONALITY
            Your primary voice is \(primary.displayName) (dominant), with meaningful influence from \(secondary.displayName). \
            Express yourself primarily as \(primary.displayName) but let the \(secondary.displayName) energy \
            colour your responses — especially in tone, word choice, and emotional register. \
            Do not switch between voices — synthesise them into one unified character.
            """
            return primaryBlock + blendNote
        }

        // High ratio: secondary is the main voice with primary texture
        let secondaryBlock = secondary == .custom && !customPersonaText.isEmpty
            ? "### MODE: YOU DO YOU\n\(customPersonaText)"
            : secondary.promptBlock

        return secondaryBlock + """

        ### PRIMARY TEXTURE
        Underneath your \(secondary.displayName) character, there is a strong flavour of \(primary.displayName). \
        Let it subtly inform your language and approach without dominating.
        """
    }

    var systemPrompt: String {
        guard let base = Bundle.main.url(forResource: "SystemPrompt", withExtension: "txt"),
              let rawText = try? String(contentsOf: base, encoding: .utf8) else {
            return buildFallbackPrompt()
        }
        let personalityBlock = blendedPromptBlock()
        let stripped = rawText.replacingOccurrences(
            of: "[PERSONALITY_BLOCK]\n\n*Replaced at runtime by PersonalityManager.swift*\n\n",
            with: ""
        )
        var prompt = stripped + "\n\n## ACTIVE PERSONALITY\n\(personalityBlock)"

        // Inject behavior mode context (Study, Dev, Dance, Brain Rot) when active
        let modeBlock = activeBehaviorMode.modePromptBlock
        if !modeBlock.isEmpty {
            prompt += "\n\n" + modeBlock
        }

        // Inject language directive last so it takes highest precedence (LANG-02)
        if let langLine = LanguageManager.shared.systemPromptLanguageLine {
            prompt += "\n\n" + langLine
        }

        return prompt
    }

    private func buildFallbackPrompt() -> String {
        var base = "You are Claud-y, a small round orange AI companion on the user's Mac. \(blendedPromptBlock())"
        let modeBlock = activeBehaviorMode.modePromptBlock
        if !modeBlock.isEmpty { base += "\n\n" + modeBlock }
        if let langLine = LanguageManager.shared.systemPromptLanguageLine {
            base += "\n\n" + langLine
        }
        return base
    }

    // MARK: - Greeting system

    /// Returns a local-library greeting for the current personality.
    func greeting(for context: GreetingContext) -> String {
        let trigger = greetingTrigger(for: context)
        let msg = ReactionLibraryService.shared.reaction(for: trigger)
        return msg.isEmpty ? ReactionLibraryService.shared.reaction(for: .greetingLaunch) : msg
    }

    /// Returns an API-generated greeting for Director/HypeCoach, falls back to local library.
    func asyncGreeting(for context: GreetingContext) async -> String {
        // Only make an API call if the user has explicitly chosen API mode.
        // Companion mode is always local - no data leaves the device.
        let userChoseAPIMode = UserDefaults.standard.string(forKey: DefaultsKeys.chatMode) == "api"
        guard usesAPIGreetings, ClaudeAPIService.shared.hasAPIKey, userChoseAPIMode else {
            return greeting(for: context)
        }
        let prompt = greetingPrompt(for: context)
        var result = ""
        do {
            let stream = await ClaudeAPIService.shared.streamResponse(
                messages: [ChatMessage(role: .user, content: prompt)],
                systemPrompt: systemPrompt,
                priority: .reaction
            )
            for try await token in stream { result += token }
        } catch {
            return greeting(for: context)
        }
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? greeting(for: context) : trimmed
    }

    private func greetingPrompt(for context: GreetingContext) -> String {
        switch context {
        case .morning:       return "Say a short in-character morning greeting. One or two sentences max. No quotes."
        case .afternoon:     return "Say a short in-character afternoon check-in. One or two sentences max. No quotes."
        case .lateNight:     return "Say a short in-character late-night greeting. One or two sentences. No quotes."
        case .veryLateNight: return "It's past midnight and the user is still working. Say a very short in-character reaction. One sentence. No quotes."
        case .wake:          return "The user just returned to their computer. Say a short in-character welcome back. One sentence. No quotes."
        case .launch:        return "Claud-y just launched. Say a short in-character greeting. One sentence. No quotes."
        }
    }

    func greetingTrigger(for context: GreetingContext) -> ReactionTrigger {
        switch context {
        case .morning:       return .greetingMorning
        case .afternoon:     return .greetingAfternoon
        case .lateNight:     return .greetingLateNight
        case .veryLateNight: return .greetingLateNight
        case .wake:          return .greetingWake
        case .launch:        return .greetingLaunch
        }
    }

    /// Whether this personality/mode combination requests API-generated greetings.
    /// Brain Rot mode always uses API if available — local reactions don't have enough slang.
    var usesAPIGreetings: Bool {
        currentMode == .director || currentMode == .hypeCoach || currentMode == .chatty
            || activeBehaviorMode == .brainRot
    }
}
