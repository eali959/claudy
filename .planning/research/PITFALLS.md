# Domain Pitfalls

**Domain:** macOS floating AI companion — v3.0 upgrade (SwiftData, Tamagotchi, 30+ animations, localization, tech-debt refactor)
**Project:** Claud-y v3.0
**Researched:** 2026-04-05

---

## Critical Pitfalls

Mistakes in this category cause launch crashes, data loss, or rewrites.

---

### Pitfall 1: Shipping SwiftData Without VersionedSchema — Guaranteed User Crash

**What goes wrong:**
You ship the Tamagotchi SwiftData store without wrapping the `@Model` in a `VersionedSchema`. Everything works fine in development. Later — even for the first schema change, such as adding a new stat or an evolution stage — you create a `SchemaMigrationPlan` and ship it. Existing users crash on launch with `"Cannot use staged migration with an unknown model version."` Their only recovery is deleting and reinstalling the app, losing all Tamagotchi data.

**Why it happens:**
SwiftData stores a fingerprint of the schema in the persistent store. If the first version was unversioned, SwiftData cannot identify what "V1" is and cannot run any migration plan on top of it. This is a well-documented, unfixed Apple bug that has affected production apps since SwiftData shipped in 2023. It is not mentioned anywhere in Apple's own SwiftData tutorials.

**Consequences:**
- Users lose all Tamagotchi stats and evolution history on upgrade
- App Store reviews tank on first schema change post-launch
- Two-release remediation cycle required: first release to add versioning with no schema change, wait for adoption, then second release with migration — adds 1–2 sprints of pure overhead

**Prevention:**
- Define `TamagotchiSchemaV1` as a `VersionedSchema` with a `versionedSchema: VersionedSchema.Type = TamagotchiSchemaV1.self` before shipping the first build that persists any data
- Use a `SchemaMigrationPlan` stub (even with no stages) from day one
- Test migration path from V1 → V2 in a separate simulator before shipping Tamagotchi at all

**Detection:**
- Code review gate: any `@Model` class must be nested inside a `VersionedSchema` enum
- Launch crash with the string "unknown model version" is the tell

**Phase to address:** Tamagotchi architecture phase — before any `@Model` is committed to the codebase.

---

### Pitfall 2: SwiftData ModelContext on @MainActor Blocks the UI During Stat Decay Writes

**What goes wrong:**
The Tamagotchi decay loop runs on a timer (every 30–60 seconds). If stat decay, evolution checks, and mood writes are all done on the `@MainActor`-isolated default `ModelContext`, each write synchronously commits on the main thread. The character's bob animation starts hitching during saves. With full evolution-stage history stored, this worsens over time.

**Why it happens:**
SwiftData's `@Query` macro and the `ModelContext` injected from the SwiftUI environment are both `@MainActor`-bound. It is the natural path of least resistance to write all stat mutations there. The decay loop already uses the `@MainActor` timer pattern that all other managers in Claud-y use — it feels consistent to keep it there.

**Consequences:**
- Dropped frames in the bob/idle animation during save commits
- `@MainActor` contention with streaming API responses (the SSE loop in `ClaudeAPIService` hops to main for UI updates)
- Compounded by the existing unnecessary `MainActor.run` hops in the API hot path (already documented in QUALITY.md)

**Prevention:**
- Isolate all SwiftData reads/writes inside a `@ModelActor` struct (not `@MainActor`)
- Pass `PersistentIdentifier` (Sendable) to the main actor for display; never pass `@Model` instances across actor boundaries
- Keep the decay timer on `@MainActor` for scheduling, but dispatch the actual write to the `ModelActor`

**Detection:**
- Profiling with Instruments → Core Animation shows frame drops coinciding with `NSPersistentStore` write events
- The character animation fps counter (if added) shows dips every decay interval

**Phase to address:** Tamagotchi architecture phase, before wiring decay loop.

---

### Pitfall 3: Tamagotchi Stat Time-Accounting Breaks Across App Quit, Mac Sleep, and System Clock Changes

