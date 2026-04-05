# Architecture Patterns — Claud-y v3.0

**Domain:** macOS floating AI companion — v3.0 new-system integration
**Researched:** 2026-04-05
**Overall confidence:** HIGH (all four integration questions answered from official docs + direct codebase inspection)

---

## Scope of This Document

This document answers the four specific integration questions for v3.0 and derives the build-order implications that flow from the answers. The existing architecture (MVVM `@Observable`, actor-isolated API, 20+ `@MainActor` managers, `NSPanel`-hosted SwiftUI) is treated as fixed. Every recommendation below fits that foundation without structural changes.

---

## Question 1: Where Does SwiftData ModelContainer Live?

### The Problem

Claud-y does not use a SwiftUI `WindowGroup` — it uses `AppDelegate` + `FloatingWindowController` + a manually created `NSHostingView`. The `.modelContainer()` scene modifier that Apple normally recommends cannot be used here.

### Recommended Pattern

**Own the `ModelContainer` as a singleton on `AppDelegate`, inject `mainContext` into the SwiftUI environment manually.**

```swift
// AppDelegate.swift — add alongside existing NSStatusItem setup
let tamagotchiContainer: ModelContainer = {
    let schema = Schema([TamagotchiState.self, EvolutionRecord.self])
    let config = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .none        // explicit: never sync to iCloud
    )
    do {
        return try ModelContainer(for: schema, configurations: [config])
    } catch {
        fatalError("SwiftData container failed: \(error)")
    }
}()
```

Then in `FloatingWindowController.init()`, append `.modelContainer(appDelegate.tamagotchiContainer)` to the root view chain alongside the existing `.environment(wm)` and `.environment(PersonalityManager.shared)` calls:

```swift
let rootView = CharacterRootView()
    .environment(wm)
    .environment(PersonalityManager.shared)
    .modelContainer(appDelegate.tamagotchiContainer)  // NEW
```

`AppDelegate` already exists and already owns process-level singletons — putting `ModelContainer` there is consistent with the existing pattern for `NSStatusItem` and `FloatingWindowController`.

### Passing Context to the TamagotchiManager

`TamagotchiManager` is a `@MainActor` class (matching all other managers). It must not receive a `ModelContext` from the environment (managers have no environment access). Instead:

```swift
// TamagotchiManager.swift
@MainActor
final class TamagotchiManager {
    weak var viewModel: CharacterViewModel?
    private let context: ModelContext       // main-actor context from container

    init(container: ModelContainer, viewModel: CharacterViewModel) {
        // container.mainContext is @MainActor — safe here
        self.context = container.mainContext
        self.viewModel = viewModel
    }
}
```

`CharacterViewModel.init()` receives the container (passed from `AppDelegate` → `FloatingWindowController` → `CharacterRootView` → `CharacterViewModel` as an init param, or via `setup()` call similar to `windowManager`) and constructs `TamagotchiManager` with it.

**Why not `@ModelActor`?** `@ModelActor` is for background-thread database work. Claud-y's stat decay is low-frequency (ticks every 60–300s), the data volume is tiny (3 numeric stats + a handful of records), and all stat changes need to immediately update SwiftUI state that is on `@MainActor`. Using `@ModelActor` would require cross-actor hops for every read without any benefit. Use `mainContext` directly.

### SwiftData Models

```swift
@Model
final class TamagotchiState {
    var hunger: Double        // 0.0 – 1.0; 1.0 = starving
    var happiness: Double     // 0.0 – 1.0; 1.0 = ecstatic
    var energy: Double        // 0.0 – 1.0; 1.0 = fully rested
    var careScore: Double     // cumulative care quality, drives evolution
    var evolutionStage: EvolutionStage
    var lastSaved: Date

    init() {
        hunger = 0.2
        happiness = 0.8
        energy = 0.9
        careScore = 0.0
        evolutionStage = .baby
        lastSaved = .now
    }
}

@Model
final class EvolutionRecord {
    var fromStage: EvolutionStage
    var toStage: EvolutionStage
    var occurredAt: Date
    var careScoreAtEvolution: Double
}

enum EvolutionStage: String, Codable {
    case baby, teen, adult, special
}
```

