<img width="1248" height="832" alt="Claud-y_Cover_Image" src="https://github.com/user-attachments/assets/ca3d4d6b-68b4-41f3-9ff7-c80c50842605" />

# Claud-y 🍊
**A small AI companion that lives on your Mac.**

---

## Why I built this

Most of my coding sessions happen alone.

No standup to look forward to, no one to tell when something finally works, no one who understands why a clean build after three hours of fighting a bug feels like an actual victory.

I wanted something in the corner of the screen. Not a chatbot. Not a tool. Something more like a presence. Something that notices when you're deep in it, reacts when something breaks, cheers when it comes together. Something that makes the room feel a little less empty.

The inspiration was *Project Hail Mary* by Andy Weir. If you've read it, you know the part I mean. If you haven't — it's about solving impossible problems alone in deep space, and what it means to find company in unexpected places. I won't spoil it. Go read it.

That's what Claud-y is trying to be. Your Rocky. Except orange. And on your desktop.

---

## What it does

Claud-y lives in a small floating window, always on top, out of the way. It watches what you're working on and reacts: build failures, git pushes, late nights, Friday deploys, the moment something finally clicks.

Tap it to open a chat. It'll talk to you. Really talk to you.

**No API key needed. No account. No setup. Free forever.**

Out of the box, Claud-y runs completely locally — curated response pools, 400+ contextual reactions, personality modes, a Pomodoro focus timer, break nudges, a daily wrap-up, mood check-ins, and a few hidden Easter eggs. Everything works on your machine, offline, always.

If you have an API key, you can unlock full AI responses — streaming, code review, debugging help, anything. Claud-y supports five providers, plus two fully local options:

