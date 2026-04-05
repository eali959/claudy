# Project Research Summary

**Project:** Claud-y v3.0
**Domain:** macOS floating AI companion — Tamagotchi virtual pet, personality blending, 30+ animation states, multilingual UI
**Researched:** 2026-04-05
**Confidence:** MEDIUM-HIGH

## Executive Summary

Claud-y v3.0 adds four pillars on top of a stable, locked v2.0 foundation: a Tamagotchi-style virtual pet layer (SwiftData persistence, stat decay, evolution), two-personality blending in the system prompt, an expanded 42-state animation catalog, and localized UI for 6 languages including RTL. The existing architecture (MVVM `@Observable`, `NSPanel`-hosted SwiftUI, 21 `@MainActor` managers, actor-isolated API) is well-suited to absorbing all four pillars without structural changes — new features slot in as additional managers and extensions, not rearchitecting. The primary danger is sequencing: all four pillars have upstream dependencies on tech debt cleanup, and building any pillar before resolving those dependencies creates compounding risk.

The recommended build order is strict: resolve tech debt first (convert Timers to Tasks, extract oversized views, add `DefaultsKeys` enum, merge duplicate DemoModeManagers, add `CharacterGeometry` abstraction, establish `VersionedSchema`), then add SwiftData infrastructure, then build TamagotchiManager, then animate new states, then wire personality blending, then do localization. Personality blending has no dependency on the Tamagotchi system and can run in parallel after Phase 1. Localization is the most parallelizable — it depends only on strings being externalised, which can happen independently of all other pillars.

The top risk is SwiftData misuse: shipping without `VersionedSchema` causes a guaranteed user-data-loss crash on first schema migration; writing SwiftData on `@MainActor` blocks the character's animation frame; and misplacing `@Query` in an ancestor view triggers a full re-render cascade on every stat decay event. Each of these has a clear, low-cost prevention — but only if implemented before the first `@Model` class is committed. The second major risk is Tamagotchi notification fatigue: the existing app already has 8 ambient bubble sources; the pet layer must route all nudges through the rate-limited path with a separate intensity setting, or the feature will be disabled by users within days.

---

## Key Findings

### Recommended Stack

The existing stack is unchanged and correct. Three new technologies are added, all zero-install system frameworks. SwiftData replaces UserDefaults extension for Tamagotchi persistence — UserDefaults already manages 20+ keys and cannot cleanly handle typed schema migration. The `ModelContainer` must be initialized in `AppDelegate` (not via the standard `.modelContainer()` scene modifier) because Claud-y has no `WindowGroup`. All SwiftData work stays on `@MainActor` for simplicity given the low data volume, with explicit `context.save()` calls after every mutation. String Catalogs (`.xcstrings`) replace the legacy `.strings` format for all new localization work — they auto-extract keys from source, track per-string translation state, and unify plurals. The animation architecture stays as enum + computed properties; no new animation drivers are needed.

**Core technologies:**
- SwiftData (`@Model`, `ModelContainer`, `ModelContext`) — Tamagotchi persistence — typed, schema-migratable, local-only; eliminates UserDefaults overload
- `CharacterAnimationState` enum + `AnimationConfig` struct — 42-state animation system — data-driven `onChange`, eliminates 35×35 state-transition problem
- String Catalogs (`.xcstrings`) — i18n infrastructure — auto-populates from source, tracks translation state, handles plurals without `.stringsdict`

**Critical version requirements:**
- `VersionedSchema` must wrap all `@Model` types from commit zero (pre-launch; cannot be retrofitted without a two-release remediation cycle)
- `cloudKitDatabase: .none` in `ModelConfiguration` is the explicit iCloud-sync prevention knob; must be set explicitly, not left at default

### Expected Features

**Must have (table stakes — Pillar 2: Tamagotchi):**
- Three visible stats: hunger, happiness, energy — displayed as glanceable bars or indicators
- Feed and pet interactions — minimum viable care loop
- Stat decay while app is open and proportional catch-up on resume (capped at 4h maximum offline decay)
- Stats persist across launches via SwiftData — non-negotiable; without this the system has no meaning
- Mood expressions driven by stat thresholds — what makes stats feel alive (`hungry_wobble`, `sleepy_droop`, `happy_bounce`)

