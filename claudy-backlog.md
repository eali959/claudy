# Claud-y — Master Feature Backlog & Implementation Prompt

Use this file as a prompt when starting a new implementation session. Each feature is self-contained with enough context to build without re-reading the entire codebase. Build in order, confirm each feature compiles before proceeding to the next.

---

## Project Context

- **Platform:** macOS 15+, Swift 6 strict concurrency, SwiftUI only
- **Architecture:** MVVM with `@Observable`, `@MainActor` by default
- **Key files:**
  - `CharacterRootView.swift` — root view hosting character + chat panel
  - `ClaudyCharacterView.swift` — animated character (do not refactor structure)
  - `CharacterViewModel.swift` — character state, bubble queue, mute, focus mode
  - `ChatView.swift` — chat panel UI
  - `ChatViewModel.swift` — chat state, streaming, send/cancel/clear
  - `AppContextMonitor.swift` — app activation, process detection (xcodebuild, npm, etc.)
  - `IdleMonitor.swift` — idle escalation, greetings, onboarding, special days
  - `PersonalityManager.swift` — personality modes, system prompt, greeting system
  - `ReactionLibraryService.swift` + `ReactionLibrary.json` — local reaction strings
  - `ClaudeAPIService.swift` — all API calls, `MessagePriority` enum
  - `WindowManager.swift` — panel position, chat height, drag
  - `SettingsView.swift` — settings form

---

## Group A — Chat Tray Polish

Build all items in this group before moving to Group B. Confirm each compiles.

---

### A1. Close (×) Button in Chat Header

**File:** `ChatView.swift`

**What:** Add an explicit close button to the chat header, to the right of the height indicator, before the trash button.

**Spec:**
- SF Symbol: `xmark`
- Font size: 11pt
- Style: `.plain` button, `.secondary` foreground
- On tap: animate `chatViewModel.isOpen = false` with `.spring(response: 0.35, dampingFraction: 0.8)`
- Closes the tray. Does not clear messages.
- Tooltip: `"Close chat"`

**Where to wire:** Inside the `header` computed property in `ChatView`. The `isOpen` state lives on `ChatViewModel` (`var isOpen = false`). `ChatView` receives `@Bindable var viewModel: ChatViewModel` — use `viewModel.isOpen = false` directly, wrapped in `withAnimation`.

---

### A2. Escape Key to Close Chat

**File:** `ChatView.swift`

**What:** Pressing `Escape` when the chat input is focused closes the tray.

**Spec:**
- Add `.onKeyPress(.escape)` modifier to the `TextField` in `inputBar`
- On trigger: `withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { viewModel.isOpen = false }`
- Returns `.handled`
- Only fires when chat is open (it will only be reachable if chat is open anyway)

---

### A3. Export / Save Chat Log

**Files:** `ChatView.swift`, `ChatViewModel.swift`

**What:** A share/export button in the chat header. Active only when there are messages.

**Spec — ViewModel (`ChatViewModel`):**
Add a computed property:
```swift
var exportText: String {
    messages.map { msg in
        let role = msg.role == .user ? "You" : "Claud-y"
        let time = msg.timestamp.formatted(date: .omitted, time: .shortened)
        return "[\(time)] \(role): \(msg.content)"
    }.joined(separator: "\n\n")
}
```

**Spec — View (`ChatView.swift`):**
- Add export button to header: SF Symbol `square.and.arrow.up`, 11pt, `.plain`, `.secondary`
- Disabled when `viewModel.messages.isEmpty`
- On tap: show a `Menu` with three items:
  1. **"Copy to Clipboard"** — `NSPasteboard.general.setString(viewModel.exportText, forType: .string)`
  2. **"Save as Text File…"** — open `NSSavePanel` with `allowedContentTypes: [.plainText]`, default filename `"Claud-y Chat \(Date().formatted(date: .abbreviated, time: .omitted)).txt"`, write `exportText` on confirm
  3. **"Share…"** — `NSSharingServicePicker` presented from the button's NSView. Use `NSApp.keyWindow?.contentView` as the anchor if direct view reference is unavailable.

