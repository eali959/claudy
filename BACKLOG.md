# Claud-y — Full Feature Backlog

> Use this as a prompt to build features in order. Each phase is self-contained and buildable independently. Confirm each compiles before proceeding to the next.

---

## Pending from Master Prompt (Phase 3 onwards)

### Phase 3 — Polish & Model Names *(in progress — nearly done)*

**Goal:** Finish wiring the "Remove Key" confirmation dialog and confirm build.

- [x] Update model names in `MessagePriority` (`.reaction` → `"claude-haiku-3-5"`, `.complex` → `"claude-opus-4-5"`)
- [x] Update companion mode banner text in `ChatView.swift` to spec
- [x] Add `@State private var showRemoveConfirm = false` to `SettingsView.swift`
- [ ] Wire `showRemoveConfirm` to the "Remove Key" button as `.confirmationDialog`
- [ ] **Fix: correct model IDs** — `"claude-haiku-3-5"` → `"claude-3-5-haiku-20241022"` and `"claude-opus-4-5"` → `"claude-opus-4-6"` (see Bug Report)

**Files:** `SettingsView.swift`, `ClaudeAPIService.swift`

---

### Phase 4 — Mute Mode

**Goal:** Let users silence all ambient bubbles without closing the app.

- Add `isMuted: Bool` to `CharacterViewModel`, persisted in `UserDefaults("IsMuted")`
- Suppress all ambient `showSpeechBubble()` calls when muted — no greetings on launch or wake
- Chat panel continues to work normally when muted
- 🔇 icon near character, bottom-right corner, 12pt, 40% opacity (already done per `CharacterRootView`)
- Right-click context menu: "Mute" / "Unmute" with checkmark (already done per `CharacterRootView`)
- Keyboard shortcut: ⌥M when app is focused (already in context menu)
- On unmute: play `ReactionLibraryService.shared.reaction(for: .muteOff)` as confirmation

**Files:** `CharacterViewModel.swift`, `CharacterRootView.swift`

---

### Phase 5 — Greeting System

**Goal:** API-generated greetings for Director and Hype Coach; screen lock return greeting; `.veryLateNight` fully wired.

- API-generated greetings for `.director` and `.hypeCoach` (unique each time, `.reaction` priority)
  - Director: dramatic, swears at the situation ("You again. Good. I have been staring at this empty canvas.")
  - Hype Coach: explosive morning energy ("YOU'RE HERE. IT'S HAPPENING. LET'S GO.")
- `.veryLateNight` context fully wired in `IdleMonitor` (already added to `GreetingContext` enum)
- Show greeting on screen lock return via `com.apple.screenIsUnlocked` (already in `IdleMonitor.startScreenLockMonitoring`)
- `PersonalityManager.asyncGreeting(for:)` already exists — wire it fully in `IdleMonitor`

**Files:** `PersonalityManager.swift`, `IdleMonitor.swift`

---

### Phase 6 — Developer Context Detection

**Goal:** Detect real developer workflows and react meaningfully.

- **Cursor detection** — bundle ID `com.todesktop.230313mzl4w4u92` (already in `ambientTrigger`)
- **Xcode build monitoring** — sysctl for `xcodebuild` process, already implemented:
  - `xcode_build_start` on process appearance
  - `xcode_build_success` / `xcode_build_fail` heuristic (< 8s = fail)
  - `xcode_build_stare` — 30s after fail: encouragement bubble
  - **Long compile awareness** — if build runs > 60s, fire special bubble: "That is a long build. Go get a coffee. I will wait." On finish: "Welcome back. It is done."
- **Vibe coding session** — Claude or Claude Code open for 20+ continuous minutes → `vibe_coding_session` (already implemented)
- **npm/install detection** — Terminal frontmost + `npm` process running → `npm_install` (already implemented)
- **StackOverflow detection** — limited to browser URL bar detection via Accessibility API or heuristic (Safari/Chrome frontmost + recent clipboard URL containing "stackoverflow")

**Files:** `AppContextMonitor.swift`

---

### Phase 7 — QoL Touches

**Goal:** Polish, personality, and hidden delights.

