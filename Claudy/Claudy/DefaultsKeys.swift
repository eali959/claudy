import Foundation

/// Central registry of all UserDefaults keys used in Claud-y.
/// Use these constants in @AppStorage and UserDefaults.standard calls.
/// IMPORTANT: String values must match exactly — changing a string value
/// will silently reset that preference for existing users.
enum DefaultsKeys {
    // MARK: - Chat
    static let chatFontSize             = "ChatFontSize"
    static let chatWindowOpacity        = "ChatWindowOpacity"
    static let userBubbleColor          = "UserBubbleColor"
    static let chatMode                 = "chatMode"
    static let claudyChatHeight         = "ClaudyChatHeight"
    
    // MARK: - Appearance
    static let characterOpacity         = "CharacterOpacity"
    static let characterSizePreset      = "CharacterSizePreset"
    static let characterWindowOrigin    = "CharacterWindowOrigin"
    static let use3DMode                = "Use3DMode"           // v4.0 addition
    static let renderMode3D             = "Use3DMode"           // alias — must point at same key as use3DMode so Settings toggle syncs with renderer
    static let seasonalThemesEnabled    = "SeasonalThemesEnabled" // v4.0 addition
    
    // MARK: - Provider / Model
    static let selectedProvider         = "SelectedProvider"
    static let selectedModel            = "SelectedModel"
    static let useComplexModel          = "UseComplexModel"
    static let ollamaModel              = "OllamaModel"         // v4.0 addition
    static let lmStudioModel            = "LmStudioModel"       // v4.0 addition
    
    // MARK: - Sound
    static let soundEffectsEnabled      = "SoundEffectsEnabled"
    static let soundVolume              = "SoundVolume"
    static let characterVoiceEnabled    = "CharacterVoiceEnabled"
    static let isMuted                  = "IsMuted"
    /// VoicePersona rawValue — drives TTS in Voice Mode + chat playback.
    static let voicePersona             = "VoicePersona"
    /// Auto-speak assistant replies in Voice Mode chat.
    static let voiceAutoSpeak           = "VoiceAutoSpeak"
    
    // MARK: - Personality
    static let personalityMode          = "PersonalityMode"
    static let customPersonaText        = "CustomPersonaText"
    
    // MARK: - Behaviour / Chattiness
    static let chattinessLevel          = "ChattinessLevel"
    static let reactToActiveApp         = "ReactToActiveApp"    // v4.0 addition
    
    // MARK: - Pomodoro / Focus
    static let pomodoroPreset           = "PomodoroPreset"
    static let pomodoroCustomMinutes    = "PomodoroCustomMinutes"
    static let timerBadgeScale          = "TimerBadgeScale"
    static let focusStats               = "FocusStats"
    
    // MARK: - Streak
    static let dailySessionDates        = "DailySessionDates"
    static let lastStreakShownDate      = "LastStreakShownDate"
    
    // MARK: - Onboarding / First launch
    static let onboardingComplete       = "onboardingComplete"
    static let firstLaunchDate          = "FirstLaunchDate"
    static let keychainExplainerShown   = "keychainExplainerShown"
    
    // MARK: - Global hotkey
    static let globalHotkeyEnabled      = "GlobalHotkeyEnabled"
    // V5.10 — Keyboard reactions opt-in (typing-burst, undo-streak, caps-lock).
    // Defaults OFF for new installs because enabling triggers the macOS
    // Input Monitoring permission prompt — should only fire on user opt-in.
    static let keyboardReactionsEnabled = "KeyboardReactionsEnabled"
    // V5.10 — Demo keyboard shortcuts opt-in (Shift+Option+D / Shift+Option+V
    // hold-to-trigger).  Same Input-Monitoring concern as above.
    static let demoShortcutsEnabled     = "DemoShortcutsEnabled"

    // MARK: - V5.11 Privacy & Storage (per-data-type opt-ins)
    // All default to FALSE except where the data was already persisted.
    // Each toggle gives the user explicit control over what Claud-y saves to disk.
    static let saveChatHistory          = "SaveChatHistory"            // off
    static let saveScratchpadNotes      = "SaveScratchpadNotes"        // on  (was always-on before)
    static let saveTamagotchiState      = "SaveTamagotchiState"        // on  (was always-on before)
    static let saveFocusStats           = "SaveFocusStats"             // on  (was always-on before)
    static let saveAlarmsReminders      = "SaveAlarmsReminders"        // on  (was always-on before)

    // V5.11 — Weather opt-in.  Triggers a macOS Location permission prompt
    // 90 s after launch in V5.10 — defaulted OFF in V5.11 so new users
    // are not surprised.  User can enable via Settings → Behaviour.
    static let weatherCommentsEnabled   = "WeatherCommentsEnabled"     // off
    
    // MARK: - Scratchpad / Notes
    static let scratchpadNotes          = "ScratchpadNotes"
    
    // MARK: - Alarms / Reminders
    static let alarmReminderItems       = "ClaudyReminders"
    
    // MARK: - Daily wrap-up
    static let wrapUpHour               = "WrapUpHour"
    static let lastWrapUpDate           = "LastWrapUpDate"
    
    // MARK: - Tamagotchi
    static let tamagotchiOverlayEnabled = "TamagotchiOverlayEnabled"
    static let tamagotchiNudgeIntensity = "TamagotchiNudgeIntensity"
    
    // MARK: - Personality Blending
    static let blendEnabled             = "BlendEnabled"
    static let blendSecondaryMode       = "BlendSecondaryMode"
    static let blendRatio               = "BlendRatio"
    
    // MARK: - Walk
    static let walkEnabled              = "WalkEnabled"
    
    // MARK: - Accessories
    static let activeAccessory          = "ActiveAccessory"
    
    // MARK: - Chat UX
    static let renderMarkdown           = "RenderMarkdown"
    static let systemPromptPresets      = "SystemPromptPresets"
    
    // MARK: - Language
    static let activeLanguage           = "ActiveLanguage"
    
    // MARK: - Music / BPM Reactor (v4.0)
    static let reactToMusicEnergy       = "ReactToMusicEnergy"

    // MARK: - Care Score (v4.0)
    static let careScoreRolling7        = "CareScoreRolling7"
}
