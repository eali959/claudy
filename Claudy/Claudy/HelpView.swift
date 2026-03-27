import SwiftUI
import AppKit

// MARK: - HelpView
// Presented as a popover from the ? button in the chat header and from the
// right-click context menu. Covers all major features in collapsible sections.

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(red: 0.784, green: 0.361, blue: 0.220))
                    Text("Help")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider().padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 1) {
                    helpSection("Getting Started") {
                        helpRow("What is Claud-y?",
                                "A small animated companion that lives on your screen. It reacts to what you're building, celebrates your wins, and keeps you company while you code.")
                        helpRow("Companion Mode vs API Mode",
                                "Companion mode runs entirely on your Mac - no internet needed, free forever. API mode connects to Claude AI for real conversations. Tap the mode pill in the chat header to switch.")
                        helpRow("Adding a Claude API key",
                                "Right-click Claud-y → Settings → Claude API Key. Paste your key and tap Save. Your key is stored in your Mac's Keychain and never leaves your device except to reach Anthropic directly.")
                    }

                    helpSection("Chat") {
                        helpRow("Opening the chat",
                                "Tap Claud-y once to toggle the chat, or double-tap to open it with a little celebration.")
                        helpRow("Exporting a conversation",
                                "Tap the share icon in the chat header to export as text or copy to clipboard.")
                        helpRow("Clearing history",
                                "Tap the trash icon in the chat header. This also cancels any in-progress response.")
                        helpRow("Easter eggs",
                                "There are a few. They exist. Finding them is half the fun - we won't list them here.")
                    }

                    helpSection("Personalities") {
                        helpRow("The Companion", "Warm, honest, steady. Your default coding companion.")
                        helpRow("The Chatty One", "Takes the scenic route. Enthusiastic, with excellent tangents.")
                        helpRow("The Hype Coach", "LOUD. UNCONDITIONAL. BELIEVES IN YOU COMPLETELY.")
                        helpRow("The Director", "Visionary, dramatic, swears at computers but never at you.")
                        helpRow("The Mate", "Australian energy. Deadpan. Chill. 'Yeah nah' is a complete sentence.")
                        helpRow("The Listener", "Calm, reflective, present. Asks good questions. Doesn't rush.")
                        helpRow("You Do You", "Write your own character in Settings. Fully custom persona.")
                    }

                    helpSection("Focus Timer") {
                        helpRow("Starting a timer", "Right-click Claud-y → Focus Timer, then pick a duration (15, 25, 45, 60 min, or your custom value). The badge appears above Claud-y once the session begins.")
                        helpRow("Pausing", "Tap the badge while the timer is running.")
                        helpRow("Resuming", "Tap the badge again while paused.")
                        helpRow("Resetting", "Double-tap the badge at any time to stop and reset. The badge disappears when the timer is idle.")
                        helpRow("Changing duration", "Right-click Claud-y → Focus Timer and select a different preset. Your choice takes effect on the next start.")
                    }

                    helpSection("Sound & Voice") {
                        helpRow("Sound effects",
                                "Enable in Settings → Sound. Subtle audio cues: a pop on bubbles, chime on clean builds, fanfare on wins.")
                        helpRow("Character voice",
                                "Enable in Settings → Sound → Character voice. Claud-y mumbles in short tones when speaking - like GTA dialogue. Charming in a weird way.")
                        helpRow("Volume",
                                "Controlled by the volume slider in Settings → Sound. Applies to all sounds including the character voice.")
                    }

                    helpSection("Reactions & Awareness") {
                        helpRow("What Claud-y watches",
                                "App switches (Xcode, Figma, Terminal, Zoom…), keyboard activity, clipboard content, and Xcode build events. All processing is local - nothing is logged or sent anywhere.")
                        helpRow("Controlling bubble frequency",
                                "Settings → Chattiness. Drag the slider from Quiet (every 2 minutes) to Non-stop (every 14 seconds).")
                        helpRow("Muting",
                                "Press Option+M, or right-click Claud-y → Mute. A 🔇 badge appears when muted. Unmuting shows a small reaction.")
                    }

                    helpSection("Privacy") {
                        helpRow("Companion mode", "100% local. No data leaves your Mac. No accounts, no telemetry, no analytics.")
                        helpRow("API mode", "Your messages go directly to Anthropic's API using your own key. Claud-y has no server and stores nothing.")
                        helpRow("Your API key", "Stored only in your Mac's Keychain. Never in UserDefaults, never in any file, never sent anywhere except Anthropic's API endpoint.")
                    }

                    helpSection("Support") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Claud-y is free. If it made your day better:")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)

                            Button {
                                if let url = URL(string: "https://ko-fi.com/ealiii") {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                Label("☕ Support on Ko-fi", systemImage: "heart")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(.link)

                            Button {
                                if let url = URL(string: "https://github.com/eali959/claudy") {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                Label("View on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(.link)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .frame(width: 320)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Section builder

    @ViewBuilder
    private func helpSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        // Evaluate content() eagerly so the result value (not the closure) is used inside
        // DisclosureGroup's escaping content closure, avoiding the capture-of-non-escaping error.
        let built = content()
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 0) {
                built
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)

        Divider().padding(.horizontal, 16)
    }

    @ViewBuilder
    private func helpRow(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
            Text(body)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }
}

#Preview {
    HelpView()
        .frame(width: 320)
}
