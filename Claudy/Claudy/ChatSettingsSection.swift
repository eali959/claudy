import SwiftUI

/// Settings section for Chat UX options (CHAT-03/04/05).
/// Uses @AppStorage directly so it works from the standalone SettingsView window (no ChatViewModel dependency).
struct ChatSettingsSection: View {
    @AppStorage(DefaultsKeys.renderMarkdown) private var renderMarkdown: Bool = true

    @State private var presets: [SystemPromptPreset] = []
    @State private var newPresetName = ""
    @State private var newPresetPrompt = ""
    @State private var showAddPreset = false

    // MARK: - Preset model (local copy; matches ChatViewModel.SystemPromptPreset)

    struct SystemPromptPreset: Codable, Identifiable {
        let id: UUID
        var name: String
        var prompt: String
        init(name: String, prompt: String) {
            self.id = UUID()
            self.name = name
            self.prompt = prompt
        }
    }

    var body: some View {
        Section(header: Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(red: 0.784, green: 0.361, blue: 0.220))) {

            // CHAT-05: Markdown rendering toggle
            Toggle("Render Markdown in responses", isOn: $renderMarkdown)

            // CHAT-04: System prompt presets
            if !presets.isEmpty {
                DisclosureGroup("System Prompt Presets (\(presets.count))") {
                    ForEach(presets) { preset in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name).font(.body)
                                Text(preset.prompt)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Button {
                                presets.removeAll { $0.id == preset.id }
                                savePresets()
                            } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Button {
                showAddPreset = true
            } label: {
                Label("Add System Prompt Preset…", systemImage: "plus.circle")
            }

            Text("Presets let you quickly inject a custom instruction into any chat session. Saved locally, never sent anywhere on their own.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear { loadPresets() }
        .sheet(isPresented: $showAddPreset) { addPresetSheet }
    }

    // MARK: - Persistence

    private func loadPresets() {
        guard let data = UserDefaults.standard.data(forKey: DefaultsKeys.systemPromptPresets),
              let decoded = try? JSONDecoder().decode([SystemPromptPreset].self, from: data) else { return }
        presets = decoded
    }

    private func savePresets() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: DefaultsKeys.systemPromptPresets)
        }
    }

    // MARK: - Add preset sheet

    private var addPresetSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New System Prompt Preset")
                .font(.headline)

            TextField("Name (e.g. \"Be concise\")", text: $newPresetName)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 4) {
                Text("Prompt text").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $newPresetPrompt)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 100)
                    .border(Color.secondary.opacity(0.3))
            }

            HStack {
                Button("Cancel") {
                    showAddPreset = false
                    newPresetName = ""
                    newPresetPrompt = ""
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    let preset = SystemPromptPreset(
                        name: newPresetName.isEmpty ? "Preset" : newPresetName,
                        prompt: newPresetPrompt
                    )
                    presets.append(preset)
                    savePresets()
                    showAddPreset = false
                    newPresetName = ""
                    newPresetPrompt = ""
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newPresetPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 380, minHeight: 260)
    }
}
