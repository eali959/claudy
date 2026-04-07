import SwiftUI

struct SoundSettingsSection: View {
    @Binding var soundEffectsEnabled: Bool
    @Binding var soundVolume: Double
    @Binding var characterVoiceEnabled: Bool

    var body: some View {
        Section {
            Toggle("Enable sound effects", isOn: $soundEffectsEnabled)
                .frame(minHeight: 44)
            Text("Subtle audio feedback: a pop on speech bubbles, chime on clean builds, fanfare on wins, and a soft tone on Pomodoro completion.")
                .font(.caption).foregroundStyle(.secondary)

            if soundEffectsEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Volume")
                        Spacer()
                        Text("\(Int(soundVolume * 100))%")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .monospacedDigit()
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "speaker").font(.caption).foregroundStyle(.secondary)
                        Slider(value: $soundVolume, in: 0.0...1.0)
                        Image(systemName: "speaker.wave.3").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: 44)

                Toggle("Character voice", isOn: $characterVoiceEnabled)
                    .frame(minHeight: 44)
                Text("Short mumble tones when Claud-y speaks - GTA-style garbled but charming. Uses the same volume setting.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text("Sound").font(.headline)
        }
    }
}
