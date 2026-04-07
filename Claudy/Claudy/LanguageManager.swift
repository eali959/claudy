import Foundation
import Observation

// MARK: - AppLanguage

/// All supported display languages for Claud-y's responses.
/// Default is British English (en-GB). Each case carries the reaction library JSON file name
/// and the API instruction line injected into the system prompt for non-English responses.
enum AppLanguage: String, CaseIterable, Codable {
    case english           = "en"
    case spanish           = "es"
    case french            = "fr"
    case german            = "de"
    case portuguese        = "pt"
    case japanese          = "ja"        // standard Japanese, mixed script (kanji/kana), no transliteration
    case chineseSimplified = "zh-Hans"   // Simplified Chinese, no transliteration
    case hindi             = "hi"        // Devanagari script
    case urdu              = "ur"        // Nastaliq/Urdu script, RTL
    case arabic            = "ar"        // Arabic script, RTL, transliteration optionally alongside

    var displayName: String {
        switch self {
        case .english:           return "English (UK)"
        case .spanish:           return "Español"
        case .french:            return "Français"
        case .german:            return "Deutsch"
        case .portuguese:        return "Português"
        case .japanese:          return "日本語"
        case .chineseSimplified: return "中文（简体）"
        case .hindi:             return "हिन्दी"
        case .urdu:              return "اردو"
        case .arabic:            return "العربية"
        }
    }

    var flag: String {
        switch self {
        case .english:           return "🇬🇧"
        case .spanish:           return "🇪🇸"
        case .french:            return "🇫🇷"
        case .german:            return "🇩🇪"
        case .portuguese:        return "🇵🇹"
        case .japanese:          return "🇯🇵"
        case .chineseSimplified: return "🇨🇳"
        case .hindi:             return "🇮🇳"
        case .urdu:              return "🇵🇰"
        case .arabic:            return "🇸🇦"
        }
    }

    /// JSON file name (without extension) for the localised reaction library.
    /// Returns nil for English (uses the default ReactionLibrary.json).
    var reactionLibraryFileName: String? {
        self == .english ? nil : "ReactionLibrary_\(rawValue)"
    }

    /// Instruction appended to the AI system prompt to enforce language output.
    /// Nil for English (no instruction needed — model defaults to English).
    var systemPromptLanguageLine: String? {
        switch self {
        case .english:
            return nil
        case .spanish:
            return "LANGUAGE DIRECTIVE: Respond ONLY in Spanish (castellano). Do not use English."
        case .french:
            return "LANGUAGE DIRECTIVE: Respond ONLY in French. Do not use English."
        case .german:
            return "LANGUAGE DIRECTIVE: Respond ONLY in German. Do not use English."
        case .portuguese:
            return "LANGUAGE DIRECTIVE: Respond ONLY in Portuguese (European). Do not use English."
        case .japanese:
            return "LANGUAGE DIRECTIVE: Respond ONLY in standard Japanese using natural kanji/hiragana/katakana mixed script. Do NOT use romaji transliteration."
        case .chineseSimplified:
            return "LANGUAGE DIRECTIVE: Respond ONLY in Simplified Chinese (普通话). Do NOT use pinyin transliteration. Use standard Mandarin character output."
        case .hindi:
            return "LANGUAGE DIRECTIVE: Respond ONLY in Hindi using Devanagari script (हिन्दी). Do not use English."
        case .urdu:
            return "LANGUAGE DIRECTIVE: Respond ONLY in Urdu using Urdu/Nastaliq script (اردو). Do not use English."
        case .arabic:
            return "LANGUAGE DIRECTIVE: Respond ONLY in Arabic (العربية). You may include transliteration alongside Arabic text where it aids pronunciation or comprehension."
        }
    }

    /// Whether the language is written right-to-left.
    var isRTL: Bool {
        switch self {
        case .urdu, .arabic: return true
        default:             return false
        }
    }

    /// Short in-character acknowledgment shown when the user switches to this language.
    /// Written in the target language so it immediately demonstrates the change.
    var switchAcknowledgment: String {
        switch self {
        case .english:           return "Back to English. Feels like home."
        case .spanish:           return "¡Cambiado al español! Hola de nuevo."
        case .french:            return "Français activé. Bonjour !"
        case .german:            return "Auf Deutsch jetzt. Verstanden."
        case .portuguese:        return "Português ativado. Olá!"
        case .japanese:          return "日本語モードに切り替えました。よろしく！"
        case .chineseSimplified: return "切换到中文了。你好！"
        case .hindi:             return "हिन्दी मोड चालू। नमस्ते!"
        case .urdu:              return "اردو موڈ فعال۔ آداب!"
        case .arabic:            return "تم التبديل للعربية. مرحباً!"
        }
    }
}

// MARK: - LanguageManager

/// Manages Claud-y's active display language.
/// Drives both the companion mode reaction pool selection and the API mode system prompt injection.
@MainActor
@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    var activeLanguage: AppLanguage {
        didSet {
            guard activeLanguage != oldValue else { return }
            UserDefaults.standard.set(activeLanguage.rawValue, forKey: DefaultsKeys.activeLanguage)
            // Reload the reaction library for the new language
            ReactionLibraryService.shared.reloadForLanguage(activeLanguage)
            // Notify character + chat to acknowledge the switch in the new language
            NotificationCenter.default.post(
                name: .claudyLanguageChanged,
                object: activeLanguage
            )
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: DefaultsKeys.activeLanguage) ?? "en"
        activeLanguage = AppLanguage(rawValue: saved) ?? .english
    }

    /// Language directive injected at the end of every API system prompt.
    var systemPromptLanguageLine: String? {
        activeLanguage.systemPromptLanguageLine
    }
}
