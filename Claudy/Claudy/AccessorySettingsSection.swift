import SwiftUI

/// Settings section for choosing Claud-y's active accessory (ACC-03).
struct AccessorySettingsSection: View {
    @State private var selected: CharacterAccessory = CharacterAccessory.active

    var body: some View {
        Section(header: Label("Accessories", systemImage: "star.circle.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(red: 0.784, green: 0.361, blue: 0.220))) {
            Picker("Active Accessory", selection: $selected) {
                ForEach(CharacterAccessory.allCases, id: \.self) { acc in
                    Label(acc.displayName, systemImage: acc.icon).tag(acc)
                }
            }
            .onChange(of: selected) { _, newValue in
                CharacterAccessory.active = newValue
            }

            Text("Accessories are drawn directly on Claud-y. Changes take effect immediately.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
