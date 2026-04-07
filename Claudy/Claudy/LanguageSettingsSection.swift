import SwiftUI

// MARK: - LanguageSettingsSection

/// Settings section for selecting Claud-y's response language.
/// Applies to both companion-mode reaction pools and API-mode system prompt injection.
struct LanguageSettingsSection: View {
    @State private var activeLanguage: AppLanguage = LanguageManager.shared.activeLanguage

    var body: some View {
        Section {
            Picker("Response language", selection: $activeLanguage) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    HStack(spacing: 6) {
                        Text(lang.flag)
                        Text(lang.displayName)
                    }
                    .tag(lang)
                }
            }
            .onChange(of: activeLanguage) { _, newValue in
                LanguageManager.shared.activeLanguage = newValue
            }

            if activeLanguage != .english {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                    Text("AI responses and companion reactions will be in \(activeLanguage.displayName). API key required for chat mode.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Language", systemImage: "globe").font(.headline)
        }
    }
}