**Must have (table stakes — Pillar 1: Personality Blending):**
- Two-personality slider in Settings, persisted across launches
- Blended system prompt that produces coherent (not incoherent) output — dominant voice + modifier pattern, not 50/50 text concatenation

**Must have (table stakes — Pillar 3: Animation):**
- `cleanupAllAnimationState()` as first change to `ClaudyCharacterView` before any new states are added
- First batch of new emotional states: `sad`, `angry`, `nervous`, `excited`, `bored`
- First batch of activity states: `typing`, `coding`
- Tamagotchi stat-linked states: `hungry_wobble`, `sleepy_droop`, `happy_bounce`, `full_belly_pat`

**Must have (table stakes — Pillar 4: Localization):**
- String Catalog infrastructure with `String(localized:)` sweep through all UI views
- RTL layout audit: `.leading`/`.trailing` everywhere, speech bubble tail geometry flipped via `flip` multiplier
- English + Spanish + French as first release (largest reach, no RTL complexity)

**Should have (differentiators):**
- Evolution stages: Baby → Teen → Adult → Special driven by care score over time
- Named personality blend presets (saveable ratios)
- Second batch of animations: `moonwalk`, `backflip`, `breakdance`, `evolution_transition`
- Arabic, Hindi, Urdu with RTL support
- Ambient reaction pool blending (weighted random between two personality reaction pools)
- Tamagotchi nudge intensity setting (silent / subtle / normal) independent of main Chattiness slider

**Defer (v3.1+):**
- Romanized script toggle for Arabic, Hindi, Urdu — novel implementation with no existing reference pattern; maintenance burden is high
- Reaction string localisation — 400 strings × 6 languages = 2,400 units; tone does not survive translation; explicitly out of scope for v3.0
- Named personality blend presets if ambient blending is not validated first
- Evolution care log/history view
- Death mechanic — explicitly excluded by design (stat floor at 15, never zero)

### Architecture Approach

The four new pillars integrate without structural changes to the existing MVVM architecture. `TamagotchiManager` is a new `@MainActor` class owned by `CharacterViewModel`, following the identical pattern as the 21 existing managers. `ModelContainer` is owned by `AppDelegate` as a process-level singleton and injected via `.modelContainer()` on `CharacterRootView`. `PersonalityManager` gains three new properties (`blendEnabled`, `secondaryMode`, `blendRatio`) and a `blendedPromptBlock()` private method; its `systemPrompt` computed property is the only change, and all callers (`ChatViewModel.streamReply()`, `asyncGreeting()`) are untouched. Animation expansion is handled entirely via new `CharacterAnimationState+Config.swift` extension file — the existing `ClaudyCharacterView.onChange` becomes data-driven rather than case-driven. Localization is a pure infrastructure layer requiring no architectural change.

**Major components:**
1. `TamagotchiManager` — stat decay loop (300s Task cadence), feed/play/pet actions, evolution threshold checks, mood → animation bridge
2. `CharacterAnimationState+Config.swift` — `AnimationConfig` struct + `EyeShape`/`MouthShape` enums, making all 42 animation states data-driven
3. `PersonalityManager.blendedPromptBlock()` — dominant-voice + modifier prompt composition, activated by `blendEnabled` flag, transparent to all API callers
4. `TamagotchiOverlayView` — isolated stat bar display; uses `@Query` in this leaf view only, never in ancestor views
5. String Catalog split: `Localizable.xcstrings` (UI chrome), `Reactions.xcstrings` (English-only, marked `shouldTranslate: false`), `Tamagotchi.xcstrings`, `Onboarding.xcstrings`

### Critical Pitfalls

