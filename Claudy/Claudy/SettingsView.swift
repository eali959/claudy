import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(PersonalityManager.self) private var personalityManager

    // Chat / Appearance
    @AppStorage("ChatFontSize")           private var chatFontSize: Double = 14
    @AppStorage("CharacterOpacity")       private var characterOpacity: Double = 1.0
    @AppStorage("ChatWindowOpacity")      private var chatWindowOpacity: Double = 1.0
    @AppStorage("UserBubbleColor")        private var userBubbleColor: String = "orange"

    // Provider + model
    @AppStorage("SelectedProvider")       private var selectedProviderRaw: String = "claude"
    @AppStorage("SelectedModel")          private var selectedModel: String = ClaudeAPIService.defaultModel
    @AppStorage("UseComplexModel")        private var useComplexModel = false

    // Sound
    @AppStorage("SoundEffectsEnabled")    private var soundEffectsEnabled = false
    @AppStorage("SoundVolume")            private var soundVolume: Double = 0.7
    @AppStorage("CharacterVoiceEnabled")  private var characterVoiceEnabled = false

    // Focus Timer
    @AppStorage("PomodoroPreset")         private var pomodoroPresetRaw: Int = PomodoroPreset.classic.rawValue
    @AppStorage("PomodoroCustomMinutes")  private var pomodoroCustomMinutes: Int = 25
    @AppStorage("TimerBadgeScale")        private var timerBadgeScale: Double = 1.0

    // Chattiness
    @AppStorage("ChattinessLevel")        private var chattinessLevel: Int = 3

    // API Key state (per-provider)
    @State private var claudeKeyInput: String = ""
    @State private var openAIKeyInput: String = ""
    @State private var geminiKeyInput: String = ""
    @State private var isSaved = false
    @State private var saveError: String?
    @State private var showKey = false
    @State private var testStatus: TestStatus = .idle
    @State private var showRemoveConfirm = false

    private var activeProvider: APIProvider {
        APIProvider(rawValue: selectedProviderRaw) ?? .claude
    }

    // Quick launch state
    @State private var quickShortcuts: [QuickLaunchManager.Shortcut] = []
    @State private var newShortcutName = ""
    @State private var newShortcutBundleID = ""
    @State private var newShortcutKey = ""

    enum TestStatus {
        case idle, testing, ok(String), fail(String)
    }

    private let orange = Color(red: 0.784, green: 0.361, blue: 0.220)

    var body: some View {
        Form {
            generalSection
            appearanceSection
            chatSection
            pomodoroSection
            chattinessSection
            quickLaunchSection
            soundSection
            apiKeySection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 540, idealWidth: 560, minHeight: 500)
        .confirmationDialog("Remove API Key?", isPresented: $showRemoveConfirm, titleVisibility: .visible) {
            Button("Remove Key", role: .destructive) { removeAPIKey() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your API key will be deleted from the Keychain. You can add it again at any time.")
        }
        .onAppear {
            claudeKeyInput = (try? KeychainService.load(for: .claude)) ?? ""
            openAIKeyInput = (try? KeychainService.load(for: .openai)) ?? ""
            geminiKeyInput = (try? KeychainService.load(for: .gemini)) ?? ""
            quickShortcuts = QuickLaunchManager.shared.shortcuts
            validateSelectedModel()
        }
    }

    // MARK: - General

    private var generalSection: some View {
        @Bindable var pm = personalityManager
        return Section {
            Picker("Personality", selection: $pm.currentMode) {
                ForEach(PersonalityMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .frame(minHeight: 44)

            if personalityManager.currentMode == .custom {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom persona")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $pm.customPersonaText)
                        .font(.system(size: 12))
                        .frame(height: 80)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
                }
            }

            Picker("Chat model", selection: $selectedModel) {
                switch activeProvider {
                case .claude:
                    Text("Haiku 4.5 — fast").tag("claude-haiku-4-5-20251001")
                    Text("Sonnet 4.6 — smart").tag("claude-sonnet-4-6")
                    Text("Haiku 3.5 — fallback").tag("claude-3-5-haiku-20241022")
                case .openai:
                    Text("GPT-4o mini — fast").tag("gpt-4o-mini")
                    Text("GPT-4o — smart").tag("gpt-4o")
                case .gemini:
                    Text("Gemini 2.0 Flash — fast").tag("gemini-2.0-flash")
                    Text("Gemini 1.5 Pro — smart").tag("gemini-1.5-pro")
                }
            }
            .frame(minHeight: 44)
            .onChange(of: selectedProviderRaw) { _, _ in
                // Reset model to provider default when switching
                selectedModel = activeProvider.defaultModel
            }

            Toggle("Use smarter model for complex tasks", isOn: $useComplexModel)
                .frame(minHeight: 44)
            Text("When on, uses \(activeProvider.smartModel) for longer tasks — more capable, but draws more API quota.")
                .font(.caption).foregroundStyle(.secondary)

            Toggle("Global hotkey ⌘⇧Space", isOn: Binding(
                get: { GlobalHotkeyManager.shared.isEnabled },
                set: { GlobalHotkeyManager.shared.isEnabled = $0 }
            ))
            .frame(minHeight: 44)
            Text("Open or close the Claud-y chat from any app. Disable if it conflicts with another shortcut.")
                .font(.caption).foregroundStyle(.secondary)
        } header: {
            Text("General").font(.headline)
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section {
            LabeledContent("Character size") {
                sizePresetPicker
            }
            .frame(minHeight: 44)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Character opacity")
                    Spacer()
                    Text("\(Int(characterOpacity * 100))%")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .monospacedDigit()
                }
                HStack(spacing: 8) {
                    Text("50%").font(.caption).foregroundStyle(.tertiary)
                    Slider(value: $characterOpacity, in: 0.5...1.0, step: 0.05)
                    Text("100%").font(.caption).foregroundStyle(.tertiary)
                }
                Text("Lower opacity keeps Claud-y present but unobtrusive.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Chat window opacity")
                    Spacer()
                    Text("\(Int(chatWindowOpacity * 100))%")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .monospacedDigit()
                }
                HStack(spacing: 8) {
                    Text("40%").font(.caption).foregroundStyle(.tertiary)
                    Slider(value: $chatWindowOpacity, in: 0.4...1.0, step: 0.05)
                    Text("100%").font(.caption).foregroundStyle(.tertiary)
                }
                Text("Reduce to keep the chat overlay subtle while you work.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text("Appearance").font(.headline)
        }
    }

    @ViewBuilder
    private var sizePresetPicker: some View {
        // Read/write the window manager's size preset via UserDefaults
        let binding = Binding<WindowManager.SizePreset>(
            get: {
                let saved = UserDefaults.standard.string(forKey: "CharacterSizePreset") ?? ""
                return WindowManager.SizePreset(rawValue: saved) ?? .medium
            },
            set: { UserDefaults.standard.set($0.rawValue, forKey: "CharacterSizePreset") }
        )
        Picker("", selection: binding) {
            ForEach(WindowManager.SizePreset.allCases, id: \.self) { preset in
                Text(preset.displayName).tag(preset)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 200)
    }

    // MARK: - Chat

    private var chatSection: some View {
        Section {
            LabeledContent("Text size") {
                HStack(spacing: 4) {
                    Button { chatFontSize = max(12, chatFontSize - 1) } label: {
                        Image(systemName: "minus").frame(width: 22, height: 22)
                    }
                    .buttonStyle(.bordered)
                    Text("\(Int(chatFontSize)) pt")
                        .monospacedDigit()
                        .frame(minWidth: 36)
                    Button { chatFontSize = min(20, chatFontSize + 1) } label: {
                        Image(systemName: "plus").frame(width: 22, height: 22)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(minHeight: 44)

            VStack(alignment: .leading, spacing: 8) {
                Text("Your message colour")
                    .font(.system(size: 13))
                HStack(spacing: 12) {
                    colorCircle("orange", Color(red: 0.784, green: 0.361, blue: 0.220))
                    colorCircle("blue",   Color.blue.opacity(0.85))
                    colorCircle("green",  Color.green.opacity(0.75))
                    colorCircle("purple", Color.purple.opacity(0.75))
                }
                Text("Sets the background colour of your chat messages.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Chat").font(.headline)
        }
    }

    @ViewBuilder
    private func colorCircle(_ key: String, _ color: Color) -> some View {
        Button {
            userBubbleColor = key
        } label: {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 28, height: 28)
                if userBubbleColor == key {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(key.capitalized) bubble colour")
    }

    // MARK: - Focus Timer

    private var pomodoroSection: some View {
        Section {
            Picker("Duration", selection: Binding(
                get: { PomodoroPreset(rawValue: pomodoroPresetRaw) ?? .classic },
                set: { pomodoroPresetRaw = $0.rawValue }
            )) {
                ForEach(PomodoroPreset.allCases, id: \.self) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .frame(minHeight: 44)

            if PomodoroPreset(rawValue: pomodoroPresetRaw) == .custom {
                HStack {
                    Text("Custom duration")
                    Spacer()
                    Stepper("\(pomodoroCustomMinutes) min",
                            value: $pomodoroCustomMinutes,
                            in: 5...120,
                            step: 5)
                }
                .frame(minHeight: 44)
            }

            Text("Timer duration - the next session will use this setting. Changing this mid-session has no effect.")
                .font(.caption).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Badge size")
                    Spacer()
                    Text("\(Int(timerBadgeScale * 100))%")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .monospacedDigit()
                }
                HStack(spacing: 8) {
                    Text("70%").font(.caption).foregroundStyle(.tertiary)
                    Slider(value: $timerBadgeScale, in: 0.7...1.6, step: 0.05)
                    Text("160%").font(.caption).foregroundStyle(.tertiary)
                }
            }
            .frame(minHeight: 44)
        } header: {
            Text("Focus Tools").font(.headline)
        }
    }

    // MARK: - Chattiness

    private var chattinessSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Chattiness")
                    Spacer()
                    Text(chattinessLabel)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                Slider(value: Binding(
                    get: { Double(chattinessLevel) },
                    set: { chattinessLevel = Int($0.rounded()) }
                ), in: 1...5, step: 1)
                Text(chattinessDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 44)
        } header: {
            Text("Chattiness").font(.headline)
        }
    }

    private var chattinessLabel: String {
        switch chattinessLevel {
        case 1: return "Quiet"
        case 2: return "Calm"
        case 3: return "Balanced"
        case 4: return "Chatty"
        case 5: return "Non-stop"
        default: return "Balanced"
        }
    }

    private var chattinessDescription: String {
        switch chattinessLevel {
        case 1: return "A bubble every ~2 minutes"
        case 2: return "A bubble every ~80 seconds"
        case 3: return "A bubble every ~45 seconds (default)"
        case 4: return "A bubble every ~27 seconds"
        case 5: return "A bubble every ~14 seconds"
        default: return "A bubble every ~45 seconds"
        }
    }

    // MARK: - Quick Launch

    private var quickLaunchSection: some View {
        Section {
            if quickShortcuts.isEmpty {
                Label("No shortcuts yet - add up to \(QuickLaunchManager.maxShortcuts) below.", systemImage: "rocket")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(quickShortcuts) { shortcut in
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(orange.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Text(String(shortcut.name.prefix(1)).uppercased())
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(orange)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(shortcut.name)
                                    .font(.system(size: 13, weight: .semibold))
                                if !shortcut.shortcutKey.isEmpty {
                                    Text("⌘\(shortcut.shortcutKey.uppercased())")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                                }
                            }
                            Text(shortcut.bundleID)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button {
                            QuickLaunchManager.shared.launch(shortcut)
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Launch \(shortcut.name)")
                    }
                    .frame(minHeight: 44)
                }
                .onDelete { offsets in
                    QuickLaunchManager.shared.remove(at: offsets)
                    quickShortcuts = QuickLaunchManager.shared.shortcuts
                }
            }

            if quickShortcuts.count < QuickLaunchManager.maxShortcuts {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Add shortcut")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                    VStack(spacing: 6) {
                        LabeledContent("Name") {
                            TextField("e.g. Terminal", text: $newShortcutName)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                        }
                        LabeledContent("Bundle ID") {
                            TextField("e.g. com.apple.Terminal", text: $newShortcutBundleID)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                        }
                        LabeledContent("⌘ Key") {
                            HStack {
                                TextField("t", text: $newShortcutKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(width: 48)
                                    .onChange(of: newShortcutKey) { _, val in
                                        if val.count > 1, let last = val.last {
                                            newShortcutKey = String(last)
                                        }
                                    }
                                Text("Optional")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                            }
                        }
                    }
                    Button {
                        let name = newShortcutName.trimmingCharacters(in: .whitespaces)
                        let bid  = newShortcutBundleID.trimmingCharacters(in: .whitespaces)
                        let key  = newShortcutKey.trimmingCharacters(in: .whitespaces).lowercased()
                        guard !name.isEmpty, !bid.isEmpty else { return }
                        QuickLaunchManager.shared.add(
                            QuickLaunchManager.Shortcut(name: name, bundleID: bid, shortcutKey: key)
                        )
                        quickShortcuts = QuickLaunchManager.shared.shortcuts
                        newShortcutName = ""
                        newShortcutBundleID = ""
                        newShortcutKey = ""
                    } label: {
                        Label("Add Shortcut", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(orange)
                    .disabled(newShortcutName.trimmingCharacters(in: .whitespaces).isEmpty ||
                              newShortcutBundleID.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.top, 4)
            }
        } header: {
            Text("Quick Launch").font(.headline)
        } footer: {
            Text("Shortcuts appear in the right-click context menu. The optional ⌘ key activates them from the menu bar.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Sound

    private var soundSection: some View {
        Section {
            Toggle("Enable sound effects", isOn: $soundEffectsEnabled)
                .frame(minHeight: 44)
            Text("Subtle audio feedback: a pop on speech bubbles, chime on clean builds, fanfare on wins, and a soft tone on Pomodoro completion.")
                .font(.caption).foregroundStyle(.secondary)

            if soundEffectsEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Volume")
                        Spacer()
                        Text("\(Int(soundVolume * 100))%")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .monospacedDigit()
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "speaker").font(.caption).foregroundStyle(.secondary)
                        Slider(value: $soundVolume, in: 0.0...1.0)
                        Image(systemName: "speaker.wave.3").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: 44)

                Toggle("Character voice", isOn: $characterVoiceEnabled)
                    .frame(minHeight: 44)
                Text("Short mumble tones when Claud-y speaks - GTA-style garbled but charming. Uses the same volume setting.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text("Sound").font(.headline)
        }
    }

    // MARK: - API Provider

    private var apiKeySection: some View {
        Section {
            // Provider picker
            Picker("AI Provider", selection: $selectedProviderRaw) {
                ForEach(APIProvider.allCases, id: \.self) { p in
                    Label(p.displayName, systemImage: p.icon).tag(p.rawValue)
                }
            }
            .frame(minHeight: 44)

            // Key field for the active provider
            VStack(alignment: .leading, spacing: 6) {
                Text("API Key — \(activeProvider.displayName)")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Group {
                        if showKey {
                            TextField(activeProvider.keyPlaceholder, text: activeKeyBinding)
                        } else {
                            SecureField(activeProvider.keyPlaceholder, text: activeKeyBinding)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                    Button { showKey.toggle() } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minHeight: 44)

            // Privacy callout
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                    Text("Your key is private — guaranteed")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(activeProvider.privacyNote)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("No Claud-y server exists. There is no middleman. We cannot see your key, your prompts, or your responses — ever. No telemetry, no analytics, no logging of any kind.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.green.opacity(0.18), lineWidth: 0.5))
            .padding(.top, 2)

            // Actions row
            HStack {
                Button("Save Key") { saveAPIKey() }
                    .disabled(activeKeyBinding.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Test") { testConnection() }
                    .disabled(activeKeyBinding.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)

                switch testStatus {
                case .idle:     EmptyView()
                case .testing:  ProgressView().scaleEffect(0.7)
                case .ok(let msg):
                    Label(msg, systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                case .fail(let msg):
                    Label(msg, systemImage: "xmark.circle.fill").foregroundStyle(.red).font(.caption)
                }
                if isSaved {
                    Label("Saved", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                }
                if let err = saveError {
                    Label(err, systemImage: "xmark.circle.fill").foregroundStyle(.red).font(.caption)
                }
                Spacer()
                Button("Remove Key", role: .destructive) { showRemoveConfirm = true }
                    .foregroundStyle(.red)
            }
            .frame(minHeight: 44)

            // Get key link
            if let url = URL(string: activeProvider.docsURL) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Get \(activeProvider.displayName) API key →", systemImage: "arrow.up.right.square")
                        .font(.caption)
                }
                .buttonStyle(.link)
            }

            Text("No key needed — Claud-y works in Companion mode without one. Local, private, and free forever.")
                .font(.caption).foregroundStyle(.secondary)
        } header: {
            Text("API Provider").font(.headline)
        }
    }

    private var activeKeyBinding: Binding<String> {
        switch activeProvider {
        case .claude: return $claudeKeyInput
        case .openai: return $openAIKeyInput
        case .gemini: return $geminiKeyInput
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            LabeledContent("Version") {
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 44)

            Text("Made with care, for developers who code alone.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            // Links
            if let kofiURL = URL(string: "https://ko-fi.com/ealiii") {
                VStack(alignment: .leading, spacing: 5) {
                    Button { NSWorkspace.shared.open(kofiURL) } label: {
                        Label("☕  Support on Ko-fi", systemImage: "heart")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.link)
                    Text("Claud-y is free and always will be — no subscriptions, no paywalls, no ads. Support is completely optional, but every coffee directly funds new features and keeps development going. Your feedback and support genuinely shape what gets built next.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minHeight: 44)
            }

            if let githubURL = URL(string: "https://github.com/eali959/claudy") {
                Button { NSWorkspace.shared.open(githubURL) } label: {
                    Label("View on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.link)
                .frame(minHeight: 36)
            }

            // Keyboard shortcuts reference
            VStack(alignment: .leading, spacing: 0) {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.bottom, 8)
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    shortcutRow("⌘⇧Space",         "Open / close chat (global)")
                    shortcutRow("⌘ ,",            "Open Settings")
                    shortcutRow("Escape",          "Close chat")
                    shortcutRow("⌥ M",             "Toggle mute")
                    shortcutRow("⇧ ⌥ D (hold 1s)", "Start Demo Mode")
                }
                .font(.system(size: 12))
            }
            .padding(.vertical, 6)
        } header: {
            Text("About").font(.headline)
        }
    }

    @ViewBuilder
    private func shortcutRow(_ key: String, _ description: String) -> some View {
        GridRow {
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            Text(description)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Actions

    private func saveAPIKey() {
        isSaved = false
        saveError = nil
        let key = activeKeyBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try KeychainService.save(key, for: activeProvider)
            isSaved = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                isSaved = false
            }
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func testConnection() {
        testStatus = .testing
        let provider = activeProvider
        let key = activeKeyBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                switch provider {
                case .claude:
                    guard let endpoint = URL(string: "https://api.anthropic.com/v1/models") else {
                        testStatus = .fail("Invalid endpoint"); return
                    }
                    var req = URLRequest(url: endpoint)
                    req.setValue(key, forHTTPHeaderField: "x-api-key")
                    req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    let (_, res) = try await URLSession.shared.data(for: req)
                    let code = (res as? HTTPURLResponse)?.statusCode ?? 0
                    testStatus = code == 200 ? .ok("Key valid") : .fail("HTTP \(code)")

                case .openai:
                    guard let endpoint = URL(string: "https://api.openai.com/v1/models") else {
                        testStatus = .fail("Invalid endpoint"); return
                    }
                    var req = URLRequest(url: endpoint)
                    req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                    let (_, res) = try await URLSession.shared.data(for: req)
                    let code = (res as? HTTPURLResponse)?.statusCode ?? 0
                    testStatus = code == 200 ? .ok("Key valid") : .fail("HTTP \(code)")

                case .gemini:
                    let urlStr = "https://generativelanguage.googleapis.com/v1beta/models?key=\(key)"
                    guard let endpoint = URL(string: urlStr) else {
                        testStatus = .fail("Invalid endpoint"); return
                    }
                    let (_, res) = try await URLSession.shared.data(from: endpoint)
                    let code = (res as? HTTPURLResponse)?.statusCode ?? 0
                    testStatus = code == 200 ? .ok("Key valid") : .fail("HTTP \(code)")
                }
            } catch {
                testStatus = .fail(error.localizedDescription)
            }
        }
    }

    /// Ensures the persisted model ID is valid for the active provider.
    /// Resets to the provider default if a stale model from a previous provider is stored
    /// (e.g. user had Claude selected, saved "claude-haiku-4-5-20251001", then switched to OpenAI).
    private func validateSelectedModel() {
        let validModels: Set<String>
        switch activeProvider {
        case .claude:  validModels = ["claude-haiku-4-5-20251001", "claude-sonnet-4-6", "claude-3-5-haiku-20241022"]
        case .openai:  validModels = ["gpt-4o-mini", "gpt-4o"]
        case .gemini:  validModels = ["gemini-2.0-flash", "gemini-1.5-pro"]
        }
        if !validModels.contains(selectedModel) {
            selectedModel = activeProvider.defaultModel
        }
    }

    private func removeAPIKey() {
        try? KeychainService.delete(for: activeProvider)
        switch activeProvider {
        case .claude: claudeKeyInput = ""
        case .openai: openAIKeyInput = ""
        case .gemini: geminiKeyInput = ""
        }
    }
}

#Preview {
    SettingsView()
        .environment(PersonalityManager.shared)
}
