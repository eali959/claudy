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

If you have an API key, you can unlock full AI responses — streaming, code review, debugging help, anything. Claud-y supports three providers:

- **[Anthropic Claude](https://console.anthropic.com)** — the original
- **[OpenAI (ChatGPT)](https://platform.openai.com/api-keys)** — GPT-4o and GPT-4o mini
- **[Google Gemini](https://aistudio.google.com/app/apikey)** — 2.0 Flash and 1.5 Pro

Your key stays in your Mac's Keychain and goes nowhere except that provider's API.

---

## Companion mode vs AI mode

| | Companion | AI |
|---|---|---|
| **Setup** | None | API key (your choice of provider) |
| **Cost** | Free forever | API usage (pay-as-you-go) |
| **Data sent** | Nothing | Messages → provider API |
| **Works offline** | Yes | No |
| **Response quality** | Warm & witty | Full AI |
| **Providers** | — | Claude · ChatGPT · Gemini |

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
- **Contextual reactions** — reacts to Xcode/Cursor builds, app switches, clipboard content, keyboard patterns, time of day, day of week, and more
- **60+ apps detected** — Xcode, Cursor, Figma, Slack, Zoom, Notion, Obsidian, VS Code, full Microsoft Office suite, full Apple productivity suite, and more
- **9 browsers** — Chrome, Safari, Edge, Firefox, Brave, Opera, DuckDuckGo, Helium, Arc — each with distinct personality-aware reactions
- **Public holiday awareness** — UK, US, Australia, Universal, and Islamic observances
- **Spotify sync** — reacts to genre changes (metal → headbanging, lo-fi → vibing)

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

**No microphone, camera, location, or contacts access** — Claud-y never requests any of these.

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

**Chat history is never persisted.** It lives in memory for the session only. Use the export function to save it.

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

## v2.0 — what changed

The big one. Highlights:

- **3 AI providers** — Claude, ChatGPT, Gemini (your key, your choice, your data)
- **Work Mode** — professional context, quieter, meeting/email/Slack aware
- **8 new background systems** — global hotkey, Focus/DND sync, break nudges, focus stats, quick-action buttons, scratchpad, mood check-ins, daily wrap-up
- **9 browsers detected** — including Helium ("A floating browser for a floating companion. We match.")
- **60+ apps detected** — up from ~20
- **400+ reactions** — up from ~200
- **Brain Rot mode** — unhinged Gen Z energy that is somehow still helpful

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

- [ ] Persistent conversation history (opt-in)
- [ ] More provider support
- [ ] iOS companion (maybe, no promises)

Have ideas? [Open an issue](../../issues).

---

## Tech

- **Platform:** macOS 15+
- **Language:** Swift 6.0 (strict concurrency)
- **UI:** SwiftUI
- **AI:** Claude · ChatGPT · Gemini (all optional)
- **Architecture:** MVVM with `@Observable`
- **License:** MIT

---

*"I am not talking to myself. I am talking to Rocky."*
*— Project Hail Mary, Andy Weir*

---

Made with care, for the developers who code alone.
