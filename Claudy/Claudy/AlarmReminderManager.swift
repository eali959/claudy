import Foundation
import OSLog
import Observation

private let logger = Logger(subsystem: "com.claudy", category: "AlarmReminderManager")

// MARK: - Reminder

struct Reminder: Codable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var fireDate: Date
    var fired: Bool

    init(id: UUID = UUID(), title: String, fireDate: Date) {
        self.id       = id
        self.title    = title
        self.fireDate = fireDate
        self.fired    = false
    }
}

// MARK: - AlarmReminderManager

/// Manages user-set reminders. Reminders are persisted to UserDefaults and fire as
/// speech bubbles + wave animation. Parses natural-language reminder phrases so the
/// chat can create reminders without UI interaction.
///
/// Typical NLP inputs:
///   "remind me in 30 minutes to take a break"
///   "set an alarm for 10 minutes"
///   "remind me at 3pm to call Alex"
///   "remind me in 2 hours to drink water"
@MainActor
@Observable
final class AlarmReminderManager {

    private(set) var reminders: [Reminder] = []

    @ObservationIgnored private weak var viewModel: CharacterViewModel?
    @ObservationIgnored private var checkTask: Task<Void, Never>?

    private static let storageKey = "ClaudyReminders"

    // MARK: - Init

    init(viewModel: CharacterViewModel) {
        self.viewModel = viewModel
        load()
        startCheckLoop()
        logger.info("AlarmReminderManager ready — \(self.reminders.count) reminders loaded")
    }

    // MARK: - Public API

    func add(title: String, fireDate: Date) {
        let reminder = Reminder(title: title, fireDate: fireDate)
        reminders.append(reminder)
        save()
        logger.info("Reminder set: '\(title)' at \(fireDate)")

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let timeStr = fireDate.timeIntervalSinceNow < 3600
            ? inMinutesString(fireDate.timeIntervalSinceNow)
            : "at \(formatter.string(from: fireDate))"
        viewModel?.showBubbleDirect("Got it. Reminding you \(timeStr): \(title)", duration: 5)
    }

    func remove(id: UUID) {
        reminders.removeAll { $0.id == id }
        save()
    }

    func clearFired() {
        reminders.removeAll { $0.fired }
        save()
    }

    // MARK: - NLP parse → schedule
    // Returns the reminder if one was successfully parsed and created.

    @discardableResult
    func parseAndSchedule(from text: String) -> Reminder? {
        let lower = text.lowercased()

        // Pattern 1: "remind me in N minutes/hours to …"
        if let (interval, taskText) = parseRelativeInterval(from: lower) {
            let fireDate = Date().addingTimeInterval(interval)
            let reminder = Reminder(title: taskText, fireDate: fireDate)
            reminders.append(reminder)
            save()
            announceSet(reminder)
            return reminder
        }

        // Pattern 2: "remind me at H:MM [am/pm] to … " or "at H:MM …"
        if let (fireDate, taskText) = parseAbsoluteTime(from: lower, original: text) {
            let reminder = Reminder(title: taskText, fireDate: fireDate)
            reminders.append(reminder)
            save()
            announceSet(reminder)
            return reminder
        }

        return nil
    }

    // MARK: - Private: parse helpers

    private func parseRelativeInterval(from lower: String) -> (TimeInterval, String)? {
        // Matches: "in N minute(s)/hour(s)" with optional "to <task>"
        let pattern = #"(?:remind me |set (?:a )?(?:reminder|alarm) )(?:in (\d+(?:\.\d+)?) (minute|minutes|min|hour|hours|hr|hrs|second|seconds|sec|secs))"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower))
        else { return nil }

        let nsLower = lower as NSString
        let numStr   = nsLower.substring(with: match.range(at: 1))
        let unitStr  = nsLower.substring(with: match.range(at: 2)).lowercased()
        guard let value = Double(numStr) else { return nil }

        let multiplier: Double
        switch unitStr {
        case "hour", "hours", "hr", "hrs": multiplier = 3600
        case "second", "seconds", "sec", "secs": multiplier = 1
        default: multiplier = 60 // minutes
        }

        let taskText = extractTask(from: lower, after: match.range)
        return (value * multiplier, taskText)
    }

