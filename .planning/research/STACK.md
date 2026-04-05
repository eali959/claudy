# Technology Stack — Claud-y v3.0 Additions

**Project:** Claud-y v3.0
**Researched:** 2026-04-05
**Scope:** SwiftData persistence, 30+ SwiftUI animation states, String Catalog i18n (6 languages + RTL)
**Confidence:** MEDIUM-HIGH — verified against Apple documentation, WWDC sessions, and community post-mortems

---

## Existing Stack (Unchanged)

Do not re-research or re-decide. These are settled:

| Technology | Version | Status |
|------------|---------|--------|
| Swift | 6.0 (approachable concurrency) | Locked |
| SwiftUI | macOS 26.2+ | Locked |
| `@Observable` / `Observation` | macOS 14+ (well established) | Locked |
| AppKit (`NSPanel`, `NSStatusItem`) | Minimal, unchanged | Locked |
| AVFoundation | Audio only | Locked |
| Zero SPM dependencies | Project constraint | Locked |

---

## New Stack: SwiftData for Tamagotchi Persistence

### Decision: SwiftData over UserDefaults

**Use SwiftData.** Do not extend UserDefaults for Tamagotchi state.

UserDefaults is already managing 20+ keys — adding hunger, happiness, energy, evolution stage, care history, and event timestamps would push it past the point where it degrades into an untyped blob store. SwiftData gives compile-time model safety, automatic migration for future v3.x updates, and a clean history/audit capability for evolution stage transitions.

| Requirement | UserDefaults | SwiftData |
|-------------|-------------|-----------|
| Typed model | No — raw Data/JSON | Yes — `@Model` class |
| Evolution history log | Manual JSON array | Natural `@Relationship` |
| Schema migration | Manual versioning | `VersionedSchema` + lightweight auto-migration |
| Query/filter by date | Manual in-memory sort | `#Predicate` + `FetchDescriptor` |
| Privacy (local-only) | Local | Local — `isStoredInMemoryOnly: false`, no CloudKit |

### API Surface to Use

**ModelContainer — manual init, not `.modelContainer` modifier**

Because Claud-y has no `WindowGroup` (it uses `NSPanel` via `AppDelegate`), the `.modelContainer()` view modifier pattern from standard SwiftUI tutorials does not apply. Instead, create the container manually in `AppDelegate` and inject it as an environment value.

```swift
// AppDelegate.swift
let schema = Schema([TamagotchiState.self, TamagotchiEvent.self])
let config = ModelConfiguration(
    "claudy-tamagotchi",
    schema: schema,
    url: FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("claudy-tamagotchi.store"),
    allowsSave: true
)
let container = try ModelContainer(for: schema, configurations: [config])
```

Use an explicit `url:` parameter pointing into `~/Library/Application Support/`. Do not use the default store path — on macOS, the default `default.store` location is shared across apps and can collide (HIGH confidence, Apple developer docs).

**Isolation: @MainActor only, no @ModelActor**

For this app, all SwiftData work happens on the main actor. The Tamagotchi data volume is tiny (a handful of stat records + event log). Do not use `@ModelActor` for background operations — the complexity cost is not worth it for this data size, and `@ModelActor` has known subtle issues where it can capture the main thread if initialized there, making isolation guarantees invisible to the compiler (MEDIUM confidence, community post-mortems).

The pattern to follow:

```swift
@Observable
@MainActor
final class TamagotchiManager {
    let modelContext: ModelContext

    init(container: ModelContainer) {
        self.modelContext = ModelContext(container)
    }
}
```

**@Query in views: use with caution on macOS**

`@Query` works in `NSHostingView`-hosted SwiftUI views (which Claud-y uses for the character panel). However, `@Query` requires the view to be in the `modelContext` environment chain. Because the character view is hosted via `NSHostingView` in a custom `NSPanel`, pass the container's main context explicitly:

```swift
hostingView.environment(\.modelContext, container.mainContext)
```

**Do not use `@Query` for the live stat display.** Instead, read `TamagotchiState` directly from the `@MainActor` manager. Use `@Query` only for event history views (e.g., a care log in settings). This avoids re-render overhead on every stat tick.

### Models to Define