`EvolutionRecord` is a separate `@Model` so evolution history is queryable and exportable without bloating `TamagotchiState`. The `@Relationship` between them is `.cascade` — deleting the state deletes all records (privacy: data is local-only anyway, but this keeps teardown clean).

### Privacy Guarantee

`cloudKitDatabase: .none` in `ModelConfiguration` is the explicit knob that prevents iCloud sync. No additional entitlements are needed. The `ModelConfiguration` default store URL is inside the app's sandbox container (`~/Library/Application Support/com.claudy/`). Document this explicitly in a `PrivacyInfo.xcprivacy` entry and in the README as required by the PROJECT.md spec.

### Confidence

HIGH — `ModelContainer` init outside `WindowGroup`, `mainContext` injection, and `cloudKitDatabase: .none` are all documented in Apple's official SwiftData documentation and WWDC23/24 session code. The `NSHostingView` injection pattern (chaining `.modelContainer()` on the root view before passing to `NSHostingView`) matches how `.environment()` is used in the existing `FloatingWindowController` today.

---

## Question 2: Tamagotchi Game Loop Architecture

### Manager Placement

`TamagotchiManager` fits the existing manager pattern exactly: `@MainActor` class, `weak var viewModel`, instantiated in `CharacterViewModel.init()`, receives the `ModelContainer` at construction time. Add it to the manager table in `ARCHITECTURE.md` alongside the existing 20+ managers.

It is **not** a singleton — like `PomodoroManager` and `BehaviorModeManager`, it is owned by `CharacterViewModel`. This is correct: the game loop state is character state.

### Stat Decay Loop

Use the same `Task` async-sleep pattern all other managers use (not `Timer`, consistent with Swift 6 concurrency):

```swift
private var decayTask: Task<Void, Never>?

func startDecayLoop() {
    decayTask = Task { [weak self] in
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Self.decayIntervalSeconds))
            await self?.tick()
        }
    }
}

private func tick() {
    guard let state = fetchOrCreateState() else { return }
    let elapsed = Date.now.timeIntervalSince(state.lastSaved)
    applyDecay(to: state, elapsed: elapsed)
    state.lastSaved = .now
    try? context.save()
    updateCharacterFromStats(state)
    checkEvolution(state)
}
```

**Decay interval:** 300 seconds (5 minutes) is appropriate — stat changes are subtle, the loop wakes from suspend on real elapsed time, and it imposes minimal background pressure. The existing `BreakNudgeManager` already runs at 60s; `TamagotchiManager` at 300s is less frequent than any existing loop.

**Elapsed-time decay (not fixed-rate):** Compute `elapsed = Date.now - state.lastSaved` on every tick and scale decay proportionally. This handles app suspension, sleep/wake, and fresh install gracefully. The character's state does not decay while the Mac is asleep.

### Feeding and Playing Actions

User interactions (feed, play, pet) call synchronous methods on `TamagotchiManager` directly from the view or via `CharacterViewModel`. These are not async — they mutate state immediately and save:

```swift
func feed() {
    guard let state = fetchOrCreateState() else { return }
    state.hunger = max(0.0, state.hunger - 0.4)
    state.energy = min(1.0, state.energy + 0.1)
    state.careScore += careScoreIncrement(for: .feeding)
    try? context.save()
    viewModel?.setState(.celebrating)
    checkEvolution(state)
}
```

### Evolution Checks

`checkEvolution` is called after every tick and after every user interaction. It is a pure threshold check:

