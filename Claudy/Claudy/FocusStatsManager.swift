import Foundation
import Observation
import OSLog

// MARK: - FocusStatsManager

/// Tracks daily Pomodoro completions and total focus time.
/// Data resets at midnight each day. Stats persist to UserDefaults.
///
/// The Pomodoro manager calls `recordPomodoro(seconds:)` on session completion.
/// BreakNudgeManager's active-time seconds can be fed in via `addFocusSeconds(_:)`.
@MainActor
@Observable
final class FocusStatsManager {
    static let shared = FocusStatsManager()

    // MARK: - Persisted (day-keyed)

    private(set) var pomodorosToday: Int = 0
    private(set) var focusSecondsToday: Int = 0
    private(set) var streakDays: Int = 0           // consecutive days with ≥1 Pomodoro

    private let logger = Logger(subsystem: "com.claudy", category: "FocusStats")

    // MARK: - Init

    private init() {
        load()
        rolloverIfNeeded()
    }

    // MARK: - Public API

    /// Call when a Pomodoro session completes.
    func recordPomodoro(seconds: Int) {
        rolloverIfNeeded()
        pomodorosToday += 1
        focusSecondsToday += seconds
        updateStreak()
        save()
        logger.info("Pomodoro recorded — \(self.pomodorosToday) today, \(self.focusSecondsToday)s total")
    }

    /// Call to add focus time not from a Pomodoro (e.g. manual coding session tracking later).
    func addFocusSeconds(_ seconds: Int) {
        rolloverIfNeeded()
        focusSecondsToday += seconds
        save()
    }

    // MARK: - Display helpers

    var focusTimeDisplay: String {
        let hours = focusSecondsToday / 3600
        let minutes = (focusSecondsToday % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    var summaryLine: String {
        if pomodorosToday == 0 { return "No sessions yet today." }
        return "\(pomodorosToday) Pomodoro\(pomodorosToday == 1 ? "" : "s") · \(focusTimeDisplay) focused"
    }

    // MARK: - Persistence

    private struct StoredStats: Codable {
        var dateKey: String
        var pomodorosToday: Int
        var focusSecondsToday: Int
        var streakDays: Int
        var lastPomodoroDateKey: String
    }

    private static let defaultsKey = "FocusStats"
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var todayKey: String { Self.dateFormatter.string(from: Date()) }

    private func rolloverIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let stored = try? JSONDecoder().decode(StoredStats.self, from: data),
              stored.dateKey != todayKey else { return }
        // New day — reset daily counters (streak preserved separately)
        pomodorosToday = 0
        focusSecondsToday = 0
        save()
        logger.info("Daily stats rolled over for \(self.todayKey)")
    }

    private func updateStreak() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let stored = try? JSONDecoder().decode(StoredStats.self, from: data) else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if let lastDate = Self.dateFormatter.date(from: stored.lastPomodoroDateKey) {
            let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
            if cal.isDate(lastDate, inSameDayAs: yesterday) {
                streakDays = stored.streakDays + 1
            } else if !cal.isDate(lastDate, inSameDayAs: today) {
                streakDays = 1   // broke streak
            } else {
                streakDays = max(stored.streakDays, 1)
            }
        } else {
            streakDays = 1
        }
    }

    private func save() {
        let stored = StoredStats(
            dateKey: todayKey,
            pomodorosToday: pomodorosToday,
            focusSecondsToday: focusSecondsToday,
            streakDays: streakDays,
            lastPomodoroDateKey: pomodorosToday > 0 ? todayKey : ""
        )
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let stored = try? JSONDecoder().decode(StoredStats.self, from: data),
              stored.dateKey == todayKey else { return }
        pomodorosToday    = stored.pomodorosToday
        focusSecondsToday = stored.focusSecondsToday
        streakDays        = stored.streakDays
    }
}
