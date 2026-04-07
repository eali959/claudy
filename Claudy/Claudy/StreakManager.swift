import Foundation
import OSLog

// MARK: - StreakManager
// Tracks daily active sessions. Shows a streak bubble on launch if streak ≥ 3,
// once per day. All data stored in UserDefaults - no persistence risk.

@MainActor
final class StreakManager {
    static let shared = StreakManager()
    private let logger = Logger(subsystem: "com.claudy", category: "Streaks")

    private let datesKey    = DefaultsKeys.dailySessionDates
    private let shownKey    = DefaultsKeys.lastStreakShownDate

    // MARK: - Record

    /// Call once on launch to mark today as active.
    func recordToday() {
        let today = isoDate(from: Date())
        var dates = savedDates
        guard !dates.contains(today) else { return }
        dates.append(today)
        // Keep last 90 days only
        if dates.count > 90 { dates = Array(dates.suffix(90)) }
        UserDefaults.standard.set(dates, forKey: datesKey)
        logger.debug("Streak: recorded \(today), streak=\(self.currentStreak)")
    }

    // MARK: - Query

    var currentStreak: Int {
        let dates = Set(savedDates)
        var count = 0
        var candidate = Date()
        let cal = Calendar.current
        while dates.contains(isoDate(from: candidate)) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: candidate) else { break }
            candidate = prev
        }
        return count
    }

    /// Returns a streak message if one is due today and streak is ≥ 3. Nil otherwise.
    func streakMessageIfDue() -> String? {
        let today = isoDate(from: Date())
        guard UserDefaults.standard.string(forKey: shownKey) != today else { return nil }
        let streak = currentStreak
        guard streak >= 3 else { return nil }
        UserDefaults.standard.set(today, forKey: shownKey)

        switch streak {
        case 3...4:  return "Three days running. I keep track of these things."
        case 5...6:  return "Five days in a row. You are forming a habit."
        case 7...13: return "One week straight. I am proud of us."
        case 14...29: return "Two whole weeks. At this point I live here."
        case 30...:  return "Day \(streak). I am basically furniture at this point."
        default:     return nil
        }
    }

    // MARK: - Helpers

    private var savedDates: [String] {
        UserDefaults.standard.stringArray(forKey: datesKey) ?? []
    }

    // DateFormatter is expensive to create; cache it - especially important because
    // currentStreak iterates up to 90 dates and calls isoDate on each one.
    private let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func isoDate(from date: Date) -> String {
        isoFormatter.string(from: date)
    }
}