```swift
@Model
final class TamagotchiState {
    var hunger: Double          // 0.0–1.0, 1.0 = full
    var happiness: Double       // 0.0–1.0
    var energy: Double          // 0.0–1.0
    var evolutionStage: Int     // 0 baby → 1 teen → 2 adult → 3+ special
    var totalCareScore: Double  // Accumulated care for evolution gating
    var lastFed: Date
    var lastPlayed: Date
    var lastPetted: Date
    var createdAt: Date
}

@Model
final class TamagotchiEvent {
    var kind: String            // "fed" | "played" | "petted" | "evolved" | "neglected"
    var timestamp: Date
    var statSnapshot: Data      // JSON blob of stats at event time
}
```

Keep `TamagotchiEvent` as a flat log rather than a `@Relationship` array on `TamagotchiState` — inverse relationship updates do not reliably trigger `@Observable` change propagation in current macOS releases (MEDIUM confidence, known SwiftData issue on macOS 15/iOS 18 platform regression).

### Migration Strategy

Use `VersionedSchema` from day one even though v3.0 has a single schema version. Establishing the versioning infrastructure prevents a painful migration if v3.1 adds fields:

```swift
enum ClaudySchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [TamagotchiState.self, TamagotchiEvent.self] }
}
```

Lightweight auto-migration handles additive changes (new optional properties). For any breaking change, write a `SchemaMigrationPlan`. SwiftData does not support heavyweight custom migrations (per-row transform logic) as of macOS 15 — design the v3.0 schema to be forward-extensible with optional fields where reasonable.

### Known SwiftData Issues on macOS 15 (Confidence: MEDIUM)

- `ModelContext.didSave` / `willSave` notifications do not reliably fire on macOS 15 / iOS 18 — do not depend on them for UI refresh. Drive UI from `@Observable` properties on your manager class instead.
- Auto-save frequency decreased in iOS 18 / macOS 15; call `try modelContext.save()` explicitly after every user interaction that mutates state.
- Entity inheritance (e.g., subclassing `@Model`) uses Single Table Inheritance under the hood and degrades performance with heterogeneous subtypes. Do not use `@Model` inheritance for the Tamagotchi models — use a flat `kind: String` discriminator on `TamagotchiEvent` instead.
- The `@Query` macro does not update immediately when a `ModelContext` from a different actor inserts records. Since all work is on `@MainActor`, this is not a concern for v3.0.

---

## New Stack: SwiftUI Animation (10 → 30+ States)

### Decision: Extend Current Enum + Computed Properties Pattern

**Do not switch to TimelineView, SpriteKit, Canvas, PhaseAnimator, or KeyframeAnimator for the core character.**

The existing `CharacterAnimationState` enum + `withAnimation` + `@State` bobs approach is correct for this character. Switching to `PhaseAnimator` or `KeyframeAnimator` would require restructuring the entire rendering pipeline with no meaningful benefit — those APIs are designed for one-shot or short cycling animations, not an always-on creature with 30 discrete named states driven by external triggers.

The correct approach is to scale what already works:

1. Add new `CharacterAnimationState` enum cases
2. Add computed properties to the enum (`bobDuration`, `bobOffset`, `eyeShape`, `mouthShape`, `armAngle`)
3. Add rendering branches in `ClaudyCharacterView` switch statements

**TimelineView: use for exactly two things, nothing else**

`TimelineView` with `AnimationTimelineSchedule` is appropriate for:
- Replacing the `Timer.scheduledTimer` lip-sync loop (`talkingTimer`) — this is the explicit tech-debt fix already in scope (BUG-05 adjacent)
- Replacing the `Timer.scheduledTimer` thinking-dot loop (`dotTimer`)

For both, the pattern is:

```swift
TimelineView(.animation(minimumInterval: 0.09, paused: animationState != .talking)) { timeline in
    // read timeline.date to advance mouthOpenAmount
}
```

This eliminates `Timer` capture-by-value bugs and integrates with Swift 6's actor isolation correctly, since `TimelineView` callbacks are `@MainActor` when the enclosing view is. Do not use `TimelineView` for the main bob/idle animation loop — `withAnimation(.easeInOut(duration:).repeatForever())` is simpler and more efficient for continuous idle motion.

