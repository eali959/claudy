import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(PersonalityManager.self) private var personalityManager

    // Chat / Appearance
    @AppStorage("ChatFontSize")           private var chatFontSize: Double = 14
    @AppStorage("CharacterOpacity")       private var characterOpacity: Double = 1.0
    @AppStorage("ChatWindowOpacity")      private var chatWindowOpacity: Double = 1.0
    @AppStorage("UserBubbleColor")        private var userBubbleColor: String = "orange"

    // Model
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

    // API Key state
    @State private var apiKeyInput: String = ""
    @State private var isSaved = false
    @State private var saveError: String?
    @State private var showKey = false
    @State private var testStatus: TestStatus = .idle
    @State private var showRemoveConfirm = false

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
            apiKeyInput = (try? KeychainService.load()) ?? ""
            quickShortcuts = QuickLaunchManager.shared.shortcuts
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
                Text("Haiku 4.5 (fast)").tag("claude-haiku-4-5-20251001")
                Text("Sonnet 4.6 (smart)").tag("claude-sonnet-4-6")
                Text("Haiku 3.5 (fallback)").tag("claude-3-5-haiku-20241022")
            }
            .frame(minHeight: 44)

            Toggle("Use Opus for complex tasks", isOn: $useComplexModel)
                .frame(minHeight: 44)
            Text("When enabled, long tasks use claude-opus-4-6 (4096 tokens). Uses more API credits.")
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
            Text("Focus Timer").font(.headline)
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

    // MARK: - API Key

    private var apiKeySection: some View {
        Section {
            HStack {
                Group {
                    if showKey {
                        TextField("sk-ant-…", text: $apiKeyInput)
                    } else {
                        SecureField("sk-ant-…", text: $apiKeyInput)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

                Button { showKey.toggle() } label: {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
            }
            .frame(minHeight: 44)

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)
                Text("Your key is stored in your Mac's Keychain and only leaves your device to reach Anthropic's API directly. Claud-y collects no data, stores no history, and has no telemetry.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)

            HStack {
                Button("Save Key") { saveAPIKey() }
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Test") { testConnection() }
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)

                switch testStatus {
                case .idle:     EmptyView()
                case .testing:  ProgressView().scaleEffect(0.7)
                case .ok(let msg):
                    Label(msg, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green).font(.caption)
                case .fail(let msg):
                    Label(msg, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red).font(.caption)
                }

                if isSaved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green).font(.caption)
                }
                if let err = saveError {
                    Label(err, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red).font(.caption)
                }

                Spacer()

                Button("Remove Key", role: .destructive) {
                    showRemoveConfirm = true
                }
                .foregroundStyle(.red)
            }
            .frame(minHeight: 44)

            Text("Without a key, Claud-y works in Companion mode - local, private, free forever.")
                .font(.caption).foregroundStyle(.secondary)
        } header: {
            Text("API Key").font(.headline)
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
                Button { NSWorkspace.shared.open(kofiURL) } label: {
                    Label("☕  Support on Ko-fi", systemImage: "heart")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.link)
                .frame(minHeight: 36)
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
                    shortcutRow("⌘ ,",           "Open Settings")
                    shortcutRow("Escape",         "Close chat")
                    shortcutRow("⌥ M",            "Toggle mute")
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
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try KeychainService.save(key)
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
        Task {
            do {
                let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let endpoint = URL(string: "https://api.anthropic.com/v1/models") else {
                    testStatus = .fail("Invalid endpoint URL")
                    return
                }
                var request = URLRequest(url: endpoint)
                request.setValue(key, forHTTPHeaderField: "x-api-key")
                request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                let (_, response) = try await URLSession.shared.data(for: request)
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                testStatus = code == 200 ? .ok("Key valid") : .fail("HTTP \(code)")
            } catch {
                testStatus = .fail(error.localizedDescription)
            }
        }
    }

    private func removeAPIKey() {
        try? KeychainService.delete()
        apiKeyInput = ""
    }
}

#Preview {
    SettingsView()
        .environment(PersonalityManager.shared)
}
