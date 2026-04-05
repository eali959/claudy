# Claud-y v3.0

## What This Is

Claud-y is a macOS desktop companion app — a small, round, animated orange creature that lives in a floating transparent window on the user's screen. It reacts to your work, tracks focus sessions, and chats using Claude, ChatGPT, or Gemini. v3.0 is a major upgrade: doubled response intelligence with personality blending, a Tamagotchi care system with visual evolution, 30+ animations (tripled from current), multilingual UI (6 languages), and a dedicated tech-debt cleanup pass. Same cute philosophy, same zero-dependency architecture, same privacy-first approach.

## Core Value

Claud-y must feel alive, adorable, and genuinely helpful — never annoying, never intrusive, never collecting data behind the user's back. If everything else fails, Claud-y must still bob on your screen, react to your apps, and make you smile.

## Requirements

### Validated (shipped in v2.0)

- ✓ 3 AI providers: Claude, ChatGPT, Gemini with per-provider Keychain keys — v2.0
- ✓ 7 personalities: Companion, Chatty, HypeCoach, Director, Mate, Listener, Custom — v2.0
- ✓ 6 behaviour modes: Normal, Study, Dev, Work, Dance, BrainRot with cooldown multipliers — v2.0
- ✓ 8 background managers (hotkey, focus, breaks, stats, quick actions, scratchpad, mood, wrap-up) — v2.0
- ✓ 9 browsers + 60+ apps detected, 400+ reaction strings — v2.0
- ✓ Alarms, reminders, Pomodoro, confetti, sound effects, streaks, size toggle — v2.0
- ✓ Public holiday awareness (UK/US/AU/Islamic 2025–2028) — v2.0
- ✓ Global hotkey ⌘⇧Space, Focus/DND sync, break nudges, daily wrap-up — v2.0
- ✓ Companion Mode (local keyword engine, 22 intents, 40+ Easter eggs) always free — v2.0
- ✓ Floating draggable NSPanel, menu bar control — v2.0

### Active (v3.0 scope)

**Pillar 1: Double Smart Responses**
- [ ] Double the response pool for every personality × mode combination (companion + API)
- [ ] Personality blending via slider spectrum (75% Companion / 25% Chatty style)
- [ ] Blended system prompt generation from two personalities with weighted mixing

**Pillar 2: Tamagotchi Mode**
- [ ] Tamagotchi stats: hunger, happiness, energy — persistent via SwiftData
- [ ] Toggleable always-on layer (stats run silently, subtle, never annoying) OR overlay mode
- [ ] Feed, play, pet interactions
- [ ] Visual evolution stages (baby → teen → adult → special forms) based on care level
- [ ] Mood expressions tied to stats (happy, grumpy, sad, energetic, sleepy)
- [ ] Full privacy disclosure in README and release notes (local-only SwiftData, never synced)

**Pillar 3: Triple Animations (10 → 30+)**
- [ ] Emotional range: sad, angry, nervous, excited, bored, love-eyes, embarrassed, mischievous
- [ ] Activity animations: typing, reading, coding, meditating, exercising, eating, studying
- [ ] Fun/viral: dab, moonwalk, backflip, breakdance, sneeze, yawn, hiccup, facepalm
- [ ] Tamagotchi-specific: hungry wobble, sleepy droop, happy bounce, full-belly pat, evolution transitions

