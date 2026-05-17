import Foundation
import OSLog

// MARK: - OpenAICompatibleService (Section 2a)
//
// Speaks to any OpenAI-style /v1/chat/completions API.
// Used by: LM Studio (localhost, no key) and DeepSeek (cloud, key required).

nonisolated final class OpenAICompatibleService: Sendable {

    let baseURL: URL
    let apiKey: String?   // nil for LM Studio; non-nil for DeepSeek

    private let logger = Logger(subsystem: "com.claudy", category: "OpenAICompatible")

    init(baseURL: URL, apiKey: String?) {
        self.baseURL  = baseURL
        self.apiKey   = apiKey
    }

    // MARK: - Model list

    /// Fetches available model IDs from GET {baseURL}/models.
    func listModels() async throws -> [String] {
        var req = URLRequest(url: baseURL.appendingPathComponent("models"))
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let key = apiKey {
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        let (data, _) = try await URLSession.shared.data(for: req)
        struct ModelsResponse: Decodable {
            struct Model: Decodable { let id: String }
            let data: [Model]
        }
        let resp = try JSONDecoder().decode(ModelsResponse.self, from: data)
        return resp.data.map(\.id)
    }

    // MARK: - Streaming chat

    /// Streams a chat completion via POST {baseURL}/chat/completions with stream:true.
    func streamChat(
        model: String,
        systemPrompt: String,
        messages: [ChatMessage],
        maxTokens: Int = 1024
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = self.baseURL.appendingPathComponent("chat/completions")
                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    if let key = self.apiKey {
                        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                    }

                    struct OAIMessage: Encodable { let role: String; let content: String }
                    struct OAIBody: Encodable {
                        let model: String
                        let messages: [OAIMessage]
                        let stream: Bool
                        let max_tokens: Int
                    }

                    var oaiMessages: [OAIMessage] = []
                    if !systemPrompt.isEmpty {
                        oaiMessages.append(OAIMessage(role: "system", content: systemPrompt))
                    }
                    oaiMessages += messages.map { OAIMessage(role: $0.role.rawValue, content: $0.content) }

                    let body = OAIBody(model: model, messages: oaiMessages, stream: true, max_tokens: maxTokens)
                    req.httpBody = try JSONEncoder().encode(body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    guard let http = response as? HTTPURLResponse else {
                        throw URLError(.badServerResponse)
                    }
                    guard http.statusCode == 200 else {
                        throw ClaudeAPIError.httpError(http.statusCode)
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        guard payload != "[DONE]",
                              let data = payload.data(using: .utf8) else { continue }
                        if let text = Self.parseChunk(data) {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    self.logger.error("OpenAICompatibleService stream error: \(error)")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - SSE chunk parser

    private static func parseChunk(_ data: Data) -> String? {
        struct Chunk: Decodable {
            struct Choice: Decodable {
                struct Delta: Decodable { let content: String? }
                let delta: Delta
            }
            let choices: [Choice]
        }
        guard let chunk = try? JSONDecoder().decode(Chunk.self, from: data) else { return nil }
        return chunk.choices.first?.delta.content
    }
}
