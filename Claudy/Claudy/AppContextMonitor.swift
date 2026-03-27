import AppKit
import Darwin
import OSLog

// MARK: - AppContextMonitor

/// Watches the frontmost application and system processes to trigger contextual reactions.
///
/// Monitors: frontmost app switches, Xcode build results (success/fail), npm/node activity,
/// Zoom/Meet video calls, and "vibe coding" sessions (sustained Claude Code use).
/// A single 15 s poll loop drives all process checks to minimise CPU usage.
/// All reaction strings are sourced from ReactionLibraryService.
@MainActor
final class AppContextMonitor {
    private weak var viewModel: CharacterViewModel?
    private var monitorTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?       // unified poll loop
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

        if isClaudeAppBundleID(bundleID) {
            handleClaudeAppActivation()
            return
        }

        guard let trigger = ambientTrigger(for: bundleID) else { return }
        let msg = ReactionLibraryService.shared.reaction(for: trigger)
        guard !msg.isEmpty else { return }

        if trigger == .appZoom { viewModel?.applyMood(for: .zoomActive) }

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

        // Developer tools
        if lower.contains("xcode")                                              { return .appXcode }
        if lower.contains("figma")                                              { return .appFigma }
        if isTerminalBundleID(bundleID)                                         { return .appTerminal }
        if lower.contains("zoom") || lower.contains("teams")                   { return .appZoom }
        if lower.contains("slack")                                              { return .appSlack }
        if lower.contains("cursor") || bundleID == "com.todesktop.230313mzl4w4u92" { return .appCursor }

        // AI competitors - friendly rivalry
        if bundleID == "com.openai.chat" || lower.contains("openai")           { return .appChatGPT }
        if lower.contains("perplexity")                                         { return .appPerplexity }

        // Music - party mode
        if bundleID == "com.spotify.client"                                     { return .appSpotify }
        if bundleID == "com.apple.Music"                                        { return .appMusic }

        // Productivity
        if bundleID == "com.google.Chrome" || bundleID == "com.google.chrome"  { return .appGoogle }
        if bundleID == "notion.id" || lower.contains("notion")                 { return .appNotion }
        if bundleID == "md.obsidian" || lower.contains("obsidian")             { return .appObsidian }

        // Database tools
        if bundleID == "com.tableplus.TablePlus" ||
           bundleID == "com.eggerapps.Postico2"  ||
           lower.contains("postico") || lower.contains("tableplus") ||
           lower.contains("sequel")                                             { return .appDatabase }

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
    // Claude Code check: every other tick (~30s) via tickCount modulo
    // Xcode build check: every tick (15s)
    // npm check: every tick, guarded by frontmost-terminal + once-per-session

    private func startPollLoop() {
        pollTask = Task { @MainActor in
            var tickCount = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }

                tickCount += 1
                self.logger.debug("AppContextMonitor: poll tick \(tickCount)")

                // ── Xcode build (every tick) ──────────────────────────────
                self.checkXcodeBuild()

                // ── npm detection (every tick, guarded) ──────────────────
                self.checkNpm()

                // ── Claude Code detection (every other tick ≈ 30s) ───────
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
            } else if duration >= 3 {
                // Build ran long enough to be a real compilation (not a sub-second
                // internal Xcode tool invocation). We have no exit code from polling,
                // so we react neutrally - no false confetti on a failed build,
                // no false alarm on a successful one.
                let msg = ReactionLibraryService.shared.reaction(for: .xcodeBuildSuccess)
                if !msg.isEmpty { viewModel?.showSpeechBubble(msg, duration: 5) }
            }
            // Mood and stare reactions removed - they relied on the unreliable
            // duration-based success/failure guess which was wrong ~50% of the time.
        }
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