**Tech Debt Cleanup (dedicated phase)**
- [ ] Fix BUG-01: `ClaudeAPIService.swift:18` model ID → `claude-3-5-haiku-20241022`
- [ ] Fix BUG-02: `ClaudeAPIService.swift:24` + `SettingsView.swift:128` sync to `claude-opus-4-6`
- [ ] Fix BUG-03: `IdleMonitor.swift:78` duplicate condition — `idle_5min` never fires
- [ ] Fix BUG-04: `IdleMonitor.swift:292` hours 18–21 fall to `.launch` — add `.afternoon`
- [ ] Fix BUG-05: `ChatViewModel.swift:59` array crash on mid-stream `clearHistory()`
- [ ] Fix SEC-01: `KeychainService.swift:28` add `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- [ ] Eliminate GCD in `TypingIndicatorView.swift:26` — use `Task.sleep`
- [ ] Extract `CharacterRootView.swift` (991 lines) into sub-views
- [ ] Extract `SettingsView.swift` (808 lines) into sub-views
- [ ] Extract `ChatView.swift` (740 lines) into sub-views
- [ ] Refactor `LocalChatResponder.swift` (1,790 lines) — split by intent category
- [ ] Centralise UserDefaults keys into a `DefaultsKeys` enum
- [ ] Merge/deduplicate `DemoModeManager.swift` and `V2DemoModeManager.swift`
- [ ] Set `SWIFT_STRICT_CONCURRENCY = complete` in Xcode project

**v2.x Backlog (absorbed into v3.0)**
- [ ] Wire `showRemoveConfirm` to Remove Key button as `.confirmationDialog`
- [ ] Chat close (×) button, Escape-to-close, export/save log, tap-to-copy, scroll-to-bottom
- [ ] Token estimate footer in chat
- [ ] Markdown rendering in assistant bubbles via `AttributedString(markdown:)`
- [ ] Mood-to-animation mapping (`applyMood(for: MoodContext)`)
- [ ] Additional app detection: Spotify, Apple Music, ChatGPT, Perplexity + reaction pools
- [ ] Long compile awareness (>60s build → coffee prompt)
- [ ] Drag tilt ±8° with spring-settle
- [ ] StackOverflow clipboard detection

**Multilingual UI (6 languages)**
- [ ] English (default), Spanish, French, Arabic (RTL), Hindi, Urdu (RTL)
- [ ] Romanized toggle for Arabic (Arabizi), Hindi (Hinglish), Urdu (Roman Urdu)
- [ ] All UI copy through `NSLocalizedString` / `Localizable.strings`
- [ ] All 400+ reaction strings localised (or decision on English-only reactions)
- [ ] RTL layout support via `.environment(\.layoutDirection, .rightToLeft)`

**API Mode Enhancements**
- [ ] Conversation history toggle (session-scoped only, never persisted)
- [ ] User-defined system prompt presets (saved to UserDefaults, local only)
- [ ] Verify chattiness slider (1–5) is fully wired
- [ ] Response formatting toggle (plain text vs markdown)
- [ ] Per-provider model update mechanism (JSON config or Settings entry)

### Out of Scope

- iCloud or remote sync — privacy-first, `ThisDeviceOnly` Keychain
- Analytics, crash reporting, telemetry — same as v1/v2
- Windows / iOS / iPadOS port — macOS only
- In-app purchases or monetisation — free forever
- Web dashboard or companion service — standalone app
- New permissions beyond v2 — no additional entitlements
- Real-time chat/messaging between users — single-user app

## Context

Claud-y has shipped v2.0 with a mature architecture: MVVM with `@Observable`, actor-based `ClaudeAPIService`, 12 `@MainActor` singleton managers, pure SwiftUI character drawing, and zero third-party dependencies. The codebase has grown to ~15K+ lines with some tech debt (oversized views, magic strings, zero tests, one GCD violation). The v3.0 upgrade adds significant new systems (SwiftData persistence, personality blending, evolution stages) while staying true to the zero-dependency, privacy-first philosophy.

The existing animation system uses 15 `CharacterAnimationState` cases (expanded from original 10) with eye position, mouth shape, body scale/offset, and arm rotation driven by SwiftUI state. Tripling to 30+ means adding new enum cases and SwiftUI drawing logic — no Lottie, no SpriteKit.

The personality × mode system stacks `[base] + [personality block] + [mode block]` in the system prompt. Personality blending will require a new interpolation layer that merges two personality blocks with weighted influence.

## Constraints

- **Zero dependencies**: No SPM packages, no CocoaPods, no third-party frameworks
- **Swift 6 strict concurrency**: All new code must be `@MainActor` or actor-isolated — set `SWIFT_STRICT_CONCURRENCY = complete`
- **Privacy**: No data leaves the device except user-initiated API calls. SwiftData store is local-only. Full privacy disclosure required for Tamagotchi state.
- **macOS 15+**: Deployment target stays macOS 15 (Sequoia)
- **SwiftUI only**: No UIKit, no AppKit except `NSPanel`/`NSStatusItem` for floating window
- **App Store consideration**: Sandbox blocks `sysctl` process detection — decision pending on App Store vs direct distribution for v3.0

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| SwiftData for Tamagotchi persistence | Richer than UserDefaults, supports history/evolution timeline, local-only | — Pending |
| Personality slider (not menu picker) | More expressive blending, fun UI, unique differentiator | — Pending |
| Visual evolution + mood expressions | Both requested — evolution stages for long-term engagement, mood for moment-to-moment feedback | — Pending |
| All 4 animation categories (30+ states) | Emotional, activity, fun/viral, Tamagotchi — all requested, maximises expressiveness | — Pending |
| Dedicated tech debt phase (not interleaved) | Clean foundation before building new systems — reduces risk of building on shaky ground | — Pending |
| 6 languages for v3.0 | English, Spanish, French for dev/student reach; Arabic, Hindi, Urdu per product requirement | — Pending |
| Romanized toggle for Arabic, Hindi, Urdu | Diaspora/heritage speakers who speak but don't read native script | — Pending |
| Absorb v2.x backlog into v3.0 | Cleaner release — no half-shipped features | — Pending |

## Open Questions

- **Model ID management**: Hardcode model IDs or use a local/remote config for updates without app releases?
- **Reaction localisation**: Translate all 400+ reaction strings or keep English reactions with localised UI chrome only?
- **Distribution**: App Store (sandbox limits process detection) vs direct download for v3.0?

---
*Last updated: 2026-04-05 after initialization*
