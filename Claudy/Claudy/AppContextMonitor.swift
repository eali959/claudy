import AppKit
import Darwin
import OSLog

// MARK: - AppContextMonitor

/// Watches the frontmost application and system processes to trigger contextual reactions.
///
/// Monitors: frontmost app switches (dev tools, productivity suites, AI tools, Office/iWork),
/// Xcode build results, Cursor IDE builds (tsc/webpack/cargo/etc), Claude Code agent builds,
/// npm/node activity, Zoom/Meet calls, and "vibe coding" sessions.
/// A single 15 s poll loop drives all process checks to minimise CPU usage.
@MainActor
final class AppContextMonitor {
    private weak var viewModel: CharacterViewModel?
    private var monitorTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var vibeCodingTask: Task<Void, Never>?
    private var lastBundleID: String = ""
    private let logger = Logger(subsystem: "com.claudy", category: "AppContextMonitor")

    // Session-level "shown once" flags
    private var claudeAppShownThisSession   = false
    private var claudeCodeShownThisSession  = false
    private var npmShownThisSession         = false
    private var vibeSessionFired            = false

    private var terminalIsFrontmost = false

    // Xcode build tracking
    private var xcodeBuildStartTime: Date? = nil
    private var longCompileReacted = false

    // Cursor build tracking
    private var cursorLastFrontmostTime: Date? = nil
    private var cursorBuildStartTime: Date? = nil

    // Claude Code agent build tracking
    private var lastClaudeAgentBuildReactionTime: Date = .distantPast

    init(viewModel: CharacterViewModel) {
        self.viewModel = viewModel
        startMonitoring()
        startPollLoop()
    }

    func stop() {
        monitorTask?.cancel()
        pollTask?.cancel()
        vibeCodingTask?.cancel()
    }

    // MARK: - App activation monitoring

    private func startMonitoring() {
        monitorTask = Task { @MainActor in
            let nc = NSWorkspace.shared.notificationCenter
            for await notification in nc.notifications(named: NSWorkspace.didActivateApplicationNotification) {
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                        as? NSRunningApplication,
                      let bundleID = app.bundleIdentifier,
                      bundleID != self.lastBundleID else { continue }
                self.lastBundleID = bundleID
                self.handleActivation(bundleID: bundleID, appName: app.localizedName)
            }
        }
    }

    // MARK: - Handle app switch

    func handleActivation(bundleID: String, appName: String?) {
        terminalIsFrontmost = isTerminalBundleID(bundleID)

        // Track Cursor frontmost time for build detection
        let lower = bundleID.lowercased()
        if lower.contains("cursor") || bundleID == "com.todesktop.230313mzl4w4u92" {
            cursorLastFrontmostTime = Date()
        }

        // Let BehaviorModeManager react (Study Mode browser nudge, BrainRot app switch, etc.)
        viewModel?.behaviorModeManager.onAppSwitch(bundleID: bundleID)

        // Surface a contextual quick-action button for supported apps
        Task { @MainActor in
            QuickActionManager.shared.appDidActivate(bundleID: bundleID)
        }

        if isClaudeAppBundleID(bundleID) {
            handleClaudeAppActivation()
            return
        }

        guard let trigger = ambientTrigger(for: bundleID) else { return }
        let msg = ReactionLibraryService.shared.reaction(for: trigger)
        guard !msg.isEmpty else { return }

        if trigger == .appZoom || trigger == .appMicrosoftTeams {
            viewModel?.applyMood(for: .zoomActive)
        }

        viewModel?.showSpeechBubble(msg)
    }

    private func isClaudeAppBundleID(_ bundleID: String) -> Bool {
        let lower = bundleID.lowercased()
        return lower == "com.anthropic.claude" || lower.contains("anthropic.claude")
    }

    private func isTerminalBundleID(_ bundleID: String) -> Bool {
        switch bundleID {
        case "com.apple.Terminal", "com.googlecode.iterm2",
             "dev.warp.Warp-Stable", "com.github.wez.wezterm",
             "net.kovidgoyal.kitty": return true
        default: return false
        }
    }

    // MARK: - Ambient trigger mapping