---

### A4. Tap-to-Copy on Message Bubbles

**File:** `ChatView.swift` — inside the private `MessageBubble` struct

**What:** Tapping a message bubble copies its text to the clipboard and briefly flashes a "Copied" confirmation.

**Spec:**
- Add `@State private var copied = false` inside `MessageBubble`
- On tap: copy `message.content` to `NSPasteboard.general`, set `copied = true`, reset after 1.5s with a `Task`
- Overlay the bubble with a small `"Copied"` label when `copied == true`:
  - Font: `.caption2`, foreground: `.white` (user) or `.primary` (assistant)
  - Appears with `.opacity` + `.scale(scale: 0.85)` transition
  - Disappears after 1.5s
- Keep existing `.textSelection(.enabled)` — tap-to-copy is additive, not a replacement
- Use `.onTapGesture` on the bubble's `Text` (not the HStack, to avoid accidental triggers)

---

### A5. Scroll-to-Bottom Button

**File:** `ChatView.swift` — inside the `messageList` computed property

**What:** A floating `↓` button that appears when the user has scrolled up, snapping back to the latest message.

**Spec:**
- Add `@State private var showScrollButton = false` to `ChatView`
- Use a `ZStack` wrapping the existing `ScrollView`, with the button anchored `.bottomTrailing` inside the ZStack
- Button: SF Symbol `arrow.down.circle.fill`, 20pt, `.orange` foreground, `.plain` style, 8pt trailing + 8pt bottom padding
- On tap: `withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }`
- To detect scroll position: use `.onScrollGeometryChange` (macOS 15) or a simpler heuristic — show the button whenever `viewModel.messages.count > 6` and the last message is not the most recently added. Pragmatic approach: show the button any time the user manually scrolls (use `ScrollView` with `.onScrollTargetVisibilityChange` or just show it always when `messages.count > 8` as a reasonable proxy).
- Hide with `.opacity(showScrollButton ? 1 : 0)` + `.animation(.easeInOut(duration: 0.2), value: showScrollButton)`

---

### A6. Token Estimate Footer

**File:** `ChatView.swift`, `ChatViewModel.swift`

**What:** A subtle one-line footer below the input bar showing approximate context size.

**Spec — ViewModel:**
```swift
var approximateTokenCount: Int {
    // Rough heuristic: ~4 characters per token
    let totalChars = messages.reduce(0) { $0 + $1.content.count }
    return totalChars / 4
}
```

**Spec — View:**
- Add a `Text` below the `inputBar` VStack, inside the main chat `VStack`
- Only show when `viewModel.messages.count > 0`
- Text: `"~\(viewModel.approximateTokenCount) tokens · \(viewModel.messages.count) messages"`
- Font: `.system(size: 10)`, foreground: `.tertiary`, padding: `4pt` vertical, `12pt` horizontal
- Does not affect layout when hidden (use `.opacity` not `if`)

---

### A7. Markdown Rendering in Message Bubbles

**File:** `ChatView.swift` — inside `MessageBubble`

