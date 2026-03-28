<img width="1248" height="832" alt="Claud-y_Cover_Image" src="https://github.com/user-attachments/assets/ca3d4d6b-68b4-41f3-9ff7-c80c50842605" />

# Claud-y 🍊
**A small AI companion that lives on your Mac.**

![Kapture 2026-03-28 at 05 19 25](https://github.com/user-attachments/assets/a6de61e8-d124-487a-aa03-a0296ffaa811)

---

## Why I built this

Most of my coding sessions happen alone.

No standup to look forward to, no one to tell when something finally works, no one who understands why a clean build after three hours of fighting a bug feels like an actual victory.

I wanted something in the corner of the screen. Not a chatbot. Not a tool. Something more like a presence. Something that notices when you're deep in it, reacts when something breaks, cheers when it comes together. Something that makes the room feel a little less empty.

The inspiration was *Project Hail Mary* by Andy Weir. If you've read it, you know the part I mean. If you haven't -- it's about solving impossible problems alone in deep space, and what it means to find company in unexpected places. I won't spoil it. Go read it.

That's what Claud-y is trying to be. Your Rocky. Except orange. And on your desktop.

---

## What it does

Claud-y lives in a small floating window, always on top, out of the way. It watches what you're working on and reacts: build failures, git pushes, late nights, Friday deploys, the moment something finally clicks.

Tap it to open a chat. It'll talk to you. Really talk to you.

**No API key needed. No account. No setup. Free forever.**

Out of the box, Claud-y runs completely locally -- curated response pools, 100+ contextual reactions, personality modes, a Pomodoro focus timer, sound effects, daily streaks, and a few hidden Easter eggs. Everything works on your machine, offline, always.

If you have an [Anthropic API key](https://console.anthropic.com), you can switch to full Claude AI -- streaming responses, code review, debugging help, anything. Your key stays in your Mac's Keychain and goes nowhere else.

---

## Companion mode vs AI mode

| | Companion | AI |
|---|---|---|
| **Setup** | None | Anthropic API key |
| **Cost** | Free forever | API usage (pay-as-you-go) |
| **Data sent** | Nothing | Messages → Anthropic API |
| **Works offline** | Yes | No |
| **Response quality** | Warm & witty | Full Claude AI |

You start in Companion mode. Switch anytime from the chat header.

---

## Personalities

Claud-y ships with seven personalities you can switch on the fly:

| Personality | Vibe |
|---|---|
| **The Companion** | Warm, clever, genuinely present |
| **The Chatty One** | Verbose, tangential, always circles back |
| **The Hype Coach** | LOUD. ENERGETIC. BELIEVES IN YOU. |
| **The Director** | Theatrical, grand, slightly unhinged |
| **The Mate** | Casual, direct, "yeah nah you've got this" |
| **The Listener** | Quiet, unhurried, asks the right questions |
| **You Do You** | Write your own persona in Settings |

---

## Features

- **Contextual reactions** -- reacts to Xcode builds, app switches, clipboard content, keyboard patterns, time of day, and more
- **Chat panel** -- tap to open, with markdown rendering, code blocks, and export
- **Pomodoro timer** -- right-click to start a focus session; badge shows countdown below the character
- **Sound effects** -- optional audio feedback and a GTA-style character mumble voice
- **Daily streaks** -- quietly tracks your coding sessions
- **Quick launch** -- up to 3 configurable app shortcuts in the right-click menu
- **Reaction log** -- hold the character for 3 seconds to see what it's been thinking

---

## Privacy & data

### What leaves your device

In **Companion mode**: nothing. All responses come from local logic. No network calls are made.

In **API mode**: your chat messages and the active personality's system prompt are sent to `https://api.anthropic.com` using the Anthropic API. That's the only outbound connection Claud-y ever makes. No other hosts. No CDN. No analytics endpoint.

### API key

- Stored in the **macOS Keychain** (`kSecClassGenericPassword`)
- `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — **never synced to iCloud Keychain**, never leaves this Mac
- Never written to `UserDefaults`, log files, or any file on disk
- Transmitted as an `x-api-key` HTTP header — never in a URL or request body

### System access

Claud-y requests two permissions and uses each narrowly:

**Accessibility access** (required for keyboard reactions):
- Monitors global keyboard events via `NSEvent.addGlobalMonitorForEvents`
- Detects: typing bursts, typing pauses, `Cmd+Z` spam, `Cmd+S`, `Cmd+C`/`Cmd+V` patterns
- Keystrokes are **never recorded or stored** — only event timing and modifier keys are used
- Granting this is required for keyboard reactions. Without it, Claud-y still works fully — keyboard reactions just don't fire.

**No microphone, camera, location, or contacts access** — Claud-y never requests any of these.

### Process inspection

Claud-y detects running processes (`xcodebuild`, `npm`, `claude`) using `sysctl KERN_PROC_ALL` with `kinfo_proc`. This reads **process names only** — no process arguments, no memory, no file handles. The poll runs every 15 seconds.

### Clipboard monitoring

`ClipboardMonitor` watches `NSPasteboard.changeCount`. When the clipboard changes, it reads the content and classifies it as plain text, code, or URL — the classification drives the reaction type. **Clipboard content is never stored, logged, or sent anywhere.**

### What's stored locally (UserDefaults)

Everything except the API key is stored in `UserDefaults` on your Mac. Full table:

| Key | Stored value |
|---|---|
| `CharacterWindowOrigin` | Last panel position `[Double, Double]` |
| `CharacterSizePreset` | `"small"` / `"medium"` / `"large"` |
| `ClaudyChatHeight` | Chat panel height in points |
| `PersonalityMode` | Active personality raw value |
| `CustomPersonaText` | Your custom persona text (if set) |
| `SelectedModel` | Active Claude model identifier |
| `UseComplexModel` | Bool — Opus for complex tasks |
| `IsMuted` | Bool — mute state |
| `SoundEffectsEnabled` | Bool — sound toggle |
| `HasSeenOnboarding` | Bool — first launch flag |
| `FirstLaunchDate` | `Date` — for anniversary reactions |
| `DailySessionDates` | `[String]` ISO dates — streak tracking (90-day window) |
| `StreakShownDate` | `String` — prevents repeat streak messages same day |
| `QuickLaunchShortcuts` | `Data` — JSON-encoded shortcut array |
| `PomodoroPreset` | `Int` raw value of active preset |
| `PomodoroCustomMinutes` | `Int` — custom timer duration |

**Chat history is never persisted.** It lives in memory for the session only. Use the export function to save it.

### No telemetry, analytics, or crash reporting

There are no analytics calls, no Sentry/Crashlytics/Firebase, no remote logging, and no usage tracking of any kind. All `OSLog` output stays on device. Claud-y has no idea how many people use it.

### App Sandbox

Claud-y runs **without App Sandbox** to allow `sysctl` process inspection and global `NSEvent` keyboard monitoring. This means it cannot be distributed on the Mac App Store as-is and is source-only / direct download. The trade-off is intentional and documented here so you can make an informed choice.

---

## Getting it

### Download

Grab the latest `.dmg` from [Releases](../../releases). Open it, drag Claud-y to Applications. Done.

### Build from source

```bash
git clone https://github.com/eali959/claudy.git
cd claudy
open Claudy/Claudy.xcodeproj
```

Requires macOS 15+ and Xcode 16+. Build and run the `Claudy` scheme.

---

## This is my first app

I've been a developer for a while. This is the first thing I've shipped publicly.

I built it for myself, and then I thought -- other people probably have the same quiet problem. So here it is. Free. Open source. No strings.

If Claud-y makes your coding sessions feel a little less solo, that's everything I wanted.

---

## Support

Claud-y is and always will be free.

If it's made a difference to your day and you want to say thanks, I've set up a Ko-fi:

**☕ [ko-fi.com/ealiii](https://ko-fi.com/ealiii)**

No pressure. Not why I built it.

---

## What's next

- [ ] Reminder / alarm system
- [ ] Persistent conversation history (opt-in)
- [ ] iOS companion (maybe)

Have ideas? Open an issue.

---

## Tech

- **Platform:** macOS 15+
- **Language:** Swift 6.0 (strict concurrency)
- **UI:** SwiftUI
- **AI:** Anthropic Claude API (optional)
- **Architecture:** MVVM with `@Observable`
- **License:** MIT

---

*"I am not talking to myself. I am talking to Rocky."*
*-- Project Hail Mary, Andy Weir*

---

Made with care, for the developers who code alone.
