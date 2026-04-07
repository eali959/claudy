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

    // MARK: - Provider / Model
    static let selectedProvider         = "SelectedProvider"
    static let selectedModel            = "SelectedModel"
    static let useComplexModel          = "UseComplexModel"

    // MARK: - Sound
    static let soundEffectsEnabled      = "SoundEffectsEnabled"
    static let soundVolume              = "SoundVolume"
    static let characterVoiceEnabled    = "CharacterVoiceEnabled"
    static let isMuted                  = "IsMuted"

    // MARK: - Personality
    static let personalityMode          = "PersonalityMode"
    static let customPersonaText        = "CustomPersonaText"

    // MARK: - Behaviour / Chattiness
    static let chattinessLevel          = "ChattinessLevel"

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

    // MARK: - Scratchpad / Notes
    static let scratchpadNotes          = "ScratchpadNotes"

    // MARK: - Alarms / Reminders
    static let alarmReminderItems       = "ClaudyReminders"

    // MARK: - Daily wrap-up
    static let wrapUpHour               = "WrapUpHour"
    static let lastWrapUpDate           = "LastWrapUpDate"

    // MARK: - Tamagotchi
    static let tamagotchiOverlayEnabled = "TamagotchiOverlayEnabled"
    static let tamagotchiNudgeIntensity = "TamagotchiNudgeIntensity"  // "silent" | "subtle" | "normal"

    // MARK: - Personality Blending
    static let blendEnabled      = "BlendEnabled"
    static let blendSecondaryMode = "BlendSecondaryMode"
    static let blendRatio        = "BlendRatio"  // Int 0–100

    // MARK: - Walk
    static let walkEnabled = "WalkEnabled"

    // MARK: - Accessories
    static let activeAccessory = "ActiveAccessory"  // CharacterAccessory.rawValue

    // MARK: - Chat UX
    static let renderMarkdown       = "RenderMarkdown"
    static let systemPromptPresets  = "SystemPromptPresets"  // JSON [SystemPromptPreset]

    // MARK: - Language
    static let activeLanguage = "ActiveLanguage"  // AppLanguage.rawValue
}