1. **Unversioned SwiftData schema** — wrap all `@Model` types in `VersionedSchema` before the first build that persists any data; cannot be retrofitted without a two-release remediation cycle causing user data loss. Gate: no `@Model` class merged to main without `VersionedSchema` wrapper.

2. **SwiftData writes on `@MainActor` block animation frames** — the research files are split on this: ARCHITECTURE.md recommends staying `@MainActor` given low data volume; PITFALLS.md recommends `@ModelActor` to prevent frame drops. Resolution: start with `@MainActor` and profile in Instruments before adding `@ModelActor` complexity. If decay write causes dropped frames at 300s interval, migrate then.

3. **Tamagotchi notification fatigue kills retention** — route all Tamagotchi stat nudges through the rate-limited `showSpeechBubble()` path (not `showBubbleDirect()`); only allow `showBubbleDirect()` for critical state, once per 30-minute window. Add Tamagotchi nudge intensity setting. Default stat overlay to hidden.

4. **State bleed at 30+ animation states** — implement `cleanupAllAnimationState()` as the very first change to `ClaudyCharacterView.swift`; this function resets all animation variables to neutral before applying entry effects for any new state. Without it, every new state risks residual animation from a predecessor.

5. **`onReceive` liveness lost during view extraction** — keep all notification wiring (`.claudyToggleChat`, `.claudyQuickActionFired`) at the `CharacterRootView` top level after extraction; moving listeners into conditionally-shown sub-views silently breaks the global hotkey and quick-action pre-fill.

---

## Implications for Roadmap

Based on research, strict dependency ordering applies. Phases 1–3 are sequential. Phases 4 and 5 can run in parallel after Phase 3 is complete. Phase 6 is parallel to all.

### Phase 1: Foundation — Tech Debt + Infrastructure Gates

**Rationale:** Every subsequent phase builds on the code that Phase 1 stabilises. SwiftData in a corrupted concurrency environment produces opaque crashes. Adding 20 animation states to a 991-line view is untenable. Writing new UserDefaults keys before a `DefaultsKeys` enum exists causes silent data bugs. This phase is not optional and cannot be deferred.

**Delivers:**
- Swift strict concurrency errors surfaced and fixed
- `CharacterRootView`, `SettingsView`, `ChatView` extracted to sub-views (with notification wiring kept at root)
- `DefaultsKeys` enum centralising all UserDefaults keys
- `DemoModeManager` + `V2DemoModeManager` merged into one
- `talkingTimer` and `dotTimer` converted from `Timer` to `Task` loops
- `CharacterGeometry` struct abstracting all draw constants
- `TamagotchiSchemaV1 VersionedSchema` stub (even with no stages yet — establishes schema fingerprint)
- Bug fixes: BUG-01 through BUG-05 and SEC-01 from PROJECT.md

**Avoids:** Pitfalls 8 (state bleed), 9 (magic string keys), 11 (liveness loss), 13 (timer restart), 15 (DemoManager duplication), and unversioned schema crash (Pitfall 1)

**Research flag:** Standard patterns — skip research-phase. These are well-documented refactoring tasks with clear scope.

---

### Phase 2: SwiftData Infrastructure

**Rationale:** Must be verified in isolation before any game logic is built on top. A container that fails silently or writes to the wrong path is impossible to debug once TamagotchiManager is also running.

**Delivers:**
- `TamagotchiState.swift` and `EvolutionRecord.swift` `@Model` classes inside `TamagotchiSchemaV1`
- `ModelContainer` initialized in `AppDelegate` with `cloudKitDatabase: .none` and explicit store URL in `~/Library/Application Support/`
- `mainContext` injected via `.modelContainer()` on `CharacterRootView`
- Verified round-trip: container initialises, writes persist, survive app restart
- Privacy: `PrivacyInfo.xcprivacy` entry documenting local-only storage

**Avoids:** Pitfalls 1 (unversioned schema), 2 (wrong context isolation), 9 (data residency policy set here)

**Research flag:** Standard patterns — Apple documentation is clear; the `NSHostingView` injection approach is confirmed to match existing `.environment()` pattern in `FloatingWindowController`.

