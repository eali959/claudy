import Foundation
import Observation
import OSLog

// MARK: - ScratchpadNote

struct ScratchpadNote: Codable, Identifiable, Sendable {
    var id: UUID
    var text: String
    var createdAt: Date
    var isPinned: Bool

    init(text: String) {
        self.id        = UUID()
        self.text      = text
        self.createdAt = Date()
        self.isPinned  = false
    }
}

// MARK: - ScratchpadManager

/// Persistent in-app notepad. Notes are stored locally in UserDefaults (JSON).
/// Access from the context menu → Scratchpad.
@MainActor
@Observable
final class ScratchpadManager {
    static let shared = ScratchpadManager()

    private(set) var notes: [ScratchpadNote] = []
    private let logger = Logger(subsystem: "com.claudy", category: "Scratchpad")
    private static let defaultsKey = DefaultsKeys.scratchpadNotes

    private init() { load() }

    // MARK: - CRUD

    func addNote(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        notes.insert(ScratchpadNote(text: trimmed), at: 0)
        save()
    }

    func updateNote(id: UUID, text: String) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].text = text
        save()
    }

    func deleteNote(id: UUID) {
        notes.removeAll { $0.id == id }
        save()
    }

    /// V5.11 — Clear every note.  Triggered by the Privacy & Storage
    /// "Clear all notes" button.  Persisted via save(), so it removes
    /// from disk too.
    func clearAllNotes() {
        notes.removeAll()
        save()
    }

    func togglePin(id: UUID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].isPinned.toggle()
        // Pinned notes float to the top
        notes.sort { ($0.isPinned ? 0 : 1) < ($1.isPinned ? 0 : 1) }
        save()
    }

    func clearAll() {
        notes.removeAll()
        save()
    }

    // MARK: - Persistence

    private func save() {
        // V5.11 — respect the user's per-data-type save preference.
        // Default-true; user can opt out via Privacy & Storage settings.
        // When the toggle is off, in-memory notes still work for the current
        // session but are not persisted to UserDefaults.
        let key = DefaultsKeys.saveScratchpadNotes
        let optedIn = UserDefaults.standard.object(forKey: key) == nil
                   || UserDefaults.standard.bool(forKey: key)
        guard optedIn else { return }
        guard let data = try? JSONEncoder().encode(notes) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    private func load() {
        // Always read existing data (so opting out then opting back in is non-destructive).
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let decoded = try? JSONDecoder().decode([ScratchpadNote].self, from: data) else { return }
        notes = decoded
        logger.info("Loaded \(decoded.count) scratchpad notes")
    }
}
