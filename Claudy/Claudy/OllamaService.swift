import Foundation
import OSLog

// MARK: - OllamaService (Section 2b)
//
// Speaks to a local Ollama instance at http://localhost:11434.
// Uses Ollama's native /api/chat endpoint (newline-delimited JSON, not SSE).

nonisolated final class OllamaService: Sendable {

    static let baseURL = URL(string: "http://localhost:11434")!

    private let logger = Logger(subsystem: "com.claudy", category: "Ollama")

    // MARK: - Model list

    /// Fetches available model names from GET /api/tags.
    func listModels() async throws -> [String] {
        let url = Self.baseURL.appendingPathComponent("api/tags")
        let (data, _) = try await URLSession.shared.data(from: url)
        struct TagsResp: Decodable {
            struct Model: Decodable { let name: String }
            let models: [Model]
        }
        let resp = try JSONDecoder().decode(TagsResp.self, from: data)
        return resp.models.map(\.name)
    }

    // MARK: - Streaming chat

    /// Streams a chat response via POST /api/chat with stream:true.
    func streamChat(
        model: String,
        systemPrompt: String,
        messages: [ChatMessage]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = Self.baseURL.appendingPathComponent("api/chat")
                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    struct OllamaMsg: Encodable { let role: String; let content: String }
                    struct OllamaBody: Encodable {
                        let model: String
                        let system: String
                        let messages: [OllamaMsg]
                        let stream: Bool
                    }

                    let body = OllamaBody(
                        model: model,
                        system: systemPrompt,
                        messages: messages.map { OllamaMsg(role: $0.role.rawValue, content: $0.content) },
                        stream: true
                    )
                    req.httpBody = try JSONEncoder().encode(body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    guard let http = response as? HTTPURLResponse else {
                        throw URLError(.badServerResponse)
                    }
                    guard http.statusCode == 200 else {
                        throw ClaudeAPIError.httpError(http.statusCode)
                    }

                    for try await line in bytes.lines {
                        guard !line.isEmpty,
                              let data = line.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(OllamaChunk.self, from: data)
                        else { continue }

                        if let content = chunk.message?.content, !content.isEmpty {
                            continuation.yield(content)
                        }
                        if chunk.done { break }
                    }
                    continuation.finish()
                } catch {
                    self.logger.error("OllamaService stream error: \(error)")
                    // Append connection-lost signal and finish cleanly
                    continuation.yield(" [connection lost]")
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - Ollama response shapes

private nonisolated struct OllamaChunk: Decodable {
    struct OllamaMessage: Decodable { let role: String?; let content: String? }
    let message: OllamaMessage?
    let done: Bool
}
