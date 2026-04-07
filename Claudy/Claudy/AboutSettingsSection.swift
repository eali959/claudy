import SwiftUI

struct AboutSettingsSection: View {
    var body: some View {
        Section {
            LabeledContent("Version") {
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 44)

            Text("Made with care, for developers who code alone.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if let kofiURL = URL(string: "https://ko-fi.com/ealiii") {
                VStack(alignment: .leading, spacing: 5) {
                    Button { NSWorkspace.shared.open(kofiURL) } label: {
                        Label("☕  Support on Ko-fi", systemImage: "heart")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.link)
                    Text("Claud-y is free and always will be — no subscriptions, no paywalls, no ads. Support is completely optional, but every coffee directly funds new features and keeps development going. Your feedback and support genuinely shape what gets built next.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minHeight: 44)
            }

            if let githubURL = URL(string: "https://github.com/eali959/claudy") {
                Button { NSWorkspace.shared.open(githubURL) } label: {
                    Label("View on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.link)
                .frame(minHeight: 36)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.bottom, 8)
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    shortcutRow("⌘⇧Space",         "Open / close chat (global)")
                    shortcutRow("⌘ ,",            "Open Settings")
                    shortcutRow("Escape",          "Close chat")
                    shortcutRow("⌥ M",             "Toggle mute")
                    shortcutRow("⇧ ⌥ D (hold 1s)", "Start Demo Mode")
                }
                .font(.system(size: 12))
            }
            .padding(.vertical, 6)
        } header: {
            Text("About").font(.headline)
        }
    }

    @ViewBuilder
    private func shortcutRow(_ key: String, _ description: String) -> some View {
        GridRow {
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            Text(description)
                .foregroundStyle(.primary)
        }
    }
}
