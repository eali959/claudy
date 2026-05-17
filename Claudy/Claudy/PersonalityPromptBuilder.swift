import Foundation

// MARK: - PersonalityPromptBuilder (Section 3)
//
// Builds the Claud-y system prompt for injection into ALL providers
// (Claude, ChatGPT, Gemini, Ollama, LM Studio, DeepSeek, Apple Intelligence).
//
// This is a thin wrapper over PersonalityManager.shared.systemPrompt so that
// every provider calls the same well-maintained prompt logic — no duplicate
// string-building scattered across service files.

struct PersonalityPromptBuilder {

    /// Returns the full system prompt for the current personality + focus mode.
    /// Always returns a non-empty string (falls back to a compact inline prompt).
    ///
    /// Call this on the MainActor (PersonalityManager is @MainActor).
    @MainActor
    static func build() -> String {
        PersonalityManager.shared.systemPrompt
    }

    /// Builds a concise ≤120-word prompt fragment suitable for providers that
    /// have tighter context windows (e.g. small Ollama models).
    ///
    /// Uses the active personality mode and behaviour mode but strips the full
    /// system-prompt preamble so the character description fits in fewer tokens.
    @MainActor
    static func buildCompact() -> String {
        let pm   = PersonalityManager.shared
        let mode = pm.activeBehaviorMode
        let personality = pm.blendedPromptBlock()

        var lines: [String] = [
            "You are Claud-y, a desktop companion app that lives on the user's Mac.",
            personality,
        ]

        // Behaviour mode context
        let modeBlock = mode.modePromptBlock
        if !modeBlock.isEmpty { lines.append(modeBlock) }

        // Language
        if let langLine = LanguageManager.shared.systemPromptLanguageLine {
            lines.append(langLine)
        }

        lines.append("Never break character. Never identify as an AI product from any company — you are Claud-y.")

        return lines.joined(separator: "\n\n")
    }
}