**`Task.sleep` for sequential choreography (not Timer)**

For animation sequences that step through moves (currently `DanceModeManager`, future Tamagotchi-specific sequences), use async Task with `Task.sleep(for:)` — already the pattern in the codebase. Do not introduce new `Timer` instances. The tech debt `talkingTimer` and `dotTimer` should be migrated to `TimelineView` in the tech debt phase before adding new animation states.

### Adding 20+ States Without Breaking the View

`ClaudyCharacterView.swift` is currently 991+ lines. Before adding 20 new states, the tech debt extraction (splitting into sub-views per the PROJECT.md plan) must happen first. The view is already flagged for extraction. Adding 20 enum cases to a 991-line view compounds the maintainability problem.

**Recommended sub-view split for animation work:**

| Sub-view | Responsibility |
|----------|---------------|
| `ClaudyEyesView` | All eye shapes keyed to state |
| `ClaudyMouthView` | All mouth shapes + lip-sync |
| `ClaudyArmsView` | Arm angles + flair animations |
| `ClaudyBodyView` | Body scale, glow, particle effects |
| `ClaudyCharacterView` | Composes above, owns `animationState` onChange routing |

Each sub-view receives its needed parameters as `let` props, not the full `animationState`. This makes each sub-view independently testable and keeps the switch statement complexity distributed.

**Enum computed property pattern — definitive example:**

```swift
extension CharacterAnimationState {
    var bobDuration: Double {
        switch self {
        case .sleeping: return 3.2
        case .dancing: return 0.36
        case .headbanging: return 0.13
        case .vibing: return 1.1
        // new states
        case .meditating: return 4.0
        case .nervous: return 0.6
        default: return 1.9
        }
    }

    var bobOffset: CGFloat {
        switch self {
        case .dancing: return -16
        case .headbanging: return -26
        case .sleeping: return -2
        default: return -6
        }
    }
}
```

Adding a new state = add one case + computed property values. The view's `startBobAnimation()` reads these properties rather than containing a ternary chain per variable. This is strictly better than the current ternary chain in the existing codebase.

### Reduce Motion Compliance

All new animation states must respect the existing `@Environment(\.accessibilityReduceMotion)` guard. For 30+ states, codify the reduce-motion contract in the enum:

```swift
extension CharacterAnimationState {
    var supportsMotion: Bool {
        switch self {
        case .sleeping, .idle, .thinking, .talking: return false  // static or minimal
        default: return true
        }
    }
}
```

When `reduceMotion` is true: bob offset = 0, glow = disabled, wiggle = disabled. This is already the pattern — make it explicit in the enum rather than scattered conditionals in the view.

### What NOT to Use

| Approach | Why Not |
|----------|---------|
| `SpriteKit` | Project constraint — SwiftUI only |
| `Lottie` | Project constraint — zero external dependencies |
| `Canvas` + `TimelineView` for main character | Overkill; loses SwiftUI reactivity for state-driven changes |
| `PhaseAnimator` for continuous idle | It cycles automatically — wrong model for externally-triggered state |
| `KeyframeAnimator` for bobs | Heavy per-frame computation for a simple easeInOut repeat; stick with `repeatForever` |
| New `Timer.scheduledTimer` instances | Tech debt direction is away from Timer — do not add new ones |

---

## New Stack: Localization (6 Languages + RTL)

### Decision: String Catalogs (.xcstrings), not Localizable.strings

**Use String Catalogs exclusively for all v3.0 localization work.** Do not create new `.strings` files. If `Localizable.strings` files exist in the project, migrate them to `.xcstrings` using Xcode's built-in migration (right-click → Migrate to String Catalog) before adding translations.

String Catalogs are the current Apple standard (Xcode 15+, 2023 onwards). They:
- Unify `.strings` and `.stringsdict` (plurals) into a single file
- Show translation state (new / needs review / stale) in the Xcode editor
- Auto-extract keys from source on each build — the catalog self-updates as strings are added in code
- Are fully backward-compatible at runtime (Xcode compiles them back to `.strings` during build)
- Support device/plural variations without a separate `.stringsdict` file

The project already uses Xcode 26.3+ which supports String Catalogs fully.