**What goes wrong:**
Stats are designed to decay by X points per hour of real time. The decay loop runs while the app is open. If the user quits for 8 hours, then reopens, you must apply "catch-up decay." The naive implementation computes `elapsed = now - lastSavedDate` and applies proportional decay. This breaks in three ways: (1) Mac sleep/wake causes `Date()` to jump forward while no real CPU time passed — applying 8 hours of decay instantly after a lock-screen is jarring; (2) the user manually moves the system clock; (3) a bug causes `lastSavedDate` to never write, so `elapsed` is either 0 or enormous.

**Why it happens:**
Time-based game loops assume a reliable, continuous clock. macOS does not provide one from the app's perspective. This problem is known from original Tamagotchi hardware (which had a pause button specifically to address it) and from mobile game engines that ship explicit "time cheating" protection.

**Consequences:**
- Pet is always near-death after any overnight gap (users feel punished, not engaged)
- Instant full-hunger recovery after mac wakeup feels broken and cheapens the system
- Users who travel across time zones get unexpected stat spikes

**Prevention:**
- Cap a single catch-up window at a configurable maximum (e.g. 4 hours of offline decay, not unlimited)
- Store the last-active wall clock AND a `ProcessInfo.processInfo.systemUptime` snapshot at each save; on restore, compare both to detect clock jumps vs genuine elapsed time
- Provide an explicit "sleep mode" in the Tamagotchi layer that pauses decay when the Mac is locked (mirror the pattern `FocusModeMonitor` already uses for screen-lock detection via `com.apple.screenIsUnlocked`)
- Write `lastSavedDate` defensively: write it first, then write stats

**Detection:**
- Test: set system clock forward 12 hours while app is backgrounded, reopen; verify pet is not dead
- Test: force-quit app, wait 10 minutes, reopen; verify decay is proportional but capped

**Phase to address:** Tamagotchi persistence design — document the decay contract before any code is written.

---

### Pitfall 4: Localization of 400+ Strings Without String Catalog Migration Produces Invisible Gaps

**What goes wrong:**
You wrap all UI strings in `NSLocalizedString` / `String(localized:)` and export the `.strings` files for translation. Translators return files. Shipping goes fine for English, Spanish, and French. Then users report that Arabic and Hindi UIs have random English fragments — entire sections of the UI are untranslated. The cause: strings in `ReactionLibrary.json`, `LocalChatResponder.swift`, personality `promptBlock` literals, and bubble strings pulled from `ReactionLibraryService` were never extracted because the export tool only scans Swift source for `NSLocalizedString` calls — it does not parse JSON or string literals assembled at runtime.

**Why it happens:**
The project has two distinct categories of user-facing strings: (1) UI chrome (labels, buttons, settings) which is straightforward to localize, and (2) content strings (400+ reaction pool entries, 1,790 lines of `LocalChatResponder` responses, personality prompt blocks) which live in non-standard locations. The content strings dwarf the UI chrome 10:1 and require an explicit decision — localize them fully or explicitly scope them as English-only.

**Consequences:**
- Arabic and Hindi users see English personality banter even when the UI chrome is localized — the experience feels half-finished
- Translating 400+ reaction strings per language × 6 languages = 2,400+ string translations just for reactions — without a translation management system, this is untrackable
- If the decision to keep reactions English-only is not surfaced in the UI (e.g. a note in Settings), users will file bugs

**Prevention:**
- Make the decision explicit before localization work begins: UI chrome localizes in v3.0; reaction pool content stays English for v3.0 with a note in Settings ("Reactions are in English in v3.0; full localization planned for v3.1")
- Use Xcode String Catalogs (`.xcstrings`, available macOS 14+) instead of `.strings` files — they track translation state per-string and show missing translations at build time
- When wrapping strings, use `String(localized:)` with a `comment:` parameter explaining context for the translator — especially important for personality voice strings that are ambiguous out of context
- Audit `ReactionLibrary.json` and `LocalChatResponder.swift` first to produce a definitive count of what must be translated before committing to scope

**Detection:**
- After wrapping all UI strings, do an export and open the resulting `.xcstrings` in Xcode — any key with `.new` state was missed
- Build with `SWIFT_PACKAGE_MANAGER_LOCALE=ar` in the scheme's Run arguments to force Arabic locale in Simulator

**Phase to address:** Localization phase — string audit must precede any wrapping work.

---

### Pitfall 5: RTL Layout Breaks the Floating Character Window in Non-Obvious Ways

