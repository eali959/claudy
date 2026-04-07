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
                                "A small animated companion that lives on your screen. It reacts to what you're building, celebrates your wins, and keeps you company while you work.")
                        helpRow("Companion Mode vs API Mode",
                                "Companion mode runs entirely on your Mac — no internet needed, free forever. API mode connects to an AI provider for real conversations. Tap the mode pill in the chat header to switch.")
                        helpRow("Supported AI providers",
                                "Claude (Anthropic), ChatGPT (OpenAI), and Gemini (Google). Add a key for any or all in Settings → API Provider. Claud-y routes to whichever provider is currently selected. No data is shared between providers.")
                        helpRow("Adding an API key",
                                "Right-click → Settings → API Provider. Select your provider, paste your key, and tap Save. Each provider's key is stored separately in your Mac's Keychain and never leaves your device except to reach that provider directly.")
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

                    helpSection("Modes") {
                        helpRow("Normal", "Default behaviour. No extra context layered on.")
                        helpRow("Study Mode", "Tailored for students. Encourages focused sessions, uses Pomodoro framing, and provides calm, exam-friendly support. Works with every personality.")
                        helpRow("Dev Mode", "Deeper flow-state awareness. Celebrates builds, respects deep focus, empathises with debugging slumps. Works with every personality.")
                        helpRow("Work Mode", "Professional context. Claud-y quiets down, shifts to business-appropriate language, and offers to help with emails, meetings, decks, and deadlines. Reacts to Zoom, Teams, Outlook, and Slack switches.")
                        helpRow("Dance Mode", "Claud-y dances. That's it. Enable from right-click → Mode. Disable the same way.")
                        helpRow("Brain Rot Mode", "Gen Z slang, chaotic energy, W builds, no cap fr. Still helpful — just unhinged about it.")
                        helpRow("Stacking personalities + modes", "Modes layer on top of your chosen personality. Director + Work = boardroom drama. Hype Coach + Study = intense revision energy. All combos work.")
                    }

                    helpSection("Focus Tools") {
                        helpRow("Pomodoro timer", "Right-click Claud-y → Focus Tools → Pomodoro, then pick a duration (15, 25, 45, or 60 min). The badge appears above Claud-y once the session begins.")
                        helpRow("Pausing / resuming", "Right-click → Focus Tools → Pomodoro while running to pause or stop. Resume from the same submenu when paused.")
                        helpRow("Alarms", "Right-click → Focus Tools → Set Alarm. Choose a quick preset (5–240 min) or tap 'Set Custom Alarm…' to pick an exact time. Claud-y will wave and remind you when it fires.")
                        helpRow("Reminders", "Right-click → Focus Tools → Reminders → New Reminder…. Give it a label and a time. Pending reminders show in the submenu — tap one to dismiss it early. 'Clear All' removes everything.")
                        helpRow("Custom alarm / reminder sheet", "Tap 'Set Custom Alarm…' or 'New Reminder…' to open a compact sheet. Pick a date and time, optionally add a label, and confirm. The sheet closes and Claud-y takes it from there.")
                    }

                    helpSection("Sound & Voice") {
                        helpRow("Sound effects",
                                "Enable in Settings → Sound. Subtle audio cues: a pop on bubbles, chime on clean builds, fanfare on wins.")
                        helpRow("Character voice",
                                "Enable in Settings → Sound → Character voice. Claud-y mumbles in short tones when speaking - like GTA dialogue. Charming in a weird way.")
                        helpRow("Volume",
                                "Controlled by the volume slider in Settings → Sound. Applies to all sounds including the character voice.")
                    }

                    helpSection("Global Shortcut") {
                        helpRow("⌘⇧Space — Toggle chat",
                                "Press Command + Shift + Space from any app to open or close the Claud-y chat panel. Works without switching focus to Claud-y. Disable in Settings if it conflicts with another app.")
                    }

                    helpSection("Smart Awareness") {
                        helpRow("Quick-action button",
                                "When you switch to an app like Zoom, Figma, Slack, or Keynote, a small button appears above Claud-y with a contextual prompt. Tap it to open chat with the question pre-filled. It auto-hides after 8 seconds.")
                        helpRow("macOS Focus / Do Not Disturb",
                                "When your Mac's Focus mode is on, Claud-y automatically suppresses most ambient bubbles. The 🌙 badge confirms Focus is active. Claud-y resumes normally when Focus ends.")
                        helpRow("Break nudges",
                                "After 90 minutes of continuous screen time, Claud-y will gently remind you to take a break. Reminders get firmer at 2 hours and 3 hours. A 5-minute gap resets the clock.")
                        helpRow("Mood check-ins",
                                "Every couple of hours of active use, Claud-y will quietly ask how you're doing. You can respond in chat or dismiss it. If you mention you're struggling, Claud-y shifts into a more supportive tone.")
                        helpRow("Daily wrap-up",
                                "At 6 pm (if you've completed at least one Pomodoro), Claud-y gives a personality-flavoured summary of your day — sessions done, total focus time, encouragement.")
                    }

                    helpSection("Language Support") {
                        helpRow("Supported languages",
                                "Claud-y supports 10 languages: English (UK), Español, Français, Deutsch, Português, 日本語, 中文（简体）, हिन्दी, اردو, and العربية. Change the active language in Settings → Language.")
                        helpRow("What language affects",
                                "Both sides of Claud-y. In API mode, all AI responses come back in your chosen language. In Companion mode, the ambient reaction bubbles — build comments, greetings, idle nudges — are drawn from a translated pool. The character's personality still shines through in every language.")
                        helpRow("Typing in your language",
                                "The chat input works with any macOS input method. Switch your keyboard layout in System Settings → Keyboard → Input Sources. Japanese (Hiragana/Katakana/Kanji), Chinese (Pinyin → Simplified characters), Hindi (Devanagari), Urdu, and Arabic all work via their standard macOS IME — just set your input source and type.")
                        helpRow("Right-to-left languages (Arabic & Urdu)",
                                "Arabic and Urdu are written right-to-left. macOS handles text direction automatically in the chat input — your text will flow correctly as soon as you switch to an RTL input source. No extra setup needed.")
                        helpRow("Arabic transliteration",
                                "Arabic is the one language where Claud-y can optionally include transliteration (romanised pronunciation) alongside the Arabic script. This is on by design — useful for learners or users who read both. All other non-Latin languages (Japanese, Chinese, Hindi, Urdu) use their native scripts only, with no transliteration.")
                        helpRow("Japanese — no romaji",
                                "Japanese responses use natural mixed kanji/hiragana/katakana script throughout — exactly as a fluent speaker would write. Romaji (romanised Japanese) is never used. If you're reading Japanese text and need help, your macOS reading tools work as normal.")
                        helpRow("Chinese — no pinyin",
                                "Simplified Chinese responses use Mandarin character output only. Pinyin is never shown in responses. macOS's built-in lookup (right-click → Look Up) works on any Chinese character if you need pronunciation.")
                        helpRow("Companion mode & API mode",
                                "In Companion mode, reactions come from a translated library — no internet needed. In API mode, the language is enforced via a system prompt directive sent with every message, so your AI provider handles the translation. Changing language takes effect immediately for both.")
                        helpRow("Changing language",
                                "Settings → Language → pick from the list. The change takes effect instantly — no restart needed. Switch back to English (UK) at any time.")
                    }

                    helpSection("Reactions & Awareness") {
                        helpRow("What Claud-y watches",
                                "App switches (Xcode, Figma, Terminal, Zoom, Cursor, Office, browsers…), keyboard activity, clipboard content, and build events. All processing is local — nothing is logged or sent anywhere.")
                        helpRow("Browser reactions",
                                "Claud-y reacts when you switch to Chrome, Edge, Firefox, Brave, Opera, Safari, DuckDuckGo, or Helium — each with its own personality-aware comment.")
                        helpRow("Controlling bubble frequency",
                                "Settings → Chattiness. Drag the slider from Quiet (every 2 min) to Non-stop (every 14 sec).")
                        helpRow("Muting",
                                "Press Option+M, or right-click → Mute. A 🔇 badge appears when muted. Unmuting shows a small reaction.")
                    }

                    helpSection("Privacy") {
                        helpRow("Companion mode — 100% local",
                                "No internet required. No accounts, no sign-up, no analytics, no telemetry. Nothing about you, your machine, or your work ever leaves your Mac.")
                        helpRow("API mode — direct and transparent",
                                "Your messages travel from your Mac straight to the AI provider's API using your own key. There is no Claud-y server. We are not in the middle. We cannot see your prompts, your responses, or your key — not even in principle.")
                        helpRow("How API keys are stored (technical)",
                                "Keys are written to macOS Keychain with kSecAttrAccessibleWhenUnlockedThisDeviceOnly — the strictest access level. Encrypted by macOS, bound to this device, never written to any file, UserDefaults, or iCloud. Presence is checked without reading the secret (no kSecReturnData), so the Keychain dialog only appears when an API call is actually made.")
                        helpRow("No cross-provider data sharing",
                                "Claude, OpenAI, and Gemini keys and conversations are completely separate. Switching providers starts a fresh session. Nothing carries over.")
                        helpRow("What Claud-y never does",
                                "No telemetry SDK. No crash reporter. No analytics library. No third-party frameworks of any kind. The only outbound connections are the API calls you explicitly trigger by chatting.")
                    }

                    helpSection("Scratchpad") {
                        helpRow("Opening",
                                "Right-click Claud-y → Scratchpad. A compact notepad opens as a sheet.")
                        helpRow("Adding notes",
                                "Type in the input at the top and press Return or the + button. Notes appear instantly and persist between sessions.")
                        helpRow("Editing",
                                "Double-tap a note to edit it inline. Press Return to save.")
                        helpRow("Pinning",
                                "Tap the ••• menu on any note → Pin. Pinned notes float to the top and get a subtle orange tint.")
                        helpRow("Deleting",
                                "Tap ••• → Delete on an individual note, or ask Claud-y to 'clear my scratchpad' in chat (API mode).")
                    }

                    helpSection("Focus Stats") {
                        helpRow("Where to find them",
                                "Right-click → Focus Tools. At the bottom of the menu, a stats line shows how many Pomodoros you've done today and your total focus time.")
                        helpRow("Streak",
                                "Claud-y tracks consecutive days where you completed at least one Pomodoro. The streak is visible in Focus Stats and mentioned in the daily wrap-up.")
                        helpRow("Resetting",
                                "Stats reset automatically at midnight each day.")
                    }


                    helpSection("Support") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Claud-y is free and always will be. No subscriptions, no paywalls, no ads, no data collection. That's the philosophy — good tools should be accessible to everyone.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("Support is completely optional. But if Claud-y has made your day a little better, a coffee goes directly toward new features and keeping development going. Your feedback and support genuinely shape what gets built next.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Button {
                                if let url = URL(string: "https://ko-fi.com/ealiii") {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                Label("☕ Support on Ko-fi", systemImage: "heart")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(.link)

                            Text("One-time tip, no account needed. Every contribution is appreciated and used well.")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)

                            Button {
                                if let url = URL(string: "https://github.com/eali959/claudy") {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                Label("View on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(.link)

                            Text("Source is public. Bug reports, feature ideas, and pull requests are all welcome.")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
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