```swift
private func checkEvolution(_ state: TamagotchiState) {
    let newStage = EvolutionStage.forCareScore(state.careScore)
    guard newStage != state.evolutionStage else { return }
    let record = EvolutionRecord(
        fromStage: state.evolutionStage,
        toStage: newStage,
        occurredAt: .now,
        careScoreAtEvolution: state.careScore
    )
    context.insert(record)
    state.evolutionStage = newStage
    try? context.save()
    viewModel?.triggerEvolutionCelebration(from: state.evolutionStage, to: newStage)
}
```

`triggerEvolutionCelebration` on `CharacterViewModel` sets the appropriate animation state and queues a direct (rate-limit-bypassing) speech bubble.

### Mood → Animation State Bridge

`TamagotchiManager` does not set animation states directly during the decay loop — it exposes a `currentMood: TamagotchMood` computed from stats, and `CharacterViewModel` maps that to animation states. This keeps the concern separation clean:

```swift
// TamagotchiManager
var currentMood: TamagotchiMood {
    switch (state.hunger, state.happiness, state.energy) {
    case (let h, _, _) where h > 0.8:  return .hungry
    case (_, _, let e) where e < 0.2:  return .sleepy
    case (_, let hp, _) where hp > 0.7: return .happy
    default:                             return .neutral
    }
}
```

```swift
// CharacterViewModel — observes mood via @Observable access
private func syncTamagotchiMood() {
    guard isTamagotchiEnabled else { return }
    let mood = tamagotchiManager.currentMood
    switch mood {
    case .hungry:  showSpeechBubble(ReactionLibraryService.shared.reaction(for: .tamagotchiHungry))
    case .sleepy:  setState(.drowsy)
    case .happy:   // idle is fine; let ambient system handle
    case .neutral: break
    }
}
```

`syncTamagotchiMood()` is called at the end of every `tick()` call — once per 5 minutes at most, so it cannot flood the speech bubble queue.

### Component Boundary Summary

```
AppDelegate
  └── tamagotchiContainer: ModelContainer (owns the database)
        ↓ passed to
CharacterViewModel.init(container:)
  └── TamagotchiManager(context: container.mainContext)
        ├── decayTask: async Task loop (300s cadence)
        ├── feed() / play() / pet() — synchronous user actions
        ├── checkEvolution() — threshold check after every mutation
        └── currentMood: TamagotchiMood — computed from stats
              ↓ read by
CharacterViewModel.syncTamagotchiMood()
  └── → setState() / showSpeechBubble()
        ↓
ClaudyCharacterView (reads animationState as let prop — no change needed)
```

---

## Question 3: Scaling CharacterAnimationState from 15 to 30+ States

### The Current Problem

`ClaudyCharacterView` has a large `.onChange(of: animationState)` that branches on state to call animation helpers (`startBobAnimation`, `startCelebrationAnimation`, `applyStartledJump`, etc.). Adding 15+ more cases to this switch will make it unmanageable.

The core issue is not the enum size — Swift handles large enums well. The issue is that `ClaudyCharacterView` has two responsibilities that will collide at 30+ states:
1. Rendering the character shape for the current state (eyes, mouth, arms).
2. Choosing which animation parameters to apply when state changes.

### Recommended Pattern: Enum With Animation Configuration Struct

Keep the enum as the source of truth (it is `Sendable`, value-typed, passed as a `let` prop — correct). Move all animation decision logic out of `ClaudyCharacterView`'s `onChange` and into computed properties on the enum itself.

```swift
// CharacterAnimationState.swift — extend the existing enum

struct AnimationConfig {
    let bobDuration: Double        // seconds per bob cycle
    let bobOffset: CGFloat         // points of vertical travel
    let bodyScale: CGFloat         // 1.0 = normal
    let eyeScale: CGFloat          // multiplier on base eye size
    let showsGlow: Bool
    let usesFastBob: Bool          // for headbanging / excited states
}

extension CharacterAnimationState {
    var animationConfig: AnimationConfig {
        switch self {
        case .idle:        return AnimationConfig(bobDuration: 1.9, bobOffset: -6,  bodyScale: 1.0,  eyeScale: 1.0,  showsGlow: false, usesFastBob: false)
        case .sleeping:    return AnimationConfig(bobDuration: 3.2, bobOffset: -2,  bodyScale: 1.0,  eyeScale: 1.0,  showsGlow: false, usesFastBob: false)
        case .dancing:     return AnimationConfig(bobDuration: 0.36, bobOffset: -16, bodyScale: 1.0,  eyeScale: 1.0,  showsGlow: true,  usesFastBob: true)
        case .headbanging: return AnimationConfig(bobDuration: 0.13, bobOffset: -26, bodyScale: 1.0,  eyeScale: 1.0,  showsGlow: false, usesFastBob: true)
        // ... all 30+ cases
        }
    }
}
```

