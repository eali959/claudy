import SwiftUI
import AppKit

// MARK: - HelpView
// Presented as a popover from the ? button in the chat header and from the
// right-click context menu. Covers all major features in collapsible sections.

struct HelpView: View {
    @State private var searchQuery: String = ""

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
                .padding(.bottom, 8)

                // V4 polish — search bar + Replay V4 demo button
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                        TextField("Search help…", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                        if !searchQuery.isEmpty {
                            Button { searchQuery = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.regularMaterial))

                    Button {
                        NotificationCenter.default.post(name: .claudyStartDemo, object: nil)
                    } label: {
                        Label("Replay V4 demo", systemImage: "play.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .help("Run the 60-second V4 showcase")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                Divider().padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 1) {
                    helpSection("What's New — V4 release polish (final round)") {
                        helpRow("First-run UX: no scary permission prompts",
                                "Global hotkey, keyboard reactions, demo shortcuts, and weather comments all default OFF for new users. macOS will only ask for permissions when you explicitly enable a feature in Settings. No more Input Monitoring or Location prompts at launch.")
                        helpRow("Voice mode equaliser is honest about what it does",
                                "The wave bars only animate when voice mode is actively listening or speaking. Idle = flat bars. The mic button only pulses while it's actually recording.")
                        helpRow("12 idle micro-behaviours (was 8)",
                                "Yawn, scratch-head, double-take, peek added. Plus the existing head-shake, jump, arm-stretch, nod, look-around, sigh, glance-smirk, double-blink. Fires every 6–10 seconds during idle.")
                        helpRow("Privacy & Storage settings (NEW)",
                                "Settings → Privacy & Storage now lets you choose exactly what Claud-y saves to disk. Chat history is OFF by default. Scratchpad, Tamagotchi, focus stats, alarms, and reminders default ON (their previous behaviour). Each has a 'Clear saved' button. Nothing leaves your Mac, regardless.")
                        helpRow("Companion response pool nearly doubled",
                                "1320 reactions across 107 categories (was 728). Every app-switch, build event, time-of-day, and personality-mode combination has more variety. The English Companion personality went from rich to extensive.")
                        helpRow("Pomodoro complete celebration",
                                "When the timer finishes, the badge does a small pulse with a sealed checkmark. Subtle, satisfying.")
                        helpRow("Scratchpad shows note count + bulk clear",
                                "Header shows '(N)' for quick context. Settings → Privacy & Storage has a 'Clear all notes' button with confirmation.")
                    }
                    helpSection("What's New — V4 polish (earlier rounds)") {
                        helpRow("3D eyes stay stable now",
                                "Each eye now has a dedicated scale wrapper so blink, eye-widen, and iris tracking can never cancel each other mid-animation. Eyes no longer get stuck huge, half-closed, or invisible. Pupils stay locked to the sclera surface at all times.")
                        helpRow("3D mouth lip-syncs naturally while talking",
                                "Ported 2D Claud-y's 16-step phoneme lip-sync to 3D. The mouth opens and closes through a hand-tuned speech rhythm pattern at 90 ms intervals — both width and height vary per phoneme so it actually looks like talking, not a blinking oval. TTS word-boundaries layer accents on top when voice mode is driving real speech.")
                        helpRow("Body doesn't drift or spin anymore",
                                "All body animations (idle sway, jolt, celebrate, twirl, dance, etc.) now route through a single helper that guarantees the previous animation Task is cancelled before the new one starts. Eliminates the slow 360° rotation drift that built up from competing animation loops.")
                        helpRow("Smile transitions are clean",
                                "The mouth-shape spring is now critically damped — going from neutral to bigSmile no longer briefly overshoots into a 'huge creepy smile' before settling. Same snap-to-target speed, zero overshoot.")
                    }
                    helpSection("What's New in v4.0") {
                        helpRow("3D Claud-y is here",
                                "Right-click Claud-y → 'Switch to 3D Claud-y'. Pre-segmented USDZ rendered with a 4-light studio rig and PBR materials — body reads as glazed clay, not plastic. The 3D character has the same eight animation parts as 2D plus per-eye Pixar-style catchlights for that 'alive' look.")
                        helpRow("Talk to Claud-y",
                                "Right-click → 'Talk to Claud-y…' opens a compact voice overlay docked directly BELOW Claud-y. Big mic button, live waveform, status caption. Claud-y's mouth animates per spoken word (real TTS-driven, not a sine wave). Fully local — your audio never leaves your Mac.")
                        helpRow("Cloud API vs Local LLM — clearly separated",
                                "Right-click menu now shows 'Cloud API' and 'Local LLM' as separate sections so you always know whether your conversation stays on-device. The menu bar header shows AI · Personality · Mode as three independent axes.")
                        helpRow("Whoa twirl + idle micro-behaviours",
                                "New `.whoaTwirl` 360° feet-planted spin (3D-exclusive — used in the V4 demo). Idle micros fire every 8-12s during idle: head shake, small jump, arm stretch, slow nod. Both arms AND legs visibly breathe in idle.")
                        helpRow("3D accessories — all 7 work in 3D now",
                                "Glasses, tinted sunnies, Heisenberg hat, cap forward/backward, classic rectangular cinema 3D glasses (cyan + red anaglyph lenses + temple arms). All built from procedural geometry — zero texture overhead.")
                        helpRow("Multi-screen mouse tracking",
                                "Claud-y now follows the cursor on whichever screen it's actually on, including when the cursor is hovering Claud-y's own panel. Throttled so it doesn't spike CPU.")
                        helpRow("V4 demo, fully refreshed",
                                "Press the demo trigger and watch: 2D Claud-y → glasses arrive → matrix-rain glitch → boom, 3D Claud-y does a 360° Whoa Twirl. Then a feature tour through Local LLM, Voice Mode, accessories, modes — all under 60 seconds. All overlays auto-suppressed during demo.")
                    }
                    helpSection("Voice & Local LLM") {
                        helpRow("Talk to Claud-y",
                                "Right-click → 'Talk to Claud-y…' opens a compact floating voice overlay docked directly BELOW Claud-y. Big mic button, live waveform, status caption. Tap to start, tap again to send — Claud-y listens on-device (your audio never leaves your Mac), routes through your selected AI, and replies out loud. His mouth lip-syncs to every word.")
                        helpRow("Three character voices",
                                "Pick a voice persona in the Voice Mode UI:\n• **Cute Claudy** — bright, bouncy, kid-show energy.\n• **Yo Claudy** — deep, laid-back cadence.\n• **Q Claudy** — measured British, dry wit.\n• **Claudy Classic** — plain system voice.")
                        helpRow("Better voices",
                                "macOS bundles compact voices by default. For noticeably higher fidelity, open System Settings and search for **'Spoken Content'** (the path varies by macOS version — usually under Accessibility, sometimes under General). Find the voice for your persona (Karen, Reed, or Daniel) and download the **Enhanced** or **Premium** variant. Voice Mode picks it up automatically.")
                        helpRow("Local LLM Setup wizard",
                                "Right-click → Local LLM → 'Set up local LLM…' opens a guided wizard with two tabs (LM Studio recommended for ease, Ollama for power users). Each tab walks through download, model loading, and starting the server, with a live 🟢 'Detected' badge.")
                        helpRow("Auto-fallback",
                                "If a local LLM goes offline mid-reply, Claud-y seamlessly switches to the first cloud provider you have a key for, and tells you which provider it switched to.")
                        helpRow("Privacy",
                                "Speech recognition runs on-device when supported. TTS is fully local — no cloud voice service is ever called. Local LLM mode keeps the entire conversation on your Mac.")
                    }

                    helpSection("What's New in v3.1") {
                        helpRow("Language switch acknowledgment",
                                "When you change the response language in Settings, Claud-y now waves and says a short greeting in the new language — immediately showing the change is live. If the chat panel is open, the same message appears there too.")
                        helpRow("Bug fixes — v3.1",
                                "• Status bar personality checkmarks now stay in sync when you change personality from the right-click menu.\n• 'Cap Forward' and 'Cap Backward' accessory icons now display correctly.\n• 60-minute Pomodoro preset icon fixed.\n• Quick Launch empty-state icon fixed.\n• Auto-Walk disable icon fixed.\n• Language info text correctly shows the selected language name.\n• Tamagotchi care actions safely guarded against unavailable state.")
                    }

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
                        helpRow("⚠️ Important: API key required for AI responses in non-English",
                                "Changing the language in Settings → Language affects two things: (1) Companion mode reactions — these come from a built-in translated library and work offline, no API key needed. (2) AI chat responses — Claud-y injects a language directive into the system prompt so your AI provider replies in the chosen language. This requires an active API key for Claude, ChatGPT, or Gemini. Without a key, the chat panel will not send messages regardless of language selected.")
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
        // V4 polish — filter by search query.  Match is case-insensitive
        // and checks both title and body.  Empty query shows all rows.
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty
            || title.lowercased().contains(q)
            || body.lowercased().contains(q) {
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
}

#Preview {
    HelpView()
        .frame(width: 320)
}
