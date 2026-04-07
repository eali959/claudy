# Claud-y Changelog

---

## v3.0.0 — The Deep One

> Claud-y grew a soul. v3.0 is about depth — Tamagotchi needs, expanded animation life, ten languages, personality blending, a richer chat experience, and SwiftData foundations that make everything more real. The orange creature on your screen is no longer just watching you. It has feelings. (Simulated ones. But still.)
>
> ☕ If v3.0 earns a place in your day, [support development on Ko-fi](https://ko-fi.com/ealiii) — one-time, no account needed.

---

### The Numbers

| What | v2.0 | v3.0 |
|------|-------|-------|
| Languages | 1 (English) | 10 |
| Personalities | 7 | 7 + blending system |
| Animation states | 10 | 15 + full mouth sync |
| Reaction strings | 400+ | 4,000+ (translated pools) |
| Character accessories | 0 | 6 |
| Persistent storage | UserDefaults only | SwiftData + UserDefaults |

---

### SwiftData Infrastructure

Claud-y now uses SwiftData for persistent storage. Conversation history, Tamagotchi state, and stats are stored on-device using a local SQLite store — no iCloud sync, no cloud dependency, no data ever leaves your Mac.

- **Explicit local URL** — data lives in `~/Library/Application Support/Claudy/claudy.store`
- **CloudKit disabled** — `cloudKitDatabase: .none` everywhere, by design
- **Schema versioning** — `VersionedSchema` + `SchemaMigrationPlan` ready for future migrations

---

### Tamagotchi Core

Claud-y has needs now. Real (simulated) needs.

A Tamagotchi system tracks three hidden stats — **happiness**, **energy**, and **hunger** — that evolve over time based on your behaviour and how much attention you pay to Claud-y.

| Stat | Depletes when | Replenishes when |
|------|--------------|-----------------|
| Happiness | Long idle periods, muted for too long | You chat, celebrate a build, send thanks |
| Energy | Continuous screen time, late nights | You take breaks, Pomodoros complete |
| Hunger | Time passing | You interact, complete focus sessions |

When stats drop low, Claud-y enters expressive states: **hungryWobble**, **sadPulse**, **tiredDroop**. These layer on top of existing animation states without interrupting work flow. A dedicated Tamagotchi settings section lets you tune nudge intensity (silent / subtle / normal) or disable it entirely.

---

### Animation Expansion

The character rendering was rebuilt from data-driven `AnimationConfig` structs.

**Full mouth sync** — all 15 `MouthShape` cases now rendered distinctly:
`talkingSync`, `sleepLine`, `sadCurve`, `hugeSmile`, `bigSmile`, `vibeSmile`, `flatLine`, `tinyOpen`, `mediumOpen`, `wideOpen`, `rockMouth`, `smirk`, `effortGrin`, `chewing`, plus default.

**Activity states** — Claud-y adopts contextual postures based on your active app:
- Coding editors (Xcode, Cursor, VS Code) → `.coding`
- Communication apps (Slack, Messages, Mail) → `.typing`
- Knowledge tools (Notion, Obsidian, Bear) → `.studying`
- Browsers and reading apps → `.reading`

**Walk across screen** — every ~10 minutes (±90s jitter) Claud-y smoothly slides to a new position using a 40-step easeInOut animation. Respects `visibleFrame`, pauses during sleep/talking/celebrating. Right-click → Walk Now to trigger manually.

**Weather awareness** — Claud-y uses CoreLocation + Open-Meteo (no API key) to detect weather and fire a contextual ambient comment once per session. Falls back to hemisphere/season approximation if location is denied.

**Accessories** — six wearable items overlaid above the face:

| Accessory | |
|-----------|---|
| Glasses | |
| Tinted Sunnies | |
| Heisenberg Hat | |
| Cap Forward | |
| Cap Backward | |

Set via Settings → Accessories or right-click → Accessories.

---

### Personality Blending

Two personalities, one character. A new blending system lets you mix any two personalities on a 0–100% slider.

- **Subtle (< 25%)** — dominant voice with a whisper of secondary flavour
- **Balanced (25–75%)** — unified voice that synthesises both, never switches between them
- **Strong (> 75%)** — secondary becomes dominant with the primary as texture

The slider and secondary picker are locked during streaming (no mid-sentence personality shifts). Blend state persists across sessions. Custom persona blends cleanly with any built-in personality.

---

### Response Expansion & Anti-Repetition

**Pool sizes doubled** — all greeting pools (launch, morning, afternoon, wake, late night) and idle/wander/hourly pools are 2× the v2.0 count. All 7 personality arrival pools expanded to 13–16 entries.

**Anti-repetition rolling window** — `ReactionLibraryService` now tracks recently shown strings per trigger, with a window of `min(8, pool.count / 2)`. You won't hear the same thing twice in quick succession.

**PersonalityManager** tracks a separate 12-entry anti-repetition window for ambient bubbles across all triggers.

---

### Chat UX Enhancements

- **Markdown toggle** — Settings → Chat → Render Markdown. Switch between full Markdown rendering (code blocks, bold, inline code) and plain text. Persists across sessions.
- **Scroll-to-bottom button** — appears when you've scrolled up and new messages arrive. `↓` button in the bottom corner, auto-hides when you're at the bottom.
- **Token counter** — subtle `~N tokens · N messages` footer in the chat. Helps you track context usage at a glance.
- **System prompt presets** — save and name custom system prompts in Settings → Chat. Load any preset into the active session from the preset picker.
- **StackOverflow / GitHub PR detection** — clipboard monitor now routes `stackoverflow.com`, `stackexchange.com` and GitHub `/pull/` and `/issues/` URLs to dedicated reaction pools.

---

### Multilingual UI — 10 Languages

Claud-y now speaks ten languages. Change in Settings → Language — takes effect instantly, no restart.

| Language | Code | Script | RTL |
|----------|------|--------|-----|
| English (UK) | `en` | Latin | — |
| Español | `es` | Latin | — |
| Français | `fr` | Latin | — |
| Deutsch | `de` | Latin | — |
| Português | `pt` | Latin | — |
| 日本語 | `ja` | Kanji/Kana | — |
| 中文（简体） | `zh-Hans` | Simplified Chinese | — |
| हिन्दी | `hi` | Devanagari | — |
| اردو | `ur` | Nastaliq | ✅ |
| العربية | `ar` | Arabic | ✅ |

**API mode**: A language directive is injected at the end of every system prompt — all AI responses come back in your chosen language.

**Companion mode**: Each language has its own translated reaction library (`ReactionLibrary_{lang}.json`) — 107 trigger pools per language, 4,000+ strings across all languages. Missing keys fall back to English seamlessly.

**Japanese**: Natural mixed kanji/hiragana/katakana — no romaji, ever.
**Chinese**: Simplified character output — no pinyin, ever.
**Arabic**: Transliteration optionally included alongside Arabic script (enabled by design — useful for learners).
**Urdu & Arabic**: RTL layout — macOS handles text direction automatically in the chat input.

---

## v2.0.0 — The Big One

> Claud-y grew up. What started as a cute floating orange blob that reacted to Xcode builds is now a full productivity companion — aware of your schedule, your rhythm, your apps, your mood, and your browser choices. Eight new background intelligence systems. Three AI providers. Nine browsers. Six modes. 42+ new app detections. Hundreds of new reaction strings. And it's still free, still local-first, and still has absolutely no telemetry.
>
> ☕ If v2.0 earns a spot in your workflow, [support development on Ko-fi](https://ko-fi.com/ealiii) — one-time, no account needed, means a lot.

---

### The Numbers

| What | Before | After |
|------|--------|-------|
| AI providers | 1 (Claude) | 3 (Claude, ChatGPT, Gemini) |
| Behaviour modes | 4 | 6 (+Work, unified Dance) |
| Browsers detected | 1 | 9 |
| Apps detected | ~20 | 60+ |
| Background managers | 3 | 11 |
| Reaction strings | ~200 | 400+ |
| New Swift files | — | 8 |

---

### Three AI Providers

Claud-y now speaks to Claude, ChatGPT, and Gemini — your key, your choice, your data.

| Provider | Models available |
|----------|-----------------|
| Claude (Anthropic) | Haiku 4.5 · Sonnet 4.6 · Haiku 3.5 |
| ChatGPT (OpenAI) | GPT-4o mini · GPT-4o |
| Gemini (Google) | 2.0 Flash · 1.5 Pro |

Switch providers instantly in Settings → API Provider. Every API call routes to whichever is selected. The model picker adapts to show only that provider's options. A built-in test button confirms your key is valid before you commit.

**Privacy:** The same guarantee as v1 — your key is stored in your Mac's Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`), sent directly to the provider over HTTPS, and never touches a Claud-y server because there isn't one. Companion mode remains 100% local, free forever, no key required.

---

### Work Mode

A sixth mode for the other half of your day — the meetings, the emails, the decks, the deadlines.

Work Mode sets a 1.8× ambient cooldown so Claud-y stays out of your way during calls, shifts to business-appropriate language, and reacts contextually to the apps professionals live in:

- **Zoom / Teams** → "You're about to be on camera. You've got this."
- **Outlook / Mail** → email drafting nudge
- **Slack** → quiet acknowledgement, no interrupt
- **Build completes** → "Deployment pipeline complete. Ship it." (no confetti)
- **10-minute idle** → gentle productivity nudge

Every personality adapts: Director becomes boardroom-dramatic, Hype Coach becomes relentless LinkedIn energy, Mate stays deadpan, Listener becomes a calm executive coach. Stack any personality with Work Mode — it all composes cleanly.

---

### Smart Awareness — Eight New Intelligence Systems

The biggest architectural addition in v2.0. Eight background managers that make Claud-y aware of your actual work rhythm, not just your app switches.

**⌘⇧Space — Global Hotkey** (`GlobalHotkeyManager`)
Toggle the chat panel from any app, without clicking anything. Enable/disable in Settings → General. Works system-wide via `NSEvent` global monitor.

**🌙 macOS Focus / Do Not Disturb Sync** (`FocusModeMonitor`)
When your Mac's Focus mode activates, Claud-y sees it (via `NSDistributedNotificationCenter`) and suppresses ambient bubbles automatically. A moon badge confirms Focus is active. Resumes when Focus ends. Also respects screen sleep and screen lock.

**⏰ Break Nudges** (`BreakNudgeManager`)
Tracks continuous active time. At 90 minutes: a gentle nudge. At 2 hours: firmer. At 3 hours: non-negotiable. A 5-minute gap resets the clock. Every nudge is personality + mode aware — Brain Rot says "no cap you been grinding fr", Study mode cites memory consolidation science, Dev mode knows you're in flow state.

**📊 Focus Session Stats** (`FocusStatsManager`)
Counts Pomodoros completed today, total focus minutes, and your consecutive-day streak. Visible in right-click → Focus Tools as a footer line: "3 Pomodoros · 1h 15m focused". Resets at midnight. Feeds the daily wrap-up.

**⚡ Contextual Quick-Action Buttons** (`QuickActionManager`)
Switch to Zoom, Figma, Notion, Slack, or a dozen other apps and a small capsule button appears above Claud-y with a pre-written contextual prompt — tap it to open chat already primed for what you're about to do. Auto-dismisses after 8 seconds if you don't need it.

**📝 Mini Scratchpad** (`ScratchpadManager`)
Right-click → Scratchpad. A compact persistent notepad that lives alongside your character. Add notes, double-tap to edit, pin important ones (they float to the top with an orange tint). Everything survives restarts. In API mode, you can ask Claud-y to "clear my scratchpad" in chat.

**💭 Mood Check-ins** (`MoodCheckInManager`)
Every ~2 hours of active use, Claud-y quietly asks how you're doing. Suppressed if the chat is open, you're muted, or Focus mode is on. If you mention you're struggling, Claud-y enters a 30-minute support mode with more empathetic responses.

**🎉 Daily Wrap-up** (`DailyWrapUpManager`)
At 6 pm, if you've completed at least one Pomodoro, Claud-y delivers a personality-flavoured summary of your day. Director is dramatic about it. Hype Coach is absolutely losing their mind with pride. Mate is three words and a nod. Brain Rot mode is genuinely unhinged about your focus stats. Fires once per day only.

---

### Nine Browsers Detected

Claud-y now has distinct, personality-aware reactions for every major browser — including the niche ones.

| Browser | Reaction flavour |
|---------|-----------------|
| Safari | Native Mac energy |
| Chrome | The default, acknowledged |
| Microsoft Edge | A Chromium in a suit |
| Firefox | Privacy-conscious respect |
| Brave | Ad-blocker appreciation |
| Opera | Sidebar enjoyer solidarity |
| DuckDuckGo | "Your search history remains yours." |
| Helium | "A floating browser for a floating companion. We match." |
| Arc | Exists. Reacted to. |

---

### 60+ Apps Detected (was ~20)

App awareness has tripled. New detections with full reaction pools:

| Category | New additions |
|----------|--------------|
| Microsoft Office | Word, Excel, PowerPoint, Outlook, Teams |
| Apple Productivity | Pages, Keynote, Numbers, Mail, Notes |
| Dev Tools | GitHub Desktop, Linear, Raycast, Postman, Insomnia |
| AI IDEs | Cursor (expanded to 16 reactions), Windsurf, Antigravity |
| Design | Figma (quick-action button) |
| Comms | Zoom, Slack, Teams (also used by Work Mode) |
| Knowledge | Notion, Obsidian |

**Cursor build detection**: When Cursor was frontmost within the last 90 seconds and a build tool runs (`tsc`, `webpack`, `vite`, `cargo`, `jest`, etc.), Claud-y reacts with dedicated `cursor_build_start` / `cursor_build_done` triggers — same quality as Xcode detection.

**Claude Code agent detection**: When the `claude` CLI is running alongside a build process, Claud-y celebrates the agent's work. Rate-limited to once per 5 minutes.

---

### Mode System v2

The Mode menu now has six entries — all unified in right-click → Mode.

| Mode | Cooldown | What it does |
|------|----------|-------------|
| Normal | 1× | Default. Claud-y is just Claud-y. |
| Study | 3× | Quiet, pedagogical, Pomodoro-framed. Milestone bubbles at 25/50/90 min. Stuck nudges reference essays and revision. |
| Dev | 0.75× | Flow-state detection at 20 min. Debugging empathy at 7-min idle. 50% extra confetti on builds. |
| Work | 1.8× | Professional context. Meeting/email/Slack awareness. Personality × Work combos all work. |
| Dance | 0.5× | Claud-y dances. That's it. |
| Brain Rot | 0.5× | Gen Z internet culture mode. Still helpful. Extremely unhinged about it. |

Every mode injects a context block into the AI system prompt — so personality × mode stacking is seamless. Director in Brain Rot mode speaks Gen Z slang dramatically. Companion in Study mode explains things with spaced repetition in mind. All 7 personalities × 6 modes work together.

---

### Alarms & Reminders

- Right-click → Focus Tools → Set Alarm: quick presets (5–240 min) or a custom time picker
- Right-click → Focus Tools → Reminders: create, view, and dismiss individually or all at once
- Natural language in chat also works: "remind me in 30 minutes to take a break"
- Reminders survive restarts; fired ones auto-prune after 24 hours
- Fires as a speech bubble + wave animation, escalating urgency for overdue alarms

---

### Public Holiday Awareness

Claud-y greets you on holidays — automatically, based on your Mac's locale.

Covered regions: **UK · US · Australia · Universal** (Valentine's, April Fools', New Year's Eve), plus **Islamic observances** (Ramadan, Eid al-Fitr, Eid al-Adha, Islamic New Year, Mawlid al-Nabi — pre-computed 2025–2028, ±1–2 days).

---

### Reaction Library Expansion

400+ reaction strings total. Highlights of what's new:

- Dedicated pools for all 9 browsers
- `cursor_build_start` / `cursor_build_done` — Cursor IDE lifecycle
- `claude_code_agent_build` — Claude Code agent builds
- Full Microsoft Office suite reactions
- Full Apple productivity suite reactions
- All existing pools expanded 2–3× to reduce repetition

---

### Under the Hood

- **Swift 6 strict concurrency throughout** — all 8 new managers are `@MainActor`, `@Observable`, properly task-cancelled on teardown
- **Multi-provider API routing** in a single actor (`ClaudeAPIService`) — Claude SSE, OpenAI SSE, and Gemini SSE all parsed distinctly
- **Keychain architecture** extended with per-provider accounts — `claude-api-key`, `openai-api-key`, `gemini-api-key` — each isolated
- **HelpView** fully updated with all new features documented, Privacy section expanded with technical Keychain detail for developers

---

## v1.0.x — Released

### v1.0.5
- Fixed `lazy var roastModeManager` incompatibility with `@Observable` macro
- Fixed SpotifyMonitor Swift 6 Sendable warning (extract String values before actor hop)

### v1.0.4
- Expanded roast fallback pool from 15 → 45 lines across 8 categories

### v1.0.3
- Added Study Mode and Dev Mode (BehaviorModeManager)
- Personality × mode cooldown multiplier
- `BehaviorModeManager.onAppSwitch` / `onBuildComplete` hooks

### v1.0.2
- Added Roast Mode (RoastModeManager) — 45 local roasts + Claude API generation
- Added Spotify sync via DistributedNotificationCenter — per-genre reactions
- Added `.headbanging` (metal) and `.vibing` (lo-fi) animation states

### v1.0.1
- Added Dance Mode (DanceModeManager) — 130 BPM choreography, 5-phrase loop
- Added `.dancing` animation state
- Dance moves: groove, leftArmUp, rightArmUp, bothArmsUp, shimmy, spin, freeze, bigJump, pointUp, lowRide, throwHands, chestPop
- Dance glow effect (pulsing orange blur)

### v1.0.0 — Initial Release
- Floating NSPanel character on macOS 15+
- ClaudyCharacterView — pure SwiftUI custom character drawing
- Personality modes: Companion, Chatty, Hype Coach, Director, Mate, Listener, Custom
- Claude API integration with streaming SSE, Keychain storage
- Clipboard, keyboard, idle, app context, system event monitors
- Pomodoro timer with badge overlay
- Reaction library (JSON-driven, 100+ reactions on launch)
- Quick Launch shortcuts
- Mute, Focus Mode, Demo Mode
- Reaction log (long-press 3s to reveal)
- App Sandbox compliant, no telemetry
