import Foundation
import OSLog

/// V5.11 — Optional local persistence for chat history.
///
/// **Off by default.** When the user enables it via Settings → Privacy &
/// Storage → "Save chat history locally", subsequent chat messages are
/// JSON-encoded and written to a single file in the user's Application
/// Support directory.  When disabled, the file is left untouched (the user
/// can clear it explicitly via the "Clear saved chat history" button).
///
/// Storage:
///   ~/Library/Application Support/Claudy/chat_history.json
///
/// Privacy notes:
/// - The file is unencrypted JSON.  Anyone with access to the user's macOS
///   account could read it.  The user is informed of this in the Settings
///   description.  We do NOT use the keychain because chat content is
///   typically larger than keychain items.
/// - Nothing leaves the device.  This is purely local persistence.
/// - Disabling the toggle does NOT auto-delete the file.  The user must
///   tap "Clear saved chat history" to remove it.  This is intentional —
///   accidental disable should not lose data.
@MainActor
final class ChatHistoryStore {
    static let shared = ChatHistoryStore()
    private let logger = Logger(subsystem: "com.claudy", category: "ChatHistoryStore")
    private let fileName = "chat_history.json"

    private init() {}

    /// Whether the user has opted in to chat history persistence.
    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKeys.saveChatHistory)
    }

    /// Path to the on-disk JSON file.  ~/Library/Application Support/Claudy/chat_history.json
    private var storeURL: URL? {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ) else { return nil }
        let dir = appSupport.appendingPathComponent("Claudy", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    /// Save the current message list.  No-op when isEnabled is false.
    /// Caller invokes this from ChatViewModel after each message append.
    func save(_ messages: [ChatMessage]) {
        guard isEnabled, let url = storeURL else { return }
        do {
            let data = try JSONEncoder().encode(messages)
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("save chat history failed: \(error.localizedDescription)")
        }
    }

    /// Load the persisted message list.  Returns empty array if no file or
    /// persistence is disabled.  Read happens at app launch from
    /// ChatViewModel.init() so existing chats can be restored.
    func load() -> [ChatMessage] {
        guard isEnabled, let url = storeURL,
              FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([ChatMessage].self, from: data)
        } catch {
            logger.error("load chat history failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Explicit deletion of the persisted file.  Triggered by the
    /// "Clear saved chat history" button in Settings.
    func clear() {
        guard let url = storeURL else { return }
        try? FileManager.default.removeItem(at: url)
        logger.info("chat history file cleared")
    }

    /// Whether a saved chat history file exists on disk (for the
    /// "Clear" button enabled-state in Settings).
    var hasSavedHistory: Bool {
        guard let url = storeURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
}
