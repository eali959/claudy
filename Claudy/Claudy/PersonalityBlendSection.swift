import SwiftUI

/// Settings section for personality blending (BLEND-01).
/// Shows only when a personality other than Custom is active.
/// Slider is locked during API streaming (BLEND-04).
struct PersonalityBlendSection: View {
    @State private var manager = PersonalityManager.shared

    var body: some View {
        Section(header: Label("Personality Blend", systemImage: "slider.horizontal.3").font(.headline)) {
            Toggle("Enable Blend", isOn: $manager.blendEnabled)

            if manager.blendEnabled {
                // Secondary personality picker (can't pick same as primary) (BLEND-05)
                Picker("Secondary Personality", selection: $manager.secondaryMode) {
                    ForEach(PersonalityMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .disabled(manager.isStreaming)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(manager.currentMode.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(manager.secondaryMode.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $manager.blendRatio, in: 0...1, step: 0.05)
                        .disabled(manager.isStreaming || manager.secondaryMode == manager.currentMode)
                        .tint(.orange)

                    if manager.isStreaming {
                        Text("Blend locked while streaming")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    } else if manager.secondaryMode == manager.currentMode {
                        Text("Choose a different secondary personality")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        let pct = Int((manager.blendRatio * 100).rounded())
                        Text("\(100 - pct)% \(manager.currentMode.displayName) · \(pct)% \(manager.secondaryMode.displayName)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Blend combines two personalities into one unified voice. Works in both Companion and API mode.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