**What goes wrong:**
You add `.environment(\.layoutDirection, .rightToLeft)` for Arabic and Urdu. The chat panel text flips correctly. But the character itself — drawn with explicit `x` offsets, `Path` commands, arm rotation angles, and `offset(x:y:)` calls in `ClaudyCharacterView.swift` — does not respond to layout direction because its geometry is specified in absolute terms, not using semantic layout primitives. The character appears to lean the wrong way, wave with the wrong arm, or have a mirrored grin in RTL. The speech bubble tail also points the wrong direction.

**Why it happens:**
SwiftUI's RTL mirroring applies to layout compositing (HStack, leading/trailing), but explicit `x` offsets, `Path` points, and rotation angles are coordinate-space values — they do not auto-mirror. The bubble tail is drawn as a `Path` with hard-coded x-values, so it always points the same direction regardless of layout.

**Consequences:**
- Character looks anatomically wrong for RTL users
- Attempting to patch individual draw calls per language adds a maintenance burden to the most fragile file in the project (`ClaudyCharacterView.swift` — documented as "never refactor structure without asking")
- Chat panel leading/trailing padding may collapse or overlap when layout direction switches

**Prevention:**
- Add a `layoutDirection: LayoutDirection` parameter to `ClaudyCharacterView` that flips the sign of `x` offsets and mirrors arm angles — a single multiplier (`let flip: CGFloat = layoutDirection == .rightToLeft ? -1 : 1`) applied to all horizontal geometry
- Do RTL layout testing early in the localization phase on a simple prototype before touching `ClaudyCharacterView`
- The speech bubble `Path` for the tail must use the `flip` multiplier consistently
- Add a dedicated Xcode preview with `\.layoutDirection = .rightToLeft` to catch regressions

**Phase to address:** Localization phase — RTL geometry audit before adding new languages.

---

## Moderate Pitfalls

Mistakes in this category cause user experience degradation, feature debt, or significant rework but not crashes or data loss.

---

### Pitfall 6: Tamagotchi Notification Fatigue Kills Retention

**What goes wrong:**
The Tamagotchi layer starts sending hunger/happiness/energy nudges through the existing `showBubbleDirect()` path (the one that bypasses mute and cooldowns). Within two days, users complain that Claud-y "won't shut up." The feature gets toggled off permanently. The engagement loop that the Tamagotchi was supposed to provide collapses.

**Why it happens:**
Tamagotchi mechanics are fundamentally attention-demanding by design — the original hardware beeped every few minutes by design. Transposing that mechanic directly onto a productivity tool that already has 8 sources of ambient bubbles creates overstimulation. Existing competitor apps (NotiSprite, DigiBuddy) have all shipped and then publicly apologized for over-notification before course-correcting.

**Consequences:**
- Users disable Tamagotchi mode entirely
- The Tamagotchi becomes a badge feature rather than an active engagement loop
- Review score damage from "it's too annoying"

**Prevention:**
- Route all Tamagotchi stat nudges through the **rate-limited** `showSpeechBubble()` path, not `showBubbleDirect()` — the existing cooldown system already handles personality × mode multipliers
- Only fire a stat nudge when a stat crosses a threshold (e.g. hunger drops below 20), not on a fixed timer
- Critical state (hunger = 0, sick) may use `showBubbleDirect()` but only once per 30-minute window
- Add a separate Tamagotchi nudge intensity setting (silent / subtle / normal) independent of the main Chattiness slider
- The "always-on layer" that shows stat bars should default to **hidden** — opt-in only

**Detection:**
- User test: run the app in normal work mode for 60 minutes; count how many Tamagotchi bubbles appear; target < 3

**Phase to address:** Tamagotchi design phase, before wiring bubble dispatch.

---

### Pitfall 7: Evolution Stage Visual Changes Break the Existing Animation System

**What goes wrong:**
Evolution stages (baby → teen → adult → special) require visual changes to the character: different body proportions, different arm lengths, possibly different color saturation. `ClaudyCharacterView.swift` currently hardcodes all geometry for a single character size. Adding a second "size variant" means every drawing call must be parameterized. This touches the file that is marked as "never refactor structure without asking."