Now `ClaudyCharacterView.onChange` becomes data-driven instead of case-driven:

```swift
.onChange(of: animationState) { _, new in
    let config = new.animationConfig
    startBobAnimation(duration: config.bobDuration, offset: config.bobOffset)
    glowActive = config.showsGlow
    // etc.
    // State-specific imperatives (jump, celebration pulse) stay as named cases:
    if new == .surprised { applyStartledJump() }
    if new == .celebrating { startCelebrationAnimation() }
}
```

Only the truly special-case imperatives (jump physics, celebration pulse, arm flair start/stop) stay as named-case branches. Everything parameterizable moves into `AnimationConfig`.

### Rendering Split: Eye Shape and Mouth Shape

For eye and mouth rendering, group states by visual category rather than exhaustive switch:

```swift
extension CharacterAnimationState {
    enum EyeShape { case pixar, arcUp, arcDown, flat, squint, halfClosed, wide, dots }
    enum MouthShape { case smile, grin, open, flat, curve, lipsync }

    var eyeShape: EyeShape {
        switch self {
        case .idle, .thinking, .talking, .confused, .surprised, .alert: return .pixar
        case .celebrating, .waving, .dancing, .excited, .love:           return .arcUp
        case .tickled, .happy:                                            return .arcDown
        case .sleeping:                                                   return .flat
        case .facepalm, .headbanging, .angry, .nervous:                  return .squint
        case .drowsy, .vibing, .bored, .sleepy:                          return .halfClosed
        case .alert:                                                      return .wide
        case .thinking:                                                   return .dots
        }
    }
}
```

`ClaudyCharacterView`'s eye drawing block switches on `animationState.eyeShape` (7–8 cases) rather than on the full 30+ state enum. The same pattern applies to `mouthShape`. This gives O(1) rendering complexity regardless of how many total states exist.

### New State Groupings for v3.0

The 30+ states fall into natural groups that drive this categorization:

| Group | States | Eye | Body Motion |
|-------|--------|-----|-------------|
| Emotional | sad, angry, nervous, excited, bored, love-eyes, embarrassed, mischievous | group-specific | gentle sway or fast |
| Activity | typing, reading, coding, meditating, exercising, eating, studying | pixar (focused) | slow or still |
| Fun/Viral | dab, moonwalk, backflip, breakdance, sneeze, yawn, hiccup, facepalm | exaggerated | fast + imperative |
| Tamagotchi | hungry-wobble, sleepy-droop, happy-bounce, full-belly, evolving | state-specific | wobble or pulse |

This grouping also informs which new `AnimationConfig` instances share parameters (e.g. all activity states use `bobDuration: 2.5, bobOffset: -4`).

### File Split Recommendation

At 30+ cases, keep the enum definition and `accessibilityDescription` in `CharacterAnimationState.swift`. Move the extensions (`animationConfig`, `eyeShape`, `mouthShape`) into a new `CharacterAnimationState+Config.swift`. This keeps the core type file under 100 lines and makes the config tables easy to audit and extend.

### Arm Choreography

New states with complex arm positions (moonwalk, breakdance, dab) should use the same `DanceModeManager` pattern: a separate value type that describes arm angles per frame, sequenced by an async Task owned by the new `AnimationMoveManager` (or extended `DanceModeManager`). `ClaudyCharacterView` reads `currentMove: AnimationMove` (already existing as `danceMove: DanceMove`) for arm angles rather than computing them inline.

