import Foundation
import Security

enum KeychainError: LocalizedError {
    case notFound
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .notFound:           return "API key not found in Keychain."
        case .saveFailed(let s):  return "Keychain save failed: \(s)"
        case .deleteFailed(let s): return "Keychain delete failed: \(s)"
        case .decodingFailed:     return "Failed to decode stored key."
        }
    }
}

// MARK: - APIProvider

/// The AI backend currently in use. Persisted in UserDefaults ("SelectedProvider").
enum APIProvider: String, CaseIterable, Sendable {
    case claude   = "claude"
    case openai   = "openai"
    case gemini   = "gemini"
    // v4.0 — local providers (no API key required)
    case ollama   = "ollama"
    case lmStudio = "lmstudio"
    // v4.0 — cloud OpenAI-compatible
    case deepseek = "deepseek"

    /// True for providers that run entirely on-device and need no API key.
    nonisolated var isLocal: Bool {
        self == .ollama || self == .lmStudio
    }

    var displayName: String {
        switch self {
        case .claude:   return "Claude (Anthropic)"
        case .openai:   return "ChatGPT (OpenAI)"
        case .gemini:   return "Gemini (Google)"
        case .ollama:   return "Ollama"
        case .lmStudio: return "LM Studio"
        case .deepseek: return "DeepSeek"
        }
    }

    /// Icon SF Symbol for the provider
    var icon: String {
        switch self {
        case .claude:   return "sparkles"
        case .openai:   return "bubble.left.and.bubble.right"
        case .gemini:   return "g.circle"
        case .ollama:   return "cpu"
        case .lmStudio: return "server.rack"
        case .deepseek: return "waveform"
        }
    }

    nonisolated var keychainAccount: String {
        switch self {
        case .claude:   return "claude-api-key"
        case .openai:   return "openai-api-key"
        case .gemini:   return "gemini-api-key"
        case .deepseek: return "deepseek-api-key"
        case .ollama, .lmStudio: return ""  // no key needed for local providers
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .claude:   return "sk-ant-api03-…"
        case .openai:   return "sk-proj-…"
        case .gemini:   return "AIzaSy…"
        case .deepseek: return "sk-…"
        case .ollama, .lmStudio: return ""
        }
    }

    var privacyNote: String {
        switch self {
        case .claude:
            return "Keychain-stored (kSecAttrAccessibleWhenUnlockedThisDeviceOnly) — device-only, encrypted by macOS. Sent only to api.anthropic.com over HTTPS."
        case .openai:
            return "Keychain-stored (kSecAttrAccessibleWhenUnlockedThisDeviceOnly) — device-only, encrypted by macOS. Sent only to api.openai.com over HTTPS."
        case .gemini:
            return "Keychain-stored (kSecAttrAccessibleWhenUnlockedThisDeviceOnly) — device-only, encrypted by macOS. Sent only to generativelanguage.googleapis.com over HTTPS."
        case .deepseek:
            return "Keychain-stored (kSecAttrAccessibleWhenUnlockedThisDeviceOnly) — device-only, encrypted by macOS. Sent only to api.deepseek.com over HTTPS."
        case .ollama, .lmStudio:
            return "Local provider — runs entirely on your Mac. No data ever leaves your device."
        }
    }

    var docsURL: String {
        switch self {
        case .claude:   return "https://console.anthropic.com/settings/keys"
        case .openai:   return "https://platform.openai.com/api-keys"
        case .gemini:   return "https://aistudio.google.com/app/apikey"
        case .deepseek: return "https://platform.deepseek.com/api_keys"
        case .ollama:   return "https://ollama.com"
        case .lmStudio: return "https://lmstudio.ai"
        }
    }

    /// Default fast model for reactions / ambient commentary
    var fastModel: String {
        switch self {
        case .claude:   return "claude-3-5-haiku-20241022"
        case .openai:   return "gpt-4o-mini"
        case .gemini:   return "gemini-2.0-flash"
        case .ollama:   return UserDefaults.standard.string(forKey: DefaultsKeys.ollamaModel) ?? "llama3.2:3b"
        case .lmStudio: return UserDefaults.standard.string(forKey: DefaultsKeys.lmStudioModel) ?? ""
        case .deepseek: return "deepseek-chat"
        }
    }

