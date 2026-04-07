import SwiftUI

struct FocusTimerSettingsSection: View {
    @Binding var pomodoroPresetRaw: Int
    @Binding var pomodoroCustomMinutes: Int
    @Binding var timerBadgeScale: Double
    @Binding var chattinessLevel: Int

    var body: some View {
        Section {
            Picker("Duration", selection: Binding(
                get: { PomodoroPreset(rawValue: pomodoroPresetRaw) ?? .classic },
                set: { pomodoroPresetRaw = $0.rawValue }
            )) {
                ForEach(PomodoroPreset.allCases, id: \.self) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .frame(minHeight: 44)

            if PomodoroPreset(rawValue: pomodoroPresetRaw) == .custom {
                HStack {
                    Text("Custom duration")
                    Spacer()
                    Stepper("\(pomodoroCustomMinutes) min",
                            value: $pomodoroCustomMinutes,
                            in: 5...120,
                            step: 5)
                }
                .frame(minHeight: 44)
            }

            Text("Timer duration - the next session will use this setting. Changing this mid-session has no effect.")
                .font(.caption).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Badge size")
                    Spacer()
                    Text("\(Int(timerBadgeScale * 100))%")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .monospacedDigit()
                }
                HStack(spacing: 8) {
                    Text("70%").font(.caption).foregroundStyle(.tertiary)
                    Slider(value: $timerBadgeScale, in: 0.7...1.6, step: 0.05)
                    Text("160%").font(.caption).foregroundStyle(.tertiary)
                }
            }
            .frame(minHeight: 44)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Chattiness")
                    Spacer()
                    Text(chattinessLabel)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                Slider(value: Binding(
                    get: { Double(chattinessLevel) },
                    set: { chattinessLevel = Int($0.rounded()) }
                ), in: 1...5, step: 1)
                Text(chattinessDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 44)
        } header: {
            Text("Focus Tools").font(.headline)
        }
    }

    private var chattinessLabel: String {
        switch chattinessLevel {
        case 1: return "Quiet"
        case 2: return "Calm"
        case 3: return "Balanced"
        case 4: return "Chatty"
        case 5: return "Non-stop"
        default: return "Balanced"
        }
    }

    private var chattinessDescription: String {
        switch chattinessLevel {
        case 1: return "A bubble every ~2 minutes"
        case 2: return "A bubble every ~80 seconds"
        case 3: return "A bubble every ~45 seconds (default)"
        case 4: return "A bubble every ~27 seconds"
        case 5: return "A bubble every ~14 seconds"
        default: return "A bubble every ~45 seconds"
        }
    }
}