---

## Question 4: Personality Blending Integration

### Current Assembly Chain

```
PersonalityManager.systemPrompt (computed):
  SystemPrompt.txt  +  personalityBlock  +  modeBlock
```

`personalityBlock` is currently a single `String` from `PersonalityMode.promptBlock`. The blending slider must replace the single `promptBlock` with a weighted merge of two personality blocks.

### Where the Blend Lives

**Do not change the `systemPrompt` computed property shape.** Its callers (`ChatViewModel.streamReply()`, `PersonalityManager.asyncGreeting()`) read a single `String` and that contract must stay stable. Instead, change how `personalityBlock` is assembled inside `systemPrompt`.

Add a blend state to `PersonalityManager`:

```swift
// PersonalityManager.swift — new fields
var blendEnabled: Bool = false {
    didSet { UserDefaults.standard.set(blendEnabled, forKey: "PersonalityBlendEnabled") }
}
var secondaryMode: PersonalityMode = .chatty {
    didSet { UserDefaults.standard.set(secondaryMode.rawValue, forKey: "PersonalitySecondaryMode") }
}
var blendRatio: Double = 0.5 {
    // 0.0 = 100% primary, 1.0 = 100% secondary
    didSet { UserDefaults.standard.set(blendRatio, forKey: "PersonalityBlendRatio") }
}
```

In `systemPrompt`, the `personalityBlock` line becomes:

```swift
let personalityBlock: String
if blendEnabled && secondaryMode != currentMode {
    personalityBlock = blendedPromptBlock(
        primary: currentMode,
        secondary: secondaryMode,
        ratio: blendRatio
    )
} else {
    personalityBlock = currentMode == .custom && !customPersonaText.isEmpty
        ? "### MODE: YOU DO YOU\n\(customPersonaText)"
        : currentMode.promptBlock
}
```

### Blending Algorithm

LLMs do not do linear arithmetic on text the way image diffusion models blend embeddings — prompt text is interpreted holistically. The correct approach is **explicit dual-voice instruction**, not string interpolation.

```swift
private func blendedPromptBlock(
    primary: PersonalityMode,
    secondary: PersonalityMode,
    ratio: Double
) -> String {
    let primaryWeight = Int((1.0 - ratio) * 100)
    let secondaryWeight = Int(ratio * 100)

    return """
    ### MODE: BLENDED PERSONALITY (\(primaryWeight)% \(primary.displayName) / \(secondaryWeight)% \(secondary.displayName))

    You are operating with a blended personality. Your responses should feel like \(primaryWeight)% \(primary.displayName) and \(secondaryWeight)% \(secondary.displayName).

    PRIMARY VOICE (\(primaryWeight)% influence):
    \(primary.promptBlock)

    SECONDARY VOICE (\(secondaryWeight)% influence):
    \(secondary.promptBlock)

    Blend these voices in your response style. Let the higher-weight voice dominate tone, sentence structure, and energy level. Let the lower-weight voice colour word choice and occasional asides.
    """
}
```

This approach works because it tells the model explicitly what to do with two character voices. It has been validated in prompt engineering practice for character blending: explicit weighting in natural language outperforms implicit techniques for instruction-following models.

The prompt is slightly longer (two `promptBlock` strings + ~5 lines of instruction). At `.reaction` priority (60 tokens, fast model) this is irrelevant. At `.chat` priority it adds ~200 tokens to the context window, which is acceptable.

### Slider UI Integration

The slider lives in `SettingsView` (or a new `PersonalityBlendView` subview, given `SettingsView` is 808 lines and being split). It binds to `PersonalityManager.shared` directly via `@Bindable`:

```swift
@Environment(PersonalityManager.self) private var personalityManager

Slider(value: Bindable(personalityManager).blendRatio, in: 0...1)
```

