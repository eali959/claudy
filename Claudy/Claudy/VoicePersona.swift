import Foundation
import AVFoundation

/// Character voice personas. Each persona maps to:
///   • a preferred AVSpeechSynthesisVoice (with sensible fallbacks),
///   • a pitch + rate tuning,
///   • an optional sentence post-processor that adds catchphrases / cadence,
///   • an OpenAI TTS voice id (used only if user has an OpenAI key + opted in).
///
/// Naming intentionally generic-adjacent — these are character flavours,
/// not impersonations.
enum VoicePersona: String, CaseIterable, Sendable, Identifiable {
    case systemDefault   // "Claudy Classic" — straight TTS, no transforms
    case cute            // "Cute Claudy"    — bright, high pitch, cheery
    case yo              // "Yo Claudy"      — deep, laid-back, light slang
    case q               // "Q Claudy"       — measured British, dry wit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .systemDefault: return "Claudy Classic"
        case .cute:          return "Cute Claudy"
        case .yo:            return "Yo Claudy"
        case .q:             return "Q Claudy"
        }
    }

    var blurb: String {
        switch self {
        case .systemDefault: return "Plain system voice. No flavour."
        case .cute:          return "Bright, bouncy, kid-show energy."
        case .yo:            return "Deep, laid-back, hip-hop cadence."
        case .q:             return "Dry British, deliberate, slightly droll."
        }
    }

    var icon: String {
        switch self {
        case .systemDefault: return "speaker.wave.2"
        case .cute:          return "heart.circle.fill"
        case .yo:            return "music.note"
        case .q:             return "cup.and.saucer.fill"
        }
    }

    // MARK: - AVSpeechSynthesizer tuning

    /// Pitch multiplier (0.5 – 2.0 per Apple docs).
    var pitch: Float {
        switch self {
        case .systemDefault: return 1.0
        case .cute:          return 1.30
        case .yo:            return 0.85
        case .q:             return 0.92
        }
    }

    /// Rate (0.0 – 1.0 in AVSpeechUtterance terms; default ≈ 0.5).
    var rate: Float {
        switch self {
        case .systemDefault: return AVSpeechUtteranceDefaultSpeechRate
        case .cute:          return 0.52
        case .yo:            return 0.48
        case .q:             return 0.46
        }
    }

    /// Volume (0–1).
    var volume: Float { 1.0 }

    /// Preferred BCP-47 language for voice lookup.
    var preferredLanguage: String {
        switch self {
        case .systemDefault: return AVSpeechSynthesisVoice.currentLanguageCode()
        case .cute:          return "en-AU"
        case .yo:            return "en-US"
        case .q:             return "en-GB"
        }
    }

    /// Hand-picked voice identifiers (Enhanced/Premium take priority when installed).
    /// Order = preference. We resolve the first one that's actually available.
    var preferredVoiceIdentifiers: [String] {
        switch self {
        case .systemDefault:
            return []
        case .cute:
            // Karen (AU) has a brighter timbre; Tessa as fallback.
            return [
                "com.apple.voice.enhanced.en-AU.Karen",
                "com.apple.voice.premium.en-AU.Karen",
                "com.apple.voice.compact.en-AU.Karen",
                "com.apple.ttsbundle.siri_Karen_en-AU_compact",
                "com.apple.voice.compact.en-ZA.Tessa"
            ]
        case .yo:
            // Reed / Aaron / Evan — deeper US male voices.
            return [
                "com.apple.voice.enhanced.en-US.Reed",
                "com.apple.voice.premium.en-US.Reed",
                "com.apple.ttsbundle.siri_Aaron_en-US_compact",
                "com.apple.voice.compact.en-US.Aaron",
                "com.apple.voice.compact.en-US.Evan",
                "com.apple.voice.compact.en-US.Fred"
            ]
        case .q:
            // Daniel (GB) is the classic refined British TTS voice.
            return [
                "com.apple.voice.enhanced.en-GB.Daniel",
                "com.apple.voice.premium.en-GB.Daniel",
                "com.apple.ttsbundle.siri_Daniel_en-GB_compact",
                "com.apple.voice.compact.en-GB.Daniel",
                "com.apple.voice.compact.en-GB.Oliver",
                "com.apple.voice.compact.en-GB.Arthur"
            ]
        }
    }

    /// OpenAI TTS voice id when routing through OpenAI (higher fidelity).
    /// Maps personas to the closest match in OpenAI's voice catalogue.
    var openAIVoice: String {
        switch self {
        case .systemDefault: return "alloy"
        case .cute:          return "shimmer"
        case .yo:            return "onyx"
        case .q:             return "fable"   // British-leaning
        }
    }

    // MARK: - Sentence post-processing

    /// Lightly tweak phrasing to add character. Kept conservative so the
    /// underlying response is preserved — we don't change meaning.
    func transform(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return text }
        switch self {
        case .systemDefault:
            return text
        case .cute:
            // Sprinkle bright punctuation, occasional sing-song "—!".
            var out = trimmed
            if !out.hasSuffix("!") && !out.hasSuffix("?") && !out.hasSuffix(".") {
                out += "!"
            }
            return out
        case .yo:
            // Light cadence intro; avoid stereotype-laden phrases.
            let intros = ["Aight, ", "So check it — ", "Listen, ", "Real talk, "]
            // Only add an intro on multi-sentence responses, ~50% chance, deterministic per content.
            if trimmed.count > 80, abs(trimmed.hashValue) % 2 == 0 {
                return (intros[abs(trimmed.hashValue) % intros.count]) + trimmed
            }
            return trimmed
        case .q:
            // Add a measured opener occasionally.
            let openers = ["Quite. ", "Indeed. ", "Hmm. ", "Observe: "]
            if trimmed.count > 60, abs(trimmed.hashValue) % 3 == 0 {
                return openers[abs(trimmed.hashValue) % openers.count] + trimmed
            }
            return trimmed
        }
    }

    // MARK: - Voice resolution

    /// Resolves the best available AVSpeechSynthesisVoice for this persona.
    /// Falls back to language, then to system default, so we never return nil
    /// silently — the caller always gets something usable.
    func resolveVoice() -> AVSpeechSynthesisVoice? {
        // 1. Try our preferred identifiers.
        for id in preferredVoiceIdentifiers {
            if let v = AVSpeechSynthesisVoice(identifier: id) {
                return v
            }
        }
        // 2. Try the language as a whole — pick first non-novelty voice.
        let allInLang = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == preferredLanguage }
            .sorted { lhs, rhs in
                // Prefer Enhanced > Premium > Default quality.
                lhs.quality.rawValue > rhs.quality.rawValue
            }
        if let v = allInLang.first { return v }
        // 3. Fall back to system default.
        return AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
    }

    /// True if at least one of our preferred identifiers is installed.
    /// Used by Settings to nudge the user to download Enhanced voices.
    var hasInstalledPremiumVoice: Bool {
        for id in preferredVoiceIdentifiers where id.contains(".enhanced.") || id.contains(".premium.") {
            if AVSpeechSynthesisVoice(identifier: id) != nil { return true }
        }
        return false
    }
}
