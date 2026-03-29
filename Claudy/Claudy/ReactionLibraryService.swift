import Foundation
import OSLog

// MARK: - ReactionTrigger

/// All trigger keys - raw values must match keys in ReactionLibrary.json exactly.
enum ReactionTrigger: String, CaseIterable {
    // Clipboard
    case clipboardText      = "clipboard_text"
    case clipboardCode      = "clipboard_code"
    case clipboardUrl       = "clipboard_url"
    case clipboardRepeat    = "clipboard_repeat"

    // Keyboard / typing
    case typingBurst        = "typing_burst"
    case typingPause        = "typing_pause"
    case cmdZSpam           = "cmd_z_spam"
    case cmdS               = "cmd_s"
    case cmdCCmdVFast       = "cmd_c_cmd_v_fast"
    case multipleTabs       = "multiple_tabs"
    case cmdWSpam           = "cmd_w_spam"
    case capsLock           = "caps_lock"

    // System events
    case screenshot         = "screenshot"
    case appCrash           = "app_crash"
    case batteryLow         = "battery_low"
    case wifiLost           = "wifi_lost"
    case wifiBack           = "wifi_back"

    // Xcode
    case appXcode           = "app_xcode"
    case xcodeBuildStart    = "xcode_build_start"
    case xcodeBuildSuccess  = "xcode_build_success"
    case xcodeBuildFail     = "xcode_build_fail"
    case xcodeBuildStare    = "xcode_build_stare"
    case xcodeSimulator     = "xcode_simulator"
    case xcodeWarnings      = "xcode_warnings"
    case xcodeAutocomplete  = "xcode_autocomplete"
    case breakpointHit      = "breakpoint_hit"
    case consoleError       = "console_error"

    // Long compile (Phase 12)
    case longCompileWait    = "long_compile_wait"
    case longCompileDone    = "long_compile_done"

    // Git / dev workflow
    case gitCommit          = "git_commit"
    case gitPush            = "git_push"
    case gitPull            = "git_pull"
    case npmInstall         = "npm_install"
    case terminalLongCmd    = "terminal_long_command"
    case stackOverflow      = "stack_overflow"
    case githubPR           = "github_pr"

    // App context - developer
    case appFigma           = "app_figma"
    case appTerminal        = "app_terminal"
    case appZoom            = "app_zoom"
    case appSlack           = "app_slack"
    case appClaude          = "app_claude"
    case appClaudeCode      = "app_claude_code"
    case appCursor          = "app_cursor"

    // App context - new (Phase 13)
    case appChatGPT         = "app_chatgpt"
    case appChatGPTCode     = "app_chatgpt_code"
    case appPerplexity      = "app_perplexity"
    case appSpotify         = "app_spotify"
    case appMusic           = "app_music"
    case appGoogle          = "app_google"
    case appNotion          = "app_notion"
    case appObsidian        = "app_obsidian"
    case appDatabase        = "app_database"

    // Cursor-specific build events
    case cursorBuildStart   = "cursor_build_start"
    case cursorBuildDone    = "cursor_build_done"
    case appAntigravity     = "app_antigravity"
    case claudeCodeAgentBuild = "claude_code_agent_build"

    // Microsoft Office suite
    case appMicrosoftWord       = "app_microsoft_word"
    case appMicrosoftExcel      = "app_microsoft_excel"
    case appMicrosoftPowerPoint = "app_microsoft_powerpoint"
    case appMicrosoftOutlook    = "app_microsoft_outlook"
    case appMicrosoftTeams      = "app_microsoft_teams"

    // Apple productivity suite
    case appApplePages    = "app_apple_pages"
    case appAppleKeynote  = "app_apple_keynote"
    case appAppleNumbers  = "app_apple_numbers"
    case appAppleMail     = "app_apple_mail"
    case appAppleNotes    = "app_apple_notes"
    case appAppleSafari   = "app_apple_safari"

    // Other popular dev tools
    case appGitHubDesktop = "app_github_desktop"
    case appLinear        = "app_linear"
    case appRaycast       = "app_raycast"
    case appArc           = "app_arc"
    case appWindsurf      = "app_windsurf"
    case appPostman       = "app_postman"
    case appInsomnia      = "app_insomnia"

    // AI session
    case vibeCodingSession  = "vibe_coding_session"
    case aiContextLimit     = "ai_context_limit"

    // Time / day
    case mondayMorning      = "monday_morning"
    case friday             = "friday"
    case lateNight          = "late_night"
    case veryLate           = "very_late"

    // Greetings
    case greetingLaunch     = "greeting_launch"
    case greetingMorning    = "greeting_morning"
    case greetingAfternoon  = "greeting_afternoon"
    case greetingWake       = "greeting_wake"
    case greetingLateNight  = "greeting_late_night"

    // Interaction
    case userThanks         = "user_thanks"
    case idle5min           = "idle_5min"
    case idleWander         = "idle_wander"
    case hourlyChime        = "hourly_chime"

    // Mute
    case muteOn             = "mute_on"
    case muteOff            = "mute_off"

    // Pomodoro
    case pomodoroStart      = "pomodoro_start"
    case pomodoro5min       = "pomodoro_5min"
    case pomodoroHalfway    = "pomodoro_halfway"
    case pomodoro5minLeft   = "pomodoro_5min_left"
    case pomodoro1minLeft   = "pomodoro_1min_left"
    case pomodoroDone       = "pomodoro_done"
    case pomodoroPause      = "pomodoro_pause"
    case pomodoroResume     = "pomodoro_resume"
    case pomodoroStop       = "pomodoro_stop"
}

// MARK: - ReactionLibraryService

@MainActor
final class ReactionLibraryService {
    static let shared = ReactionLibraryService()

    private var library:      [String: [String]] = [:]
    private var recentlyUsed: [String: [String]] = [:]
    private let logger = Logger(subsystem: "com.claudy", category: "ReactionLibrary")

    private init() { loadLibrary() }

    // MARK: - Public API

    func reaction(for trigger: ReactionTrigger) -> String {
        let key = trigger.rawValue
        guard let pool = library[key], !pool.isEmpty else {
            logger.warning("No reactions found for trigger: \(key)")
            return ""
        }
        let recent    = recentlyUsed[key] ?? []
        let available = pool.filter { !recent.contains($0) }
        let choices   = available.isEmpty ? pool : available
        let picked    = choices.randomElement() ?? pool[0]

        var updated = recent + [picked]
        if updated.count > 3 { updated.removeFirst() }
        recentlyUsed[key] = updated
        return picked
    }

    // MARK: - Load

    private func loadLibrary() {
        guard let url = Bundle.main.url(forResource: "ReactionLibrary", withExtension: "json") else {
            logger.error("ReactionLibrary.json not found in bundle")
            return
        }
        guard let data = try? Data(contentsOf: url) else {
            logger.error("Failed to read ReactionLibrary.json")
            return
        }
        guard let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            logger.error("Failed to decode ReactionLibrary.json")
            return
        }
        library = decoded
        logger.info("Loaded \(decoded.count) reaction triggers from ReactionLibrary.json")
    }
}
