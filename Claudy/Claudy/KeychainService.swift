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
