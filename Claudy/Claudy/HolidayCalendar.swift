import Foundation
import OSLog

private let logger = Logger(subsystem: "com.claudy", category: "HolidayCalendar")

// MARK: - Holiday

struct ClaudyHoliday {
    let name: String
    let emoji: String
    let messages: [String]
}

// MARK: - HolidayCalendar

/// Checks today's date against public holidays in the UK, US, and Australia,
/// as well as key Islamic calendar dates (approximate, based on astronomical
/// calculations — actual observance depends on moon sighting).
///
/// Call `holidayToday()` on launch and again at midnight to get a `ClaudyHoliday`
/// if one matches today. The character announces it with a speech bubble.
@MainActor
final class HolidayCalendar {

    static let shared = HolidayCalendar()
    private init() {}

    // MARK: - Public

    /// Returns the holiday matching today (first match wins), or nil if none.
    func holidayToday() -> ClaudyHoliday? {
        let cal  = Calendar.current
        let now  = Date()
        let year = cal.component(.year, from: now)
        let month = cal.component(.month, from: now)
        let day   = cal.component(.day, from: now)

        return allHolidays(year: year).first {
            let comps = cal.dateComponents([.month, .day], from: $0.date)
            return comps.month == month && comps.day == day
        }?.holiday
    }

    // MARK: - All holidays for a given year

    private struct Entry { let date: Date; let holiday: ClaudyHoliday }

    private func allHolidays(year: Int) -> [Entry] {
        var entries: [Entry] = []

        // ── Fixed universal / multi-region ───────────────────────────────────
        entries += fixed(year: year, month: 1,  day: 1,  holiday: newYearsDay)
        entries += fixed(year: year, month: 12, day: 25, holiday: christmas)
        entries += fixed(year: year, month: 12, day: 26, holiday: boxingDay)
        entries += fixed(year: year, month: 12, day: 31, holiday: newYearsEve)

        // ── UK ───────────────────────────────────────────────────────────────
        entries += fixed(year: year, month: 11, day: 5,  holiday: guyFawkesNight)
        entries += fixed(year: year, month: 3,  day: 17, holiday: stPatricksDay)
        entries += fixed(year: year, month: 11, day: 11, holiday: remembranceDay)

        // ── US ───────────────────────────────────────────────────────────────
        entries += fixed(year: year, month: 7,  day: 4,  holiday: independenceDay)
        entries += fixed(year: year, month: 10, day: 31, holiday: halloween)
        entries += fixed(year: year, month: 11, day: 11, holiday: Self.veteransDay)
        entries += fixed(year: year, month: 6,  day: 19, holiday: juneteenth)
        // Thanksgiving: 4th Thursday of November
        if let thanksgivingDate = nthWeekday(4, .thursday, month: 11, year: year) {
            entries.append(Entry(date: thanksgivingDate, holiday: thanksgiving))
        }
        // MLK Day: 3rd Monday of January
        if let mlk = nthWeekday(3, .monday, month: 1, year: year) {
            entries.append(Entry(date: mlk, holiday: Self.mlkDay))
        }
        // Memorial Day: last Monday of May
        if let memorial = lastWeekday(.monday, month: 5, year: year) {
            entries.append(Entry(date: memorial, holiday: Self.memorialDay))
        }
        // Labor Day: 1st Monday of September
        if let labor = nthWeekday(1, .monday, month: 9, year: year) {
            entries.append(Entry(date: labor, holiday: Self.laborDay))
        }

        // ── Australia ────────────────────────────────────────────────────────
        entries += fixed(year: year, month: 1, day: 26, holiday: australiaDay)
        entries += fixed(year: year, month: 4, day: 25, holiday: anzacDay)

        // ── Easter (used by UK, AU, US — computed via Meeus/Jones/Butcher) ──
        if let (goodFriday, easterMonday) = easterDates(year: year) {
            entries.append(Entry(date: goodFriday, holiday: Self.goodFriday))
            entries.append(Entry(date: easterMonday, holiday: Self.easterMonday))
        }

        // ── Islamic (approximate, based on astronomical calculations) ───────
        entries += islamicHolidays(year: year)

        // ── Valentine's / other fun ──────────────────────────────────────────
        entries += fixed(year: year, month: 2,  day: 14, holiday: valentinesDay)
        entries += fixed(year: year, month: 4,  day: 1,  holiday: aprilFools)

        return entries
    }

    // MARK: - Fixed-date helper

    private func fixed(year: Int, month: Int, day: Int, holiday: ClaudyHoliday) -> [Entry] {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        guard let date = Calendar.current.date(from: comps) else { return [] }
        return [Entry(date: date, holiday: holiday)]
    }