---

### Phase 3: TamagotchiManager Core (Pillar 2 — MVP)

**Rationale:** The stat system is the structural foundation that all Tamagotchi animation states, mood expressions, and evolution depend on. Must ship before any Tamagotchi-linked animation states are added.

**Delivers:**
- `TamagotchiManager`: 300s decay Task loop, elapsed-time accounting with 4h offline cap, sleep-mode pause via `FocusModeMonitor`
- `feed()`, `play()`, `pet()` actions — synchronous, save immediately
- `currentMood: TamagotchiMood` computed property → `CharacterViewModel.syncTamagotchiMood()` bridge
- `TamagotchiOverlayView` with `@Query` isolated in this leaf view only
- `ReactionTrigger` cases for Tamagotchi events + `ReactionLibrary.json` entries
- Decay rate modifiers wired to `BehaviorMode` (Study: energy ×1.4; Dev: hunger ×1.2; etc.)
- Tamagotchi nudge intensity setting with rate-limited bubble dispatch

**Avoids:** Pitfalls 2 (profile before adding ModelActor), 3 (time accounting), 6 (notification fatigue), 14 (@Query isolation)

**Open product decisions required before implementation:**
- Should Mac sleep pause stat decay entirely, or apply 40% rate? (research recommends full pause via `FocusModeMonitor` screen-lock signal)
- What is the exact UI pattern for stat display: floating badge, overlay bar, or full panel? (affects `TamagotchiOverlayView` scope)

**Research flag:** Tamagotchi time-accounting and sleep/wake handling may benefit from a targeted research spike. The screen-lock pausing pattern via `FocusModeMonitor` is established in the codebase already; the open question is the decay math contract during Mac sleep vs app-backgrounded vs user-active.

---

### Phase 4: Animation Expansion — 42 States (Pillar 3)

**Rationale:** Depends on Phase 1 (`CharacterGeometry` abstraction, Timer → Task conversion) and Phase 3 (Tamagotchi stat triggers exist). The `AnimationConfig` refactor is non-breaking — it establishes the data-driven `onChange` pattern before adding any new states.

**Delivers:**
- `CharacterAnimationState+Config.swift`: `AnimationConfig`, `EyeShape`, `MouthShape` enums
- Data-driven `ClaudyCharacterView.onChange` (replaces manual switch)
- `cleanupAllAnimationState()` as first change to character view
- Batch 1 (emotional): `sad`, `angry`, `nervous`, `excited`, `bored`, `love_eyes`, `embarrassed`, `mischievous`
- Batch 2 (activity): `typing`, `reading`, `coding`, `meditating`, `exercising`, `eating`, `studying`
- Batch 3 (Tamagotchi): `hungry_wobble`, `sleepy_droop`, `happy_bounce`, `full_belly_pat`, `evolution_transition`
- Batch 4 (fun/viral): `dab`, `moonwalk`, `backflip`, `breakdance`, `sneeze`, `yawn`, `hiccup`
- `accessibilityReduceMotion` guard on all new states via `supportsMotion` enum property

**Note:** Batch 3 requires Phase 3 complete (stat triggers). Batches 1, 2, and 4 can be stubbed (state exists, no trigger wired) and run partially in parallel with Phase 3 once `AnimationConfig` is established.

**Avoids:** Pitfalls 7 (geometry abstraction from Phase 1), 8 (cleanupAllAnimationState), 13 (Timer already converted in Phase 1)

**Research flag:** Standard patterns — animation enum + computed property approach is fully specified in ARCHITECTURE.md and STACK.md. No additional research needed.

---

### Phase 5: Personality Blending (Pillar 1)

**Rationale:** No dependency on Phases 3 or 4. The only prerequisite is Phase 1 (`SettingsView` extracted so it is safe to add blend UI). Can run in parallel with Phases 3 and 4 on a separate branch.