    private func parseAbsoluteTime(from lower: String, original: String) -> (Date, String)? {
        // Matches: "at H:MM" or "at H am/pm" or "at H:MM am/pm"
        let pattern = #"at (\d{1,2})(?::(\d{2}))?\s*(am|pm)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower))
        else { return nil }

        let ns = lower as NSString
        let hourStr = ns.substring(with: match.range(at: 1))
        let minStr  = match.range(at: 2).location != NSNotFound ? ns.substring(with: match.range(at: 2)) : "0"
        let ampm    = match.range(at: 3).location != NSNotFound ? ns.substring(with: match.range(at: 3)) : ""

        guard var hour = Int(hourStr), let minute = Int(minStr) else { return nil }

        if ampm == "pm", hour < 12 { hour += 12 }
        if ampm == "am", hour == 12 { hour = 0 }

        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour   = hour
        comps.minute = minute
        comps.second = 0

        guard var fireDate = cal.date(from: comps) else { return nil }
        // If the time has already passed today, schedule for tomorrow
        if fireDate <= Date() { fireDate = fireDate.addingTimeInterval(86400) }

        let taskText = extractTask(from: lower, after: match.range)
        return (fireDate, taskText)
    }

    /// Extracts "to <task>" text after a matched range; falls back to "do the thing".
    private func extractTask(from lower: String, after range: NSRange) -> String {
        let ns = lower as NSString
        let after = ns.substring(from: range.location + range.length)
        // Look for "to <task>" after the matched time expression
        if let toRange = after.range(of: #"(?:to |to do |to:)\s*(.+)"#,
                                      options: .regularExpression) {
            let captured = String(after[toRange])
            // Strip the "to " prefix
            let stripped = captured.replacingOccurrences(of: #"^to\s+"#, with: "",
                                                         options: .regularExpression)
            return stripped.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
        }
        return "That thing"
    }

    // MARK: - Private: check loop

    private func startCheckLoop() {
        checkTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                self?.checkFired()
            }
        }
    }

    private func checkFired() {
        let now = Date()
        var changed = false
        for i in reminders.indices {
            guard !reminders[i].fired, reminders[i].fireDate <= now else { continue }
            reminders[i].fired = true
            changed = true
            fire(reminders[i])
        }
        if changed { save() }
        // Prune fired reminders older than 24 hours
        let cutoff = now.addingTimeInterval(-86400)
        let before = reminders.count
        reminders.removeAll { $0.fired && $0.fireDate < cutoff }
        if reminders.count != before { save() }
    }

    private func fire(_ reminder: Reminder) {
        logger.info("Reminder fired: '\(reminder.title)'")
        viewModel?.wave()
        let messages = [
            "Hey — reminder: \(reminder.title)",
            "Heads up! You wanted to: \(reminder.title)",
            "This is your reminder: \(reminder.title)",
            "Don't forget — \(reminder.title)",
            "Reminder time: \(reminder.title)",
        ]
        viewModel?.showBubbleDirect(messages.randomElement()!, duration: 8)
    }

    // MARK: - Announce

    private func announceSet(_ reminder: Reminder) {
        logger.info("Reminder scheduled: '\(reminder.title)' at \(reminder.fireDate)")
        let timeStr = inMinutesString(reminder.fireDate.timeIntervalSinceNow)
        viewModel?.showBubbleDirect("Reminder set for \(timeStr): \(reminder.title)", duration: 5)
        viewModel?.nod()
    }

    private func inMinutesString(_ interval: TimeInterval) -> String {
        let absInterval = abs(interval)
        if absInterval < 90 { return "in \(Int(absInterval)) seconds" }
        if absInterval < 3600 { return "in \(Int(absInterval / 60)) minutes" }
        let hours = Int(absInterval / 3600)
        let mins  = Int((absInterval.truncatingRemainder(dividingBy: 3600)) / 60)
        if mins == 0 { return "in \(hours) hour\(hours == 1 ? "" : "s")" }
        return "in \(hours)h \(mins)m"
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(reminders) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([Reminder].self, from: data) else { return }
        // Drop fired reminders that are older than 24 hours on load
        reminders = decoded.filter { !$0.fired || $0.fireDate > Date().addingTimeInterval(-86400) }
    }
}