- **Drag tilt ±8°** — when dragging character, apply rotation in the direction of movement with `rotationEffect`. Spring-settle back to 0° on drag end. Track delta in `WindowManager.updateDrag`. Pass tilt angle to `ClaudyCharacterView` as a `@Binding`.
- **Double-click to chat** — already implemented in `CharacterRootView.handleDoubleTap`. Add a short `beSurprised()` → `celebrate()` animation sequence before opening.
- **Memory greeting illusion** — 1-in-4 chance on launch, show a fake "memory" greeting from `IdleMonitor.memoryGreetings` pool (already implemented).
- **First launch onboarding** — 3 sequential bubbles with delays (already in `IdleMonitor.scheduleOnboarding`). Add bounce-in animation on first launch.
- **Seasonal reactions** — Jan 1 (New Year), Dec 25 (Christmas), Mar 26 (birthday), launch anniversary (already in `IdleMonitor.checkSpecialDays`).
- **Focus/DND mode detection** — reduce reactions 80%, suppress greetings, show 🌙 icon (already implemented in `CharacterViewModel.isFocusModeActive`).

**Files:** `WindowManager.swift`, `ClaudyCharacterView.swift`, `IdleMonitor.swift`

---

## Chat Panel Polish

### Phase 8 — Chat UX Overhaul

**Goal:** Make the chat panel genuinely great to use.

**8a — Close Button**
- Add an `×` button in the chat header, right-aligned, next to the trash icon
- Tapping it closes the chat panel (`chatViewModel.isOpen = false`)
- Also wire Escape key to close the panel when it is focused

**8b — Export / Save Chat Log**
- "Export" button in the chat header (SF Symbol: `square.and.arrow.up`)
- On tap: show an action sheet / NSPanel with options:
  - **Copy all** — copies full conversation as plain text to clipboard
  - **Save as .txt** — `NSSavePanel` to choose location, saves formatted log
  - **Share** — macOS share sheet (`NSSharingServicePicker`)
- Format: `[HH:MM] You: …` / `[HH:MM] Claud-y: …`

