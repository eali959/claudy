import SwiftUI

struct AppearanceSettingsSection: View {
    @Binding var characterOpacity: Double
    @Binding var chatWindowOpacity: Double
    @Binding var chatFontSize: Double
    @Binding var userBubbleColor: String

    private let orange = Color(red: 0.784, green: 0.361, blue: 0.220)

    var body: some View {
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
            Label("Appearance", systemImage: "paintbrush.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 0.784, green: 0.361, blue: 0.220))
        }
    }

    @ViewBuilder
    private var sizePresetPicker: some View {
        let binding = Binding<WindowManager.SizePreset>(
            get: {
                let saved = UserDefaults.standard.string(forKey: DefaultsKeys.characterSizePreset) ?? ""
                return WindowManager.SizePreset(rawValue: saved) ?? .medium
            },
            set: { UserDefaults.standard.set($0.rawValue, forKey: DefaultsKeys.characterSizePreset) }
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
}