**Why it happens:**
The current character has no geometry abstraction — sizes are constants (`bodyRadius = 55`, `eyeRadius = 14`, etc.). Evolution stages require at minimum a scale factor and a shape variant parameter. Without a geometry layer, each evolution stage either requires copy-pasting the entire draw function or adding a deeply nested conditional structure.

**Consequences:**
- 30+ animation states × 4 evolution stages = visual regression matrix that is nearly untestable without snapshot tests
- Adding evolution visuals without abstracting geometry creates a combinatorial debt that makes future animations even harder to add

**Prevention:**
- Introduce a `CharacterGeometry` struct before drawing any evolution art: `struct CharacterGeometry { let bodyRadius: CGFloat; let eyeRadius: CGFloat; let armLength: CGFloat; ... }` with static factory methods `CharacterGeometry.baby`, `.teen`, `.adult`
- Pass `CharacterGeometry` as a parameter to `ClaudyCharacterView` alongside `animationState`
- Do this refactor in the tech debt phase (before Tamagotchi) so the character is parameterized before evolution art is drawn

**Detection:**
- If any draw constant is hard-coded rather than derived from `CharacterGeometry`, the abstraction is incomplete

**Phase to address:** Tech debt cleanup phase — geometry abstraction must precede Tamagotchi visual work.

---

### Pitfall 8: Adding 20 New Animation States Without a State Transition Guard Causes Visual Corruption

**What goes wrong:**
Currently the character handles 15 states with an `onChange(of: animationState)` block that fires cleanup code (cancel bob, stop glow, reset mouth amount). Adding 20 more states that each have their own timers, offsets, and glow states means each new state must explicitly clean up after each other state. When state transitions are not exhaustively handled, animations bleed: the "moonwalk" offset persists into the "meditating" state; the "sneeze" body shake continues after transitioning to "idle."

**Why it happens:**
The existing `onChange` block uses a chain of if/else to handle specific transition logic. With 15 states it is manageable. At 35+ states it becomes a 35×35 transition matrix problem. The existing architecture has no concept of "exit actions" for states — only entry actions.

**Consequences:**
- Residual animation state causes visual glitches that are hard to reproduce
- Each new animation added increases the probability of a regression in a previously working animation
- The `talkingTimer` and `dotTimer` already use `Timer` (documented as fragile in CONCERNS.md) — more timer-based animations amplify this fragility

**Prevention:**
- Before adding new states, define a `cleanupAllAnimationState()` function that resets every animation variable to its neutral value (offsets to 0, timers invalidated, glow off, scale to 1.0)
- The `onChange` block should always call `cleanupAllAnimationState()` first, then apply entry effects for the new state — this converts the 35×35 matrix into 35 isolated entry functions
- Convert `talkingTimer` and `dotTimer` from `Timer` to `Task` loops (already flagged in CONCERNS.md) before adding any new timer-based animations

**Detection:**
- Manual test: rapidly cycle through 10 random states; verify each reaches a clean visual state after 3 seconds
- `_printChanges()` in `ClaudyCharacterView.body` during development to catch unexpected re-renders

**Phase to address:** Animation phase — implement `cleanupAllAnimationState()` as the first change to `ClaudyCharacterView.swift`.

---

### Pitfall 9: Magic String UserDefaults Keys Multiplied by SwiftData Coexistence Causes Silent Data Loss

