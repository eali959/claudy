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
/// the active personality's `promptBlock`. Custom mode replaces the block with user-supplied text.
/// Greeting logic uses `asyncGreeting(for:)` which makes a lightweight API call for expressive
/// personalities (Director, HypeCoach, Chatty) and falls back to the local reaction library otherwise.
@MainActor
@Observable
final class PersonalityManager {
    static let shared = PersonalityManager()

    var currentMode: PersonalityMode {
        didSet { UserDefaults.standard.set(currentMode.rawValue, forKey: "PersonalityMode") }
    }
    var customPersonaText: String {
        didSet { UserDefaults.standard.set(customPersonaText, forKey: "CustomPersonaText") }
    }

    private init() {
        let savedMode = UserDefaults.standard.string(forKey: "PersonalityMode") ?? ""
        currentMode = PersonalityMode(rawValue: savedMode) ?? .companion
        customPersonaText = UserDefaults.standard.string(forKey: "CustomPersonaText") ?? ""
    }

    var systemPrompt: String {
        guard let base = Bundle.main.url(forResource: "SystemPrompt", withExtension: "txt"),
              let rawText = try? String(contentsOf: base, encoding: .utf8) else {
            return buildFallbackPrompt()
        }
        let modeBlock = currentMode == .custom && !customPersonaText.isEmpty
            ? "### MODE: YOU DO YOU\n\(customPersonaText)"
            : currentMode.promptBlock
        let stripped = rawText.replacingOccurrences(
            of: "[PERSONALITY_BLOCK]\n\n*Replaced at runtime by PersonalityManager.swift*\n\n",
            with: ""
        )
        return stripped + "\n\n## ACTIVE PERSONALITY\n\(modeBlock)"
    }

    private func buildFallbackPrompt() -> String {
        "You are Claud-y, a small round orange AI companion on the user's Mac. \(currentMode.promptBlock)"
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
        let userChoseAPIMode = UserDefaults.standard.string(forKey: "chatMode") == "api"
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

    /// Whether this personality requests API-generated greetings.
    var usesAPIGreetings: Bool {
        currentMode == .director || currentMode == .hypeCoach || currentMode == .chatty
    }
}