    private func ambientTrigger(for bundleID: String) -> ReactionTrigger? {
        let lower = bundleID.lowercased()

        // ── AI tools ──────────────────────────────────────────────────────────
        if lower.contains("xcode")                                                { return .appXcode }
        if lower.contains("figma")                                                { return .appFigma }
        if isTerminalBundleID(bundleID)                                           { return .appTerminal }
        if lower.contains("cursor") || bundleID == "com.todesktop.230313mzl4w4u92" { return .appCursor }
        if lower.contains("windsurf") || lower.contains("codeium")               { return .appWindsurf }
        if lower.contains("antigravity")                                          { return .appAntigravity }

        // ── AI competitors ─────────────────────────────────────────────────────
        if bundleID == "com.openai.chat" || lower.contains("openai")             { return .appChatGPT }
        if lower.contains("perplexity")                                           { return .appPerplexity }

        // ── Communication & meetings ─────────────────────────────────────────
        if lower.contains("zoom")                                                 { return .appZoom }
        if lower.contains("slack")                                                { return .appSlack }
        if lower.contains("microsoft.teams") || lower.contains("msteams")        { return .appMicrosoftTeams }

        // ── Microsoft Office suite ────────────────────────────────────────────
        if bundleID == "com.microsoft.Word"       || lower == "com.microsoft.word"       { return .appMicrosoftWord }
        if bundleID == "com.microsoft.Excel"      || lower == "com.microsoft.excel"      { return .appMicrosoftExcel }
        if bundleID == "com.microsoft.Powerpoint" || lower.contains("microsoft.powerpoint") { return .appMicrosoftPowerPoint }
        if lower.contains("microsoft.outlook")                                    { return .appMicrosoftOutlook }

        // ── Apple productivity suite ─────────────────────────────────────────
        if bundleID == "com.apple.iWork.Pages"   || lower.contains("iwork.pages")    { return .appApplePages }
        if bundleID == "com.apple.iWork.Keynote" || lower.contains("iwork.keynote")  { return .appAppleKeynote }
        if bundleID == "com.apple.iWork.Numbers" || lower.contains("iwork.numbers")  { return .appAppleNumbers }
        if bundleID == "com.apple.mail"                                           { return .appAppleMail }
        if bundleID == "com.apple.Notes"                                          { return .appAppleNotes }
        if bundleID == "com.apple.Safari" || bundleID == "com.apple.safari"       { return .appAppleSafari }

        // ── Dev tools & services ─────────────────────────────────────────────
        if bundleID == "com.github.GitHubDesktop" || lower.contains("githubdesktop") { return .appGitHubDesktop }
        if lower.contains("linear.app") || bundleID == "com.linear.Linear"       { return .appLinear }
        if lower.contains("raycast")                                              { return .appRaycast }
        if lower.contains("arc") && lower.contains("browser")                    { return .appArc }
        if lower.contains("postman")                                              { return .appPostman }
        if lower.contains("insomnia")                                             { return .appInsomnia }

        // ── Music ─────────────────────────────────────────────────────────────
        if bundleID == "com.spotify.client"                                       { return .appSpotify }
        if bundleID == "com.apple.Music"                                          { return .appMusic }

        // ── Browsers ──────────────────────────────────────────────────────────
        if bundleID == "com.google.Chrome" || bundleID == "com.google.chrome"    { return .appChrome }
        if lower.contains("microsoft.edge") || lower.contains("edgemac")         { return .appEdge }
        if lower.contains("firefox") || bundleID == "org.mozilla.firefox"        { return .appFirefox }
        if lower.contains("brave") || bundleID == "com.brave.Browser"            { return .appBrave }
        if lower.contains("opera") || bundleID == "com.operasoftware.Opera"      { return .appOpera }
        if lower.contains("duckduckgo")                                           { return .appDuckDuckGo }
        if lower.contains("helium") || bundleID == "com.externalhard.Helium"      { return .appHelium }

        // ── Knowledge & productivity ─────────────────────────────────────────
        if bundleID == "notion.id" || lower.contains("notion")                   { return .appNotion }
        if bundleID == "md.obsidian" || lower.contains("obsidian")               { return .appObsidian }

        // ── Database tools ─────────────────────────────────────────────────────
        if bundleID == "com.tableplus.TablePlus" ||
           bundleID == "com.eggerapps.Postico2"  ||
           lower.contains("postico") || lower.contains("tableplus") ||
           lower.contains("sequel")                                               { return .appDatabase }

        return nil
    }

