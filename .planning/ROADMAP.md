# Roadmap: Claud-y v3.0

## Overview

v3.0 upgrades Claud-y across four pillars — Tamagotchi care system, tripled animations, personality blending, and multilingual UI — while first clearing the technical debt that would otherwise compound every new feature. The build order is strict: debt cleanup gates everything, SwiftData infrastructure is verified in isolation before game logic runs on it, and the animation expansion draws on both the geometry abstraction and the Tamagotchi stat system before new states fire. Personality blending and the chat UX backlog run after Phase 1's view extraction. Localisation is the most independent pillar and can begin string work as soon as views are extracted.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [ ] **Phase 1: Foundation** - Tech debt cleanup, bug fixes, strict concurrency, and CharacterGeometry abstraction — the hard gate for all v3.0 work
- [ ] **Phase 2: SwiftData Infrastructure** - ModelContainer, VersionedSchema, and persistence verified in isolation before any game logic runs on it
- [ ] **Phase 3: Tamagotchi Core** - Stat system, decay loop, feed/play/pet actions, mood bridge, and overlay UI
- [ ] **Phase 4: Animation Expansion** - Data-driven AnimationConfig system and all 30+ new states across four batches
- [ ] **Phase 5: Personality Blending & Response Doubling** - Two-personality slider, blended system prompts, doubled response pools
- [ ] **Phase 6: Chat UX & API Enhancements** - Scroll-to-bottom, token footer, history toggle, prompt presets, formatting toggle, StackOverflow detection
- [ ] **Phase 7: Multilingual UI** - String Catalogs infrastructure, RTL layout support, and 6-language translations

## Phase Details

### Phase 1: Foundation
**Goal**: The codebase is safe to build on — all known bugs fixed, strict concurrency enabled, oversized views extracted, and CharacterGeometry abstracted so animation expansion can proceed
**Depends on**: Nothing (first phase)
**Requirements**: DEBT-01, DEBT-02, DEBT-03, DEBT-04, DEBT-05, DEBT-06, DEBT-07, DEBT-08, DEBT-09, DEBT-10, DEBT-11, DEBT-12, DEBT-13, DEBT-14, DEBT-15, DEBT-16
**Success Criteria** (what must be TRUE):
  1. App builds with `SWIFT_STRICT_CONCURRENCY = complete` and zero warnings
  2. All five known bugs (BUG-01 through BUG-05) are fixed — correct model IDs served, idle_5min fires correctly, afternoon time-of-day fires correctly, clearHistory() no longer crashes during streaming
  3. SEC-01 resolved — Keychain entries use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
  4. `CharacterRootView`, `SettingsView`, `ChatView`, and `LocalChatResponder` are each split into sub-views/files with all notification wiring kept at root level
  5. `DefaultsKeys` enum exists and all UserDefaults access goes through it; `DemoModeManager` and `V2DemoModeManager` are merged into one
**Plans**: 9 plans

Plans:
- [ ] 01-01-PLAN.md — Verify DEBT-01–06: confirm all bug fixes and Keychain security fix already committed
- [ ] 01-02-PLAN.md — GCD/Timer elimination: replace DispatchQueue and Timer with Task.sleep (DEBT-07, DEBT-15)
- [ ] 01-03-PLAN.md — SettingsView extraction: split 808-line file into 7 section sub-views (DEBT-09)
- [ ] 01-04-PLAN.md — ChatView + LocalChatResponder split: extract 740-line ChatView and split 1790-line responder (DEBT-10, DEBT-11)
- [ ] 01-05-PLAN.md — CharacterGeometry abstraction: extract all drawing constants from ClaudyCharacterView (DEBT-16)
- [ ] 01-06-PLAN.md — CharacterRootView extraction: split 991-line root view, keep all notification wiring at root (DEBT-08)
- [ ] 01-07-PLAN.md — DefaultsKeys enum: centralise all 35+ UserDefaults string literals (DEBT-12)
- [ ] 01-08-PLAN.md — DemoManager merge: unify DemoModeManager + V2DemoModeManager into single manager with DemoVariant (DEBT-13)
- [ ] 01-09-PLAN.md — Strict concurrency gate: enable SWIFT_STRICT_CONCURRENCY = complete, resolve errors (DEBT-14)

### Phase 2: SwiftData Infrastructure
**Goal**: A verified, schema-versioned, privacy-correct SwiftData container is running in the app — nothing written to it yet except a round-trip smoke test
**Depends on**: Phase 1
**Requirements**: TAMA-01, TAMA-02, TAMA-13
**Success Criteria** (what must be TRUE):
  1. App launches with `ModelContainer` initialized in AppDelegate using explicit Application Support URL and `cloudKitDatabase: .none`
  2. `TamagotchiSchemaV1` VersionedSchema exists and wraps all `@Model` types — confirmed by a test write/read round-trip that survives app restart
  3. No iCloud sync occurs — container is local-only; `PrivacyInfo.xcprivacy` documents the data practice
**Plans**: TBD

