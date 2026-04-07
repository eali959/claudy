import Foundation
import Observation
import OSLog

// MARK: - PomodoroPreset

enum PomodoroPreset: Int, CaseIterable, Codable {
    case short   = 15
    case classic = 25
    case long    = 45
    case deep    = 60
    case custom  = 0   // rawValue unused - reads customMinutes from UserDefaults

    var displayName: String {
        switch self {
        case .short:   return "Short (15m)"
        case .classic: return "Classic (25m)"
        case .long:    return "Long (45m)"
        case .deep:    return "Deep (60m)"
        case .custom:  return "Custom"
        }
    }

    var shortLabel: String {
        switch self {
        case .short:   return "15m"
        case .classic: return "25m"
        case .long:    return "45m"
        case .deep:    return "60m"
        case .custom:  return "Custom"
        }
    }
}

// MARK: - PomodoroState

enum PomodoroState: Equatable {
    case idle
    case running
    case paused
    case complete
}

// MARK: - PomodoroManager

/// Manages a Pomodoro-style focus timer with presets, pause/resume, and milestone reactions.
///
/// State machine: idle -> running -> paused -> running -> complete -> idle.
/// Fires character reactions at the 5-minute mark, halfway point, 5 minutes remaining,
/// and 1 minute remaining. All timings are driven by a single async Task countdown loop.
@MainActor
@Observable
final class PomodoroManager {

    // MARK: - Persisted settings

    var selectedPreset: PomodoroPreset = {
        // UserDefaults.integer returns 0 for a missing key, and PomodoroPreset.custom
        // also has rawValue 0 - so we must check whether the key actually exists first.
        guard UserDefaults.standard.object(forKey: DefaultsKeys.pomodoroPreset) != nil else { return .classic }
        let raw = UserDefaults.standard.integer(forKey: DefaultsKeys.pomodoroPreset)
        return PomodoroPreset(rawValue: raw) ?? .classic
    }() {
        didSet { UserDefaults.standard.set(selectedPreset.rawValue, forKey: DefaultsKeys.pomodoroPreset) }
    }

    var customMinutes: Int = {
        let saved = UserDefaults.standard.integer(forKey: DefaultsKeys.pomodoroCustomMinutes)
        return saved > 0 ? max(5, min(120, saved)) : 25
    }() {
        didSet {
            customMinutes = max(5, min(120, customMinutes))
            UserDefaults.standard.set(customMinutes, forKey: DefaultsKeys.pomodoroCustomMinutes)
        }
    }

    // MARK: - Runtime state

    private(set) var state: PomodoroState = .idle
    private(set) var remainingSeconds: Int = 0
    private(set) var totalDuration: Int = 0

    // MARK: - Milestone flags (reset per session)

    private var fired5min      = false
    private var firedHalfway   = false
    private var fired5minLeft  = false
    private var fired1minLeft  = false

    // MARK: - Internals

    private weak var viewModel: CharacterViewModel?
    private var timerTask: Task<Void, Never>?
    private var sessionElapsedAtPause: Int = 0
    private let logger = Logger(subsystem: "com.claudy", category: "Pomodoro")

    init(viewModel: CharacterViewModel) {
        self.viewModel = viewModel
        remainingSeconds = activeDuration
    }

    // MARK: - Computed

    var activeDuration: Int {
        selectedPreset == .custom
            ? customMinutes * 60
            : selectedPreset.rawValue * 60
    }

    var elapsedSeconds: Int { totalDuration - remainingSeconds }

    var progressFraction: Double {
        guard totalDuration > 0 else { return 0 }
        return max(0, min(1, Double(elapsedSeconds) / Double(totalDuration)))
    }

    var displayTime: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var isActive: Bool { state == .running || state == .paused }

    /// Label for the context menu "start" item
    var presetLabel: String {
        if selectedPreset == .custom {
            return "Start Focus Timer (\(customMinutes)m)"
        }
        return "Start Focus Timer (\(selectedPreset.rawValue)m)"
    }

    // MARK: - Controls

    func start() {
        guard state == .idle || state == .complete else { return }
        totalDuration    = activeDuration
        remainingSeconds = totalDuration
        resetMilestones()
        state = .running
        logger.info("Pomodoro started - \(self.totalDuration)s")

        fire(.pomodoroStart)
        startCountdown()
    }

    func pause() {
        guard state == .running else { return }
        timerTask?.cancel()
        timerTask = nil
        state = .paused
        logger.info("Pomodoro paused at \(self.remainingSeconds)s remaining")
        fire(.pomodoroPause)
    }

    func resume() {
        guard state == .paused else { return }
        state = .running
        logger.info("Pomodoro resumed")
        fire(.pomodoroResume)
        startCountdown()
    }

    func stop() {
        let wasRunningLong = state == .running && elapsedSeconds > 60
        timerTask?.cancel()
        timerTask = nil
        state = .idle
        remainingSeconds = activeDuration
        totalDuration = activeDuration
        resetMilestones()
        logger.info("Pomodoro stopped")
        if wasRunningLong { fire(.pomodoroStop) }
    }

    func restart() {
        stop()
        start()
    }

    func togglePause() {
        switch state {
        case .running: pause()
        case .paused:  resume()
        default: break
        }
    }

    // MARK: - Private

    private func startCountdown() {
        timerTask = Task { @MainActor in
            while self.remainingSeconds > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.remainingSeconds -= 1
                self.checkMilestones()
            }
            guard !Task.isCancelled else { return }
            self.state = .complete
            self.logger.info("Pomodoro complete")
            self.fire(.pomodoroDone)
            SoundManager.shared.play(.timerDone)
            self.viewModel?.celebrate()
            self.viewModel?.triggerConfetti()
            FocusStatsManager.shared.recordPomodoro(seconds: self.totalDuration)
        }
    }

    private func checkMilestones() {
        let elapsed = elapsedSeconds

        if !fired5min && elapsed >= 300 {
            fired5min = true
            fireDirect(.pomodoro5min)
        }
        if !firedHalfway && elapsed >= totalDuration / 2 {
            firedHalfway = true
            fireDirect(.pomodoroHalfway)
        }
        if !fired5minLeft && remainingSeconds <= 300 && remainingSeconds > 0 {
            fired5minLeft = true
            fireDirect(.pomodoro5minLeft)
        }
        if !fired1minLeft && remainingSeconds <= 60 && remainingSeconds > 0 {
            fired1minLeft = true
            fireDirect(.pomodoro1minLeft)
        }
    }

    /// Standard rate-limited bubble
    private func fire(_ trigger: ReactionTrigger) {
        let msg = ReactionLibraryService.shared.reaction(for: trigger)
        if !msg.isEmpty { viewModel?.showSpeechBubble(msg, duration: 5) }
    }

    /// Bypass cooldown - milestone messages always show
    private func fireDirect(_ trigger: ReactionTrigger) {
        let msg = ReactionLibraryService.shared.reaction(for: trigger)
        if !msg.isEmpty { viewModel?.showBubbleDirect(msg, duration: 5) }
    }

    private func resetMilestones() {
        fired5min     = false
        firedHalfway  = false
        fired5minLeft = false
        fired1minLeft = false
    }
}
