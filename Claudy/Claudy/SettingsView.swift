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

    // MARK: - API Key state (per-provider)
    @State private var claudeKeyInput: String = ""
    @State private var openAIKeyInput: String = ""
    @State private var geminiKeyInput: String = ""
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

    var body: some View {
        Form {
            GeneralSettingsSection(
                selectedProviderRaw: $selectedProviderRaw,
                selectedModel: $selectedModel,
                useComplexModel: $useComplexModel
            )
            AppearanceSettingsSection(
                characterOpacity: $characterOpacity,
                chatWindowOpacity: $chatWindowOpacity,
                chatFontSize: $chatFontSize,
                userBubbleColor: $userBubbleColor
            )
            ProviderSettingsSection(
                selectedProviderRaw: $selectedProviderRaw,
                claudeKeyInput: $claudeKeyInput,
                openAIKeyInput: $openAIKeyInput,
                geminiKeyInput: $geminiKeyInput,
                isSaved: $isSaved,
                saveError: $saveError,
                showKey: $showKey,
                testStatus: $testStatus,
                showRemoveConfirm: $showRemoveConfirm
            )
            SoundSettingsSection(
                soundEffectsEnabled: $soundEffectsEnabled,
                soundVolume: $soundVolume,
                characterVoiceEnabled: $characterVoiceEnabled
            )
            FocusTimerSettingsSection(
                pomodoroPresetRaw: $pomodoroPresetRaw,
                pomodoroCustomMinutes: $pomodoroCustomMinutes,
                timerBadgeScale: $timerBadgeScale,
                chattinessLevel: $chattinessLevel
            )
            QuickLaunchSettingsSection(
                quickShortcuts: $quickShortcuts,
                newShortcutName: $newShortcutName,
                newShortcutBundleID: $newShortcutBundleID,
                newShortcutKey: $newShortcutKey
            )
            AboutSettingsSection()
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

    // MARK: - Actions

    private var activeProvider: APIProvider {
        APIProvider(rawValue: selectedProviderRaw) ?? .claude
    }

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