No new notification, no `CharacterViewModel` involvement — the blend is pure personality-layer state that `systemPrompt` picks up on the next call. This is architecturally identical to how `activeBehaviorMode` is set: one layer writes a property on `PersonalityManager.shared`, the computed property picks it up.

### Custom Mode Interaction

If `currentMode == .custom`, blending is disabled (custom text cannot be weighted against a template block). The `blendEnabled` toggle should be hidden or disabled in the UI when custom mode is selected.

---

## Component Boundaries (Complete v3.0 Picture)

```
AppDelegate
  ├── tamagotchiContainer: ModelContainer  ← NEW — owns SwiftData store
  ├── FloatingWindowController
  │   ├── FloatingPanel (NSPanel)
  │   ├── WindowManager
  │   └── CharacterRootView
  │       ├── CharacterViewModel
  │       │   ├── TamagotchiManager  ← NEW — game loop, decay, evolution
  │       │   │     uses: container.mainContext (SwiftData)
  │       │   │     writes: TamagotchiState, EvolutionRecord
  │       │   │     reads: currentMood → setState / showSpeechBubble
  │       │   ├── [all existing 20+ managers — unchanged]
  │       │   └── syncTamagotchiMood()  ← NEW bridge method
  │       ├── ChatViewModel
  │       │   └── ClaudeAPIService.shared (reads PersonalityManager.shared.systemPrompt)
  │       ├── ClaudyCharacterView
  │       │   ├── animationState: CharacterAnimationState (30+ cases)
  │       │   ├── CharacterAnimationState+Config.swift  ← NEW
  │       │   │     AnimationConfig (bob params, glow, scale)
  │       │   │     EyeShape / MouthShape groupings
  │       │   └── [existing drawing code — minimal changes to onChange]
  │       └── TamagotchiOverlayView  ← NEW (optional overlay, reads TamagotchiManager)
  └── PersonalityManager.shared
        ├── currentMode: PersonalityMode (primary)    ← existing
        ├── blendEnabled: Bool                        ← NEW
        ├── secondaryMode: PersonalityMode            ← NEW
        ├── blendRatio: Double                        ← NEW
        └── systemPrompt (computed)  ← modified to call blendedPromptBlock()
              ↓ read by
        ChatViewModel.streamReply()  (no change to callers)
```

---

## Data Flow

### Tamagotchi Stat Decay

```
[300s Task.sleep] → TamagotchiManager.tick()
  → read TamagotchiState from mainContext
  → compute elapsed since lastSaved
  → applyDecay(hunger +=, happiness -=, energy -=)
  → context.save()
  → checkEvolution()  (if careScore threshold crossed → insert EvolutionRecord, save again)
  → syncTamagotchiMood()  →  CharacterViewModel.setState() / showSpeechBubble()
```

### User Feeds Character

```
TamagotchiOverlayView: "Feed" button tap
  → CharacterViewModel.feedTamagotchi()
  → TamagotchiManager.feed()
  → mutate TamagotchiState.hunger, .energy, .careScore
  → context.save()
  → checkEvolution()
  → CharacterViewModel.setState(.celebrating)
```

### Personality Blend Applied

```
User adjusts blend slider in SettingsView
  → PersonalityManager.shared.blendRatio = newValue  (persisted to UserDefaults)
User sends chat message
  → ChatViewModel.streamReply()
  → reads PersonalityManager.shared.systemPrompt  (computed fresh each call)
  → systemPrompt calls blendedPromptBlock(primary, secondary, ratio)
  → sends blended system prompt to ClaudeAPIService
```

### New Animation State Set

```
CharacterViewModel.setState(.excited)
  → ClaudyCharacterView receives animationState = .excited via let prop
  → .onChange fires
  → reads .excited.animationConfig → AnimationConfig(bobDuration: 0.8, bobOffset: -10, ...)
  → startBobAnimation(config.bobDuration, config.bobOffset)
  → reads .excited.eyeShape → .arcUp → draws arc-up eyes (no state-specific branch needed)
```