    /// Default chat model
    var defaultModel: String {
        switch self {
        case .claude:   return "claude-haiku-4-5-20251001"
        case .openai:   return "gpt-4o-mini"
        case .gemini:   return "gemini-2.0-flash"
        case .ollama:   return UserDefaults.standard.string(forKey: DefaultsKeys.ollamaModel) ?? "llama3.2:3b"
        case .lmStudio: return UserDefaults.standard.string(forKey: DefaultsKeys.lmStudioModel) ?? ""
        case .deepseek: return "deepseek-chat"
        }
    }

    /// Smarter / larger model
    var smartModel: String {
        switch self {
        case .claude:   return "claude-sonnet-4-6"
        case .openai:   return "gpt-4o"
        case .gemini:   return "gemini-1.5-pro"
        case .ollama:   return UserDefaults.standard.string(forKey: DefaultsKeys.ollamaModel) ?? "llama3.2:3b"
        case .lmStudio: return UserDefaults.standard.string(forKey: DefaultsKeys.lmStudioModel) ?? ""
        case .deepseek: return "deepseek-reasoner"
        }
    }

    nonisolated static var selected: APIProvider {
        get {
            let raw = UserDefaults.standard.string(forKey: "SelectedProvider") ?? "claude"
            return APIProvider(rawValue: raw) ?? .claude
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "SelectedProvider")
        }
    }
}

enum KeychainService {
    // nonisolated: Keychain APIs are internally thread-safe; allow calls from any actor context.
    // service/account are inlined as locals to prevent Swift from inferring actor isolation on
    // static properties via proximity to Security framework constants.
    nonisolated static func save(_ key: String) throws {
        let service = "com.claudy"
        let account = "claude-api-key"
        guard let data = key.data(using: .utf8) else { return }
        try? delete()  // remove any existing entry first
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     service,
            kSecAttrAccount:     account,
            kSecValueData:       data,
            kSecAttrAccessible:  kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    nonisolated static func load() throws -> String {
        let service = "com.claudy"
        let account = "claude-api-key"
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      account,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { throw KeychainError.notFound }
        guard let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }
        return key
    }

    nonisolated static func delete() throws {
        let service = "com.claudy"
        let account = "claude-api-key"
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    // MARK: - Provider-parameterised variants

    nonisolated static func save(_ key: String, for provider: APIProvider) throws {
        let service = "com.claudy"
        let account = provider.keychainAccount
        guard let data = key.data(using: .utf8) else { return }
        try? delete(for: provider)
        let query: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    service,
            kSecAttrAccount:    account,
            kSecValueData:      data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    nonisolated static func load(for provider: APIProvider) throws -> String {
        let service = "com.claudy"
        let account = provider.keychainAccount
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { throw KeychainError.notFound }
        guard let data = item as? Data, let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }
        return key
    }

    nonisolated static func delete(for provider: APIProvider) throws {
        let service = "com.claudy"
        let account = provider.keychainAccount
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    nonisolated static func has(for provider: APIProvider) -> Bool {
        // Local providers (Ollama, LM Studio) never need a key — always "available"
        if provider.isLocal { return true }
        let service = "com.claudy"
        let account = provider.keychainAccount
        guard !account.isEmpty else { return false }
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    /// Checks whether an API key entry exists WITHOUT reading its value.
    /// This does NOT trigger the macOS keychain access dialog because
    /// it requests no secret data - only the item's presence is tested.
    /// The dialog only appears when `load()` actually reads the key value
    /// (i.e. when an API call is about to be made).
    nonisolated static var hasAPIKey: Bool {
        let service = "com.claudy"
        let account = "claude-api-key"
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecMatchLimit:  kSecMatchLimitOne
            // No kSecReturnData / kSecReturnRef / kSecReturnAttributes -
            // we're only asking "does this item exist?" not "give me its secret".
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
}