**Delivers:**
- `PersonalityManager`: `blendEnabled`, `secondaryMode`, `blendRatio` properties with UserDefaults persistence
- `blendedPromptBlock()`: dominant-voice + modifier pattern (not 50/50 string concatenation)
- Blend UI in `SettingsView`: two-personality picker + horizontal slider with 50/50 snap haptic
- "Preview" button: fires a test greeting with blended prompt before committing
- Ambient reaction pool blending: probabilistic selection between two personality pools at `blendRatio`
- Cross-provider validation: blended prompts tested with Claude, OpenAI, and Gemini; token budget verified

**Avoids:** Pitfall 10 (incoherent mid-range output — dominant voice + modifier prevents this)

**Open product decisions required before implementation:**
- Should blend be disabled when custom personality mode is active? (research recommends yes — custom text cannot be weighted against a template block)
- Is there a maximum number of saveable named blend presets? (MVP recommendation: defer presets to post-launch, ship just the slider)

**Research flag:** The personality blending prompt composition approach (dominant voice + modifier) should be empirically tested with 3–5 prompt pairs at 20/80, 50/50, and 80/20 ratios before building the slider UI. This is a quick validation step, not a full research phase.

---

### Phase 6: Multilingual UI (Pillar 4)

**Rationale:** No architectural dependencies on Pillars 1–3. Depends only on strings being externalised (which happens organically as views are written). Can run fully in parallel after Phase 1's view extraction is complete.

**Delivers:**
- String Catalog split: `Localizable.xcstrings`, `Reactions.xcstrings` (marked `shouldTranslate: false`), `Tamagotchi.xcstrings`, `Onboarding.xcstrings`
- `String(localized:)` sweep through all UI views (no `NSLocalizedString` mixing)
- RTL geometry fix: `let flip: CGFloat = layoutDirection == .rightToLeft ? -1 : 1` multiplier on all `ClaudyCharacterView` horizontal geometry including speech bubble tail
- Default character panel position flipped for RTL locales
- English + Spanish + French translations shipped first
- Arabic, Hindi, Urdu shipped second (RTL + new script validation required)
- Settings note: "Personality reactions are in English in v3.0"

**Avoids:** Pitfalls 4 (invisible string gaps), 5 (RTL character geometry), 12 (API inconsistency)

**Open product decisions required before implementation:**
- Final decision on reaction string scope: research strongly recommends English-only for reactions — needs sign-off before translator handoff
- Should Romanized script toggle ship in v3.0 or be deferred? (research recommends defer — no existing implementation reference)

**Research flag:** RTL geometry audit of `ClaudyCharacterView` drawing code should be done as a targeted research spike before any RTL work begins. The `flip` multiplier approach is specified, but there are likely edge cases in the 991-line view that require careful review.

---

### Phase Ordering Rationale

- Phase 1 is a hard gate for everything. Building on unfixed concurrency bugs and oversized views multiplies risk quadratically.
- Phase 2 (SwiftData) must be verified standalone before Phase 3 builds on it. A broken container foundation causes opaque failures.
- Phase 3 (TamagotchiManager) is the structural foundation for all stat-driven animation triggers in Phase 4. Batches 1, 2, and 4 of Phase 4 can begin in parallel, but Batch 3 (stat-linked states) cannot.
- Phase 5 (Blending) has no cross-pillar dependency and is the most parallelizable work. If resourcing allows, start Phase 5 immediately after Phase 1.
- Phase 6 (Localization) is the most independent pillar. It can begin string extraction work as soon as views are extracted in Phase 1.

### Research Flags