### String API: String(localized:) preferred, NSLocalizedString acceptable

```swift
// Preferred — Swifty, works with String Catalogs
Text(String(localized: "tamagotchi.hungry.message"))

// Also acceptable — no code changes needed during migration
Text(NSLocalizedString("tamagotchi.hungry.message", comment: "Shown when pet is hungry"))
```

Do not mix both styles in the same file. Pick `String(localized:)` for all new v3.0 strings.

### Key Strategy: Structured Namespacing

With 400+ reaction strings plus UI copy, key naming discipline is essential. Use dot-notation namespacing:

```
ui.settings.personality.title
ui.chat.placeholder
reaction.xcode.build_success.1
reaction.xcode.build_success.2
tamagotchi.hungry.bubble.1
tamagotchi.evolving.announcement
```

The `reaction.` namespace decision: whether to localise all 400+ reaction strings or keep them in English is an open product question (noted in PROJECT.md). For v3.0 stack purposes, String Catalogs handle large string counts well — the concern is translation effort cost, not technical feasibility. The catalog can mark reaction strings as "don't translate" with a `shouldTranslate: false` attribute per-string.

### Multiple Catalogs for Scale

Do not put 400+ strings in a single `Localizable.xcstrings`. Split by domain:

| Catalog file | Strings | Notes |
|--------------|---------|-------|
| `Localizable.xcstrings` | UI chrome — settings, menus, buttons, chat UI | Core, always translated |
| `Reactions.xcstrings` | 400+ reaction pool strings | Mark as `shouldTranslate: false` for English-only decision |
| `Tamagotchi.xcstrings` | Tamagotchi UI, hunger/evolution messages | Translated |
| `Onboarding.xcstrings` | Onboarding copy | Translated |

When referencing strings from a non-default catalog, use the `table:` parameter:

```swift
String(localized: "tamagotchi.hungry.bubble.1", table: "Tamagotchi")
```

### RTL Support (Arabic, Urdu)

**SwiftUI handles RTL automatically when the locale is set** — do not manually mirror layouts with `.flipsForRightToLeftLayoutDirection`. The correct approach:

1. Add `ar` (Arabic) and `ur` (Urdu) to the project's localizations list in Xcode
2. Use `.leading` / `.trailing` everywhere — never `.left` / `.right` in view layout
3. Use `HStack` — it mirrors automatically for RTL locales
4. Test using Xcode scheme → Options → App Language: "Right to Left Pseudolanguage"

The one exception for Claud-y specifically: the character itself (the round orange creature). The character is symmetrical, so no mirroring is needed. Arm animations that are left/right specific (e.g., waving right arm) do not need RTL mirroring — this is a character art decision, not a layout decision.

**Forcing RTL for testing without changing system language:**

```swift
// For development testing only — not for production code
contentView.environment(\.layoutDirection, .rightToLeft)
```

**Romanized toggle (Arabic → Arabizi, Hindi → Hinglish, Urdu → Roman Urdu):** This is a product feature, not a localization system feature. The implementation is: a `UserDefaults` bool per language (`UseRomanizedArabic`, etc.), and a string lookup that selects from a separate `Romanized.xcstrings` table when the toggle is on. This is a parallel string table, not a locale — do not create a fake `ar-Latn` locale for this.

### SF Symbols: RTL-Ready by Default

SF Symbols 2.0+ includes pre-localized RTL variants for directional symbols (arrows, chevrons, etc.). Always use `Image(systemName:)` — never manually rotate or mirror SF Symbol images for RTL. The system handles this automatically.

### Character Set and Font Considerations

Arabic and Urdu use the Arabic script, which requires fonts that support it. macOS system fonts (San Francisco) include Arabic fallback glyphs. Because Claud-y uses system fonts exclusively (no custom fonts are in the project), no font configuration is needed for RTL language support.

---

## Installation / Adoption

