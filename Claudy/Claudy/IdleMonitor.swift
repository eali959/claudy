import AppKit

// MARK: - IdleMonitor

/// Tracks user inactivity and drives time-aware character reactions.
///
/// Responsibilities: idle escalation (idle to drowsy to sleeping), launch and wake greetings,
/// screen-unlock detection, hourly chimes, day-of-week comments, streak messages, and
/// locale-aware special-day celebrations.
/// All reaction strings sourced from PersonalityManager or ReactionLibraryService.

@MainActor
final class IdleMonitor {
    private weak var viewModel: CharacterViewModel?
    private var monitorTask: Task<Void, Never>?
    private var hourChimeTask: Task<Void, Never>?
    private var screenLockTask: Task<Void, Never>?
    private var focusModeTask: Task<Void, Never>?
    private var lastActivityTime: Date = Date()
    private var lastChimedHour: Int = -1

    // Memory greeting lines (1-in-4 chance on launch)
    private static let memoryGreetings = [
        "Oh, you're back. I've been thinking about what we were working on.",
        "Welcome back. I kept our last session in mind.",
        "There you are. I was just reflecting on our last build.",
        "Back again. I may have been thinking about that last bug.",
        "Ah. I was wondering when you'd return.",
        "You know, I never really stop thinking about the things we work on.",
    ]

    init(viewModel: CharacterViewModel) {
        self.viewModel = viewModel
        startMonitoring()
        startHourChimeLoop()
        startScreenLockMonitoring()
        startFocusModeMonitoring()
        recordFirstLaunchDate()

        StreakManager.shared.recordToday()

        if isFirstLaunch() {
            scheduleOnboarding()
        } else {
            scheduleLaunchGreeting()
        }
        scheduleDayOfWeekComment()
        checkSpecialDays()
    }

    func stop() {
        monitorTask?.cancel()
        hourChimeTask?.cancel()
        screenLockTask?.cancel()
        focusModeTask?.cancel()
    }

    // MARK: - Activity reset

    func resetActivity() {
        lastActivityTime = Date()
        guard let vm = viewModel else { return }
        let wasSleeping = vm.animationState == .sleeping || vm.animationState == .drowsy
        vm.setState(.idle)
        if wasSleeping { showWakeGreeting() }
    }

    // MARK: - Idle escalation (drowsy → sleeping)

