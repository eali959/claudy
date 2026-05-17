import SwiftUI
import AppKit

struct SettingsView: View {
    // MARK: - Appearance
    @AppStorage(DefaultsKeys.chatFontSize)           private var chatFontSize: Double = 14
    @AppStorage(DefaultsKeys.characterOpacity)       private var characterOpacity: Double = 1.0
    @AppStorage(DefaultsKeys.chatWindowOpacity)      private var chatWindowOpacity: Double = 1.0
    @AppStorage(DefaultsKeys.userBubbleColor)        private var userBubbleColor: String = "orange"

    // MARK: - Provider + model
    @AppStorage(DefaultsKeys.selectedProvider)       private var selectedProviderRaw: String = "claude"
    @AppStorage(DefaultsKeys.selectedModel)          private var selectedModel: String = ClaudeAPIService.defaultModel
    @AppStorage(DefaultsKeys.useComplexModel)        private var useComplexModel = false

    // MARK: - Sound
    @AppStorage(DefaultsKeys.soundEffectsEnabled)    private var soundEffectsEnabled = false
    @AppStorage(DefaultsKeys.soundVolume)            private var soundVolume: Double = 0.7
    @AppStorage(DefaultsKeys.characterVoiceEnabled)  private var characterVoiceEnabled = false

    // MARK: - Focus Timer
    @AppStorage(DefaultsKeys.pomodoroPreset)         private var pomodoroPresetRaw: Int = PomodoroPreset.classic.rawValue
    @AppStorage(DefaultsKeys.pomodoroCustomMinutes)  private var pomodoroCustomMinutes: Int = 25
    @AppStorage(DefaultsKeys.timerBadgeScale)        private var timerBadgeScale: Double = 1.0

    // MARK: - Chattiness
    @AppStorage(DefaultsKeys.chattinessLevel)        private var chattinessLevel: Int = 3

    // MARK: - API Key state
    @State private var claudeKeyInput: String = ""
    @State private var openAIKeyInput: String = ""
    @State private var geminiKeyInput: String = ""
    @State private var deepSeekKeyInput: String = ""
    @State private var isSaved = false
    @State private var saveError: String?
    @State private var showKey = false
    @State private var testStatus: TestStatus = .idle
    @State private var showRemoveConfirm = false

    // MARK: - Quick launch state
    @State private var quickShortcuts: [QuickLaunchManager.Shortcut] = []
    @State private var newShortcutName = ""
    @State private var newShortcutBundleID = ""
    @State private var newShortcutKey = ""

    enum TestStatus {
        case idle, testing, ok(String), fail(String)
    }

    @State private var searchQuery: String = ""

    /// Section keywords used to filter the Settings list when the user
    /// types in the search bar.  Each section reports the keywords that
    /// describe its content; if the query matches NONE of them the
    /// section is hidden.  Empty query shows everything.
    private let sectionKeywords: [String: [String]] = [
        "general":      ["general", "provider", "ai", "model", "complex"],
        "appearance":   ["appearance", "opacity", "font", "colour", "color", "bubble"],
        "render":       ["render", "3d", "2d", "mode"],
        "behaviour":    ["behaviour", "behavior", "personality", "mode", "study", "dev", "work", "dance"],
        "provider":     ["api", "key", "claude", "openai", "gpt", "gemini", "deepseek", "ollama", "lm studio", "local"],
        "sound":        ["sound", "audio", "volume", "effects", "mute", "speaker", "voice"],
        "voicemode":    ["voice", "talk", "mic", "tts", "speech", "persona", "auto-speak"],
        "focus":        ["focus", "pomodoro", "timer", "badge", "chattiness"],
        "language":     ["language", "locale", "translate"],
        "personality":  ["personality", "blend", "weight"],
        "chat":         ["chat", "history", "stream"],
        "tamagotchi":   ["tamagotchi", "hunger", "energy", "happiness", "feed", "play"],
        "accessory":    ["accessory", "glasses", "hat", "cap"],
        "quicklaunch":  ["quick", "launch", "shortcut", "hotkey"],
        "about":        ["about", "version", "build", "credit"]
    ]

