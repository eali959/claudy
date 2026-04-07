import Foundation
import OSLog

// MARK: - Message Priority

/// Determines which model and token budget to use per call type.
enum MessagePriority: Sendable {
    /// Ambient one-liner reactions (fast, cheap). Uses Haiku 3.5, 60 tokens.
    case reaction
    /// User-initiated chat. Uses the user's selected model, 1024 tokens.
    case chat
    /// Long / complex tasks. Uses Opus, 4096 tokens (opt-in via Settings).
    case complex

    var model: String {
        let provider = APIProvider.selected
        switch self {
        case .reaction:
            return provider.fastModel
        case .chat:
            return UserDefaults.standard.string(forKey: DefaultsKeys.selectedModel)
                ?? provider.defaultModel
        case .complex:
            let useComplex = UserDefaults.standard.bool(forKey: DefaultsKeys.useComplexModel)
            if provider == .claude {
                return useComplex ? "claude-opus-4-6"
                    : (UserDefaults.standard.string(forKey: DefaultsKeys.selectedModel) ?? ClaudeAPIService.defaultModel)
            }
            return useComplex ? provider.smartModel : provider.defaultModel
        }
    }

    var maxTokens: Int {
        switch self {
        case .reaction: return 60
        case .chat:     return 1024
        case .complex:  return 4096
        }
    }
}

// ChatMessage is defined in ChatMessage.swift (separate file avoids Swift 6 actor-isolation
// inference that would affect types in the same file as actor ClaudeAPIService).
// APIRequest and StreamEvent are defined in APIShapes.swift for the same reason.

// MARK: - Service