### Phase 3: Tamagotchi Core
**Goal**: Users can feed, play with, and pet Claud-y — stats persist across launches, decay while the app is open, and drive character animations and speech bubbles without overwhelming the existing ambient system
**Depends on**: Phase 2
**Requirements**: TAMA-03, TAMA-04, TAMA-05, TAMA-06, TAMA-07, TAMA-08, TAMA-09, TAMA-10, TAMA-11, TAMA-12
**Success Criteria** (what must be TRUE):
  1. Hunger, happiness, and energy stats persist across app relaunches — closing and reopening the app shows stats that decayed by the correct elapsed time (capped at 24h)
  2. Tapping Feed, Play, and Pet in the stat overlay changes the relevant stat immediately and Claud-y plays a matching animation (hungry wobble, happy bounce, or sleepy droop)
  3. Stats never fall to zero — the floor holds at 15% and Claud-y shows a grumpy but alive expression rather than an error or blank state
  4. The stat overlay can be toggled on/off in Settings and defaults to hidden — when on, it shows stat bars or icons without obscuring the character
  5. Tamagotchi nudge bubbles respect the rate limiter — no more than one nudge per rate-limited window, with a separate intensity setting (silent/subtle/normal)
**Plans**: TBD

### Phase 4: Animation Expansion
**Goal**: Claud-y has 30+ distinct animation states across emotional, activity, fun/viral, and Tamagotchi batches — all data-driven, all accessible-motion-safe, all pure SwiftUI
**Depends on**: Phase 3
**Requirements**: ANIM-01, ANIM-02, ANIM-03, ANIM-04, ANIM-05, ANIM-06, ANIM-07, ANIM-08
**Success Criteria** (what must be TRUE):
  1. `AnimationConfig` struct drives all animation state rendering — no per-case switch statements remain in `ClaudyCharacterView.onChange`
  2. All 8 emotional states (sad, angry, nervous, excited, bored, love-eyes, embarrassed, mischievous) play visually distinct animations
  3. All 7 activity states (typing, reading, coding, meditating, exercising, eating, studying) trigger on correct app-context events
  4. All 8 fun/viral states (dab, moonwalk, backflip, breakdance, sneeze, yawn, hiccup, facepalm) are reachable and visually distinct
  5. With "Reduce Motion" enabled in macOS Accessibility, all new states show a still or minimal-motion version — no full-movement animations play
**Plans**: TBD

### Phase 5: Personality Blending & Response Doubling
**Goal**: Users can blend two personalities via a slider and experience doubled response variety — both API and Companion Mode responses feel richer and less repetitive
**Depends on**: Phase 1
**Requirements**: BLEND-01, BLEND-02, BLEND-03, BLEND-04, BLEND-05, BLEND-06, RESP-01, RESP-02, RESP-03, RESP-04
**Success Criteria** (what must be TRUE):
  1. A two-personality slider appears in Settings — dragging it to any position immediately affects the next message's tone without restarting the app
  2. Blended prompts produce coherent output at all slider positions (20/80, 50/50, 80/20) — responses feel like a single personality with an influence, not two conflicting voices
  3. The slider is locked (non-interactive) while an API response is streaming — it unlocks when streaming completes
  4. Companion Mode (local keyword responses) and API Mode both reflect the active blend ratio
  5. Ambient speech bubbles in any personality never repeat the same response within a rolling window
**Plans**: TBD

### Phase 6: Chat UX & API Enhancements
**Goal**: The chat panel and settings are polished — missing v2.x features are shipped and users have more control over conversation context, formatting, and API configuration
**Depends on**: Phase 1
**Requirements**: CHAT-01, CHAT-02, CHAT-03, CHAT-04, CHAT-05, CHAT-06, CHAT-07
**Success Criteria** (what must be TRUE):
  1. A scroll-to-bottom button (`arrow.down.circle.fill`) appears in the chat panel when scrolled up and auto-hides at the bottom
  2. The chat footer shows a live token estimate and message count (e.g., "~420 tokens · 6 messages")
  3. Removing an API key in Settings shows a confirmation dialog before deleting — no silent deletions
  4. Users can save, name, and switch between system prompt presets in Settings — presets persist across launches via UserDefaults
  5. StackOverflow URLs detected on the clipboard trigger a contextual quick-action prompt above the character
**Plans**: TBD

### Phase 7: Multilingual UI
**Goal**: Claud-y's UI is fully localised in 6 languages including two RTL scripts — all UI chrome goes through String Catalogs, no hardcoded strings remain, and the character renders correctly in RTL layouts
**Depends on**: Phase 1
**Requirements**: I18N-01, I18N-02, I18N-03, I18N-04, I18N-05, I18N-06, I18N-07, I18N-08, I18N-09, I18N-10
**Success Criteria** (what must be TRUE):
  1. Switching macOS system language to Spanish or French shows all UI chrome (menus, settings, chat labels, buttons) translated — no raw string keys visible
  2. Switching to Arabic or Urdu flips the entire UI to RTL — the speech bubble tail, stat bars, and all horizontal geometry mirror correctly without overlap or clipping
  3. No hardcoded UI strings remain in any Swift file — all text goes through `String(localized:)` with String Catalogs
  4. Companion Mode responds in the active language (via transliteration/keyword matching per language)
  5. API Mode offers a live-translation option with a clear disclosure that it uses the user's own API key and may incur token costs
**Plans**: TBD

## Progress

**Execution Order:**
Phases 1 → 2 → 3 → 4 sequential. Phase 5 can start after Phase 1 (parallel branch). Phase 6 can start after Phase 1 (parallel branch). Phase 7 can start after Phase 1 (parallel branch). Phases 5, 6, 7 must complete before v3.0 ships.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 0/9 | Not started | - |
| 2. SwiftData Infrastructure | 0/TBD | Not started | - |
| 3. Tamagotchi Core | 0/TBD | Not started | - |
| 4. Animation Expansion | 0/TBD | Not started | - |
| 5. Personality Blending & Response Doubling | 0/TBD | Not started | - |
| 6. Chat UX & API Enhancements | 0/TBD | Not started | - |
| 7. Multilingual UI | 0/TBD | Not started | - |
