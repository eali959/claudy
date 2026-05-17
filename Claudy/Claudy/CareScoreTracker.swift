import Foundation
import Observation

// MARK: - CareScoreTracker (Section 10.1)
//
// Tracks a 7-day rolling care score (0–100%) in UserDefaults.
// Score > 80% → golden rim glow on character.
// Score < 30% → subtle desaturation.
// Reset button returns score to 50%.

@MainActor
@Observable
final class CareScoreTracker {

    // MARK: - State

    /// 0.0–1.0 rolling average over last 7 days.
    private(set) var score: Double = 0.5

    enum EvolutionState: Sendable { case thriving, normal, neglected }
    var evolutionState: EvolutionState {
        if score > 0.80 { return .thriving }
        if score < 0.30 { return .neglected }
        return .normal
    }

    // MARK: - Persistence

    private struct DailyEntry: Codable {
        let date: Date
        let points: Double  // 0.0–1.0 per day
    }

    private var entries: [DailyEntry] = []

    // MARK: - Init

    init() { loadEntries() }

    // MARK: - Actions

    /// Call each time the user has a meaningful interaction (chat, mood check, pomodoro).
    func recordInteraction() {
        let today = Calendar.current.startOfDay(for: Date())
        if let idx = entries.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            let updated = DailyEntry(date: today, points: min(entries[idx].points + 0.15, 1.0))
            entries[idx] = updated
        } else {
            entries.append(DailyEntry(date: today, points: 0.2))
        }
        pruneOldEntries()
        recompute()
        saveEntries()
    }

    func reset() {
        // Reset to 50% (3–4 moderate days in last 7)
        let today = Calendar.current.startOfDay(for: Date())
        entries = (0..<7).map { offset in
            let d = Calendar.current.date(byAdding: .day, value: -offset, to: today)!
            return DailyEntry(date: d, points: 0.5)
        }
        recompute()
        saveEntries()
    }

    // MARK: - Private

    private func pruneOldEntries() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        entries = entries.filter { $0.date >= cutoff }
    }

    private func recompute() {
        guard !entries.isEmpty else { score = 0.5; return }
        let total = entries.reduce(0.0) { $0 + $1.points }
        score = total / 7.0  // normalise over 7-day window
    }

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: DefaultsKeys.careScoreRolling7),
              let decoded = try? JSONDecoder().decode([DailyEntry].self, from: data) else {
            // First launch — start neutral
            reset()
            return
        }
        entries = decoded
        pruneOldEntries()
        recompute()
    }

    private func saveEntries() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: DefaultsKeys.careScoreRolling7)
    }
}