**8c — Markdown Rendering**
- Replace `Text(message.content)` in `MessageBubble` with a Markdown-aware renderer
- Use SwiftUI's built-in `Text(AttributedString)` with `AttributedString(markdown:)` for basic rendering
- Supports: `**bold**`, `*italic*`, `` `code` ``, `# headings`, `- lists`, `> blockquotes`
- For code blocks (` ``` `), use a custom `CodeBlockView` with monospaced font + light grey background + copy button
- Wrap in a `ScrollView` within `MessageBubble` if content is very long

**8d — Tap-to-Copy on Messages**
- Long-press on any message bubble → copy content to clipboard
- Brief "Copied" tooltip overlay using an `.overlay` with opacity transition

**8e — Scroll-to-Bottom Button**
- When scrolled up, show a small floating `↓` button (SF Symbol: `arrow.down.circle.fill`) at bottom-right of message list
- Tapping it smooth-scrolls to the latest message
- Auto-hide when already at bottom (track scroll offset via `GeometryReader` or `PreferenceKey`)

**8f — Token / Character Estimate**
- Small footer below input bar: `~{N} tokens in context`
- Estimate: `messages.reduce(0) { $0 + ($1.content.count / 4) }` (rough 4 chars/token)
- Update live as messages accumulate
- Greyed out, small monospaced text

**Files:** `ChatView.swift`, `ChatViewModel.swift`

---

## Character & Expression

### Phase 9 — Mood System

**Goal:** Claud-y's animation state reflects the current context without API calls.

Wire existing animation states to meaningful triggers:

| Context | State |
|---|---|
| Clean build | `.celebrating` (already fires) |
| Build fail > 30s stare | `.confused` |
| After midnight | `.drowsy` if idle |
| Zoom/Teams active | `.alert` (work is happening) |
| npm install running | `.thinking` |
| Muted | No change (🔇 shows instead) |
| Vibe coding session | `.celebrating` briefly, then `.idle` |

- Add `applyMood(for context: MoodContext)` to `CharacterViewModel`
- `MoodContext` enum: `.postBuildSuccess`, `.postBuildFail`, `.lateNight`, `.npmRunning`, `.zoomActive`
- Call from `AppContextMonitor` and `IdleMonitor` at the right moments
- No new Lottie states — map to existing `CharacterAnimationState` cases

**Files:** `CharacterViewModel.swift`, `AppContextMonitor.swift`, `IdleMonitor.swift`

---

### Phase 10 — Size Toggle

**Goal:** Users can resize Claud-y to suit their screen real estate preferences.

- Three sizes: Small (60pt), Medium (90pt, default), Large (120pt)
- Persisted in `UserDefaults("CharacterSize")`
- Right-click context menu: `Menu("Size") { Button("Small") … Button("Medium") … Button("Large") … }`
- `WindowManager` updates panel frame with `spring` animation on size change
- `WindowManager.characterSize` becomes dynamic (was a `static let`)
- Chat panel width scales proportionally

**Files:** `WindowManager.swift`, `CharacterRootView.swift`, `CharacterViewModel.swift`

---

## Developer-Specific Features

### Phase 11 — Pomodoro Mode

**Goal:** Built-in focus timer with Claud-y as your timekeeper.

- Right-click context menu: "Start Focus Timer (25 min)" / "Stop Timer"
- `PomodoroManager` class (new file), `@Observable`, owned by `CharacterViewModel`
- State: `.idle`, `.running(remaining: TimeInterval)`, `.done`
- Uses `Timer` (or `Task.sleep` loop) — ticks every 60s
- UI: compact countdown bubble updates every minute e.g. "23 min remaining."
- Reactions:
  - At 12m30s: fire `pomodoro_halfway` from `ReactionLibrary.json` ("Still going. Halfway there.")
  - At 0:00: `celebrate()` + confetti burst + `pomodoro_done` bubble ("Done. You did the thing.")
  - On cancel: quiet, no bubble
- Cancel via right-click → "Stop Timer"
- Add `pomodoro_halfway` and `pomodoro_done` keys to `ReactionLibrary.json`
- Add `case pomodoroHalfway = "pomodoro_halfway"` and `case pomodoroDone = "pomodoro_done"` to `ReactionTrigger`

**Files:** `PomodoroManager.swift` (new), `CharacterViewModel.swift`, `CharacterRootView.swift`, `ReactionLibraryService.swift`, `ReactionLibrary.json`

---

### Phase 12 — Long Compile Awareness

**Goal:** React specifically when builds drag on.

- Already tracking `xcodeBuildStartTime` in `AppContextMonitor`
- In `startXcodeBuildMonitor`, when `isBuilding && xcodeBuildStartTime != nil`:
  - If elapsed > 60s and `longCompileReacted == false`: fire `long_compile_wait` bubble
  - Set `longCompileReacted = true`
- On build end, if `longCompileReacted`:
  - Fire `long_compile_done` bubble ("Welcome back. It is done.")
  - Reset `longCompileReacted = false`
- Add `long_compile_wait` and `long_compile_done` to `ReactionLibrary.json` and `ReactionTrigger`

**Files:** `AppContextMonitor.swift`, `ReactionLibrary.json`, `ReactionLibraryService.swift`

---

### Phase 13 — Additional App Detection

**Goal:** React to more apps the user switches into.

Add to `ambientTrigger(for:)` in `AppContextMonitor`:

| App | Bundle ID | Trigger Key |
|---|---|---|
| TablePlus | `com.tableplus.TablePlus` | `app_database` |
| Postico | `com.eggerapps.Postico2` | `app_database` |
| DBngin | `com.sequel-ace.sequel-ace` (also `com.sequel-pro.sequel-pro`) | `app_database` |
| Notion | `notion.id` | `app_notion` |
| Obsidian | `md.obsidian` | `app_obsidian` |
| Spotify | `com.spotify.client` | `app_spotify` |
| Apple Music | `com.apple.Music` | `app_music` |
| Google Chrome | `com.google.Chrome` | `app_google` |
| ChatGPT | `com.openai.chat` | `app_chatgpt` |
| Perplexity | `com.perplexity.PerplexityiOS` | `app_perplexity` |

Add to `ReactionTrigger` enum:
```swift
case appDatabase    = "app_database"
case appNotion      = "app_notion"
case appObsidian    = "app_obsidian"
case appSpotify     = "app_spotify"
case appMusic       = "app_music"
case appGoogle      = "app_google"
case appChatGPT     = "app_chatgpt"
case appPerplexity  = "app_perplexity"
```

Add reaction pools to `ReactionLibrary.json`:

```json
"app_database": [
  "Database open. Tread carefully.",
  "Migrations are irreversible. Just saying.",
  "I respect this energy. And fear it.",
  "Do not drop the table. Please.",
  "Here we go. Schema spelunking."
],
"app_notion": [
  "Documentation time. A rare and noble act.",
  "Oh, writing things down. Very civilised.",
  "Notion open. This must be serious.",
  "The doc lives. Update it.",
  "This means you are planning something. I am here for it."
],
"app_obsidian": [
  "Second brain activated.",
  "Obsidian. Where thoughts go to become graphs.",
  "Notes. The good kind.",
  "Documentation mode engaged. I approve.",
  "Writing things down. Future you will thank you."
],
"app_spotify": [
  "Music on. We are in the zone.",
  "Ooh, a soundtrack for this session. Nice.",
  "Let me guess — lo-fi hip hop?",
  "Music detected. Productivity incoming.",
  "I cannot hear it but I feel the energy.",
  "Now we are cooking. What's playing?"
],
"app_music": [
  "Apple Music. Taste confirmed.",
  "Music time. Let's go.",
  "A playlist and a purpose. This is the way.",
  "The vibes are being set. I see you.",
  "Turn it up. We are building things."
],
"app_google": [
  "Googling it. Classic.",
  "The oracle of the internet. Let's see.",
  "Research mode. I respect this.",
  "Answers incoming. Probably.",
  "The search begins."
],
"app_chatgpt": [
  "Oh. Hello. I see how it is.",
  "Consulting the competition. Fair enough.",
  "I am not jealous. I am just... noting it.",
  "Getting a second opinion? Bold.",
  "You know I am right here, yes?"
],
"app_perplexity": [
  "Perplexity. The curious cousin.",
  "Another AI. We are all family, I suppose.",
  "Deep research mode. I respect the hustle.",
  "Good question, whatever it is.",
  "The search engine that talks back. Relatable."
]
```

**Files:** `AppContextMonitor.swift`, `ReactionLibraryService.swift`, `ReactionLibrary.json`

---

## Small Personality Touches

### Phase 14 — Sound Effects (opt-in)

**Goal:** Optional audio feedback that makes Claud-y feel alive.

- New `SoundManager.swift` — `@MainActor final class`, `static let shared`
- Uses `AVFoundation.AVAudioPlayer` (or `NSSound` for simplicity)
- Sounds (all < 200ms, system-adjacent):
  - `bubble_pop` — tiny pop when a speech bubble appears (use `NSSound(named:)` or bundled .aiff)
  - `clean_build_chime` — soft chime on `xcode_build_success`
  - `celebrate_ding` — bright note on Pomodoro completion
- One toggle in `SettingsView`: "Sound effects" → `@AppStorage("SoundEffectsEnabled") var soundEffectsEnabled = false`
- `SoundManager.play(.bubblePop)` called from `CharacterViewModel.displayBubble()`
- Zero overhead when disabled (guard at the top of `play()`)

**Files:** `SoundManager.swift` (new), `CharacterViewModel.swift`, `SettingsView.swift`

---

### Phase 15 — Confetti Burst

**Goal:** Celebrate clean builds and first launch with a particle burst.

- New `ConfettiView.swift` — pure SwiftUI, no library
- Uses `TimelineView(.animation)` + `Canvas` to draw ~20 particles
- Each particle: random start position, random colour (orange, teal, yellow, white), random size 4–8pt
- Physics: gravity + horizontal drift, 1.5s lifespan, opacity fades from 1→0
- `ConfettiView` is shown as a `.overlay` on `CharacterRootView`, positioned above the character
- Exposed as `CharacterViewModel.triggerConfetti()` — sets `showConfetti = true`, auto-clears after 2s
- Triggers: clean build (`xcodeBuildSuccess`), first launch onboarding end, Pomodoro completion
- No external library — SwiftUI `Canvas` only

**Files:** `ConfettiView.swift` (new), `CharacterRootView.swift`, `CharacterViewModel.swift`

---

### Phase 16 — Quick Launch Shortcuts

**Goal:** Make Claud-y a genuine launcher, not just reactive.

- Up to 3 configurable shortcuts stored in `UserDefaults` as `[[String: String]]`
  - Keys: `"name"`, `"bundleID"` or `"path"`
- Settings section "Quick Launch" — allows adding/removing shortcuts
  - Text field for display name
  - Text field for bundle ID or app path
  - "Add" button, list of current shortcuts with delete button
- Shortcuts appear in right-click context menu under a "Launch" submenu
- Launch using `NSWorkspace.shared.launchApplication(withBundleIdentifier:options:additionalEventParamDescriptor:launchIdentifier:)`
- If bundle ID not found, fall back to `NSWorkspace.shared.open(URL(fileURLWithPath: path))`
- Show `beSurprised()` animation on launch

**Files:** `SettingsView.swift`, `CharacterRootView.swift`, `QuickLaunchManager.swift` (new)

---

## Long-Term Polish

### Phase 17 — Streaks

**Goal:** Subtle acknowledgement of consistent usage that feels genuine.

- Track daily active sessions in `UserDefaults("DailySessionDates")` as `[String]` (ISO date strings)
- `StreakManager.swift` — checks on launch if today is already recorded, appends if not
- Calculate current streak: count consecutive days going back from today
- Streak bubble shown once per day on launch, only if streak ≥ 3:
  - 3 days: "Three days running. I keep track of these things."
  - 5 days: "Five days in a row. You are forming a habit."
  - 7 days: "One week straight. I am proud of us."
  - 30 days: "Thirty days. I am basically furniture at this point."
- Max shown once per day — `UserDefaults("LastStreakShownDate")`
- Streak shown 8s after launch greeting to avoid overlap

**Files:** `StreakManager.swift` (new), `IdleMonitor.swift`

---

### Phase 18 — Reaction Log Easter Egg

**Goal:** A hidden delight for curious developers.

- Track `reactionLog: [(Date, String, String)]` in `CharacterViewModel` — `(timestamp, triggerKey, text)`
- Append to log in `CharacterViewModel.displayBubble()` when source is ambient (not chat)
- Long-press on Claud-y for 3 seconds (via `LongPressGesture(minimumDuration: 3)`) reveals a popover
- Popover shows: "Today's reactions" — scrollable list of `[HH:MM] trigger_key — "text"` entries
- Max 50 entries (trim oldest if exceeded)
- Flushed on app quit (in-memory only)
- No mention in settings or documentation — pure Easter egg

**Files:** `CharacterViewModel.swift`, `CharacterRootView.swift`, `ReactionLogView.swift` (new)

---

## Bugs to Fix Before Next Build

> See `BUG_REPORT.md` for full details with line references.

| # | File | Issue | Severity |
|---|---|---|---|
| 1 | `IdleMonitor.swift:78` | Dead code — `idle5min` bubble unreachable (duplicate `>= 300` condition) | MEDIUM |
| 2 | `IdleMonitor.swift:285` | Hours 18–21 return `.launch` context instead of evening/afternoon | MEDIUM |
| 3 | `ClaudeAPIService.swift:18` | `"claude-haiku-3-5"` is not a valid model ID (should be `"claude-3-5-haiku-20241022"`) | HIGH |
| 4 | `ClaudeAPIService.swift:24` | `"claude-opus-4-5"` but SettingsView says `"claude-opus-4-6"` — inconsistent | HIGH |
| 5 | `ChatViewModel.swift:59` | `messages[idx]` index unsafe if `clearHistory()` called during streaming | MEDIUM |
| 6 | `AppContextMonitor.swift:68,80` | `lower` computed then immediately discarded (`_ = lower`) | LOW |
| 7 | `KeychainService.swift:28` | Missing `kSecAttrAccessible` — should be `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` | LOW |
| 8 | `AppContextMonitor.swift:207` | Build success heuristic (`duration >= 8`) causes false negatives on fast machines | LOW |

---

## Implementation Order Summary

| Priority | Phase | Description |
|---|---|---|
| 🔴 Fix first | Bug fixes | Items 1–4 in table above are blocking correctness |
| 🟠 High | Phase 8 | Chat polish (close button, export, markdown) |
| 🟠 High | Phase 9 | Mood system |
| 🟠 High | Phase 13 | New app detection (music, ChatGPT, etc.) |
| 🟡 Medium | Phase 10 | Size toggle |
| 🟡 Medium | Phase 11 | Pomodoro |
| 🟡 Medium | Phase 12 | Long compile awareness |
| 🟡 Medium | Phase 15 | Confetti |
| 🟢 Lower | Phase 14 | Sound effects |
| 🟢 Lower | Phase 16 | Quick launch |
| 🟢 Lower | Phase 17 | Streaks |
| 🟢 Lower | Phase 18 | Reaction log Easter egg |
