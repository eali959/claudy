import SwiftUI

// MARK: - LanguageSettingsSection

/// Settings section for selecting Claud-y's response language.
/// Applies to both companion-mode reaction pools and API-mode system prompt injection.
struct LanguageSettingsSection: View {
    // @Bindable on the @Observable singleton: the picker writes directly to
    // langManager.activeLanguage, firing its didSet (saves to UserDefaults +
    // reloads the reaction library). No local @State copy needed.
    @Bindable private var langManager = LanguageManager.shared

    var body: some View {
        Section {
            Picker("Response language", selection: $langManager.activeLanguage) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Text("\(lang.flag)  \(lang.displayName)")
                        .tag(lang)
                }
            }

            if langManager.activeLanguage != .english {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                    Text("AI responses and companion reactions will be in \(langManager.activeLanguage.displayName). API key required for chat mode.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Language", systemImage: "globe")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 0.784, green: 0.361, blue: 0.220))
        }
    }
}