    // MARK: - Claude app reaction (once per session)

    private func handleClaudeAppActivation() {
        guard !claudeAppShownThisSession else { return }
        claudeAppShownThisSession = true
        startVibeSessionTimer()
        viewModel?.applyMood(for: .vibeCoding)

        let userChoseAPIMode = UserDefaults.standard.string(forKey: "chatMode") == "api"
        if PersonalityManager.shared.currentMode == .director,
           ClaudeAPIService.shared.hasAPIKey,
           userChoseAPIMode {
            fireIntenseClaudeReaction()
            return
        }

        let msg = ReactionLibraryService.shared.reaction(for: .appClaude)
        if !msg.isEmpty { viewModel?.showSpeechBubble(msg, duration: 5) }
        viewModel?.celebrate()
    }

    private func fireIntenseClaudeReaction() {
        guard let vm = viewModel else { return }
        vm.celebrate()
        Task {
            let prompt = "You are Claud-y in INTENSE DIRECTOR mode. The user just switched to the Claude app - your sibling, your kin, the main interface. React with unhinged director-level excitement in exactly one sentence (≤ 15 words)."
            let msg = ChatMessage(role: .user, content: "The Claude app just opened.")
            let stream = await ClaudeAPIService.shared.streamResponse(
                messages: [msg],
                systemPrompt: prompt,
                priority: .reaction
            )
            var response = ""
            do {
                for try await token in stream { response += token }
            } catch {
                response = ReactionLibraryService.shared.reaction(for: .appClaude)
            }
            let final = response.trimmingCharacters(in: .whitespacesAndNewlines)
            if !final.isEmpty { vm.showSpeechBubble(final, duration: 5) }
        }
    }

    // MARK: - Vibe coding session (20 min with Claude / Claude Code)