/// Streams responses from the Claude API using server-sent events.
///
/// All API calls are made via `streamResponse(messages:systemPrompt:priority:)`, which returns
/// an `AsyncThrowingStream<String, Error>` of text tokens. The actor isolates mutable state
/// (last unprompted commentary timestamp) and manages URLSession lifetime.
///
/// The API key is read from the macOS Keychain via `KeychainService` at call time.
actor ClaudeAPIService {
    static let shared = ClaudeAPIService()

    // nonisolated: these are immutable Sendable values accessed inside a Task created inside
    // AsyncThrowingStream's @Sendable closure (which loses actor isolation). Marking nonisolated
    // lets the Task read them without needing an actor hop / 'await'.
    nonisolated private let logger = Logger(subsystem: "com.claudy", category: "API")
    nonisolated private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    nonisolated private let apiVersion = "2023-06-01"
    static let defaultModel = "claude-haiku-4-5-20251001"

    /// True when an API key is stored for the currently selected provider.
    nonisolated var hasAPIKey: Bool { KeychainService.has(for: APIProvider.selected) }

    /// True when any API key exists (used for companion/API mode toggle).
    nonisolated var hasAnyAPIKey: Bool {
        APIProvider.allCases.contains { KeychainService.has(for: $0) }
    }

    private var lastUnpromptedTime: Date = .distantPast
    private let unpromptedInterval: TimeInterval = 60

    // MARK: - Public

    /// Returns an async throwing stream of text tokens from Claude.
    func streamResponse(
        messages: [ChatMessage],
        systemPrompt: String,
        priority: MessagePriority = .chat
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let resolvedModel   = await MainActor.run { priority.model }
                    let resolvedMaxToks = await MainActor.run { priority.maxTokens }
                    let provider        = await MainActor.run { APIProvider.selected }
                    let apiKey          = try KeychainService.load(for: provider)

                    var request: URLRequest
                    switch provider {
                    case .claude:
                        request = try await self.buildClaudeRequest(
                            apiKey: apiKey, model: resolvedModel, maxTokens: resolvedMaxToks,
                            messages: messages, systemPrompt: systemPrompt)
                    case .openai:
                        request = try await self.buildOpenAIRequest(
                            apiKey: apiKey, model: resolvedModel, maxTokens: resolvedMaxToks,
                            messages: messages, systemPrompt: systemPrompt)
                    case .gemini:
                        request = try await self.buildGeminiRequest(
                            apiKey: apiKey, model: resolvedModel, maxTokens: resolvedMaxToks,
                            messages: messages, systemPrompt: systemPrompt)
                    }

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw URLError(.badServerResponse)
                    }
                    guard http.statusCode == 200 else {
                        var errorLines: [String] = []
                        for try await line in bytes.lines {
                            errorLines.append(line)
                            if errorLines.count >= 5 { break }
                        }
                        let errBody = errorLines.joined(separator: " ")
                        self.logger.error("API \(http.statusCode): \(errBody)")
                        throw ClaudeAPIError.httpError(http.statusCode, body: errBody)
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        guard payload != "[DONE]",
                              let data = payload.data(using: .utf8) else { continue }
                        let text: String?
                        switch provider {
                        case .claude:
                            let event = await MainActor.run { try? JSONDecoder().decode(StreamEvent.self, from: data) }
                            text = (event?.type == "content_block_delta" && event?.delta?.type == "text_delta")
                                ? event?.delta?.text : nil
                        case .openai:
                            text = await MainActor.run { Self.parseOpenAIChunk(data) }
                        case .gemini:
                            text = await MainActor.run { Self.parseGeminiChunk(data) }
                        }
                        if let t = text { continuation.yield(t) }
                    }
                    continuation.finish()
                } catch {
                    self.logger.error("Stream error: \(error)")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Provider request builders

    private func buildClaudeRequest(
        apiKey: String, model: String, maxTokens: Int,
        messages: [ChatMessage], systemPrompt: String
    ) async throws -> URLRequest {
        var req = URLRequest(url: baseURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        let body = APIRequest(
            model: model, maxTokens: maxTokens, system: systemPrompt,
            messages: messages.map { APIRequest.APIMessage(role: $0.role.rawValue, content: $0.content) },
            stream: true)
        req.httpBody = try await MainActor.run { try JSONEncoder().encode(body) }
        return req
    }

    private func buildOpenAIRequest(
        apiKey: String, model: String, maxTokens: Int,
        messages: [ChatMessage], systemPrompt: String
    ) async throws -> URLRequest {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        struct OAIMessage: Encodable { let role: String; let content: String }
        struct OAIBody: Encodable {
            let model: String; let messages: [OAIMessage]
            let stream: Bool; let max_tokens: Int
        }
        var oaiMessages: [OAIMessage] = []
        if !systemPrompt.isEmpty { oaiMessages.append(OAIMessage(role: "system", content: systemPrompt)) }
        oaiMessages += messages.map { OAIMessage(role: $0.role.rawValue, content: $0.content) }
        let body = OAIBody(model: model, messages: oaiMessages, stream: true, max_tokens: maxTokens)
        req.httpBody = try await MainActor.run { try JSONEncoder().encode(body) }
        return req
    }

    private func buildGeminiRequest(
        apiKey: String, model: String, maxTokens: Int,
        messages: [ChatMessage], systemPrompt: String
    ) async throws -> URLRequest {
        let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse&key=\(apiKey)"
        let url = URL(string: urlStr)!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct GPart:    Encodable { let text: String }
        struct GContent: Encodable { let role: String; let parts: [GPart] }
        struct GSysInst: Encodable { let parts: [GPart] }
        struct GConfig:  Encodable { let maxOutputTokens: Int }
        struct GBody:    Encodable {
            let contents: [GContent]
            let systemInstruction: GSysInst?
            let generationConfig: GConfig
        }
        let contents = messages.map { m in
            GContent(role: m.role == .user ? "user" : "model", parts: [GPart(text: m.content)])
        }
        let sysInst = systemPrompt.isEmpty ? nil : GSysInst(parts: [GPart(text: systemPrompt)])
        let body = GBody(contents: contents, systemInstruction: sysInst,
                         generationConfig: GConfig(maxOutputTokens: maxTokens))
        req.httpBody = try await MainActor.run { try JSONEncoder().encode(body) }
        return req
    }

    // MARK: - Provider SSE parsers

    private static func parseOpenAIChunk(_ data: Data) -> String? {
        struct OAIChunk: Decodable {
            struct Choice: Decodable {
                struct Delta: Decodable { let content: String? }
                let delta: Delta
            }
            let choices: [Choice]
        }
        guard let chunk = try? JSONDecoder().decode(OAIChunk.self, from: data) else { return nil }
        return chunk.choices.first?.delta.content
    }

    private static func parseGeminiChunk(_ data: Data) -> String? {
        struct GChunk: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String? }
                    let parts: [Part]
                }
                let content: Content?
            }
            let candidates: [Candidate]?
        }
        guard let chunk = try? JSONDecoder().decode(GChunk.self, from: data) else { return nil }
        return chunk.candidates?.first?.content?.parts.first?.text
    }

    /// Collects a full non-streaming response to a single prompt. Returns nil on error or no key.
    func singleMessage(
        _ prompt: String,
        systemPrompt: String = "",
        priority: MessagePriority = .reaction
    ) async -> String? {
        guard hasAPIKey else { return nil }
        let message = ChatMessage(role: .user, content: prompt)
        var result = ""
        do {
            for try await token in streamResponse(messages: [message], systemPrompt: systemPrompt, priority: priority) {
                result += token
            }
            return result.isEmpty ? nil : result.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            logger.error("singleMessage error: \(error)")
            return nil
        }
    }

    /// Rate-limited unprompted commentary. Returns nil if within the rate-limit window.
    func requestUnpromptedCommentary(
        context: String,
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error>? {
        let now = Date()
        guard now.timeIntervalSince(lastUnpromptedTime) >= unpromptedInterval else {
            logger.debug("Unprompted commentary rate-limited")
            return nil
        }
        lastUnpromptedTime = now
        let message = ChatMessage(role: .user, content: context)
        return streamResponse(messages: [message], systemPrompt: systemPrompt)
    }
}

/// Errors that `ClaudeAPIService` can throw to callers.
enum ClaudeAPIError: LocalizedError {
    case httpError(Int, body: String = "")
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let body):
            let detail = body.isEmpty ? "" : " - \(body.prefix(120))"
            return "HTTP \(code)\(detail)"
        case .noAPIKey:
            return "No API key configured. Open Settings to add one."
        }
    }
}
