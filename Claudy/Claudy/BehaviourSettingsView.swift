import SwiftUI

// MARK: - BehaviourSettingsSection (Section 11)
//
// New toggles for v4.0 behaviour features.
// Sits inside the main SettingsView Form.

struct BehaviourSettingsSection: View {

    @AppStorage(DefaultsKeys.reactToActiveApp)      private var reactToActiveApp: Bool = false
    @AppStorage(DefaultsKeys.seasonalThemesEnabled) private var seasonalThemes: Bool = true
    @AppStorage(DefaultsKeys.reactToMusicEnergy)    private var reactToMusicEnergy: Bool = true
    // V5.11 — opt-in weather comments (location permission required).
    @AppStorage(DefaultsKeys.weatherCommentsEnabled) private var weatherComments: Bool = false

    // Detect whether Spotify is connected (key existence check)
    private var spotifyConnected: Bool {
        UserDefaults.standard.string(forKey: "SpotifyAccessToken") != nil
    }

    var body: some View {
        Section {
            Toggle(isOn: $reactToActiveApp) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("React to active app")
                    Text("Suggest a Focus Mode when you switch to Xcode, Zoom, etc.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $seasonalThemes) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Seasonal themes")
                    Text("Time-of-day tints and seasonal particle effects.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if spotifyConnected {
                Toggle(isOn: $reactToMusicEnergy) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("React to music energy")
                        Text("Animation speed and dance bursts match the current track's BPM.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            // V5.11 — opt-in weather comments (location permission)
            Toggle(isOn: $weatherComments) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weather comments")
                    Text("Claud-y occasionally references the weather. Requires Location permission. Restart Claud-y after toggling.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Behaviour", systemImage: "wand.and.sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 0.784, green: 0.361, blue: 0.220))
        }
    }
}