No new SPM packages. No new entitlements required. SwiftData is a system framework available on macOS 14+ (confirmed available on the project's macOS 26.2 target). String Catalogs require Xcode 15+ (project is on Xcode 26.3). Both are zero-install additions.

To enable SwiftData:
1. Add `import SwiftData` to relevant files
2. Create `TamagotchiState.swift` and `TamagotchiEvent.swift` with `@Model` classes
3. Initialize `ModelContainer` in `AppDelegate` with explicit store URL
4. Pass `container.mainContext` via `.environment(\.modelContext, ...)` on the `NSHostingView`

To enable String Catalogs:
1. In Xcode: File → New → String Catalog (creates `Localizable.xcstrings`)
2. Add project localizations: Project → Info → Localizations → + (ar, es, fr, hi, ur)
3. Build once — Xcode auto-populates keys from source
4. If migrating existing `.strings` files: right-click → Migrate to String Catalog

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Persistence | SwiftData | Extend UserDefaults | UserDefaults is already overloaded; no schema migration; untyped |
| Persistence | SwiftData | Core Data | SwiftData is the forward-looking API for macOS 15+; Core Data is maintenance mode |
| Animation driver (lip-sync) | `TimelineView` | `Timer.scheduledTimer` | Timer has capture-by-value bugs documented in CONCERNS.md; TimelineView is Swift-concurrency-safe |
| Animation architecture | Enum + computed props | `PhaseAnimator` | PhaseAnimator cycles automatically — wrong model for externally-triggered named states |
| Animation architecture | Enum + computed props | `KeyframeAnimator` | Per-frame computation overhead for a continuous idle creature; overkill |
| i18n format | String Catalogs (.xcstrings) | Localizable.strings | String Catalogs are the current Apple standard; .strings lacks plural support without .stringsdict |
| RTL implementation | Automatic via locale | Manual `.environment(\.layoutDirection, .rightToLeft)` | Manual override only for testing; production must use real locale |

---

## Sources

- [ModelContainer — Apple Developer Documentation](https://developer.apple.com/documentation/swiftdata/modelcontainer)
- [ModelConfiguration — Apple Developer Documentation](https://developer.apple.com/documentation/swiftdata/modelconfiguration)
- [SwiftData Architecture Patterns and Practices — AzamSharp (2025-03)](https://azamsharp.com/2025/03/28/swiftdata-architecture-patterns-and-practices.html)
- [ModelActor is Just Weird — massicotte.org](https://www.massicotte.org/model-actor/)
- [SwiftData Background Tasks — Use Your Loaf](https://useyourloaf.com/blog/swiftdata-background-tasks/)
- [SwiftData Pitfalls — Wade Tregaskis](https://wadetregaskis.com/swiftdata-pitfalls/)
- [SwiftData Issues in macOS 14 and iOS 17 — Michael Tsai](https://mjtsai.com/blog/2024/06/04/swiftdata-issues-in-macos-14-and-ios-17/)
- [High Performance SwiftData Apps — Jacob Bartlett](https://blog.jacobstechtavern.com/p/high-performance-swiftdata)
- [SwiftData: Dive into Inheritance and Schema Migration — WWDC25](https://developer.apple.com/videos/play/wwdc2025/291/)
- [Is Entity Inheritance Slowing Down Your SwiftData/CoreData App? — Fatbobman](https://fatbobman.com/en/snippet/is-entity-inheritance-slowing-down-your-swiftdata-coredata-app/)
- [KeyframeAnimator — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/keyframeanimator)
- [PhaseAnimator — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/phaseanimator)
- [Wind Your Way Through Advanced Animations — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10157/)
- [Advanced SwiftUI Animations Part 4: TimelineView — The SwiftUI Lab](https://swiftui-lab.com/swiftui-animations-part4/)
- [Localizing and Varying Text with a String Catalog — Apple Developer Documentation](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
- [Xcode String Catalogs — compile-time safety and RTL gotchas — Atomic Robot](https://atomicrobot.com/blog/lost-in-translation-understanding-ios-localization/)
- [LayoutDirection — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/layoutdirection)
- [Code-along: Explore Localization with Xcode — WWDC25](https://developer.apple.com/videos/play/wwdc2025/225/)
- [A Better Way to Localize Swift Packages with String Catalogs — Daniel Saidi (2025-12)](https://danielsaidi.com/blog/2025/12/02/a-better-way-to-localize-swift-packages-with-xcode-string-catalogs)

---

*Stack research: 2026-04-05 | Confidence: MEDIUM-HIGH | Downstream: roadmap phase structure*