- **[Anthropic Claude](https://console.anthropic.com)** — the original
- **[OpenAI (ChatGPT)](https://platform.openai.com/api-keys)** — GPT-4o and GPT-4o mini
- **[Google Gemini](https://aistudio.google.com/app/apikey)** — 2.0 Flash and 1.5 Pro
- **[Ollama](https://ollama.ai)** — run any open model fully on-device, zero cloud, zero API key
- **[LM Studio](https://lmstudio.ai)** — local model runner with an OpenAI-compatible API
- **DeepSeek** — cloud API option for an alternative frontier model

Your key stays in your Mac's Keychain and goes nowhere except that provider's API.

---

## Companion mode vs AI mode

| | Companion | AI | Local LLM |
|---|---|---|---|
| **Setup** | None | API key | Ollama or LM Studio running locally |
| **Cost** | Free forever | API usage (pay-as-you-go) | Free (your hardware) |
| **Data sent** | Nothing | Messages → provider API | Nothing |
| **Works offline** | Yes | No | Yes |
| **Response quality** | Warm & witty | Full AI | Depends on model |
| **Providers** | — | Claude · ChatGPT · Gemini · DeepSeek | Ollama · LM Studio |

You start in Companion mode. Switch anytime from the chat header.

---

## Personalities

Seven personalities, switchable on the fly:

| Personality | Vibe |
|---|---|
| **The Companion** | Warm, clever, genuinely present |
| **The Chatty One** | Verbose, tangential, always circles back |
| **The Hype Coach** | LOUD. UNCONDITIONAL. BELIEVES IN YOU COMPLETELY. |
| **The Director** | Theatrical, grand, slightly unhinged |
| **The Mate** | Australian energy. Deadpan. Chill. "Yeah nah" is a complete sentence. |
| **The Listener** | Quiet, unhurried, asks the right questions |
| **You Do You** | Write your own persona in Settings |

---

## Modes

Right-click → Mode to switch. Every mode stacks with your personality — Director + Brain Rot is exactly what it sounds like.

| Mode | Vibe |
|---|---|
| **Normal** | Default. Claud-y is just Claud-y. |
| **Study** | Quieter, pedagogical, Pomodoro-framed. Milestone bubbles at 25/50/90 min. |
| **Dev** | Flow-state detection, debugging empathy, extra confetti on builds. |
| **Work** | Professional. Quieter. Reacts to Zoom, Outlook, Slack. |
| **Dance** | It dances. That's it. |
| **Brain Rot** | Gen Z internet culture mode. Still helpful. Completely unhinged about it. |

---

## Features

### Smart awareness
- **3D character** — toggle between 2D and 3D from right-click → Appearance; full RealityKit renderer with pupil tracking and idle micro-behaviours
- **Voice mode** — hold ⌘⇧V to talk; Claud-y listens and replies with real lip-sync; works with cloud and local AI
- **Local LLM support** — Ollama and LM Studio: no cloud, no API key, zero data leaves your Mac
- **Contextual reactions** — reacts to Xcode/Cursor builds, app switches, clipboard content, keyboard patterns, time of day, day of week, and more
- **60+ apps detected** — Xcode, Cursor, Figma, Slack, Zoom, Notion, Obsidian, VS Code, full Microsoft Office suite, full Apple productivity suite, and more
- **9 browsers** — Chrome, Safari, Edge, Firefox, Brave, Opera, DuckDuckGo, Helium, Arc — each with distinct personality-aware reactions
- **Activity states** — Claud-y adopts different postures while you code, type, study, or browse
- **Weather awareness** — opt-in; reacts to your local weather using CoreLocation + Open-Meteo (no API key, no account)
- **Public holiday awareness** — UK, US, Australia, Universal, and Islamic observances
- **Spotify sync** — reacts to genre changes (metal → headbanging, lo-fi → vibing)
- **10 languages** — full reaction pools and AI responses in English, Español, Français, Deutsch, Português, 日本語, 中文（简体）, हिन्दी, اردو, العربية

### Focus & productivity
- **Pomodoro focus timer** — right-click to start; badge shows countdown; customisable durations
- **Alarms & reminders** — set via right-click or natural language in chat ("remind me in 30 min to take a break")
- **Break nudges** — gentle at 90 min, firm at 2 hours, non-negotiable at 3 hours
- **Focus stats** — today's Pomodoros, total focus time, day streak — shown in the right-click menu
- **Daily wrap-up** — personality-flavoured 6pm session summary (only fires if you actually worked)
- **Mood check-ins** — every ~2 hours of active use, Claud-y quietly asks how you're doing

### Smart shortcuts
- **⌘⇧Space global hotkey** — toggle chat from any app, no clicking required
- **Contextual quick-action buttons** — switch to Zoom, Figma, Notion, etc. and a pre-written prompt appears above Claud-y for 8 seconds
- **Quick launch** — up to 5 configurable app shortcuts in the right-click menu
- **Mini scratchpad** — persistent notepad in the right-click menu; pin notes, edit inline, survives restarts

### Ambience
- **Care score** — 7-day rolling interaction score; thriving gives a golden rim glow, neglected causes subtle desaturation
- **Optional chat history** — persist chat sessions locally, off by default; toggle in Settings → Privacy & Storage
- **macOS Focus / DND sync** — Claud-y sees your Focus mode and quiets down automatically
- **Sound effects** — optional audio feedback with a GTA-style character mumble voice
- **Reaction log** — hold for 3 seconds to see what it's been thinking
- **Roast Mode** — it will roast you. You asked for this.
- **Dance Mode** — 130 BPM choreography with full arm choreography
- **Brain Rot Mode** — Gen Z slang on everything. "W build no cap fr."

---

## Privacy & data

### What leaves your device

| Mode | What's sent | Where | When |
|------|-------------|-------|------|
| **Companion** | Nothing | — | Never |
| **AI (Claude)** | Your message + active system prompt | `api.anthropic.com` | When you send a message |
| **AI (ChatGPT)** | Your message + active system prompt | `api.openai.com` | When you send a message |
| **AI (Gemini)** | Your message + active system prompt | `generativelanguage.googleapis.com` | When you send a message |

In **Companion mode**: nothing leaves your Mac. No network calls are made at all.

In **AI mode**: your messages go directly from your Mac to the provider's API using your own key. There is no Claud-y server. Nothing is in the middle. We cannot see your prompts, your responses, or your key — not even in principle.

### API key storage

- Stored in **macOS Keychain** (`kSecClassGenericPassword`)
- `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — **never synced to iCloud Keychain**, never leaves this Mac
- Never written to `UserDefaults`, log files, or any file on disk
- Each provider has its own isolated account: `claude-api-key`, `openai-api-key`, `gemini-api-key`
- Claude key is transmitted as an `x-api-key` header; OpenAI as `Authorization: Bearer`; Gemini as a URL query param (Google's requirement, still HTTPS)
- Presence is checked with `SecItemCopyMatching` and **no `kSecReturnData`** — the secret is never read unless an API call is being made, so the Keychain dialog doesn't appear on launch

### System access

**Accessibility access** (required for keyboard reactions):
- Monitors global keyboard events via `NSEvent.addGlobalMonitorForEvents`
- Detects: typing bursts, typing pauses, `Cmd+Z` spam, `Cmd+S`, `Cmd+C`/`Cmd+V` patterns
- Keystrokes are **never recorded or stored** — only event timing and modifier keys are used
- Without this permission, Claud-y still works fully — keyboard reactions just don't fire

**Process inspection**:
- Reads running process names via `sysctl KERN_PROC_ALL` with `kinfo_proc`
- Detects: `xcodebuild`, `tsc`, `webpack`, `vite`, `cargo`, `make`, `jest`, `claude` CLI, and others
- **Process names only** — no arguments, no memory, no file handles. Poll runs every 15 seconds.

**Clipboard monitoring**:
- Watches `NSPasteboard.changeCount`. On change, reads content and classifies it as plain text, code, or URL — the classification drives the reaction type
- **Clipboard content is never stored, logged, or sent anywhere**

**Permission model — opt-in only:** macOS Input Monitoring (keyboard reactions and global hotkey), Location (weather), and microphone (voice mode) are all off by default. Claud-y requests zero system permissions on first launch. Every prompt is tied to an explicit toggle you enable in Settings.

### What's stored locally (UserDefaults)

Everything except API keys lives in `UserDefaults` on your Mac:

| Key | Value |
|-----|-------|
| `CharacterWindowOrigin` | Last panel position `[Double, Double]` |
| `CharacterSizePreset` | `"small"` / `"medium"` / `"large"` |
| `PersonalityMode` | Active personality raw value |
| `CustomPersonaText` | Your custom persona text (if set) |
| `SelectedProvider` | Active AI provider (`"claude"` / `"openai"` / `"gemini"`) |
| `SelectedModel` | Active model identifier |
| `UseComplexModel` | Bool — smarter model for complex tasks |
| `IsMuted` | Bool — mute state |
| `SoundEffectsEnabled` | Bool — sound toggle |
| `ChattinessLevel` | Int 1–5 — ambient bubble frequency |
| `GlobalHotkeyEnabled` | Bool — ⌘⇧Space toggle |
| `HasSeenOnboarding` | Bool — first launch flag |
| `FirstLaunchDate` | `Date` — for anniversary reactions |
| `DailySessionDates` | `[String]` ISO dates — streak tracking (90-day window) |
| `QuickLaunchShortcuts` | `Data` — JSON-encoded shortcut array |
| `PomodoroPreset` | `Int` — active timer preset |
| `PomodoroCustomMinutes` | `Int` — custom timer duration |
| `FocusStats` | `Data` — JSON: today's Pomodoros, focus seconds, streak days |
| `ScratchpadNotes` | `Data` — JSON-encoded scratchpad notes |
| `RenderMode3D` | Bool — 3D character renderer enabled |
| `VoiceModeEnabled` | Bool — voice mode active |
| `ChatHistoryEnabled` | Bool — local chat history persistence (default OFF) |
| `KeyboardReactionsEnabled` | Bool — typing-burst / undo-streak reactions (default OFF) |
| `WeatherCommentsEnabled` | Bool — weather context monitoring (default OFF) |

**Chat history is stored in memory only by default.** Enable "Save chat history" in Settings → Privacy & Storage to persist locally to `~/Library/Application Support/Claudy/chat_history.json` — never uploaded, never synced. Per-data-type toggles also cover scratchpad notes, Tamagotchi state, focus stats, and alarms.

### No telemetry, analytics, or crash reporting

No analytics calls. No Sentry/Crashlytics/Firebase. No remote logging. No usage tracking of any kind. All `OSLog` output stays on device. Claud-y has no idea how many people use it.

### App Sandbox

Claud-y runs **without App Sandbox** to allow `sysctl` process inspection and global `NSEvent` keyboard monitoring. This means it cannot be distributed on the Mac App Store and is source-only / direct download. The trade-off is intentional and documented here so you can make an informed choice.

---

## Getting it

### Download
Grab the latest `.dmg` from [Releases](../../releases). Open it, drag Claud-y to Applications. Done.

On first launch macOS may say it can't verify the developer — right-click the app → Open to get past this. It's because Claud-y is distributed outside the App Store.

### Build from source

```bash
git clone https://github.com/eali959/claudy.git
cd claudy
open Claudy/Claudy.xcodeproj
```

Requires macOS 15+ and Xcode 16+. Build and run the `Claudy` scheme. No dependencies to install.

---

## v4.0 — what changed

The biggest Claud-y release yet. Claud-y is now a fully expressive 3D character with voice mode, local LLM support, and a living ambient personality.

### Highlights
- **3D character** — Claud-y renders in full 3D via RealityKit. Pupil-tracking eyes, procedural limbs, lip-sync mouth, and 12 idle micro-behaviours (yawns, head scratches, double takes, peeks). Toggle between 2D and 3D any time from right-click → Appearance.
- **Voice mode** — tap the mic or hold ⌘⇧V to talk. Claud-y listens, thinks, then speaks back with real lip-sync. Works with all AI providers including local ones.
- **Local LLM** — run Claud-y fully on-device with Ollama or LM Studio. Nothing leaves your Mac. DeepSeek also supported as a cloud option.
- **Floating voice overlay** — a compact panel docks directly below Claud-y when voice mode is active. Animated waveform bars, live transcript, state-aware mic pulse.
- **Care score** — a 7-day rolling score tracks how much you've interacted with Claud-y. High score → golden rim glow (thriving). Low score → subtle desaturation (neglected). Reset any time from Settings.
- **Optional chat history** — off by default. Enable in Settings → Privacy & Storage to persist chat sessions locally to `~/Library/Application Support/Claudy/chat_history.json`. Per-data-type toggles for scratchpad, Tamagotchi state, focus stats, and alarms too.
- **Privacy-first permissions** — no unexpected system permission prompts on first launch. Input Monitoring, Location, and keyboard monitoring are now all opt-in via Settings toggles.
- **7 accessories in 3D** — all accessories (glasses, tinted sunnies, Heisenberg hat, cap forward, cap backward, cinema 3D glasses) now have full 3D counterparts with PBR materials. Santa hat added.
- **Response pool +81%** — `ReactionLibrary.json` grew from 728 → 1,320 lines of Companion-voice content.
- **Settings search bar** — type "voice", "ollama", "pomodoro" to filter any setting instantly.

Full history in [CHANGELOG.md](CHANGELOG.md).

---

## v3.1 — what changed (see v4.0 above for latest)

A polish release. One new feature, a handful of bug fixes, nothing broken.

### New
- **Language switch acknowledgment** — when you change the response language in Settings, Claud-y immediately waves and greets you in the new language, confirming the change is live. If the chat panel is open, the greeting appears there too. Covers all 10 languages.
- **Settings section headers** — now bold and orange instead of the muted macOS default gray. Much easier to scan.

### Fixed
- Personality checkmarks in the menu bar status item now stay correct after changing personality from the right-click context menu (they were going stale)
- Language picker in Settings now correctly shows flag + language name (only the flag was showing)
- Missing SF Symbol icons: `baseball.cap` doesn't exist on macOS — cap accessories now use `hat.widebrim` / `graduationcap`; `60.circle` fixed to `timer.circle`; `rocket` fixed to `bolt.circle`; `figure.walk.slash` fixed to `figure.stand`
- Tamagotchi care actions (Feed / Play / Rest) in the right-click menu are now safely guarded — no force-unwrap crash if the Tamagotchi manager is unavailable
- Language info text in Settings was referencing an undefined variable — corrected
- AppDelegate `NSMenuDelegate` conformance cleaned up — no more Swift 6 warning

---

## v3.0 — what changed

The deep one. Highlights:

- **10 languages** — English, Español, Français, Deutsch, Português, 日本語, 中文（简体）, हिन्दी, اردو, العربية. Change in Settings → Language. Takes effect instantly.
- **Tamagotchi system** — Claud-y has happiness, energy, and hunger. It has feelings now. (Simulated. But still.)
- **Personality blending** — mix any two personalities on a 0–100% slider. Subtle whisper or full synthesis.
- **Full mouth animation sync** — 15 distinct mouth shapes, all data-driven
- **Activity states** — Claud-y adopts different postures for coding, typing, studying, reading
- **Walk across screen** — roams to a new spot every ~10 minutes
- **Weather awareness** — reacts to actual local weather (CoreLocation + Open-Meteo, no API key)
- **6 accessories** — glasses, sunnies, hats. Dress Claud-y up.
- **4,000+ reaction strings** — translated pools for all 10 languages
- **Chat UX** — markdown toggle, scroll-to-bottom button, token counter, system prompt presets

Full history in [CHANGELOG.md](CHANGELOG.md).

---

## This is my first app

I've been a developer for a while. This is the first thing I've shipped publicly.

I built it for myself, and then I thought — other people probably have the same quiet problem. So here it is. Free. Open source. No strings.

If Claud-y makes your coding sessions feel a little less solo, that's everything I wanted.

---

## Support

Claud-y is and always will be free. No subscriptions. No paywalls. No ads.

I don't believe in making people pay for something like this. But if Claud-y has earned a spot in your day and you want to support more features being built, a coffee goes a long way:

**☕ [ko-fi.com/ealiii](https://ko-fi.com/ealiii)**

Your feedback and support genuinely shape what gets built next. Every bit of it is appreciated.

---

## What's next

- [ ] Apple Intelligence integration — on-device foundation model, zero API key required
- [ ] Personality export/import — share your custom Claud-y persona as a `.claudyprofile` file
- [ ] iOS companion (maybe, no promises)
- [ ] More accessories and seasonal cosmetics

Have ideas? [Open an issue](../../issues).

---

## Tech

- **Platform:** macOS 15+
- **Language:** Swift 6.0 (strict concurrency)
- **UI:** SwiftUI
- **3D engine:** RealityKit
- **Voice:** AVSpeechSynthesizer · SFSpeechRecognizer
- **AI:** Claude · ChatGPT · Gemini · Ollama · LM Studio · DeepSeek (all optional)
- **Architecture:** MVVM with `@Observable`
- **License:** MIT

---

*"I am not talking to myself. I am talking to Rocky."*
*— Project Hail Mary, Andy Weir*

---

Made with care, for the developers who code alone.