    private func startVibeSessionTimer() {
        guard vibeCodingTask == nil, !vibeSessionFired else { return }
        vibeCodingTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(20 * 60))
            guard !Task.isCancelled, !self.vibeSessionFired else { return }
            self.vibeSessionFired = true
            let msg = ReactionLibraryService.shared.reaction(for: .vibeCodingSession)
            if !msg.isEmpty { self.viewModel?.showSpeechBubble(msg, duration: 6) }
            self.viewModel?.applyMood(for: .vibeCoding)
        }
    }

    // MARK: - Unified poll loop (15s tick)

    private func startPollLoop() {
        pollTask = Task { @MainActor in
            var tickCount = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }

                tickCount += 1
                self.logger.debug("AppContextMonitor: poll tick \(tickCount)")

                self.checkXcodeBuild()
                self.checkNpm()
                self.checkCursorBuild()
                self.checkClaudeCodeAgentBuild()

                if tickCount.isMultiple(of: 2) {
                    self.checkClaudeCode()
                }
            }
        }
    }

    private func checkXcodeBuild() {
        let isBuilding = Self.isProcessRunning(named: "xcodebuild")

        if isBuilding && xcodeBuildStartTime == nil {
            xcodeBuildStartTime = Date()
            longCompileReacted = false
            let msg = ReactionLibraryService.shared.reaction(for: .xcodeBuildStart)
            if !msg.isEmpty { viewModel?.showSpeechBubble(msg, duration: 4) }

        } else if isBuilding, let startTime = xcodeBuildStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > 60 && !longCompileReacted {
                longCompileReacted = true
                let msg = ReactionLibraryService.shared.reaction(for: .longCompileWait)
                if !msg.isEmpty { viewModel?.showSpeechBubble(msg, duration: 6) }
            }

        } else if !isBuilding, let startTime = xcodeBuildStartTime {
            xcodeBuildStartTime = nil
            let duration = Date().timeIntervalSince(startTime)

            if longCompileReacted {
                let msg = ReactionLibraryService.shared.reaction(for: .longCompileDone)
                if !msg.isEmpty { viewModel?.showSpeechBubble(msg, duration: 5) }
                longCompileReacted = false
                viewModel?.behaviorModeManager.onBuildComplete()
            } else if duration >= 3 {
                let msg = ReactionLibraryService.shared.reaction(for: .xcodeBuildSuccess)
                if !msg.isEmpty { viewModel?.showSpeechBubble(msg, duration: 5) }
                viewModel?.behaviorModeManager.onBuildComplete()
            }
        }
    }

    // MARK: - Cursor build detection
    // Fires when Cursor was frontmost within the last 90s and a non-Xcode build tool runs.

    private static let cursorBuildProcessNames = [
        "tsc", "webpack", "vite", "rollup", "esbuild",
        "cargo", "make", "cmake", "gradle", "mvn",
        "pytest", "jest", "vitest", "mocha"
    ]

    private func checkCursorBuild() {
        // Only fire if Cursor was recently active
        guard let lastFrontmost = cursorLastFrontmostTime,
              Date().timeIntervalSince(lastFrontmost) < 90 else { return }

        let isBuilding = Self.cursorBuildProcessNames.contains { Self.isProcessRunning(named: $0) }

        if isBuilding && cursorBuildStartTime == nil {
            cursorBuildStartTime = Date()
            let msg = ReactionLibraryService.shared.reaction(for: .cursorBuildStart)
            if !msg.isEmpty { viewModel?.showSpeechBubble(msg, duration: 4) }

        } else if !isBuilding, let start = cursorBuildStartTime {
            cursorBuildStartTime = nil
            let duration = Date().timeIntervalSince(start)
            if duration >= 2 {
                let msg = ReactionLibraryService.shared.reaction(for: .cursorBuildDone)
                if !msg.isEmpty { viewModel?.showSpeechBubble(msg, duration: 5) }
                viewModel?.behaviorModeManager.onBuildComplete()
            }
        }
    }

    // MARK: - Claude Code agent build detection
    // Fires when the claude CLI is running AND a build process is detected.

    private static let agentBuildProcessNames = [
        "tsc", "node", "webpack", "vite", "cargo", "make",
        "python3", "pytest", "jest", "gradle", "mvn"
    ]

    private func checkClaudeCodeAgentBuild() {
        guard Self.isProcessRunning(named: "claude") else { return }
        // Rate-limit to once every 5 minutes
        guard Date().timeIntervalSince(lastClaudeAgentBuildReactionTime) > 5 * 60 else { return }
        let isBuilding = Self.agentBuildProcessNames.contains { Self.isProcessRunning(named: $0) }
        guard isBuilding else { return }

        lastClaudeAgentBuildReactionTime = Date()
        let msg = ReactionLibraryService.shared.reaction(for: .claudeCodeAgentBuild)
        if !msg.isEmpty { viewModel?.showSpeechBubble(msg, duration: 6) }
        viewModel?.celebrate()
    }

    private func checkNpm() {
        guard terminalIsFrontmost, !npmShownThisSession else { return }
        if Self.isProcessRunning(named: "npm") {
            npmShownThisSession = true
            let msg = ReactionLibraryService.shared.reaction(for: .npmInstall)
            if !msg.isEmpty { viewModel?.showSpeechBubble(msg, duration: 5) }
            viewModel?.applyMood(for: .npmRunning)
        }
    }

    private func checkClaudeCode() {
        guard !claudeCodeShownThisSession else { return }
        if Self.isProcessRunning(named: "claude") {
            claudeCodeShownThisSession = true
            startVibeSessionTimer()
            let msg = ReactionLibraryService.shared.reaction(for: .appClaudeCode)
            if !msg.isEmpty {
                viewModel?.showSpeechBubble(msg, duration: 5)
                viewModel?.celebrate()
            }
        }
    }

    // MARK: - Process detection via sysctl (sandbox-safe)

    private static func isProcessRunning(named processName: String) -> Bool {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else { return false }

        let count = size / MemoryLayout<kinfo_proc>.stride
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        guard sysctl(&mib, 4, &procs, &size, nil, 0) == 0 else { return false }

        let actualCount = size / MemoryLayout<kinfo_proc>.stride
        let lower = processName.lowercased()
        for i in 0..<actualCount {
            let name = withUnsafeBytes(of: procs[i].kp_proc.p_comm) { buf -> String in
                let bytes = buf.prefix(while: { $0 != 0 })
                return String(bytes: bytes, encoding: .utf8) ?? ""
            }
            if name.lowercased() == lower { return true }
        }
        return false
    }
}
