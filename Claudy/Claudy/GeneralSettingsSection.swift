import SwiftUI

struct GeneralSettingsSection: View {
    @Binding var selectedProviderRaw: String
    @Binding var selectedModel: String
    @Binding var useComplexModel: Bool
    @Environment(PersonalityManager.self) private var personalityManager

    private var activeProvider: APIProvider {
        APIProvider(rawValue: selectedProviderRaw) ?? .claude
    }

    var body: some View {
        @Bindable var pm = personalityManager
        Section {
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
            Label("General", systemImage: "gearshape.fill").font(.headline)
        }
    }
}