**What goes wrong:**
SwiftData is added for Tamagotchi stats. Some config (Tamagotchi enabled, nudge intensity, evolution stage display size) ends up in UserDefaults because it is simple boolean/int data. No `DefaultsKeys` enum exists yet (that's a tech debt item). Over the course of the v3.0 development, a new key — say `"TamagotchiEnabled"` — is written in `TamagotchiManager.swift` and read in `CharacterRootView.swift` with a typo: `"TamaGotchiEnabled"`. The feature silently defaults to `false` for all users on first launch. A code search finds both variants and it is unclear which was the intended key.

**Why it happens:**
This is the exact failure mode documented in QUALITY.md under "UserDefaults Keys — Magic Strings Risk." Adding SwiftData introduces a new category of question ("should this live in UserDefaults or SwiftData?") that, without a policy, results in ad-hoc decisions that mix both systems with no clear boundary.

**Consequences:**
- Silent persistence failures are the hardest category of bug to debug in production (no crash, no log error, just wrong state)
- With zero tests, there is no regression harness to catch a key typo before shipping

**Prevention:**
- The `DefaultsKeys` enum (already planned in tech debt scope) must be implemented **before** any new v3.0 feature writes its first UserDefaults key — it cannot be deferred
- Document the data residency policy: Tamagotchi stats (hunger, happiness, energy, evolution stage, care history) → SwiftData; UI config (Tamagotchi enabled, nudge intensity, overlay visible) → UserDefaults via `DefaultsKeys`
- All SwiftData model attributes that mirror UserDefaults must be explicitly justified in a comment

**Detection:**
- Code review: any string literal passed to `UserDefaults.standard.set/bool/integer/string(forKey:)` that is not a `DefaultsKeys` case is a failing review

**Phase to address:** Tech debt phase — `DefaultsKeys` enum must ship before the first v3.0 feature branch.

---

### Pitfall 10: Personality Blending Produces Incoherent LLM Output at Mid-Range Slider Values

**What goes wrong:**
The personality blending slider is designed to produce a weighted mix — 50% HypeCoach / 50% Director. The implementation concatenates portions of both personality prompt blocks with a proportional length split. At the 50/50 midpoint, the assembled prompt tells the model to be "energetic and enthusiastic but analytical and terse." The model's output becomes inconsistent: sometimes it responds like a hype coach, sometimes like a director, sometimes it switches mid-reply. Users perceive the character as "broken" rather than "blended."

**Why it happens:**
LLMs do not linearly interpolate between persona instructions. Research shows that complex or contradictory persona prompts degrade consistency: the model expresses personality as a function of both its training and contextual cues, with substantial variability across responses. Prompt blending via string concatenation is not the same as weight-space interpolation in model parameters — it creates ambiguity rather than interpolation.

**Consequences:**
- The personality blending feature — one of the Pillar 1 differentiators — feels unreliable rather than expressive
- Users report that the character's "vibe" is inconsistent during a single conversation
- Mid-range slider values are the most used positions (Fitts's Law applied to sliders)

**Prevention:**
- Design the blend as a **dominant voice + modifier** rather than an equal mix: the higher-weighted personality sets the primary voice; the lower-weighted personality contributes 2–3 modifier adjectives inserted into the dominant block (e.g. "Be like a Director who also brings occasional hype-coach energy")
- Empirically test the 20/80, 50/50, and 80/20 positions with each combination of personalities before shipping
- Add a "Preview" button in Settings that fires a test prompt and shows how the current blend responds — lets users calibrate without burning full-conversation turns

**Detection:**
- A/B test: for each slider position, generate 5 responses to the same prompt; measure how many feel consistent with the expected blend
- Qualitative signal: if users describe mid-range sliders as "weird" or "broken," the prompt composition needs redesign

**Phase to address:** Personality blending design phase — verify the composition approach with 3–5 test prompts before building the slider UI.

---

### Pitfall 11: Refactoring 991/808/740-Line Views Without Tests Breaks Notification Wiring Silently

**What goes wrong:**
`CharacterRootView.swift` is extracted into sub-views. The `onReceive` handlers that wire `.claudyToggleChat` and `.claudyQuickActionFired` are moved to a sub-view that is conditionally shown. On some code paths, the sub-view is not in the hierarchy when the notification fires, and the handler never executes. The chat panel stops responding to the global hotkey `⌘⇧Space`. The bug only manifests when the character starts in a specific state — it looks like a hotkey regression but the root cause is a missing `onReceive` in the restructured hierarchy.

**Why it happens:**
SwiftUI `onReceive` modifiers are only active when the view they are attached to is in the live view hierarchy. Moving a notification listener into a sub-view that is gated by `if showingX { SubView() }` creates a liveness dependency that is invisible at the call site. The existing code places all notification wiring on the top-level `ZStack` in `CharacterRootView` specifically to guarantee liveness — extracting to sub-views breaks this invariant without any compiler warning.

**Consequences:**
- The global hotkey silently stops working in certain app states
- `QuickActionManager` pre-fill of `ChatViewModel.inputText` stops working
- No crash or error log — the notification fires and is simply not received

**Prevention:**
- Keep all `onReceive` notification wiring at the `CharacterRootView` level (top of the view hierarchy) even after extraction — pass state down via bindings or `@Observable` rather than moving the listeners into sub-views
- Add a documentation comment above each `onReceive` block: `// IMPORTANT: must remain at root level — liveness guarantee`
- Before merging any `CharacterRootView` extraction PR, manually verify: hotkey opens chat, quick action pre-fills chat, mute toggle reacts correctly

**Detection:**
- Manual test checklist for `CharacterRootView` extraction: hotkey test, quick action test, mute test, personality switch test — all must pass before PR merge

**Phase to address:** Tech debt phase — extract views, but notification wiring review is a required step in the PR checklist.

---

## Minor Pitfalls

---

### Pitfall 12: String(localized:) vs NSLocalizedString Inconsistency Creates Duplicate Keys

**What goes wrong:**
Some developers use `String(localized: "key")` (modern Swift 5.9+ API) and others use `NSLocalizedString("key", comment: "")`. Both work, but Xcode's `.xcstrings` exporter treats them as the same key space while `genstrings` (the legacy command-line tool) only picks up `NSLocalizedString`. If both tools are used at different points in the project, keys get duplicated or missed.

**Prevention:**
- Standardize on `String(localized:)` with a `comment:` for all new strings; do not mix with `NSLocalizedString` in new code
- Migrate existing strings during the localization phase rather than leaving a mix
- Use Xcode's built-in String Catalog feature (`.xcstrings`) from day one — it auto-extracts from both APIs and maintains state per language

**Phase to address:** Localization phase — set the standard at the start before any wrapping begins.

---

### Pitfall 13: ClaudyCharacterView Timers Not Restarted After Hot Reload or Preview Cycle

**What goes wrong:**
During development, hot reload or Xcode previews cycle the view hierarchy. `talkingTimer` and `dotTimer` (both `Timer.scheduledTimer`) are invalidated on `onDisappear` but are not restarted if `onAppear` fires on the same view instance (previews can reuse instances). The lip-sync animation freezes. This is already documented in CONCERNS.md as fragile.

**Prevention:**
- Convert both timers to `Task` loops inside `task {}` modifiers — already planned as a tech debt fix
- Do this conversion **before** adding any new timer-based animations in the 30+ animation expansion
- Ensures the fragile timer pattern is not copied into 20 new animation implementations

**Phase to address:** Tech debt phase — timer migration is a prerequisite for animation expansion.

---

### Pitfall 14: SwiftData @Query in CharacterRootView Forces SwiftUI Re-render on Every Stat Decay

**What goes wrong:**
Placing a `@Query var tamagotchiState: [TamagotchiState]` in `CharacterRootView` (or any ancestor view) causes the entire view hierarchy below it to re-render every time any Tamagotchi model property is saved — including the 30+ animation state rendering in `ClaudyCharacterView`. At one decay event per 30–60 seconds this is tolerable; if debug mode fires decay faster, or if future features add more frequent writes, the character will visually stutter on every save.

**Prevention:**
- Isolate `@Query` in a dedicated `TamagotchiStatusView` that only renders stat bars — not in `CharacterRootView` itself
- Use `equatable()` modifier or `Equatable` conformance on the sub-view to prevent re-renders when the relevant view data has not changed
- Keep `ClaudyCharacterView` entirely isolated from SwiftData — it should receive only `animationState: CharacterAnimationState` and `geometry: CharacterGeometry`, nothing from the persistence layer

**Phase to address:** Tamagotchi integration phase — verify render isolation before connecting stat displays.

---

### Pitfall 15: DemoModeManager Duplication Carried Into v3.0 Adds New Features Twice

**What goes wrong:**
`DemoModeManager` and `V2DemoModeManager` are structurally identical (documented in QUALITY.md). If the Tamagotchi demo sequence or new animation demos are wired before the merge, both managers need updating. The developer updates one and forgets the other. The App Store demo mode shows the wrong animations.

**Prevention:**
- Merge the two demo managers **in the tech debt phase**, before any v3.0 feature wires demo sequences
- The merge is low-risk (identical structure, just configure via a parameter) and the payoff is removing a silent duplication trap before it multiplies

**Phase to address:** Tech debt phase — first task, before any other feature work.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| SwiftData schema design | Unversioned schema → launch crash on first migration | VersionedSchema from commit zero |
| Tamagotchi decay loop | MainActor write blocks animation frame | ModelActor for all persistence writes |
| Tamagotchi time accounting | App quit / Mac sleep causes death-on-open | Capped catch-up + sleep-mode pausing |
| Tamagotchi bubble dispatch | Notification fatigue | Rate-limited path only; intensity setting |
| Evolution stage visuals | Geometry hard-coded → can't parameterize | CharacterGeometry struct in tech debt phase |
| 30+ animation states | State bleed across transitions | cleanupAllAnimationState() before entry logic |
| New animation timers | Timer leak / no restart after hot reload | Convert talkingTimer/dotTimer to Task first |
| CharacterRootView extraction | onReceive listener loses liveness | Keep all notification wiring at root level |
| DefaultsKeys enum | New features write magic strings before enum exists | Enum ships before first v3.0 feature branch |
| Localization wrapping | Reaction pool and LocalChatResponder missed by export | Scope decision + explicit audit before wrapping |
| RTL layout | Character geometry does not mirror | CharacterGeometry flip multiplier; RTL preview |
| Personality blending | Mid-range slider produces incoherent output | Dominant-voice + modifier pattern; empirical test |
| DemoModeManager split | New features wired to both managers | Merge in tech debt phase before any new feature |
| @Query placement | Ancestor query causes full re-render on decay | Isolate @Query in TamagotchiStatusView only |

---

## Sources

- [Never use SwiftData without VersionedSchema — Mert Bulan](https://mertbulan.com/programming/never-use-swiftdata-without-versionedschema)
- [An Unauthorized Guide to SwiftData Migrations — Atomic Robot](https://atomicrobot.com/blog/an-unauthorized-guide-to-swiftdata-migrations/)
- [Taking SwiftData Further: @ModelActor, Swift Concurrency, and Avoiding @MainActor Pitfalls](https://killlilwinters.medium.com/taking-swiftdata-further-modelactor-swift-concurrency-and-avoiding-mainactor-pitfalls-3692f61f2fa1)
- [Concurrent Programming in SwiftData — fatbobman](https://fatbobman.com/en/posts/concurret-programming-in-swiftdata/)
- [SwiftData unversioned migration crash — Apple Developer Forums](https://developer.apple.com/forums/thread/761735)
- [Demystify SwiftUI performance — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10160/)
- [Pet Companion Design in Gamification — Yu-kai Chou](https://yukaichou.com/advanced-gamification/the-pet-companion-design-in-gamification/)
- [NotiSprite notification fatigue redesign — App Store](https://apps.apple.com/us/app/notisprite-smart-desktop-pet/id6752292657)
- [SwiftUI is convenient, but slow — Alin Panaitiu](https://notes.alinpanaitiu.com/SwiftUI-is-convenient,-but-slow)
- [Optimizing SwiftUI: Reducing Body Recalculation — Wesley Matlock](https://medium.com/@wesleymatlock/optimizing-swiftui-reducing-body-recalculation-and-minimizing-state-updates-8f7944253725)
- [Forcing iOS localization at runtime — the right way](https://medium.com/swift2go/forcing-ios-localization-at-runtime-the-right-way-8afa0569162a)
- [RTL Support in iOS Apps — Technet Expert](https://www.technetexperts.com/right-to-left-rtl-language-support-in-ios-apps/)
- [Avoiding massive SwiftUI views — Swift by Sundell](https://www.swiftbysundell.com/articles/avoiding-massive-swiftui-views/)
- [Simplifying Swift Timers: solving memory leaks — Oleg Dreyman](https://olegdreyman.medium.com/simplifying-swift-timers-solving-memory-leaks-complexity-once-and-for-all-1fecfeba4f29)
- [The Way We Prompt: Conceptual Blending in LLMs — arXiv](https://arxiv.org/abs/2505.10948)

---

*Pitfalls research: 2026-04-05 | Confidence: HIGH for SwiftData/localization pitfalls (multiple verified sources); MEDIUM for Tamagotchi design (pattern-based from competitor analysis and game design research); HIGH for animation/refactor pitfalls (derived directly from CONCERNS.md and QUALITY.md codebase audit)*