**What:** Render assistant messages as styled markdown. User messages stay as plain text (they're usually short prompts).

**Spec:**
- For assistant messages (`!isUser`): replace `Text(message.content)` with `Text(try! AttributedString(markdown: message.content, options: AttributedString.MarkupOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)))`
- Wrap in a `do/try` or use a helper that falls back to plain `Text` on parse failure:
```swift
private func renderedContent(_ text: String) -> Text {
    if let attributed = try? AttributedString(markdown: text,
        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
        return Text(attributed)
    }
    return Text(text)
}
```
- Apply same font (`.system(size: 13)`) and foreground (`.primary`) as before
- Keep `.textSelection(.enabled)`
- For streaming messages (content building up token by token): markdown will re-render on each token — this is acceptable; SwiftUI diffs efficiently
- Code spans (backtick) will render in monospaced automatically via `AttributedString` markdown
- Do NOT use `SwiftUI.MarkdownView` or any third-party library — `AttributedString(markdown:)` is sufficient for inline formatting

---

## Group B — Character & Expression

---

### B1. Mood System

**Files:** `CharacterViewModel.swift`, `AppContextMonitor.swift`, `IdleMonitor.swift`

**What:** Claud-y's expression shifts automatically based on context. Uses existing animation states — no new states needed.

**Spec — Mapping:**
| Context | State | Duration |
|---|---|---|
| Clean build (`xcodeBuildSuccess`) | `.celebrating` | 3s |
| Build fail (`xcodeBuildFail`) | `.confused` | 4s |
| Build stare (30s after fail) | `.confused` | persistent until next event |
| After midnight (00:00–05:00) | `.drowsy` | persistent until activity |
| Npm install running | `.thinking` | while process active |
| Claude app opened | `.celebrating` | 2s |
| Vibe coding session fired | `.alert` | 3s |
| Muted | no change | — |

**Spec — Implementation:**
- In `AppContextMonitor`, after firing reaction bubbles for these triggers, call the appropriate `viewModel.setState(_, duration:)` or named helpers (`celebrate()`, `beConfused()`, etc.)
- In `IdleMonitor`, after midnight check (already have `currentGreetingContext()` returning `.veryLateNight`): if the current time is 00:00–05:00 and character is `.idle`, call `viewModel.setState(.drowsy)`
- Do not override states that are already in a non-idle animation (check `vm.animationState == .idle` before applying mood)

---

### B2. Size Toggle

**Files:** `WindowManager.swift`, `CharacterRootView.swift`, `SettingsView.swift` or right-click menu

**What:** Three size presets selectable from the right-click context menu.

**Spec:**
- Add enum:
```swift
enum CharacterSize: String, CaseIterable {
    case small  = "small"   // 80pt character, 260pt chat width
    case medium = "medium"  // 130pt character, 300pt chat width (current default)
    case large  = "large"   // 180pt character, 360pt chat width
}
```
- Persist selection: `@AppStorage("CharacterSize") var characterSize: String = "medium"`
- `WindowManager` exposes computed `characterFrameSize` and `chatPanelWidth` based on stored preference
- Resize the floating `NSPanel` on change — call `windowManager.applySize()` which updates panel frame with `NSPanel.setFrame(_:display:animate:)`
- Right-click menu: `Menu("Size") { Button("Small") {...}; Button("Medium") {...}; Button("Large") {...} }` with a checkmark on the current selection (prefix "✓ " when active)
- Animate character scale change with `.animation(.spring(response: 0.4, dampingFraction: 0.7), value: size)`

---

## Group C — Developer Tools

---

### C1. Pomodoro Mode

**Files:** `CharacterViewModel.swift`, `CharacterRootView.swift`

**What:** 25-minute focus timer accessible from the right-click menu. Claud-y shows countdown, reacts at halfway and on completion.

**Spec:**
- Add to `CharacterViewModel`:
```swift
var pomodoroState: PomodoroState = .idle

enum PomodoroState {
    case idle
    case running(endsAt: Date)
    case done
}
```
- `func startPomodoro()` — sets `pomodoroState = .running(endsAt: Date().addingTimeInterval(25 * 60))`, starts a `Task` loop
- Task loop: fires every 60s, checks remaining time:
  - At 12m30s remaining (halfway): `showSpeechBubble("Halfway. Still going. I respect this.", duration: 5)` + `nod()`
  - At 0s: `pomodoroState = .done`, `celebrate()`, fire confetti, `showBubbleDirect("25 minutes. Done. Get up. Move. You earned it.", duration: 6)`
- `func cancelPomodoro()` — cancels task, resets to `.idle`
- In `CharacterRootView` — overlay a compact countdown label on the character when `pomodoroState == .running`:
  - Bottom of character, small pill shape with dark background
  - Text: remaining time formatted as `"mm:ss"`, updated every second via a `TimelineView(.periodic(from:by:))` or a `@State` timer
  - Tapping the pill cancels the Pomodoro (with confirmation if > 5 min elapsed)
- Right-click menu: `Button("Start Focus Timer (25 min)")` when idle; `Button("Cancel Timer (\(remaining))")` when running

---

### C2. Long Compile Awareness

**File:** `AppContextMonitor.swift`

**What:** If `xcodebuild` runs for > 60 seconds, fire a special "go get coffee" bubble. Already tracking `xcodeBuildStartTime`.

**Spec:**
- In `startXcodeBuildMonitor()`, after setting `xcodeBuildStartTime` and showing the start bubble, schedule a one-shot task:
```swift
Task { @MainActor in
    try? await Task.sleep(for: .seconds(60))
    guard self.xcodeBuildStartTime != nil else { return }  // still building
    let msg = "That is a long build. Go get a coffee. I will wait."
    self.viewModel?.showSpeechBubble(msg, duration: 7)
    self.viewModel?.setState(.sleeping, duration: nil)  // nap while building
}
```
- When the build ends (existing logic), if the character is `.sleeping` from this, wake it: `viewModel?.setState(.idle)`
- The existing build-end reaction ("Welcome back. It is done.") already fires from `xcodeBuildSuccess` — no change needed there. Just make sure the reaction text in `ReactionLibrary.json` under `xcode_build_success` has something post-coffee suitable, e.g. "There it is. Worth the wait." already exists.

---

### C3. Database & Documentation App Detection

**Files:** `AppContextMonitor.swift`, `ReactionLibrary.json`

**What:** Detect TablePlus, Postico, DBngin, Sequel Pro, Notion, Obsidian, Bear.

**Spec — Bundle IDs:**
| App | Bundle ID |
|---|---|
| TablePlus | `com.tinyapp.TablePlus` |
| Postico | `at.eggerapps.Postico` or `at.eggerapps.Postico2` |
| DBngin | `com.proxyman.DBngin` |
| Sequel Pro | `com.sequelpro.SequelPro` |
| Notion | `notion.id` |
| Obsidian | `md.obsidian` |
| Bear | `net.shinyfrog.bear` |

**Spec — Triggers to add:**
- `app_database` → "Database open. Tread carefully." / "Migrations are irreversible. Just saying." / "Schema changes ahead. Breathe." / "Query carefully. I have seen things." / "The data knows all. Be respectful."
- `app_notes` → "Documentation time. A rare and noble act." / "Writing things down. The most underrated skill." / "Future you will thank present you for this." / "Notes. The unsung hero of shipping." / "The knowledge base grows. Slowly, but it grows."

**Spec — Implementation:**
- Add both trigger cases to `ReactionTrigger` enum in `ReactionLibraryService.swift`
- Add JSON entries under `"app_database"` and `"app_notes"` in `ReactionLibrary.json`
- Add to `ambientTrigger(for:)` in `AppContextMonitor`:
```swift
if ["com.tinyapp.TablePlus", "at.eggerapps.Postico", "at.eggerapps.Postico2",
    "com.proxyman.DBngin", "com.sequelpro.SequelPro"].contains(bundleID) { return .appDatabase }
if ["notion.id", "md.obsidian", "net.shinyfrog.bear"].contains(bundleID) { return .appNotes }
```

---

## Group D — Personality Touches

---

### D1. Quick Launch Shortcuts

**Files:** `SettingsView.swift`, `CharacterRootView.swift`, new `QuickLaunchService.swift`

**What:** Up to 3 configurable app shortcuts in the right-click menu. "Open Terminal", "Open Claude", "Open Xcode" etc.

**Spec — Data model:**
```swift
struct QuickLaunchItem: Codable, Identifiable {
    let id: UUID
    var name: String        // display name, e.g. "Terminal"
    var bundleID: String    // e.g. "com.apple.Terminal"
}
```
- Persisted as JSON in `UserDefaults` under key `"QuickLaunchItems"` (array, max 3)
- Default on first launch: Terminal, Xcode (if installed), Safari

**Spec — Launch:**
```swift
NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
// or:
NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleID, ...)
```

**Spec — Settings UI:**
- Section "Quick Launch" in `SettingsView`
- `List` of up to 3 items, each with a `TextField` for name and a `TextField` or picker for bundle ID
- "Add" button (disabled when 3 items exist), delete via swipe or minus button
- Small note: "These appear in Claud-y's right-click menu"

**Spec — Context menu:**
```swift
if !quickLaunchItems.isEmpty {
    Divider()
    ForEach(quickLaunchItems) { item in
        Button("Open \(item.name)") {
            QuickLaunchService.shared.launch(item)
        }
    }
}
```

---

### D2. Sound Effects (Opt-In)

**Files:** `SettingsView.swift`, `CharacterViewModel.swift`, new `SoundService.swift`

**What:** Two subtle sound effects, off by default. Toggle in Settings.

**Spec:**
- `@AppStorage("SoundEffectsEnabled") var soundEffectsEnabled = false` in `SettingsView` and read in `SoundService`
- `SoundService` is a simple `@MainActor` class using `NSSound`:
```swift
func playBubblePop() {
    guard soundEffectsEnabled else { return }
    NSSound(named: "Pop")?.play()   // built-in macOS sound
}
func playChime() {
    guard soundEffectsEnabled else { return }
    NSSound(named: "Glass")?.play()
}
```
- `playBubblePop()` called in `CharacterViewModel.displayBubble(_:duration:)` at the point the bubble is set
- `playChime()` called in `AppContextMonitor` when `xcodeBuildSuccess` fires
- Settings toggle: `Toggle("Sound effects", isOn: $soundEffectsEnabled)` with caption "A soft pop on bubbles, chime on clean builds."
- Zero overhead when disabled — the guard returns immediately

---

### D3. Confetti Burst

**Files:** `CharacterRootView.swift`, new `ConfettiView.swift`

**What:** A short particle burst for clean builds and first-launch onboarding completion. Pure SwiftUI, no library.

**Spec — `ConfettiView.swift`:**
```swift
struct ConfettiView: View {
    // ~24 particles, random angle, random color from orange palette
    // Each particle: small rounded rectangle, launched with random velocity
    // Gravity applied via offset animation over 1.5s
    // View removes itself after animation completes (via onAppear task)
}
```
- Particle colors: `[#C85C38, #E07048, #F5A623, #FFFFFF, #9A3520]`
- Particle shapes: mix of small squares (4×4pt) and rectangles (3×7pt)
- Animation: `.easeOut(duration: 1.4)` offset from origin, with slight horizontal spread
- Triggered by setting `@State private var showConfetti = false` in `CharacterRootView`, wrapped in `if showConfetti { ConfettiView().onAppear { Task { try? await Task.sleep(for: .seconds(2)); showConfetti = false } } }`
- Add `func fireConfetti()` to `CharacterViewModel` that sets a `@Published`-style trigger observed by `CharacterRootView`

**Trigger points:**
- `AppContextMonitor`: after `xcodeBuildSuccess` fires
- `IdleMonitor`: after last onboarding bubble completes

---

## Group E — Long-Term Polish

---

### E1. Daily Streaks

**File:** `IdleMonitor.swift`, `CharacterViewModel.swift`

**What:** Track consecutive days the app has been opened. Show a streak message once per day when the streak is ≥ 3 days.

**Spec:**
- On each launch, `IdleMonitor` calls `updateStreak()`:
```swift
func updateStreak() {
    let key = "StreakDates"
    var dates = (UserDefaults.standard.array(forKey: key) as? [String]) ?? []
    let today = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
    guard !dates.contains(today) else { return }  // already counted today
    // Check if yesterday was in the list
    let yesterday = ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!)
    if !dates.contains(yesterday) { dates = [] }  // streak broken, reset
    dates.append(today)
    if dates.count > 365 { dates = Array(dates.suffix(365)) }
    UserDefaults.standard.set(dates, forKey: "StreakDates")
    showStreakMessageIfNeeded(streak: dates.count)
}
```
- `showStreakMessageIfNeeded(streak:)`:
  - Only fire if streak ≥ 3 and `"StreakShownToday"` UserDefaults date ≠ today
  - Messages: 3 days → "Three days in a row. I notice these things." / 7 → "A whole week. Consistent. I respect that." / 30 → "Thirty days. You are basically unstoppable." / 100 → "One hundred days. I am genuinely proud of you."
  - Use `showSpeechBubble` with duration 7s, fire 12s after launch (after onboarding/greeting)

---

### E2. Reaction Log Easter Egg

**Files:** `CharacterViewModel.swift`, `CharacterRootView.swift`

**What:** Long-press Claud-y for 3 seconds to reveal today's reaction log as a popover. In-memory only, devs will find it.

**Spec — Data:**
- Add to `CharacterViewModel`:
```swift
struct ReactionLogEntry {
    let time: Date
    let trigger: String   // e.g. "xcode_build_success"
    let text: String      // the reaction text shown
}
var reactionLog: [ReactionLogEntry] = []
```
- In `displayBubble(_:duration:)`, append to `reactionLog` with current time and the text. The trigger isn't directly available here — pass it optionally as a parameter with a default of `"—"`. Update call sites that know the trigger.

**Spec — UI:**
- In `ClaudyCharacterView`, add `var onLongPress: () -> Void = {}`
- Add a `LongPressGesture(minimumDuration: 3)` via `.simultaneousGesture` (so it doesn't conflict with drag/tap):
```swift
.simultaneousGesture(LongPressGesture(minimumDuration: 3).onEnded { _ in onLongPress() })
```
- In `CharacterRootView`, wire `onLongPress` to toggle `@State private var showReactionLog = false`
- Attach `.popover(isPresented: $showReactionLog)` to the character:
  - Title: "Today's Reactions 🔍"
  - `List` of `reactionLog` entries, newest first
  - Each row: time (formatted as `HH:mm:ss`) + trigger key + truncated text (40 chars)
  - If empty: "Nothing yet today. Get to work."
  - Font: `.system(size: 11, design: .monospaced)`
  - Max height 300pt

---

## Implementation Notes

- **Always build after each feature before proceeding**
- **Do not use third-party libraries** — everything above is achievable with system frameworks
- **Swift 6 strict concurrency** — all new types must be `@MainActor` or explicitly isolated
- **`@Observable` not `ObservableObject`** — use `@Observable` macro for any new observable types
- **No `print()`** — use `Logger` from `OSLog` for all logging
- **No new files unless necessary** — prefer extending existing files within the 100-line-per-view guideline

---

## Quick Reference — Bundle IDs for App Detection

| App | Bundle ID |
|---|---|
| Xcode | `com.apple.dt.Xcode` |
| Terminal | `com.apple.Terminal` |
| iTerm2 | `com.googlecode.iterm2` |
| Warp | `dev.warp.Warp-Stable` |
| Claude | `com.anthropic.claude` |
| Cursor | `com.todesktop.230313mzl4w4u92` |
| Figma | `com.figma.Desktop` |
| Zoom | `us.zoom.xos` |
| Slack | `com.tinyspeck.slackmacgap` |
| TablePlus | `com.tinyapp.TablePlus` |
| Postico 2 | `at.eggerapps.Postico2` |
| DBngin | `com.proxyman.DBngin` |
| Sequel Pro | `com.sequelpro.SequelPro` |
| Notion | `notion.id` |
| Obsidian | `md.obsidian` |
| Bear | `net.shinyfrog.bear` |
| Safari | `com.apple.Safari` |
| Chrome | `com.google.Chrome` |
| VS Code | `com.microsoft.VSCode` |
| GitHub Desktop | `com.github.GitHubClient` |

---

*Generated from Claud-y dev session — 2026-03-26*