Phases needing deeper research during planning:
- **Phase 3 (Tamagotchi decay contract):** The sleep/wake time accounting math and the interaction between `FocusModeMonitor` screen-lock events and decay pausing should be specced precisely before implementation. One targeted research spike (~1 hour) to confirm the `ProcessInfo.systemUptime` approach is sufficient.
- **Phase 5 (Blend prompt validation):** Empirically test 3 personality pair combinations at 3 slider positions with live API before building the UI. Not a full research phase — a 30-minute prompt engineering test session.
- **Phase 6 (RTL geometry audit):** Read `ClaudyCharacterView.swift` in its entirety and identify every hard-coded `x` offset and `Path` coordinate before writing any RTL code. Document as a RTL geometry map.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Tech debt):** All tasks are well-defined with clear scope from CONCERNS.md, QUALITY.md, and PROJECT.md.
- **Phase 2 (SwiftData infra):** Pattern is fully specified in ARCHITECTURE.md and STACK.md with official Apple documentation backing.
- **Phase 4 (Animation expansion):** The `AnimationConfig` data-driven pattern is fully specified. Adding new states is additive and mechanical.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | SwiftData, String Catalogs, and animation pattern are all verified against Apple docs and WWDC sessions; the `NSHostingView` injection pattern matches existing code exactly |
| Features | MEDIUM-HIGH | Tamagotchi stat structure is HIGH (Tamagotchi Wiki + open-source implementations); specific decay rate numbers are MEDIUM (synthesised from Tamagotchi Uni rates); evolution threshold specifics are MEDIUM (design synthesis); personality blending approach is MEDIUM (NeurIPS research confirms weighted blocks work, but practical tuning is novel) |
| Architecture | HIGH | All four integration questions answered from official docs + direct codebase inspection; build order derived from confirmed dependency graph |
| Pitfalls | HIGH for SwiftData, animation/refactor pitfalls (sourced from documented Apple bugs + CONCERNS.md codebase audit); MEDIUM for Tamagotchi design pitfalls (competitor analysis + game design research) |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **`@MainActor` vs `@ModelActor` for SwiftData writes:** ARCHITECTURE.md and PITFALLS.md give conflicting recommendations. Resolution: ship with `@MainActor` (simpler, lower risk of `@ModelActor` thread capture bugs), profile in Instruments during Phase 3, and migrate to `@ModelActor` only if frame drops are measured. Document this decision in code.

- **Evolution stage visual design:** The 4-stage visual evolution (Baby → Teen → Adult → Special) requires design work (what do each visual forms look like in the terra-cotta palette?) before implementation. This is a product/design decision, not a technical one. Must be resolved before Phase 4 Batch 3.

- **Tamagotchi overlay UI pattern:** Research specifies `TamagotchiOverlayView` but does not specify the exact UI pattern (floating badge vs retractable panel vs always-visible bar). This is a product decision that affects the view's scope and dismissibility logic.

- **Personality blend presets:** The MVP recommendation is to defer presets to post-launch and ship only the slider. This needs explicit sign-off before Phase 5 scoping.

- **Romanized script toggle:** No existing SwiftUI implementation reference was found. LOW confidence on this feature. Recommend deferring to v3.1 and noting it explicitly in the localization Phase 6 scope.

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation — ModelContainer, ModelConfiguration, SwiftData concurrency
- WWDC23/24/25 sessions — SwiftData, String Catalogs, RTL layout
- Existing codebase direct inspection — `CharacterAnimationState.swift`, `PersonalityManager.swift`, `FloatingWindowController.swift`, `CONCERNS.md`, `QUALITY.md` (all inspected 2026-04-05)
- Tamagotchi Wiki, TamaTalk community guides — stat mechanics structure

### Secondary (MEDIUM confidence)
- AzamSharp SwiftData Architecture Patterns (2025-03) — `@MainActor` pattern recommendation
- massicotte.org — `@ModelActor` thread capture pitfall
- Wade Tregaskis — SwiftData pitfalls
- fatbobman.com — SwiftData concurrency, SwiftUI performance
- PersonaFuse framework, NeurIPS 2025 — personality blending via weighted prompt blocks
- Mert Bulan — VersionedSchema launch crash documentation
- NotiSprite competitor analysis — Tamagotchi notification fatigue precedent

### Tertiary (LOW confidence)
- Romanized script toggle — no existing SwiftUI reference found; design synthesis only
- Specific evolution threshold numbers — synthesised from Tamagotchi Uni rates, not sourced from a direct implementation

---

*Research completed: 2026-04-05*
*Ready for roadmap: yes*
