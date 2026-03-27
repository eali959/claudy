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
        switch self {
        case .reaction:
            return "claude-3-5-haiku-20241022"
        case .chat:
            return UserDefaults.standard.string(forKey: "SelectedModel")
                ?? ClaudeAPIService.defaultModel
        case .complex:
            let useComplex = UserDefaults.standard.bool(forKey: "UseComplexModel")
            return useComplex ? "claude-opus-4-6"
                : (UserDefaults.standard.string(forKey: "SelectedModel") ?? ClaudeAPIService.defaultModel)
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

    /// True when an API key is stored in the Keychain.
    nonisolated var hasAPIKey: Bool { KeychainService.hasAPIKey }

    private var model: String {
        UserDefaults.standard.string(forKey: "SelectedModel") ?? Self.defaultModel
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
            // Capture the Task so onTermination can cancel it.
            // Without this, dropping the stream (e.g. on cancel) leaves the URLSession
            // request running until it completes or times out.
            let task = Task {
                do {
                    // Hop to MainActor to resolve UserDefaults-backed priority values,
                    // then immediately return to the task's isolation context.
                    let resolvedModel    = await MainActor.run { priority.model }
                    let resolvedMaxToks  = await MainActor.run { priority.maxTokens }

                    let apiKey = try KeychainService.load()
                    var request = URLRequest(url: self.baseURL)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue(self.apiVersion, forHTTPHeaderField: "anthropic-version")

                    let body = APIRequest(
                        model: resolvedModel,
                        maxTokens: resolvedMaxToks,
                        system: systemPrompt,
                        messages: messages.map { APIRequest.APIMessage(role: $0.role.rawValue, content: $0.content) },
                        stream: true
                    )
                    // Hop to MainActor for encode: the synthesized Encodable conformance is
                    // inferred @MainActor by the compiler in this SDK/module combination.
                    request.httpBody = try await MainActor.run { try JSONEncoder().encode(body) }

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw URLError(.badServerResponse)
                    }
                    guard http.statusCode == 200 else {
                        // Read error body so we know exactly what went wrong
                        var errorLines: [String] = []
                        for try await line in bytes.lines {
                            errorLines.append(line)
                            if errorLines.count >= 5 { break }
                        }
                        let body = errorLines.joined(separator: " ")
                        self.logger.error("API \(http.statusCode): \(body)")
                        throw ClaudeAPIError.httpError(http.statusCode, body: body)
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        guard payload != "[DONE]",
                              let data = payload.data(using: .utf8) else { continue }
                        // Hop to MainActor for decode: same @MainActor conformance inference issue.
                        let event = await MainActor.run { try? JSONDecoder().decode(StreamEvent.self, from: data) }
                        guard let event else { continue }

                        if event.type == "content_block_delta",
                           event.delta?.type == "text_delta",
                           let text = event.delta?.text {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    self.logger.error("Stream error: \(error)")
                    continuation.finish(throwing: error)
                }
            }
            // When the stream is cancelled or dropped by the caller, cancel the
            // underlying URLSession request immediately rather than waiting for it
            // to drain naturally.
            continuation.onTermination = { _ in task.cancel() }
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