    private func sectionMatches(_ key: String) -> Bool {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return true }
        guard let words = sectionKeywords[key] else { return true }
        return words.contains { $0.contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // V4 polish — search bar at the top of Settings
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search settings…", text: $searchQuery)
                    .textFieldStyle(.plain)
                if !searchQuery.isEmpty {
                    Button { searchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .overlay(Divider(), alignment: .bottom)

            Form {
                if sectionMatches("general") {
                GeneralSettingsSection(
                    selectedProviderRaw: $selectedProviderRaw,
                    selectedModel: $selectedModel,
                    useComplexModel: $useComplexModel
                )
                }

                if sectionMatches("appearance") {
                    AppearanceSettingsSection(
                        characterOpacity: $characterOpacity,
                        chatWindowOpacity: $chatWindowOpacity,
                        chatFontSize: $chatFontSize,
                        userBubbleColor: $userBubbleColor
                    )
                }

                if sectionMatches("render") { RenderModeToggle() }
                if sectionMatches("behaviour") { BehaviourSettingsSection() }

                // V5.11 — Privacy & Storage section (per-data-type save toggles)
                if sectionMatches("privacy") || sectionMatches("storage") || sectionMatches("save") {
                    PrivacyStorageSection()
                }

                if sectionMatches("provider") {
                    ProviderSettingsSection(
                        selectedProviderRaw: $selectedProviderRaw,
                        claudeKeyInput: $claudeKeyInput,
                        openAIKeyInput: $openAIKeyInput,
                        geminiKeyInput: $geminiKeyInput,
                        deepSeekKeyInput: $deepSeekKeyInput,
                        isSaved: $isSaved,
                        saveError: $saveError,
                        showKey: $showKey,
                        testStatus: $testStatus,
                        showRemoveConfirm: $showRemoveConfirm
                    )
                }

                if sectionMatches("sound") {
                    SoundSettingsSection(
                        soundEffectsEnabled: $soundEffectsEnabled,
                        soundVolume: $soundVolume,
                        characterVoiceEnabled: $characterVoiceEnabled
                    )
                }

                if sectionMatches("voicemode") { VoiceModeSettingsSection() }

                if sectionMatches("focus") {
                    FocusTimerSettingsSection(
                        pomodoroPresetRaw: $pomodoroPresetRaw,
                        pomodoroCustomMinutes: $pomodoroCustomMinutes,
                        timerBadgeScale: $timerBadgeScale,
                        chattinessLevel: $chattinessLevel
                    )
                }

                if sectionMatches("language") { LanguageSettingsSection() }
                if sectionMatches("personality") { PersonalityBlendSection() }
                if sectionMatches("chat") { ChatSettingsSection() }
                if sectionMatches("tamagotchi") { TamagotchiSettingsSection() }
                if sectionMatches("accessory") { AccessorySettingsSection() }

                if sectionMatches("quicklaunch") {
                    QuickLaunchSettingsSection(
                        quickShortcuts: $quickShortcuts,
                        newShortcutName: $newShortcutName,
                        newShortcutBundleID: $newShortcutBundleID,
                        newShortcutKey: $newShortcutKey
                    )
                }

                if sectionMatches("about") { AboutSettingsSection() }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 540, idealWidth: 560, minHeight: 500)
        .confirmationDialog("Remove API Key?", isPresented: $showRemoveConfirm, titleVisibility: .visible) {
            Button("Remove Key", role: .destructive) { removeAPIKey() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your API key will be deleted from the Keychain. You can add it again at any time.")
        }
        .onAppear {
            quickShortcuts = QuickLaunchManager.shared.shortcuts
            validateSelectedModel()
        }
    }

    // MARK: - Actions

    private var activeProvider: APIProvider {
        APIProvider(rawValue: selectedProviderRaw) ?? .claude
    }

    private func validateSelectedModel() {
        let validModels: Set<String>
        switch activeProvider {
        case .claude:
            validModels = ["claude-haiku-4-5-20251001", "claude-sonnet-4-6", "claude-3-5-haiku-20241022"]
        case .openai:
            validModels = ["gpt-4o-mini", "gpt-4o"]
        case .gemini:
            validModels = ["gemini-2.0-flash", "gemini-1.5-pro"]
        case .deepseek:
            validModels = ["deepseek-chat", "deepseek-reasoner"]
        case .ollama, .lmStudio:
            return
        }
        if !validModels.contains(selectedModel) {
            selectedModel = activeProvider.defaultModel
        }
    }

    private func removeAPIKey() {
        try? KeychainService.delete(for: activeProvider)
        switch activeProvider {
        case .claude:   claudeKeyInput = ""
        case .openai:   openAIKeyInput = ""
        case .gemini:   geminiKeyInput = ""
        case .deepseek: deepSeekKeyInput = ""
        case .ollama, .lmStudio:
            break
        }
    }
}

// MARK: - Render mode (2D / 3D)

private struct RenderModeToggle: View {
    @AppStorage(DefaultsKeys.renderMode3D) private var renderMode3D: Bool = true

    var body: some View {
        Section("Character render") {
            Toggle("Use 3D Claud-y", isOn: $renderMode3D)
        }
    }
}

#Preview {
    SettingsView()
        .environment(PersonalityManager.shared)
}
