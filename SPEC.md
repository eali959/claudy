# Claud-y

**A macOS floating AI companion for developers.**

Claud-y is a small, round, animated orange creature that lives on your screen. It watches what you're doing — builds, git pushes, music, app switches — and reacts with character. Tap it to open a full chat panel. Right-click for options. It works without an API key and gets significantly better with one.

**Platform:** macOS 15+
**Language:** Swift 6.0
**License:** MIT
**Version:** 1.0

---

## Table of Contents

1. [What Claud-y Does](#1-what-claudy-does)
2. [Getting Started](#2-getting-started)
3. [Chat Modes](#3-chat-modes)
4. [Personalities](#4-personalities)
5. [Ambient Awareness](#5-ambient-awareness)
6. [Focus Timer (Pomodoro)](#6-focus-timer-pomodoro)
7. [Character & Expressions](#7-character--expressions)
8. [Settings & Customisation](#8-settings--customisation)
9. [Keyboard Shortcuts & Gestures](#9-keyboard-shortcuts--gestures)
10. [Architecture Overview](#10-architecture-overview)
11. [File Map](#11-file-map)
12. [Security & Privacy](#12-security--privacy)
13. [Data & Persistence](#13-data--persistence)
14. [Accessibility](#14-accessibility)
15. [Known Limitations](#15-known-limitations)
16. [Contributing](#16-contributing)

---

## 1. What Claud-y Does

Claud-y lives in a small floating window that sits above your other apps. It never gets in the way — it's always in the corner, always watching, occasionally having opinions.

### Without an API key (free, always)

- **Ambient reactions** — reacts to Xcode builds, npm installs, app switches, clipboard activity, battery warnings, Wi-Fi drops, screenshots, and more
- **Local chat** — keyword-matching conversation engine with 22 intents, ~120 responses, personality-aware pools, and 20 developer Easter eggs. No network call, no latency.
- **Focus timer** — configurable Pomodoro countdown (15 / 25 / 45 / 60 min or custom) with milestone reactions
- **Streak tracking** — records daily sessions, congratulates you on streaks of 3+ days
- **Hourly chimes** — subtle commentary at 9am, 5pm, and midnight
- **Day-of-week reactions** — special messages on Mondays and Fridays
- **Special dates** — New Year's Day, Christmas, Claud-y's birthday (March 26), and your app anniversary

### With a Claude API key (optional)

Everything above, plus:

- **Full AI chat** — streaming responses, code review, debugging help, any question
- **Personality-driven responses** — the active personality shapes every reply
- **API-generated greetings** — Director, Hype Coach, and Chatty modes generate live greetings instead of pulling from a pool
- **Director special mode** — when you open the Claude app with Director personality active, Claud-y fires a live API call for a one-sentence unhinged reaction

---

## 2. Getting Started

### Requirements

- macOS 15 Sequoia or later
- Xcode 16+ (to build from source)

### Build & Run

```bash
git clone https://github.com/yourusername/Claud-y.git
cd Claud-y
open Claudy/Claudy.xcodeproj
```

Build and run the `Claudy` scheme. Claud-y will appear in the bottom-right corner of your screen.

> **First launch:** A three-page welcome screen explains what Claud-y is, the two chat modes, and the privacy model. It only appears once.

### Adding an API Key (optional)

1. Get a key from [console.anthropic.com](https://console.anthropic.com)
2. Right-click Claud-y → **Settings** → paste your key → **Save Key**
3. Use **Test** to verify the connection
4. The key is stored in the macOS Keychain — never in UserDefaults, never synced to iCloud

---

## 3. Chat Modes

Tap Claud-y to open the chat panel. It slides up from below the character.

### Companion Mode (default)

**Always available. No setup. Nothing sent anywhere.**

The chat input is always active. Claud-y responds using a local keyword-intent engine — no network call, no latency. A 0.5–1.0s random delay is added so responses feel considered rather than instant.

A **typing indicator** (three bouncing orange dots) appears while the response is being "composed." Claud-y's eyes shift upward in a thinking expression during this time.

The chat header shows an orange **Companion** pill. Tap it to switch to API mode if you have a key saved.

#### What Claud-y understands locally

| Category | Example inputs |
|---|---|
| Greetings | hey, hi, hello, morning, g'day |
| How are you | how are you, you good, you okay |
| Thanks | thanks, cheers, appreciate it |
| Farewell | bye, cya, goodnight, logging off |
| Capabilities | what can you do, how do you work |
| Time / Date | what time is it, what's the date → system clock |
| Weather | honest deflect — can't check |
| Jokes | tell me a joke, make me laugh |
| It works | it works, fixed it, nailed it, cracked it |
| Stuck | i'm stuck, hitting a wall, going in circles |
| Broke everything | i broke it, everything is broken |
| Breakthrough | eureka, wait I think I've got it |
| Confused | doesn't make sense, why isn't this working |
| Hate this | hate this, this sucks, worst language |
| Stressed | stressed, overwhelmed, freaking out |
| Tired | tired, exhausted, running on fumes |
| Bored | bored, procrastinating, can't focus |
| Excited | excited, hyped, in the zone, flow state |
| Imposter syndrome | feel like a fraud, not good enough |
| Sad / bad day | rough day, not okay, feeling down |
| Working late | pulling an all-nighter, still working |
| Shipped | shipped it, went live, just released |
| PR / code review | pull request, waiting on review |
| Debugging | in the debugger, chasing a bug |
| Refactoring | refactor, tech debt, cleaning up |
| Testing | tests passing, tests failing, TDD |
| Meeting | standup, retro, sprint planning |
| Learning | learning, new framework, reading docs |
| New project | first day, blank slate, new repo |
| Compliments | you're great, you're helpful |
| API key / settings | how do I add a key, open settings |
| Are you AI | are you real, are you alive |
| Who made you | who built you, who created you |
| Reminders | remind me → honest deflect + focus timer pointer |

#### Easter eggs (40+)

Highest-priority exact/short matches — personality-independent:

| Input | Response |
|---|---|
| `42` | "I know. I have always known." |
| `ping` | "Pong." |
| `null` | "Ah. The void. I stare into it sometimes too." |
| `404` | "Not found. A feeling I know well." |
| `coffee` | "Go. Immediately. The code will be here when you get back." |
| `hello world` | "Classic. The one that started everything for so many of us." |
| `git blame` | "It was probably you. It is always you. It is okay." |
| `rm -rf` | "…I am going to pretend I did not read that." |
| `sudo make me a sandwich` | "Regrettably, I cannot make sandwiches." |
| `works on my machine` | "Congratulations on solving the most common bug in existence." |
| `undefined is not a function` | "The classic. The timeless. The wound that never fully heals." |
| `segfault` | "The universe politely asking you to check your pointers." |
| `deploy on friday` | "Are you sure? On a Friday? Are you absolutely certain?" |
| `it's not a bug` | "Sure it is. Update the docs. Ship it." |
| `¯\_(ツ)_/¯` | "Exactly. Sometimes that is the only correct answer." |
| `...` | "I'm here. Take your time." |
| …and 25+ more | — |

#### Personality-aware local responses

For key emotional intents, Claud-y picks from personality-specific pools:

- **Hype Coach** — short, loud, energetic. "STUCK? You are NOT stuck. You are PRE-SOLVING."
- **The Listener** — gentle, unhurried. "That's okay. What part feels hardest right now?"
- **The Director** — theatrical. "CHAOS IS JUST UNORDERED SUCCESS. REBUILD."
- **The Chatty One** — verbose, tangential, always circles back
- **The Mate** — casual, direct. "Yeah nah, you'll get it. What's the go?"
- All other personalities use the warm default pool

### API Mode (optional)

Full Claude AI streaming. The chat header shows a green **API** pill. Switch to it by tapping the mode pill or the "Use Claude AI" button in the chat header.

Responses stream token by token. The typing indicator appears until the first token arrives, then the bubble fills in live.

The active personality's system prompt is injected on every API call. Conversation history is sent in full on each request.

> **Privacy note:** In API mode, your messages are sent to Anthropic's API using the key you saved. Claud-y itself stores nothing — no logs, no analytics, no conversation history persisted to disk.

#### Long conversation warning

When a chat gets very long, a subtle inline warning appears:

- **~60,000 tokens** — "Long chat — consider starting fresh"
- **~80,000 tokens** — "This chat is getting very long — start a new one for best results"

Tapping either opens an alert to clear history. Nothing is shown for short conversations — no noise.

### Chat panel controls

| Control | Action |
|---|---|
| `×` button (or `Escape`) | Close chat |
| `↑` (share) button | Export conversation |
| Trash button | Clear history |
| Long-press any bubble (0.4s) | Copy message to clipboard |
| Drag resize handle at top | Resize panel height (200–600pt) |

### Export

The export sheet shows a transcript preview and offers:
- **Copy All** → clipboard
- **Save .txt** → `NSSavePanel` → UTF-8 file, default name `claud-y-chat.txt`

Format: `[HH:MM] You: …` / `[HH:MM] Claud-y: …`

### Markdown & code

Assistant responses render inline markdown (`**bold**`, `_italic_`, etc.) via `AttributedString`. Code fences (` ``` `) are parsed into code blocks with:
- Language label
- Copy button
- Horizontal scroll for wide lines
- Monospaced font

---

## 4. Personalities

Switch via right-click → **Personality**, or in Settings.

| Mode | Display Name | Voice | API Greetings |
|---|---|---|---|
| `companion` | The Companion | Warm, curious, witty, concise | No |
| `chatty` | The Chatty One | Verbose, tangential, always gets there, ≤200 words | Yes |
| `hype_coach` | The Hype Coach | Loud, energetic, ALL CAPS support, momentum-focused | Yes |
| `director` | The Director | Theatrical, dramatic, swears freely (never AT you) | Yes |
| `mate` | The Mate | Deadpan Australian, "yeah nah", understatement | No |
| `listener` | The Listener | Calm, asks good questions, 1am-friend energy | No |
| `custom` | You Do You | User-written persona applied to every response | No |

**Chatty mode** uses phrases like "which reminds me", "and actually", "here's the thing though". It takes the scenic route but always gets to the answer. Capped at 200 words so it's verbose, not endless.

**Director mode** with an API key active gets a live API-generated greeting and a special one-sentence reaction when you open the Claude desktop app.

**The Companion** is the default — helpful first, charming second.

Personality persists across sessions (`UserDefaults`).

---

## 5. Ambient Awareness

Claud-y watches what you're doing and reacts. All reactions come from `ReactionLibrary.json` — a bundled JSON file with pools of responses per trigger. The last 3 used responses per trigger are excluded from selection to avoid repetition.

Rate limits prevent spam: **45-second cooldown** between ambient bubbles. Maximum 3 bubbles can queue. Focus Mode (macOS Do Not Disturb) suppresses 4-in-5 ambient bubbles.

### Build & development

| What happened | Reaction |
|---|---|
| Xcode opened | Comment on switching to Xcode |
| Build started | Encouraging send-off |
| Build succeeded | Celebration — character celebrates + confetti |
| Build failed | Confused expression — stare reaction after 30s if not fixed |
| Build running > 60s | "Long compile wait" reaction |
| Long build finished | Special "welcome back" reaction |
| Breakpoint hit | Comment |
| Console error detected | Comment |
| npm running (Terminal frontmost) | Npm install reaction, once per session |
| Claude Code process detected | Celebration, vibe session timer starts |
| 20 min in Claude / Claude Code | Vibe coding session reaction |

### App switches

Claud-y reacts when you switch to these apps:

| App | Reaction style |
|---|---|
| Xcode | Developer solidarity |
| Figma | Design mode commentary |
| Terminal / iTerm2 / Warp / WezTerm / Kitty | Terminal energy |
| Zoom / Teams | Presents energy |
| Slack | Slack commentary |
| Cursor | Fellow AI tool acknowledgment |
| Claude desktop app | Celebration — optionally API-generated (Director mode) |
| **ChatGPT** | Warm, self-aware ("Visiting the neighbours. I respect it.") |
| **Perplexity** | Respectful ("The search for truth continues. Godspeed.") |
| **Spotify** | Music / dance vibe |
| **Apple Music** | Music vibe |
| **Google Chrome** | Web commentary |
| **Notion** | Notes/productivity mode |
| **Obsidian** | Writing mode |
| **TablePlus / Postico / Sequel** | Database tools commentary |

Rival AI reactions (ChatGPT, Perplexity) are always warm and good-natured — Claud-y is confident, not threatened.

### Keyboard & clipboard

| Trigger | When |
|---|---|
| Typing burst | Fast sustained typing |
| Typing pause | Long pause mid-session |
| Cmd+Z spam | Undo pressed 3+ times rapidly |
| Cmd+S | Save detected |
| Fast copy-paste | Cmd+C then Cmd+V within ~1s |
| Tab spam | Many tabs rapidly |
| Cmd+W spam | Multiple window closes |
| Caps Lock | Enabled |
| Text copied | Plain text clipboard |
| Code copied | Code-like content detected |
| URL copied | Link copied |
| Repeated paste | Same content pasted again |

### System events

| Trigger | When |
|---|---|
| Screenshot | Screenshot shortcut detected |
| App crash | App terminated unexpectedly |
| Battery low | Below 20% |
| Wi-Fi lost | Connectivity dropped |
| Wi-Fi back | Reconnected |

### Time & calendar

| Trigger | When |
|---|---|
| Monday morning | Launched on Monday |
| Friday | Launched on Friday |
| Hourly chime | On the hour (9am, 5pm, midnight have special messages) |
| New Year's Day | January 1 |
| Christmas | December 25 |
| Claud-y's birthday | March 26 |
| App anniversary | Same date as first launch, 1+ years later |
| Australian holidays | Jan 26, ANZAC Day, Easter, Boxing Day |

### Idle & sleep

| State | After |
|---|---|
| Drowsy (half-closed eyes, slow bob) | 5 minutes of inactivity |
| Sleeping (closed eyes, Zs) | 10 minutes of inactivity |
| Wake greeting | Any activity after sleeping/drowsy |
| Late-night mood (after midnight + drowsy) | Midnight + 5min idle |

### Greeting on launch

Three seconds after launch, Claud-y greets you based on time of day:

| Time | Context |
|---|---|
| 6am–11am | Morning greeting |
| 12pm–9pm | Afternoon greeting |
| 10pm–11pm | Late night greeting |
| Midnight–5am | Very late night greeting |

There's a 1-in-4 chance of a "memory greeting" instead — e.g. "Oh, you're back. I kept our last session in mind." No actual memory is stored; it's a warmth illusion.

Director, Hype Coach, and Chatty personalities use live API-generated greetings when a key is present.

### Streak tracking

Claud-y records each day you use it. Once you've used it 3+ consecutive days, a streak message fires 8 seconds after the launch greeting. Shown once per day maximum. History kept for 90 days.

---

## 6. Focus Timer (Pomodoro)

Right-click → **Start Focus Timer** to begin a focus session. The timer floats above Claud-y's head as a circular progress badge.

### Presets

| Name | Duration |
|---|---|
| Short | 15 minutes |
| Classic | 25 minutes (default) |
| Long | 45 minutes |
| Deep | 60 minutes |
| Custom | 5–120 minutes (set in Settings) |

The active preset persists between sessions. Changing it mid-session has no effect — takes effect on next start.

### Timer states

| State | Badge appearance |
|---|---|
| Running | Orange arc, countdown |
| Paused | Yellow arc, pause icon |
| Last 5 minutes | Red-orange arc (urgency) |
| Complete | Confetti + celebration |

Tap the badge to pause or resume.

### Milestone reactions

These fire automatically via `showBubbleDirect` (bypasses the 45s cooldown):

| Milestone | When |
|---|---|
| Start | Timer begins |
| 5 minutes in | After 5 min elapsed |
| Halfway | When half the session is done |
| 5 minutes left | When 5 min remain |
| 1 minute left | When 1 min remains |
| Done | Timer completes → confetti + celebration |

### Context menu controls

| State | Menu items |
|---|---|
| Idle | "Start Focus Timer (Xm)" |
| Running | "⏸ Pause Timer (MM:SS)" · "⏹ Stop Timer" |
| Paused | "▶ Resume Timer (MM:SS)" · "⏹ Stop Timer" |

---

## 7. Character & Expressions

Claud-y is a 90×72pt rounded orange rectangle with expressive Pixar-style eyes, nub arms, and four small feet. It lives in a 150×150pt floating transparent panel.

### Animation states

| State | What it looks like | When |
|---|---|---|
| `idle` | Gentle floating bob | Default |
| `thinking` | Three pulsing dots where eyes should be | Waiting for response |
| `talking` | Mouth opens and closes | During streaming reply |
| `celebrating` | Arms raised, big smile, bouncing | Build success, Pomodoro done |
| `confused` | Round surprised mouth | Build failure, confusion |
| `sleeping` | Flat closed eyes, slow bob, Zs | After 10 min idle |
| `drowsy` | Half-closed eyes, slower bob | After 5 min idle |
| `alert` | Slightly enlarged eyes | Hover |
| `tickled` | Arc-down happy eyes, tooth grin | Touch/tickle interaction |
| `surprised` | Wide eyes + "!" bubble, quick jump | Double-tap, startled |

### Drag & tilt

Drag Claud-y anywhere on screen. While dragging, the character tilts in the direction of movement (±8° max), then bounces back with a spring settle when released. Position is saved to `UserDefaults` and restored on next launch.

If Claud-y flies off screen, right-click → **Reset Position** to bring it back to the bottom-right corner.

### Tickle system

Hover over Claud-y or hold the mouse on it for escalating reactions:
1. Hover → `.alert` (eyes widen)
2. Brief press → `.tickled` (laugh expression)
3. Sustained → full tickle (arm flair, bigger laugh)
4. Sudden move → `.surprised` (jump + "!" bubble)

### Confetti

A 24-particle burst fires on:
- Successful Xcode build
- Pomodoro completion
- First launch onboarding
- Vibe coding session (20 min with Claude/Claude Code)

### Reaction log (Easter egg)

**Long-press Claud-y for 3 seconds** to reveal the reaction history — every speech bubble Claud-y has shown, with timestamps, in reverse chronological order. Max 50 entries.

### Size

Right-click → **Size** to change Claud-y's visual scale:

| Size | Scale |
|---|---|
| Small | 60% |
Medium | 80% |
| Large | 100% (default) |

The floating panel stays the same size — only the character scales.

---

## 8. Settings & Customisation

Right-click → **Settings** to open the settings panel.

### API Key

- Paste your Anthropic API key (`sk-ant-…`)
- **Save Key** stores it in the macOS Keychain
- **Test** verifies the connection
- **Remove Key** deletes it from the Keychain
- Key is device-only (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`) — never synced to iCloud

### Personality Mode

Picker for all 7 modes. When **You Do You** is selected, a text editor appears for your custom persona description.

### Chat Model

| Model | Use |
|---|---|
| Haiku 4.5 (fast) | Default — quick responses, lower cost |
| Sonnet 4.6 (smart) | Better reasoning, slower |
| Haiku 3.5 (fallback) | Older, if needed |

Toggle: **Use Opus for complex tasks** — when on, long/complex tasks use `claude-opus-4-6` with 4096 token budget.

Ambient reactions always use `claude-3-5-haiku-20241022` at 60 tokens regardless of this setting.

### Sound Effects

Toggle on/off. Three sounds:
- **Pop** — on every speech bubble
- **Glass** — on a successful build
- **Hero** — on Pomodoro completion / confetti

Off by default.

### Focus Timer

Preset picker (Short / Classic / Long / Deep / Custom). When Custom is selected, a stepper sets the duration (5–120 minutes in 5-minute steps).

### Quick Launch

Up to 3 app shortcuts. Each has a name, bundle ID, and optional `⌘` key. Shortcuts appear in the right-click context menu under **Launch**.

---

## 9. Keyboard Shortcuts & Gestures

| Action | How |
|---|---|
| Open / close chat | Single tap on Claud-y |
| Open chat + surprise animation | Double-tap on Claud-y |
| Close chat | `Escape` key |
| Mute / unmute | `Option+M` |
| Copy message | Long-press bubble (0.4s) |
| View reaction log | Long-press Claud-y (3s) |
| Resize chat | Drag the handle at the top of the panel |
| Move Claud-y | Drag the character |
| Reset Claud-y's position | Right-click → Reset Position |
| Quick launch shortcuts | Right-click → Launch → `⌘ + key` |
| Pause/resume Pomodoro | Tap the timer badge |

---

## 10. Architecture Overview

```
AppDelegate (NSStatusItem, settings window, menu bar)
    │
FloatingWindowController (NSPanel host)
    └─ CharacterRootView (SwiftUI root)
         ├─ ClaudyCharacterView   animated character, drag handling
         ├─ ChatView              chat tray, slides up from below
         ├─ SpeechBubbleView      reaction bubbles above character
         ├─ PomodoroTimerBadge    circular progress arc over character
         ├─ TypingIndicatorView   3-dot bounce animation in chat
         ├─ ConfettiView          celebration particle burst
         └─ ReactionLogView       reaction history popover (3s long-press)

ViewModels  (@Observable, all @MainActor)
  CharacterViewModel     master state, bubble queue, mood, confetti
  ChatViewModel          messages, streaming, local routing, context warning
  WindowManager          panel position, size preset, chat height
  PersonalityManager     active mode, system prompt injection, greetings
  PomodoroManager        countdown, presets, pause/resume, milestones

Services
  ClaudeAPIService       actor — REST + SSE streaming, rate limiting
  ReactionLibraryService JSON pools, recency deduplication
  LocalChatResponder     companion mode intent matching
  KeychainService        API key — save / load / delete

Monitors  (owned by CharacterViewModel)
  IdleMonitor            inactivity, greetings, chimes, streaks, special days
  AppContextMonitor      app switches, builds, npm — unified 15s poll loop
  ClipboardMonitor       clipboard content classification
  KeyboardMonitor        typing patterns, Cmd+Z spam, Cmd+S
  TickleManager          hover → tickle escalation
  SystemEventMonitor     battery, Wi-Fi, screenshots, app crashes
```

### Key design decisions

**`@Observable` not `ObservableObject`** — all view models use the Swift 5.9+ `@Observable` macro for simpler, more efficient observation.

**`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** — all types are implicitly `@MainActor`. The one exception is `ClaudeAPIService`, which is an explicit `actor` to manage concurrent API calls.

**`NSEvent.mouseLocation` for drag** — SwiftUI's `DragGesture.translation` shifts coordinate origin as the window moves, causing erratic movement. The drag implementation ignores SwiftUI's translation and uses `NSEvent.mouseLocation` (true screen coordinates) instead.

**Single poll loop** — `AppContextMonitor` runs one 15-second `Task.sleep` loop that handles Xcode build detection, npm detection, and Claude Code detection (every other tick). Previously three separate loops.

**Reaction library deduplication** — `ReactionLibraryService` tracks the last 3 responses used per trigger and excludes them from the next draw, preventing the same line from appearing twice in a row.

**Local chat with typing delay** — `LocalChatResponder` adds a 0.5–1.0s random delay before responding. This is intentional — instant responses feel robotic. The delay is spent showing the typing indicator and setting the `.thinking` character state.

---

## 11. File Map

```
Claudy/
├── ClaudyApp.swift               App entry, .accessory policy (no Dock icon)
├── AppDelegate.swift             NSStatusItem, menu bar, settings window
├── FloatingPanel.swift           NSPanel: floating, non-activating, borderless
├── FloatingWindowController.swift Hosts CharacterRootView, restores position
│
├── CharacterRootView.swift       Root SwiftUI view: character + chat + overlays
├── ClaudyCharacterView.swift     Animated character — do not refactor without reading CLAUDE.md
├── LottieCharacterView.swift     Lottie integration wrapper
├── SpeechBubbleView.swift        Speech bubble popup above character
├── PomodoroTimerBadge.swift      Circular progress arc badge for focus timer
├── TypingIndicatorView.swift     Three-dot bounce animation (chat typing state)
├── ConfettiView.swift            24-particle celebration burst
├── ReactionLogView.swift         Reaction history popover
│
├── CharacterViewModel.swift      @Observable master view model
├── CharacterAnimationState.swift Enum: 10 animation states + TickleIntensity
├── WindowManager.swift           Panel position, SizePreset, chat height
│
├── ChatView.swift                Chat tray UI: messages, input, header, export
├── ChatViewModel.swift           Messages, streaming, local routing, context warning
├── LocalChatResponder.swift      Companion Mode: 22 intents + Easter eggs + personality pools
│
├── PersonalityManager.swift      7 personality modes, system prompt injection
│
├── IdleMonitor.swift             Inactivity, greetings, chimes, streaks, special days
├── AppContextMonitor.swift       App switches + unified 15s poll loop
├── ClipboardMonitor.swift        Clipboard content watcher + classifier
├── KeyboardMonitor.swift         Typing burst, Cmd+Z spam, shortcut detection
├── TickleManager.swift           Hover → tickle escalation stages
├── ContextMonitor.swift          Window-level context bridge
├── SystemEventMonitor.swift      Battery, Wi-Fi, screenshots, app crashes
│
├── ClaudeAPIService.swift        actor — REST streaming, MessagePriority routing
├── KeychainService.swift         Save/load/delete API key, device-only
├── ReactionLibraryService.swift  JSON reaction pools, recency deduplication
│
├── PomodoroManager.swift         Focus timer: presets, pause/resume, milestones
├── SoundManager.swift            NSSound effects gated by Settings toggle
├── QuickLaunchManager.swift      Up to 3 app shortcuts, NSWorkspace launch
├── StreakManager.swift           Daily session recording, streak count + message
│
├── SettingsView.swift            All settings: key, model, personality, sound, timer, shortcuts
│
└── Resources/
    ├── SystemPrompt.txt          Base system prompt (personality injected at runtime)
    ├── ReactionLibrary.json      All reaction pools — 90+ trigger keys
    └── Animations/               Lottie JSON files (one per CharacterAnimationState name)
```

---

## 12. Security & Privacy

### API key

- Stored in the **macOS Keychain** only (`kSecClassGenericPassword`)
- `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — **never synced to iCloud Keychain**
- Never written to `UserDefaults`, logs, or any file
- Sent as `x-api-key` HTTP header only — never in URL or request body

### Process inspection

Claud-y detects running processes (`xcodebuild`, `npm`, `claude`) using `sysctl KERN_PROC_ALL` with `kinfo_proc`. This reads process names only — no process memory, no arguments, no content. Works without sandbox entitlements.

### No analytics

No telemetry. No crash reporting services. No remote logging. All `OSLog` output stays on device.

### No sandbox

Claud-y runs without App Sandbox to allow:
- `sysctl` process inspection
- Global `NSEvent` keyboard monitoring (requires Accessibility permission)

This means it cannot be distributed via the Mac App Store as-is.

### Network

All API calls go to `https://api.anthropic.com` over HTTPS. No other network connections are made.

---

## 13. Data & Persistence

Everything except the API key is stored in `UserDefaults`:

| Key | What it stores |
|---|---|
| `CharacterWindowOrigin` | Last panel position `[Double, Double]` |
| `CharacterSizePreset` | `"small"` / `"medium"` / `"large"` |
| `ClaudyChatHeight` | Chat panel height in points |
| `PersonalityMode` | Active personality raw value |
| `CustomPersonaText` | User-written custom persona |
| `SelectedModel` | Active Claude model identifier |
| `UseComplexModel` | Bool — Opus for complex tasks |
| `IsMuted` | Bool — mute state |
| `SoundEffectsEnabled` | Bool — sound toggle |
| `HasSeenOnboarding` | Bool — first launch flag |
| `FirstLaunchDate` | `Date` — for anniversary reactions |
| `DailySessionDates` | `[String]` ISO dates — streak tracking (90-day window) |
| `StreakShownDate` | `String` — prevents repeat streak messages same day |
| `QuickLaunchShortcuts` | `Data` — JSON-encoded shortcut array |
| `PomodoroPreset` | `Int` raw value of active `PomodoroPreset` |
| `PomodoroCustomMinutes` | `Int` — custom timer duration (5–120) |

**Chat history is not persisted.** It lives in memory for the session only. Use the export function to save it.

---

## 14. Accessibility

- All interactive elements have `accessibilityLabel` and `accessibilityHint`
- Claud-y character: label "Claud-y", value = current animation state, hint reflects chat open state
- Every new speech bubble posts an `AccessibilityNotification.Announcement`
- `@Environment(\.accessibilityReduceMotion)` respected — bob, wiggle, jump, and celebration animations suppressed when enabled
- All animation states expose an `accessibilityDescription` string
- Chat bubbles: long-press hint visible to VoiceOver
- Keyboard: `Escape` closes chat, `Option+M` mutes, quick launch shortcuts configurable
- Header buttons: 32pt tap targets, all labelled

---

## 15. Known Limitations

| Item | Detail |
|---|---|
| **Accessibility permission required** | Global keyboard monitoring requires the user to grant Accessibility access in System Settings. Without it, keyboard reactions don't fire. |
| **No App Store distribution** | App Sandbox is disabled to allow `sysctl` and global event monitoring. Distribution is source-only / direct download. |
| **Build detection latency** | Xcode build polling runs every 15 seconds. Reactions may appear up to 15s after a build starts or ends. |
| **Chat history not persisted** | Conversations exist in memory only. Exporting is the only way to save them. |
| **Lottie animations optional** | If `.json` Lottie files are missing from `Resources/Animations/`, the SwiftUI fallback layer is used. The character still works fully. |
| **Focus Mode detection** | Uses `com.apple.doNotDisturb.state.changed` distributed notification. May not fire with all macOS Focus configurations. |
| **npm detection** | Fires once per session and only when a Terminal-family app is frontmost. |
| **Growing context window** | Full conversation history is sent on every API call. Long sessions increase latency and cost. The context warning UI helps manage this. |
| **Multi-monitor** | If your monitor setup changes between sessions, the saved position may be off-screen. Use Reset Position from the right-click menu. |

---

## 16. Contributing

Claud-y is open source and contributions are welcome.

### Things to know before diving in

- Read `CLAUDE.md` at the project root — it has architecture rules and lists files that shouldn't be restructured without discussion
- `ClaudyCharacterView.swift` is the most delicate file — the character drawing is precise and small changes can have outsized visual effects
- All new `.swift` files are auto-included via `PBXFileSystemSynchronizedRootGroup` — no manual project file editing needed
- The `ReactionLibrary.json` file is the easiest place to contribute — add reaction pools, improve existing ones, or extend to new triggers

### Adding a new reaction trigger

1. Add a case to `ReactionTrigger` in `ReactionLibraryService.swift`
2. Add a matching key + pool to `ReactionLibrary.json`
3. Call `ReactionLibraryService.shared.reaction(for: .yourTrigger)` and pass to `viewModel.showSpeechBubble()`

### Adding a new personality

1. Add a case to `PersonalityMode` in `PersonalityManager.swift`
2. Add `displayName` and `promptBlock`
3. Optionally add personality-specific pools to `LocalChatResponder.swift` for the intents that matter
4. Set `usesAPIGreetings` to `true` if the personality should use live API greetings

### Lottie animations

Drop Lottie JSON files into `Resources/Animations/`. Name them to match `CharacterAnimationState` raw values (`idle.json`, `thinking.json`, etc.). The `LottieCharacterView` wrapper picks them up automatically.

---

*Built with Swift + SwiftUI + the Anthropic Claude API.*
*Free forever. No telemetry. Your API key stays on your device.*