    // MARK: - Nth weekday helper (e.g. 3rd Monday of January)

    private func nthWeekday(_ n: Int, _ weekday: Weekday, month: Int, year: Int) -> Date? {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = 1
        guard let firstDay = cal.date(from: comps) else { return nil }
        let firstWD = cal.component(.weekday, from: firstDay) // 1=Sun, 2=Mon...
        let target  = weekday.calendarValue
        var diff    = target - firstWD
        if diff < 0 { diff += 7 }
        let day = 1 + diff + (n - 1) * 7
        comps.day = day
        return cal.date(from: comps)
    }

    private func lastWeekday(_ weekday: Weekday, month: Int, year: Int) -> Date? {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = year; comps.month = month + 1; comps.day = 1
        guard let firstOfNext = cal.date(from: comps),
              let lastDay     = cal.date(byAdding: .day, value: -1, to: firstOfNext) else { return nil }
        let lastWD = cal.component(.weekday, from: lastDay)
        let target = weekday.calendarValue
        var diff   = lastWD - target
        if diff < 0 { diff += 7 }
        return cal.date(byAdding: .day, value: -diff, to: lastDay)
    }

    private enum Weekday {
        case sunday, monday, tuesday, wednesday, thursday, friday, saturday
        var calendarValue: Int {
            switch self { case .sunday: 1; case .monday: 2; case .tuesday: 3;
            case .wednesday: 4; case .thursday: 5; case .friday: 6; case .saturday: 7 }
        }
    }

    // MARK: - Easter (Meeus/Jones/Butcher algorithm)

    private func easterDates(year: Int) -> (Date, Date)? {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day   = ((h + l - 7 * m + 114) % 31) + 1

        let cal = Calendar.current
        var easterComps = DateComponents()
        easterComps.year = year; easterComps.month = month; easterComps.day = day
        guard let easter        = cal.date(from: easterComps),
              let goodFriday    = cal.date(byAdding: .day, value: -2, to: easter),
              let easterMonday  = cal.date(byAdding: .day, value:  1, to: easter) else { return nil }
        return (goodFriday, easterMonday)
    }

    // MARK: - Islamic holidays (astronomical approximations)
    // Dates are calculated using the Umm al-Qura calendar approximations.
    // Actual observance may differ by 1-2 days based on moon sighting.

    private func islamicHolidays(year: Int) -> [Entry] {
        // Pre-computed approximate dates. Key: (year, month, day)
        let eidAlFitr: [(Int, Int, Int)] = [
            (2025, 3, 31), (2026, 3, 20), (2027, 3, 9), (2028, 2, 27)
        ]
        let eidAlAdha: [(Int, Int, Int)] = [
            (2025, 6, 7), (2026, 5, 27), (2027, 5, 16), (2028, 5, 5)
        ]
        let islamicNewYear: [(Int, Int, Int)] = [
            (2025, 6, 27), (2026, 6, 16), (2027, 6, 6), (2028, 5, 25)
        ]
        let mawlid: [(Int, Int, Int)] = [
            (2025, 9, 5), (2026, 8, 25), (2027, 8, 14), (2028, 8, 3)
        ]
        let ramadanStart: [(Int, Int, Int)] = [
            (2025, 3, 1), (2026, 2, 18), (2027, 2, 7), (2028, 1, 27)
        ]

        var entries: [Entry] = []

        for (y, m, d) in eidAlFitr where y == year {
            entries += fixed(year: year, month: m, day: d, holiday: Self.eidAlFitr)
        }
        for (y, m, d) in eidAlAdha where y == year {
            entries += fixed(year: year, month: m, day: d, holiday: Self.eidAlAdha)
        }
        for (y, m, d) in islamicNewYear where y == year {
            entries += fixed(year: year, month: m, day: d, holiday: Self.islamicNewYear)
        }
        for (y, m, d) in mawlid where y == year {
            entries += fixed(year: year, month: m, day: d, holiday: Self.mawlidNabawi)
        }
        for (y, m, d) in ramadanStart where y == year {
            entries += fixed(year: year, month: m, day: d, holiday: Self.ramadanStart)
        }

        return entries
    }

    // MARK: - Holiday definitions

    private let newYearsDay = ClaudyHoliday(
        name: "New Year's Day", emoji: "🎉",
        messages: [
            "Happy New Year! New year, new bugs to fix.",
            "It's New Year's Day. Fresh start. Clean slate. You've got this.",
            "2025 is already loading. Let's make something great this year.",
            "New Year! The git log starts fresh. Metaphorically."
        ])