    private func startMonitoring() {
        monitorTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let vm = self.viewModel else { return }

                let interruptible: Set<CharacterAnimationState> = [.idle, .drowsy, .alert]
                guard interruptible.contains(vm.animationState) else { continue }

                let idle = Date().timeIntervalSince(self.lastActivityTime)
                if idle >= 600 {
                    vm.setState(.sleeping)
                } else if idle >= 300 {
                    // Show idle bubble when first going drowsy (BUG-03 fix)
                    if vm.animationState != .drowsy {
                        let msg = ReactionLibraryService.shared.reaction(for: .idle5min)
                        if !msg.isEmpty { vm.showSpeechBubble(msg, duration: 4) }
                    }
                    vm.setState(.drowsy)
                    let hour = Calendar.current.component(.hour, from: Date())
                    if hour < 5 { vm.applyMood(for: .lateNight) }
                }
            }
        }
    }

    // MARK: - First launch / onboarding

    /// Returns true only when neither the onboarding window nor the bubble intro has run.
    /// Both systems share "onboardingComplete" so they don't fire simultaneously.
    private func isFirstLaunch() -> Bool {
        !UserDefaults.standard.bool(forKey: DefaultsKeys.onboardingComplete)
    }

    private func recordFirstLaunchDate() {
        let key = DefaultsKeys.firstLaunchDate
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(Date(), forKey: key)
        }
    }

    private func scheduleOnboarding() {
        // Mark complete immediately so re-launches don't repeat this.
        // OnboardingWindowController uses the same key - whichever runs first wins.
        UserDefaults.standard.set(true, forKey: DefaultsKeys.onboardingComplete)
        let bubbles: [(String, TimeInterval, TimeInterval)] = [
            ("Hi! I'm Claud-y. I live here now.", 4.0, 2.0),
            ("I'll react to what you're doing - builds, commits, the usual.", 5.0, 8.0),
            ("Tap me to chat, or right-click for options. I'll be here.", 6.0, 15.0),
        ]
        Task { @MainActor in
            for (text, duration, delay) in bubbles {
                try? await Task.sleep(for: .seconds(delay))
                self.viewModel?.showBubbleDirect(text, duration: duration)
            }
            // Confetti on onboarding completion
            try? await Task.sleep(for: .seconds(23))
            self.viewModel?.triggerConfetti()
        }
    }

    // MARK: - Launch greeting

    private func scheduleLaunchGreeting() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))

            // 1-in-4 memory greeting illusion
            if Int.random(in: 0...3) == 0, let memory = Self.memoryGreetings.randomElement() {
                self.viewModel?.showSpeechBubble(memory, duration: 6)
            } else {
                let context = self.currentGreetingContext()
                let msg = await PersonalityManager.shared.asyncGreeting(for: context)
                self.viewModel?.showSpeechBubble(msg, duration: 6)
            }

            try? await Task.sleep(for: .seconds(8))
            if let streakMsg = StreakManager.shared.streakMessageIfDue() {
                self.viewModel?.showSpeechBubble(streakMsg, duration: 6)
            }
        }
    }

    // MARK: - Wake greeting

    private func showWakeGreeting() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            let msg = await PersonalityManager.shared.asyncGreeting(for: .wake)
            self.viewModel?.showSpeechBubble(msg, duration: 5)
        }
    }

    // MARK: - Screen lock / unlock detection

    private func startScreenLockMonitoring() {
        screenLockTask = Task { @MainActor in
            let nc = DistributedNotificationCenter.default()
            for await _ in nc.notifications(named: NSNotification.Name("com.apple.screenIsUnlocked")) {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(1))
                let msg = await PersonalityManager.shared.asyncGreeting(for: .wake)
                self.viewModel?.showSpeechBubble(msg, duration: 5)
                self.lastActivityTime = Date()
            }
        }
    }

    // MARK: - Day-of-week comment

    private func scheduleDayOfWeekComment() {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let trigger: ReactionTrigger? = {
            switch weekday {
            case 2: return .mondayMorning
            case 6: return .friday
            default: return nil
            }
        }()
        guard let t = trigger else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(10))
            let msg = ReactionLibraryService.shared.reaction(for: t)
            if !msg.isEmpty { self.viewModel?.showSpeechBubble(msg, duration: 6) }
        }
    }

    // MARK: - Special days

    private func checkSpecialDays() {
        let today = Calendar.current.dateComponents([.month, .day], from: Date())
        guard let month = today.month, let day = today.day else { return }

        let specialMessage: String? = {
            switch (month, day) {
            case (1, 1):   return "Happy New Year! Fresh year, fresh bugs. Let's go."
            case (12, 25): return "Merry Christmas! Today is the one day I will not judge your commit messages."
            case (3, 26):  return "It is my birthday! Well. The day I came into existence. Cake? No? Just code? Fine."
            default:
                // Anniversary - read exclusively from UserDefaults, never from StreakManager
                // (StreakManager trims entries after 90 days and would lose the original date)
                if let firstLaunch = UserDefaults.standard.object(forKey: DefaultsKeys.firstLaunchDate) as? Date {
                    let calendar = Calendar.current
                    let now = Date()
                    let sameMonthDay = calendar.component(.month, from: firstLaunch) == month
                                   && calendar.component(.day,   from: firstLaunch) == day
                    let yearsElapsed = calendar.dateComponents([.year], from: firstLaunch, to: now).year ?? 0
                    if sameMonthDay && yearsElapsed >= 1 {
                        let label = yearsElapsed == 1 ? "a whole year" : "\(yearsElapsed) years"
                        return "We have been together for \(label). Time flies."
                    }
                }
                return nil
            }
        }()

        guard let msg = specialMessage else {
            checkLocaleHoliday(month: month, day: day)
            return
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            self.viewModel?.showBubbleDirect(msg, duration: 8)
            self.viewModel?.celebrate()
        }
    }

    private func checkLocaleHoliday(month: Int, day: Int) {
        let region = Locale.current.region?.identifier ?? ""
        var holidayMsg: String?

        // AU holidays (all locales get these if AU, plus Boxing Day is shared with UK)
        if region == "AU" {
            switch (month, day) {
            case (1, 26): holidayMsg = "Happy Australia Day! Chuck a snag on the barbie and call it a day."
            case (4, 25): holidayMsg = "ANZAC Day. Lest we forget."
            case (11, _) where day >= 1 && day <= 7:
                // Melbourne Cup - first Tuesday of November
                let cal = Calendar.current
                let weekday = cal.component(.weekday, from: Date())
                if weekday == 3 { holidayMsg = "Melbourne Cup Day. The race that stops the nation. And your build." }
            case (12, 26): holidayMsg = "Boxing Day. Leftover turkey and zero obligations. Perfect."
            default: break
            }
        }

        // UK holidays
        if region == "GB" || region == "UK" {
            switch (month, day) {
            case (11, 5): holidayMsg = "Remember, remember, the 5th of November. Also: save your work."
            case (12, 26): holidayMsg = "Boxing Day. The best holiday. You've already done the hard part."
            default: break
            }
        }

        // US holidays
        if region == "US" {
            switch (month, day) {
            case (7, 4):  holidayMsg = "Happy 4th of July! Go outside. There will be fireworks."
            case (9, _) where {
                // Labor Day: first Monday of September
                let cal = Calendar.current
                let weekday = cal.component(.weekday, from: Date())
                return weekday == 2 && day <= 7
            }(): holidayMsg = "Happy Labor Day. You know what that means? Day off."
            case (11, _) where {
                // Thanksgiving: fourth Thursday of November
                let cal = Calendar.current
                let weekday = cal.component(.weekday, from: Date())
                return weekday == 5 && day >= 22 && day <= 28
            }(): holidayMsg = "Happy Thanksgiving. Take the day off. The code will wait."
            case (1, _) where {
                // MLK Day: third Monday of January
                let cal = Calendar.current
                let weekday = cal.component(.weekday, from: Date())
                return weekday == 2 && day >= 15 && day <= 21
            }(): holidayMsg = "Happy Martin Luther King Jr. Day. A good day to reflect."
            default: break
            }
        }

        guard let msg = holidayMsg else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            self.viewModel?.showSpeechBubble(msg, duration: 8)
            self.viewModel?.celebrate()
        }
    }

    // MARK: - Hour chime loop

    private func startHourChimeLoop() {
        hourChimeTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                self.checkHourChime()
            }
        }
    }

    private func checkHourChime() {
        let cal = Calendar.current
        let now = Date()
        let minute = cal.component(.minute, from: now)
        let hour   = cal.component(.hour,   from: now)
        guard minute == 0, hour != lastChimedHour else { return }
        lastChimedHour = hour

        guard let vm = viewModel else { return }
        let quietStates: Set<CharacterAnimationState> = [.thinking, .talking, .celebrating, .confused]
        guard !quietStates.contains(vm.animationState) else { return }

        vm.nod()
        let chimeMsg = ReactionLibraryService.shared.reaction(for: .hourlyChime)

        let hourMsg: String? = {
            switch hour {
            case 6:  return "Early start. Respect. Coffee first, though."
            case 7:  return "7am. The dedicated ones are always up first."
            case 9:  return "9 o'clock. Let's get into it."
            case 12: return "Noon. Have you eaten? Go eat something."
            case 13: return "Post-lunch slump incoming. Fight through it."
            case 15: return "3pm. The danger hour. Stay focused."
            case 17: return "5pm. You could stop… theoretically."
            case 18: return "Evening. Still here? Respect."
            case 20: return "Late session starting. Set a stopping time."
            case 22: return "Getting late. What is the one thing left to finish?"
            case 0:  return "Midnight. New day, fresh bugs."
            case 2:  return "2am. I am not judging. But also, please sleep."
            case 4:  return "4am. Whatever you are building had better be worth it."
            default: return chimeMsg.isEmpty ? nil : chimeMsg
            }
        }()
        if let msg = hourMsg { vm.showSpeechBubble(msg, duration: 4) }
    }

    // MARK: - Focus / DND mode detection

    private func startFocusModeMonitoring() {
        focusModeTask = Task { @MainActor in
            let nc = DistributedNotificationCenter.default()
            for await notification in nc.notifications(named: NSNotification.Name("com.apple.doNotDisturb.state.changed")) {
                guard !Task.isCancelled else { return }
                let userInfo = notification.userInfo
                let enabled = (userInfo?["doNotDisturbEnabled"] as? Int) == 1
                    || (userInfo?["enabled"] as? Bool) == true
                self.viewModel?.isFocusModeActive = enabled
            }
        }
    }

    // MARK: - Helpers

    private func currentGreetingContext() -> GreetingContext {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0...5:   return .veryLateNight  // BUG-04 fix: covers 0-5 including hour 5
        case 6...11:  return .morning
        case 12...21: return .afternoon      // BUG-04 fix: covers 18-21 correctly
        case 22...23: return .lateNight
        default:      return .launch
        }
    }
}
