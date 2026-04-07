import Foundation
import Observation
import OSLog

enum ChatMode: String {
    case companion  // always-available local responses
    case api        // full Claude API streaming
}

/// Drives the chat panel UI and owns the message history for the current session.
///
/// Supports two modes: Companion (local responses via `LocalChatResponder`) and
/// API (streaming from Claude via `ClaudeAPIService`). Mode is persisted to UserDefaults.
/// Context is auto-trimmed above 60k tokens to stay within the model window.
@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isStreaming = false
    var isTyping   = false      // true while waiting for first token / local delay
    var isOpen = false
    var errorMessage: String?

    // MARK: - Mode

    /// Companion mode is always available; API mode requires a key.
    /// Defaults to companion so the app is useful immediately out of the box.
    var chatMode: ChatMode {
        didSet { UserDefaults.standard.set(chatMode.rawValue, forKey: DefaultsKeys.chatMode) }
    }

    var hasAPIKey: Bool { KeychainService.has(for: APIProvider.selected) }

    /// True when the user has an API key and has chosen API mode.
    var isAPIMode: Bool { chatMode == .api && hasAPIKey }

    func toggleMode() {
        guard hasAPIKey else { return }   // can't switch to API without a key
        chatMode = (chatMode == .companion) ? .api : .companion
    }

    // MARK: - Context window tracking

    /// Rough token estimate: total chars / 4
    var approximateTokenCount: Int {
        messages.reduce(0) { $0 + $1.content.count } / 4
    }
    /// Warn at ~60k tokens (soft) and ~80k tokens (urgent)
    var showContextWarning: Bool { approximateTokenCount >= 60_000 }
    var isNearContextLimit: Bool { approximateTokenCount >= 80_000 }

    // MARK: - Response formatting toggle (CHAT-05)

    /// When true, render assistant messages as Markdown; when false, plain text.
    var renderMarkdown: Bool = {
        let stored = UserDefaults.standard.object(forKey: DefaultsKeys.renderMarkdown)
        return stored == nil ? true : UserDefaults.standard.bool(forKey: DefaultsKeys.renderMarkdown)
    }() {
        didSet { UserDefaults.standard.set(renderMarkdown, forKey: DefaultsKeys.renderMarkdown) }
    }

    // MARK: - System prompt presets (CHAT-04)

    struct SystemPromptPreset: Codable, Identifiable {
        let id: UUID
        var name: String
        var prompt: String
        init(name: String, prompt: String) {
            self.id = UUID()
            self.name = name
            self.prompt = prompt
        }
    }

    var systemPromptPresets: [SystemPromptPreset] = {
        guard let data = UserDefaults.standard.data(forKey: DefaultsKeys.systemPromptPresets),
              let decoded = try? JSONDecoder().decode([SystemPromptPreset].self, from: data) else {
            return []
        }
        return decoded
    }()

    func savePresets() {
        if let data = try? JSONEncoder().encode(systemPromptPresets) {
            UserDefaults.standard.set(data, forKey: DefaultsKeys.systemPromptPresets)
        }
    }

    private let logger = Logger(subsystem: "com.claudy", category: "Chat")
    private var streamingTask: Task<Void, Never>?

    init() {
        // Restore last-used mode; fall back to companion (the default)
        let saved = UserDefaults.standard.string(forKey: DefaultsKeys.chatMode) ?? ""
        chatMode = ChatMode(rawValue: saved) ?? .companion

        NotificationCenter.default.addObserver(
            forName: .claudyLanguageChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let lang = notification.object as? AppLanguage,
                  self.isOpen else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .milliseconds(400))
                self.messages.append(ChatMessage(role: .assistant, content: lang.switchAcknowledgment))
            }
        }
    }

    // MARK: - Send

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))
        NotificationCenter.default.post(name: .claudyChatSendTapped, object: nil)

        if isAPIMode {
            streamingTask = Task { await streamReply() }
        } else {
            streamingTask = Task { await localReply(to: text) }
        }
    }

    func cancel() {
        streamingTask?.cancel()
        streamingTask = nil
        isTyping   = false   // Bug fix: reset typing indicator if cancelled before first token
        isStreaming = false
    }

    // MARK: - Local reply (Companion Mode - no API key)

    private func localReply(to input: String) async {
        isTyping = true
        errorMessage = nil

        // Random delay so the response feels considered, not instant
        let delay = Double.random(in: 0.5...1.0)
        try? await Task.sleep(for: .seconds(delay))
        guard !Task.isCancelled else { isTyping = false; return }

        let personality = PersonalityManager.shared.currentMode
        let response = LocalChatResponder.shared.respond(to: input, personality: personality)
        isTyping = false
        messages.append(ChatMessage(role: .assistant, content: response))
    }

    // MARK: - Streaming reply (API key present)

    private func streamReply() async {
        // Auto-trim context before sending if session is very long
        trimContextIfNeeded()

        isTyping = true          // show dots while API roundtrip completes
        isStreaming = true
        PersonalityManager.shared.isStreaming = true   // lock blend slider (BLEND-04)
        errorMessage = nil

        let placeholder = ChatMessage(role: .assistant, content: "")
        messages.append(placeholder)
        let placeholderID = placeholder.id

        let systemPrompt = PersonalityManager.shared.systemPrompt
        let stream = await ClaudeAPIService.shared.streamResponse(
            messages: messages.dropLast(),
            systemPrompt: systemPrompt
        )

        var firstToken = true
        do {
            for try await token in stream {
                guard !Task.isCancelled else { break }
                if firstToken {
                    isTyping = false    // hide dots once streaming begins
                    firstToken = false
                }
                if let i = messages.firstIndex(where: { $0.id == placeholderID }) {
                    messages[i].content += token
                }
            }
        } catch {
            logger.error("Stream failed: \(error)")
            if let i = messages.firstIndex(where: { $0.id == placeholderID }),
               messages[i].content.isEmpty {
                messages.remove(at: i)
            }
            errorMessage = error.localizedDescription
        }

        isTyping = false
        isStreaming = false
        PersonalityManager.shared.isStreaming = false  // unlock blend slider

        // Post-stream ambient reactions (local, no extra API calls)
        if let lastMsg = messages.last(where: { $0.role == .assistant }), !lastMsg.content.isEmpty {
            // Code block follow-up bubble
            if lastMsg.content.contains("```") {
                NotificationCenter.default.post(name: .claudyAPICodeBlock, object: nil)
            }
            // Long response celebration (> 300 words → .celebrating for 0.8s)
            let wordCount = lastMsg.content.split(separator: " ").count
            if wordCount > 300 {
                NotificationCenter.default.post(name: .claudyAPILongResponse, object: nil)
            }
        }
    }

    /// Appends a short in-character arrival message when the user switches personality.
    /// Only fires if the chat is open - no surprise messages out of nowhere.
    func announcePersonalityChange(to mode: PersonalityMode) {
        NotificationCenter.default.post(name: .claudyPersonalitySwitched, object: nil)
        guard isOpen else { return }
        let line = LocalChatResponder.shared.arrivalMessage(for: mode)
        // Brief pause so it feels like a character stepping in, not a system event
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            messages.append(ChatMessage(role: .assistant, content: line))
        }
    }

    func clearHistory() {
        cancel()
        messages = []
        contextTrimNotified = false
    }

    // MARK: - Context trimming

    private var contextTrimNotified = false

    /// Auto-trims the oldest messages when the session exceeds ~60k tokens.
    /// Keeps the 20 most recent messages. Fires a one-time bubble notification.
    func trimContextIfNeeded() {
        guard approximateTokenCount >= 60_000 else { return }
        let recentCount = min(20, messages.count)
        let dropped = messages.count - recentCount
        guard dropped > 0 else { return }
        messages = Array(messages.suffix(recentCount))
        guard !contextTrimNotified else { return }
        contextTrimNotified = true
        NotificationCenter.default.post(name: .claudyContextTrimmed, object: nil)
    }

    // MARK: - Demo injection

    /// IDs of messages injected during Demo Mode - removed on demo stop.
    @ObservationIgnored private var demoMessageIDs: Set<UUID> = []

    /// Injects a message directly into the conversation without triggering streaming
    /// or the local responder. Demo mode only - do not call from normal user flows.
    func injectMessage(_ content: String, role: ChatMessage.Role) {
        let msg = ChatMessage(role: role, content: content)
        demoMessageIDs.insert(msg.id)
        messages.append(msg)
    }

    /// Removes all demo-injected messages. Called by DemoModeManager.stop().
    func removeDemoMessages() {
        messages.removeAll { demoMessageIDs.contains($0.id) }
        demoMessageIDs.removeAll()
    }

    // MARK: - Export

    func exportTranscript() -> String {
        guard !messages.isEmpty else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return messages.map { msg in
            let time = formatter.string(from: msg.timestamp)
            let role = msg.role == .user ? "You" : "Claud-y"
            return "[\(time)] \(role): \(msg.content)"
        }.joined(separator: "\n\n")
    }
}

// MARK: - Array extension

private extension Array {
    func dropLast() -> [Element] {
        guard count > 0 else { return self }
        return Array(self.dropLast(1))
    }
}