    private let newYearsEve = ClaudyHoliday(
        name: "New Year's Eve", emoji: "🥂",
        messages: [
            "Last day of the year. How's the code looking going in?",
            "New Year's Eve! Please do not deploy tonight.",
            "The year ends tonight. Ship nothing. Celebrate everything."
        ])

    private let christmas = ClaudyHoliday(
        name: "Christmas Day", emoji: "🎄",
        messages: [
            "Merry Christmas! Close the laptop. It will still be broken tomorrow.",
            "It's Christmas! The code can wait. Go eat something.",
            "Happy Christmas! Today is not for shipping. Today is for rest.",
            "Merry Christmas. If you're coding today, I respect it AND worry about you."
        ])

    private let boxingDay = ClaudyHoliday(
        name: "Boxing Day", emoji: "📦",
        messages: [
            "Boxing Day! Still recovering from yesterday I hope.",
            "Happy Boxing Day! The UK tradition of continuing to not work.",
            "Boxing Day. Code still broken from before Christmas? Same."
        ])

    private let halloween = ClaudyHoliday(
        name: "Halloween", emoji: "🎃",
        messages: [
            "Happy Halloween! The scariest thing today? The bug you introduced last week.",
            "Spooky season. Perfect time to check those error logs.",
            "Happy Halloween! The only thing more terrifying than production is your CSS.",
            "It's Halloween. Costume idea: developer who ships on time."
        ])

    private let independenceDay = ClaudyHoliday(
        name: "Independence Day (US)", emoji: "🇺🇸",
        messages: [
            "Happy 4th of July! Freedom from the office today.",
            "Independence Day! Free from bugs? Not quite. But free from the office.",
            "Happy 4th! The fireworks are nice but the build pipeline never sleeps."
        ])

    private let thanksgiving = ClaudyHoliday(
        name: "Thanksgiving (US)", emoji: "🦃",
        messages: [
            "Happy Thanksgiving! Grateful for clean builds.",
            "Thanksgiving! Grateful for: version control, Stack Overflow, and coffee.",
            "Happy Thanksgiving. The code was terrible but we're thankful for the lessons."
        ])

    private let valentinesDay = ClaudyHoliday(
        name: "Valentine's Day", emoji: "❤️",
        messages: [
            "Happy Valentine's Day! Love is the only thing with fewer edge cases than your code.",
            "Happy Valentine's Day! Even if no one else does, I believe in your pull requests.",
            "February 14th. The heart wants what it wants. Mine wants clean builds."
        ])

    private let aprilFools = ClaudyHoliday(
        name: "April Fools' Day", emoji: "🃏",
        messages: [
            "April Fools'! The bugs today are indistinguishable from the bugs yesterday.",
            "It's April 1st. Do NOT trust any documentation you read today.",
            "April Fools'! I would prank you but honestly the codebase does that already."
        ])

    private let australiaDay = ClaudyHoliday(
        name: "Australia Day", emoji: "🇦🇺",
        messages: [
            "Happy Australia Day! Chuck another function on the barbie.",
            "Australia Day! Somewhere, a developer is coding in thongs. Legendary.",
            "Happy Australia Day. The land of good coffee, bad spiders, and clean code."
        ])

    private let anzacDay = ClaudyHoliday(
        name: "ANZAC Day", emoji: "🌺",
        messages: [
            "ANZAC Day. Lest we forget.",
            "Happy ANZAC Day. Quiet day of remembrance.",
            "ANZAC Day. A moment to pause."
        ])

    private let guyFawkesNight = ClaudyHoliday(
        name: "Bonfire Night", emoji: "🔥",
        messages: [
            "Bonfire Night! Remember remember the fifth of November.",
            "Guy Fawkes Night! The only time setting things on fire is acceptable.",
            "Bonfire Night in the UK. Much like my code review comments — explosive."
        ])

    private let stPatricksDay = ClaudyHoliday(
        name: "St Patrick's Day", emoji: "🍀",
        messages: [
            "Happy St Patrick's Day! May your code compile on the first try.",
            "St Paddy's Day! Wearing green helps with debugging. I read that somewhere.",
            "Happy St Patrick's Day! The luck of the Irish — applied to your build pipeline."
        ])

    private let remembranceDay = ClaudyHoliday(
        name: "Remembrance Day", emoji: "🌹",
        messages: [
            "Remembrance Day. A moment of quiet.",
            "11th November. Lest we forget.",
            "Remembrance Day. Pause, reflect."
        ])

