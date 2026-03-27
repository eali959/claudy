import Foundation

// MARK: - API Request and Response shapes
//
// Kept in a separate file from ClaudeAPIService.swift so Swift's actor-isolation inference
// cannot propagate @MainActor from the actor declaration onto these types' Encodable/Decodable
// conformances. Both types are Sendable so they can safely cross actor boundaries.

/// Encodes the JSON body sent to the Claude Messages API.
struct APIRequest: Encodable, Sendable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [APIMessage]
    let stream: Bool

    struct APIMessage: Encodable, Sendable {
        let role: String
        let content: String
    }

    enum CodingKeys: String, CodingKey {
        case model, system, messages, stream
        case maxTokens = "max_tokens"
    }
}

/// Decodes a single server-sent event from the Claude streaming response.
struct StreamEvent: Decodable, Sendable {
    let type: String
    let delta: Delta?

    struct Delta: Decodable, Sendable {
        let type: String?
        let text: String?
    }
}
