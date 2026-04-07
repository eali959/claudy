import SwiftUI

struct TamagotchiSettingsSection: View {
    @AppStorage(DefaultsKeys.tamagotchiOverlayEnabled) private var overlayEnabled = false
    @AppStorage(DefaultsKeys.tamagotchiNudgeIntensity) private var nudgeIntensity = "normal"

    var body: some View {
        Section {
            Toggle("Show stat overlay", isOn: $overlayEnabled)
                .frame(minHeight: 44)

            Picker("Nudge intensity", selection: $nudgeIntensity) {
                Text("Silent").tag("silent")
                Text("Subtle (bubble only)").tag("subtle")
                Text("Normal (animation + bubble)").tag("normal")
            }
            .frame(minHeight: 44)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("About Tamagotchi mode")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text("Claud-y has hunger, happiness, and energy stats that slowly change over time. Feed, play with, or rest him using the stat overlay below the character (or via the right-click menu). Stats are saved locally — no cloud sync, no telemetry.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.15), lineWidth: 0.5))
            .padding(.top, 2)

        } header: {
            Label("Tamagotchi", systemImage: "heart.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 0.784, green: 0.361, blue: 0.220))
        }
    }
}