---

## Suggested Build Order

Dependencies flow top-to-bottom. Each item must be complete before the items that depend on it.

### Phase 1: Foundation (Tech Debt + Preconditions)
Before any new system is built, establish the clean foundation. This is not optional — SwiftData in a corrupted concurrency environment will produce opaque crashes.

1. Set `SWIFT_STRICT_CONCURRENCY = complete` — exposes all isolation violations before new code is written.
2. Fix the five BUGs and SEC-01 from `PROJECT.md`. The array crash (BUG-05) is a correctness issue that will affect `TamagotchiManager` if it ever touches `ChatViewModel.messages`.
3. Extract `CharacterRootView`, `SettingsView`, `ChatView` into sub-views — needed before adding `TamagotchiOverlayView` and blend UI; 991/808/740 line files are too large to safely add to.
4. Centralise `UserDefaults` keys into `DefaultsKeys` enum — `TamagotchiManager` and `PersonalityManager` blending will add 6+ new keys; this is the last safe moment to centralise.

### Phase 2: SwiftData Infrastructure
1. Add `TamagotchiState.swift` and `EvolutionRecord.swift` (`@Model` classes).
2. Wire `ModelContainer` in `AppDelegate` with `cloudKitDatabase: .none`.
3. Inject `mainContext` into `CharacterViewModel` via `setup()` extension call (matching the `windowManager` injection pattern).
4. Verify container initialises and persists across app restarts with no data before building any logic on top.

### Phase 3: TamagotchiManager Core
1. Implement `TamagotchiManager` with decay loop, feed/play/pet actions, evolution check.
2. Implement `syncTamagotchiMood()` in `CharacterViewModel`.
3. Add `TamagotchiOverlayView` (minimal — stats display only, no interaction yet).
4. Add `ReactionTrigger` cases for Tamagotchi events (`tamagotchiHungry`, `tamagotchiEvolved`, etc.) and corresponding entries in `ReactionLibrary.json`.

### Phase 4: Animation Expansion
1. Create `CharacterAnimationState+Config.swift` with `AnimationConfig`, `EyeShape`, `MouthShape`.
2. Refactor `ClaudyCharacterView.onChange` to be data-driven (non-breaking — existing states just get their config entries).
3. Add new states in batches by group (Emotional first — simplest drawing changes; Fun/Viral last — most complex arm choreography).
4. Add Tamagotchi-specific animation states last — they depend on Phase 3 being complete so the triggers that activate them exist.

**Note:** Phase 4 can run in parallel with Phase 3 once `CharacterAnimationState+Config.swift` exists — animation states can be added as stubs before their triggers are wired.

### Phase 5: Personality Blending
1. Add `blendEnabled`, `secondaryMode`, `blendRatio` to `PersonalityManager`.
2. Implement `blendedPromptBlock()`.
3. Add blend UI in `SettingsView` (now extracted from Phase 1, so safe to extend).
4. Test across all three providers — blended prompts are longer; verify token budget is sufficient for `.reaction` priority.

**Dependency:** Phase 5 has no dependency on Phases 3 or 4 — it can run in parallel after Phase 1. The only ordering constraint is that `SettingsView` extraction (Phase 1, step 3) is done first to avoid editing 808-line files.

### Phase 6: Multilingual UI + API Enhancements
No architectural dependencies on Phases 3–5. Can be sequenced last or run in parallel with a separate contributor.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Creating Multiple ModelContexts in TamagotchiManager
**What goes wrong:** Creating a new `ModelContext(container)` inside `TamagotchiManager.tick()` creates a separate context that is not synchronized with `mainContext`. Changes do not propagate to the view hierarchy and merge conflicts appear as phantom data.
**Instead:** Pass `container.mainContext` once in `init()` and hold it for the manager's lifetime. `mainContext` is always on `@MainActor`, so there is no isolation issue.

