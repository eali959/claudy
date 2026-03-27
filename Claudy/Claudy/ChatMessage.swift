import Foundation

// MARK: - ChatMessage
// Kept in its own file so Swift 6 does not infer actor isolation from ClaudeAPIService.swift.

struct ChatMessage: Identifiable, Sendable, Codable {
    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date

    nonisolated init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    enum Role: String, Codable, Sendable {
        case user, assistant
    }
}