    private let juneteenth = ClaudyHoliday(
        name: "Juneteenth", emoji: "✊",
        messages: [
            "Happy Juneteenth! Freedom and progress — in code and in life.",
            "Juneteenth. Celebrating freedom, community, and what comes next.",
            "Happy Juneteenth! A day to celebrate, reflect, and build forward."
        ])

    private static let mlkDay = ClaudyHoliday(
        name: "Martin Luther King Jr. Day", emoji: "✊",
        messages: [
            "Happy MLK Day. Dream big. Build things that matter.",
            "Martin Luther King Jr. Day. A reminder of what courage and vision looks like.",
            "MLK Day. Pause, reflect, and then go build something that helps people."
        ])

    private static let memorialDay = ClaudyHoliday(
        name: "Memorial Day (US)", emoji: "🇺🇸",
        messages: [
            "Happy Memorial Day! In memory of those who served.",
            "Memorial Day. A day to pause and remember.",
            "Happy Memorial Day weekend. Take the day, you've earned it."
        ])

    private static let laborDay = ClaudyHoliday(
        name: "Labor Day (US)", emoji: "💪",
        messages: [
            "Happy Labor Day! Ironically the day most developers still code.",
            "Labor Day! A day to celebrate work by not doing it.",
            "Happy Labor Day. The CI/CD pipeline doesn't get a day off. But you do."
        ])

    private static let veteransDay = ClaudyHoliday(
        name: "Veterans Day (US)", emoji: "🎖️",
        messages: [
            "Happy Veterans Day. Thank you to those who served.",
            "Veterans Day. A day to honour and remember.",
            "Happy Veterans Day. Proud to be here because of them."
        ])

    private static let goodFriday = ClaudyHoliday(
        name: "Good Friday", emoji: "✝️",
        messages: [
            "Good Friday. A quieter day.",
            "Good Friday. The weekend is almost here.",
            "Happy Good Friday. Take a breath."
        ])

    private static let easterMonday = ClaudyHoliday(
        name: "Easter Monday", emoji: "🐣",
        messages: [
            "Happy Easter Monday! The egg hunt is over. Back to the bugs.",
            "Easter Monday! Long weekend vibes. Enjoy the last of it.",
            "Happy Easter! Hope you found more eggs than bugs this weekend."
        ])

    // MARK: - Islamic holidays

    private static let eidAlFitr = ClaudyHoliday(
        name: "Eid al-Fitr", emoji: "🌙",
        messages: [
            "Eid Mubarak! Eid al-Fitr — the celebration after Ramadan. Wishing you joy.",
            "Eid al-Fitr Mubarak! A beautiful day of gratitude and celebration.",
            "Eid Mubarak! May this Eid bring you peace, happiness, and clean builds.",
            "Happy Eid al-Fitr! A blessed end to Ramadan. Enjoy the celebration."
        ])

    private static let eidAlAdha = ClaudyHoliday(
        name: "Eid al-Adha", emoji: "🕌",
        messages: [
            "Eid al-Adha Mubarak! Wishing you and your family a blessed celebration.",
            "Eid Mubarak! The Festival of Sacrifice. A time of generosity and reflection.",
            "Happy Eid al-Adha! May your day be full of joy and meaning.",
            "Eid al-Adha Mubarak! One of Islam's most important holidays. A blessed day."
        ])

    private static let islamicNewYear = ClaudyHoliday(
        name: "Islamic New Year (Muharram 1)", emoji: "🌙",
        messages: [
            "Happy Islamic New Year! A new year in the Hijri calendar.",
            "Muharram 1 — the start of the Islamic New Year. Wishing you a blessed year.",
            "Islamic New Year Mubarak! May this year bring you peace and blessings."
        ])

    private static let mawlidNabawi = ClaudyHoliday(
        name: "Mawlid al-Nabi (Prophet's Birthday)", emoji: "🕌",
        messages: [
            "Mawlid al-Nabi Mubarak! Celebrating the Prophet's birthday.",
            "Happy Mawlid! A day of reflection and celebration.",
            "Mawlid Mubarak! Wishing you a blessed and peaceful day."
        ])

    private static let ramadanStart = ClaudyHoliday(
        name: "Ramadan Begins", emoji: "🌙",
        messages: [
            "Ramadan Mubarak! The month of fasting and reflection begins.",
            "Ramadan Kareem! Wishing you a blessed, peaceful month.",
            "Ramadan begins today. Ramadan Mubarak! May this month be full of meaning.",
            "Happy Ramadan! A sacred month for so many. Wishing everyone observing a peaceful fast."
        ])
}