### Anti-Pattern 2: Storing EvolutionStage as an Int in UserDefaults
**What goes wrong:** If `EvolutionStage` order changes (e.g. `special` case splits into multiple forms in v3.5), raw int values become invalid and users' progress silently regresses.
**Instead:** Use SwiftData `@Model` with `EvolutionStage: String, Codable`. The rawValue string is stable across code changes.

### Anti-Pattern 3: A 30-case Switch in ClaudyCharacterView.onChange
**What goes wrong:** Each new animation state requires editing the same `onChange` block. Review conflicts, missed cases, and regression risk multiply with state count.
**Instead:** `animationConfig` computed property on the enum makes `onChange` data-driven. Only add named-case branches for genuinely imperative behaviours (jump physics, one-shot confetti).

### Anti-Pattern 4: Interpolating Personality Prompt Strings with String Templates
**What goes wrong:** Mechanically inserting "75% of VOICE A tokens + 25% of VOICE B tokens" by slicing strings produces incoherent prompts. LLMs process prompts holistically.
**Instead:** Use explicit dual-voice instruction ("blend these voices, X% dominates tone") and let the model interpret the blend semantically. This is the standard technique in prompt engineering for character mixing.

### Anti-Pattern 5: Putting ModelContainer in CharacterViewModel
**What goes wrong:** `CharacterViewModel` is owned as `@State` in `CharacterRootView`. If it is ever recreated (e.g. hot reload, future multi-window support), the `ModelContainer` is also recreated, creating a second SQLite database file or losing the in-memory reference.
**Instead:** `ModelContainer` lives in `AppDelegate` for the same reason all process-level singletons do — it survives any view lifecycle events.

---

## Scalability Considerations

| Concern | Current (v3.0) | Future (v4+) |
|---------|---------------|--------------|
| SwiftData store size | ~10KB (3 stats + evolution records) | Negligible — evolution records are a handful per user lifetime |
| Animation state count | ~30 cases | Config struct pattern scales to 50+ without structural change |
| Personality blend | 2-way blend | 3-way blend requires extending `blendedPromptBlock()` — no structural change needed |
| Multiple Tamagotchi | N/A | SwiftData schema supports it: add `name: String` field to `TamagotchiState`, `@Query` filters by name |
| Manager count | 21 managers | Pattern handles dozens; only `CharacterViewModel.init()` needs updating per addition |

---

## Sources

- [SwiftData ModelContainer — Apple Developer Documentation](https://developer.apple.com/documentation/swiftdata/modelcontainer)
- [ModelConfiguration init with cloudKitDatabase — Apple Developer Documentation](https://developer.apple.com/documentation/swiftdata/modelconfiguration/init(_:schema:isstoredinmemoryonly:allowssave:groupcontainer:cloudkitdatabase:))
- [Track model changes with SwiftData history — WWDC24](https://developer.apple.com/videos/play/wwdc2024/10075/)
- [How SwiftData works with Swift concurrency — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-swiftdata-works-with-swift-concurrency)
- [Using ModelActor in SwiftData — BrightDigit](https://brightdigit.com/tutorials/swiftdata-modelactor/)
- [SwiftData Architecture Patterns and Practices — AzamSharp 2025](https://azamsharp.com/2025/03/28/swiftdata-architecture-patterns-and-practices.html)
- [Five powerful ways to use Swift enums — Swift by Sundell](https://www.swiftbysundell.com/articles/powerful-ways-to-use-swift-enums/)
- [The Secret to Flawless SwiftUI Animations — fatbobman](https://fatbobman.com/en/posts/mastering-transaction/)
- [Splitting SwiftData and SwiftUI via MVVM — DEV Community](https://dev.to/jameson/swiftui-with-swiftdata-through-repository-36d1)
- Existing codebase: `CharacterAnimationState.swift`, `PersonalityManager.swift`, `FloatingWindowController.swift`, `ARCHITECTURE.md`, `CONCERNS.md` (all inspected directly, 2026-04-05)

---

*Architecture research: 2026-04-05*
