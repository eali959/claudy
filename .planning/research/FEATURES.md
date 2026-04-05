# Feature Landscape

**Domain:** Tamagotchi-style virtual pet systems + AI personality blending + character animation catalogs + multilingual macOS UI
**Project:** Claud-y v3.0
**Researched:** 2026-04-05
**Research mode:** Ecosystem

---

## Domain 1: Virtual Pet Care Mechanics

### Table Stakes

Features users expect from any virtual pet system. Missing = product feels broken or "not a real pet."

| Feature | Why Expected | Complexity | Specific Numbers |
|---------|--------------|------------|-----------------|
| Hunger stat (visible, actionable) | Core Tamagotchi loop since 1996 — absence breaks genre contract | Low | 0–100 internal; decay ~1pt/3–5 min when awake |
| Happiness stat (visible, actionable) | Second pillar of care loop; fills via play/petting | Low | 0–100 internal; decay ~1pt/5–8 min baseline |
| Energy/sleep stat | Third pillar; depletes over active time, recovers during idle/sleep | Low | 0–100; drains ~1pt/2 min active, recovers 2×/min idle |
| Feed interaction | Minimum viable care action | Low | +20–25 hunger on feed; snacks +5 happiness, -0 hunger |
| Pet/play interaction | Second care action; must feel tactile | Low | +15–20 happiness; play also costs −10 energy |
| Visual stat indicators | Stats must be glanceable — bars, emoji, or numeric | Low | At minimum: full/ok/low/critical four-state |
| Mood expression tied to stats | Face/body reflects current stat combination | Medium | Critical hunger → grumpy; low energy → drowsy |
| Stats persist across launches | Non-negotiable: pets must remember state | Low | SwiftData, local-only |
| Care decay while app is backgrounded | Stats should decay even when app is not frontmost | Medium | Use elapsed-time delta on resume |

### Differentiators (virtual pet mechanics)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Visual evolution stages | Long-term engagement arc; milestone moments | High | Baby → Teen → Adult → Special: driven by sustained high care |
| Evolution tied to care quality, not just time | Better care = cuter/cooler forms (Tamagotchi precedent) | Medium | Care score accumulated via low "neglect events" |
| Gradual visual degradation at critical stats | Pet looks visually worse (dimmer glow, drooping posture) when neglected | Medium | Per-stat visual modifier on character draw |
| Personality influence on pet needs | Different personality modes create different decay rates (Study: energy decays faster; Dance: happiness decays slower) | High | Multipliers on decay rates per BehaviorMode |
| "Today's mood" badge | At-a-glance stat summary without opening full UI | Low | Menu bar or floating badge |
| Care log / history | Users can review when they fed/played | Medium | SwiftData — timestamp + action type |
| Milestone celebrations at evolution | Evolution triggers confetti + speech bubble | Low | Builds on existing `celebrating` state |
| Persistent level/age counter | Days alive counter adds sentimental value | Low | SwiftData — age persists through launches |

### Anti-Features (virtual pet mechanics — explicitly exclude)

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Death mechanic** | Creates anxiety and guilt; hostile to "focus companion" use case; community research shows user division; incompatible with Claud-y's "never annoying" core value | Stat floor at 20% minimum; neglect = grumpy expressions + nag bubbles, never death |
| **Microtransactions / premium food items** | Out of scope per PROJECT.md; "free forever" mandate | All care items built-in |
| **Mandatory care alarms** | Desktop companion must be passive, not demanding | Optional notification toggle; never mandatory |
| **Complex multi-stat interactions with hidden formulas** | Small-team maintenance burden; opaque to user | Three visible stats, documented decay rates |
| **Weight stat** | Original Tamagotchi weight mechanic is confusing and easy to misread as body shaming | Omit entirely; energy serves the "activity" role |
| **Sickness/medicine mechanic** | Adds caretaking burden that conflicts with work-focus use case | Stats show "unwell" face without requiring medicine action |
| **Resetting to baby on neglect** | Punitive; destroys user's long-term progress | Never reset evolution; grumpy mode is the consequence |
| **Real-time push notifications demanding care** | macOS companion must never be the demanding party | Optional, gentle, suppressed during Focus Mode |

### Stat System Specification (MEDIUM confidence — synthesized from Tamagotchi Wiki + open-source implementations)

```
INTERNAL REPRESENTATION
  hunger:    Int, 0–100    (0=starving, 100=full)
  happiness: Int, 0–100    (0=miserable, 100=thrilled)
  energy:    Int, 0–100    (0=exhausted, 100=energised)

FLOOR (never reaches 0 due to anti-death design)
  All stats: minimum persisted value = 15

DECAY RATES (per minute, while user is active)
  hunger:    −1.5/min  (~67 min to go full → critical if never fed)
  happiness: −0.8/min  (~125 min full → critical)
  energy:    −1.0/min  (~85 min full → critical)

DECAY MODIFIERS BY BEHAVIOR MODE
  Study mode:  energy ×1.4 (studying is tiring)
  Dev mode:    hunger ×1.2 (coding = forgetting to eat)
  Dance mode:  energy ×1.8, happiness decay −50% (dancing is fun but tiring)
  Work mode:   happiness ×1.2 (meetings drain happiness)
  BrainRot:    all decays ×0.7 (very chill)
  Normal:      1× baseline

DECAY WHILE BACKGROUNDED
  On resume: elapsed = now − lastActiveTimestamp
  Apply decay: stat -= (decayRate × elapsedMinutes × 0.4)  // 40% rate while idle
  Cap: never below floor (15)

CARE ACTIONS
  Feed:   hunger += 25    (max 100)    one feed every 30s (anti-spam)
  Snack:  happiness += 8  (no hunger change)
  Play:   happiness += 15, energy -= 8
  Pet:    happiness += 5   (no energy cost)
  Sleep:  energy recovers at 2× base rate for 90s if user goes idle

STAT → MOOD THRESHOLDS
  Critical zone: stat ≤ 25   → negative expression active
  Low zone:      26–45       → subtle negative expression
  Ok zone:       46–75       → neutral/happy expression
  Full zone:     76–100      → bonus positive expression

MOOD EXPRESSION PRIORITY (if multiple stats critical)
  hunger critical > energy critical > happiness critical
```

### Evolution System Specification (LOW confidence — design synthesis, not sourced from existing implementation)

```
EVOLUTION STAGES
  Baby     → first 2 calendar days (age 0–2)
  Teenager → days 3–7
  Adult    → days 8–21
  Senior   → days 22+
  Special  → unlocked by Special care score ≥ 90 during Senior

CARE SCORE
  Rolling 7-day average: (hunger_avg + happiness_avg + energy_avg) / 3
  Ranges: 0–100
  Good care (≥75): unlocks better adult/senior visual form
  Poor care (≤40): unlocks "scraggly" adult/senior form
  Special (≥90, sustained 7+ days): unlocks special form

EVOLUTION EVENTS
  - Character changes visual appearance (different eye shape, blush marks, pattern)
  - `celebrating` animation plays for 10s
  - Speech bubble: personality-flavoured evolution message
  - Care log entry: "Claud-y evolved!"
```

---

## Domain 2: AI Personality Blending

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Discrete personality picker (existing) | Already shipped in v2; baseline expectation | — | Already exists — 7 personalities |
| Single active personality at a time | Fallback when blend is not set | Low | Maintain existing PersonalityMode system |
| Persist selected personality/blend across launches | Users expect their settings to survive quit | Low | Already persisted via UserDefaults |
| Blended prompt that actually works with underlying LLM | Blend must produce coherent output, not hallucinated tone | High | Requires careful prompt engineering |

### Differentiators (personality blending)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Two-personality slider blend | Expressive, unique — no competitor does this for a desktop companion | Medium | Single `CGFloat` 0.0–1.0 maps A→B |
| Real-time preview of blend in chat | Users see the blend working before committing | Low | Sample greeting generated on slider release |
| Named blend presets | "75% HypeCoach / 25% Listener" → saveable as "Energetic Support" | Medium | UserDefaults array of named presets |
| Blend affects ambient bubbles too | Blend personality influences reaction strings, not just API responses | Medium | Weighted random selection between two reaction pools |
| Smooth prompt interpolation (weighted string injection) | Both personality prompt blocks injected with explicit weighting instruction | Medium | See implementation approach below |

### Anti-Features (personality blending)

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Three-way or N-way blending | Combinatorial explosion; UI becomes confusing; diminishing returns | Two personality maximum |
| Continuous slider during active API call | Mid-stream personality changes cause incoherent responses | Lock slider during API streaming |
| Blend resets on launch by default | Defeats purpose; users expect their tuning to persist | Persist blend ratio to UserDefaults |
| Separate model per personality | Defeats architecture; cost and complexity explosion | Single prompt with weighted blocks |
| "Smart" automatic blending based on context | Invisible = unpredictable = untrustworthy | Manual control only; explicit user choice |

### Blended Prompt Implementation Approach (MEDIUM confidence)

Research on LLM persona blending (PersonaFuse framework, NeurIPS 2025 workshop) confirms that linear interpolation of personality traits via weighted prompt blocks is an effective and transferable approach. The key finding: top-2 persona attributes are sufficient; SCOPE-style 141-facet approaches are over-engineering for this use case.

```
BLEND RATIO
  blendRatio: CGFloat    // 0.0 = 100% personality A, 1.0 = 100% personality B

  Example: blendRatio = 0.25
    → 75% PersonalityA, 25% PersonalityB

PROMPT CONSTRUCTION (new layer between PersonalityManager and API call)
  If blendRatio == 0.0 || blendRatio == 1.0:
    // Pure mode — use existing single personalityBlock (no change to current system)
    systemPrompt = base + personalityBlockA + modeBlock

  Else:
    // Blend mode — inject both blocks with explicit weighting instruction
    systemPrompt = base
      + "\n## PRIMARY PERSONALITY (\(Int((1-blendRatio)*100))% influence)\n"
      + personalityBlockA
      + "\n## SECONDARY PERSONALITY (\(Int(blendRatio*100))% influence)\n"
      + "Modulate the above with these secondary traits, weighted at \(Int(blendRatio*100))%:\n"
      + personalityBlockB
      + modeBlock

SLIDER UI
  - Horizontal slider, full-width
  - Left anchor label: PersonalityA name + icon
  - Right anchor label: PersonalityB name + icon
  - Thumb label: current ratio (e.g. "70/30")
  - Second picker above slider: selects PersonalityB (PersonalityA = current mode)
  - Haptic feedback on 50/50 snap point (NSHapticFeedbackManager)
  - "Preview" button triggers greeting API call with blended prompt

PERSISTENCE
  UserDefaults["PersonalityBlendSecondary"]: String (PersonalityMode raw value or "none")
  UserDefaults["PersonalityBlendRatio"]: Double (0.0–1.0)

AMBIENT REACTION BLENDING
  // For reaction strings (non-API), weight selection between two pools
  let poolA = ReactionLibraryService.reaction(for: trigger, personality: modeA)
  let poolB = ReactionLibraryService.reaction(for: trigger, personality: modeB)
  // Pick A at (1-blendRatio) probability, B at blendRatio probability
  return Double.random(in: 0...1) < blendRatio ? poolB : poolA
```

---

## Domain 3: Character Animation Catalog (30+ States)

### Current 15 States (shipped v2)

`idle`, `thinking`, `talking`, `celebrating`, `confused`, `sleeping`, `surprised`, `alert`, `tickled`, `drowsy`, `waving`, `facepalm`, `dancing`, `headbanging`, `vibing`

### Full 30+ State Catalog for v3.0

Each state requires: eye shape variant, mouth shape variant, body motion variant, and (optional) arm position variant.

#### Emotional Range (8 new states — Pillar 3 scope)

| State | Trigger Context | Eyes | Mouth | Body |
|-------|----------------|------|-------|------|
| `sad` | Care stat critical; negative event | Heavy drooping, tears visible (small drop shapes) | Down-curve frown, small | Slow sag −4pt; shoulder droop |
| `angry` | Roast mode; repeated ignore of care needs | Angled brows (V-shape over pupils), squint | Flat tight line, slight bared teeth | Vibrate ±2pt rapid; arms crossed |
| `nervous` | Build anxiety; deadline approaching; long compile | Darting side-eye (pupils offset left-right alternating) | Slight open O | Rapid small bob ±2pt, 0.4s |
| `excited` | Positive news; first Pomodoro; evolution | Wide bright Pixar eyes 1.2× | Wide grin showing teeth | Bounce ±12pt 0.25s; arms up |
| `bored` | 20+ min idle; BrainRot mode; no interaction | Half-open, heavy-lidded | Small flat line | Slow lean left/right 4s cycle |
| `love_eyes` | Valentine's Day; appreciation bubble; "thank you" intent | Heart pupils (custom draw) | Big smile with blush marks | Slow float bob; hands to cheeks |
| `embarrassed` | Caught in mistake; wrong answer bubble | Tilted down-gaze, one eye hidden | Shy curve with blush marks | Slightly shrunk 0.95×; arm covering face |
| `mischievous` | Easter egg triggered; prank bubble; BrainRot mode | Sideways glance, raised inner brow | Sly half-grin | Slight tilt 5°; one arm behind back |

#### Activity Animations (7 new states — Pillar 3 scope)

| State | Trigger Context | Eyes | Mouth | Body |
|-------|----------------|------|-------|------|
| `typing` | Keyboard burst detected; chat input active | Focused Pixar eyes, slight squint | Neutral concentration | Leaning forward 4pt; tiny arm-tap rhythm |
| `reading` | Long idle in browser/Notion/Obsidian | Eyes tracking left-right (animated pupil) | Slightly open, focused | Still with occasional bob |
| `coding` | Xcode/VS Code/Cursor frontmost + flow state | Intense squint, one raised "eyebrow" (brow line) | Flat line, focused | Forward lean 6pt; finger-coding arm gesture |
| `meditating` | Study mode idle 8+ min; Focus Mode active | Closed, peaceful (thin arc) | Gentle smile | Ultra-slow bob 4.5s; arms resting |
| `exercising` | After Dance mode 10+ min; break nudge | Determined squint | Open grin | Fast bob 0.3s; alternating arm pump |
| `eating` | Feed action triggered | Eyes closed in bliss (^^ shape) | Chewing motion (open/close cycle) | Slight forward-tilt; arm brings food up |
| `studying` | Study mode active + keyboard activity | Focused Pixar, looking down slightly | Slightly open | Very slow bob; arm holds "book" prop |

#### Fun / Viral Animations (8 new states — Pillar 3 scope)

| State | Trigger Context | Eyes | Mouth | Body |
|-------|----------------|------|-------|------|
| `dab` | Achievement; streak milestone | Arc-up ^^ | Wide grin | Arms: one across face, one extended — held 1.5s |
| `moonwalk` | Dance mode special move; Easter egg | Cool half-close | Smug grin | Horizontal glide animation (window position nudge) |
| `backflip` | Evolution moment; 10-Pomodoro milestone | Wide surprised → landing | Gasp then grin | Full rotation via `rotationEffect` + jump |
| `breakdance` | Dance mode extended session | Squint (concentration) | Open grin | Rapid alternating lean + arm spin sequence |
| `sneeze` | Random 1/500 chance per idle cycle | Build-up: eyes squeeze; release: eyes wide | "Achoo" — big open | Head snap forward + backward |
| `yawn` | Drowsy → sleeping transition; energy < 30% | Slow eye close during yawn | Wide open O, stretch | Stretch upward 6pt, arms out, settle |
| `hiccup` | Random ambient; BrainRot mode | Surprised blink | Hiccup O | Sharp small jump ±3pt, single beat |
| `facepalm` | Already exists — retained | Existing | Existing | Existing (counted toward 30) |

#### Tamagotchi-Specific States (5 new states — Pillar 2 scope)

| State | Trigger Context | Eyes | Mouth | Body |
|-------|----------------|------|-------|------|
| `hungry_wobble` | Hunger stat < 30% | Pleading eyes (big pupil, slight tear) | Small pouting curve | Wobble left-right 0.5s; one arm on belly |
| `sleepy_droop` | Energy stat < 30% | Progressively drooping (3-frame) | Tiny sleeping curve | Slow downward drift −6pt; head tilt |
| `happy_bounce` | All stats > 70% simultaneously | Bright arc-up ^^ | Wide grin | Exaggerated bounce ±14pt 0.35s |
| `full_belly_pat` | Hunger stat 90–100 after feeding | Blissful closed ^^ | Happy curve | Arm pats belly in circular motion; sway |
| `evolution_transition` | Evolution stage change | Eyes grow then shift to new form | Gasp → huge grin | Scale up 1.0→1.3→1.0 with glow burst; particle confetti |

### Complete 30+ State List (all states including v2)

1. `idle`
2. `thinking`
3. `talking`
4. `celebrating`
5. `confused`
6. `sleeping`
7. `surprised`
8. `alert`
9. `tickled`
10. `drowsy`
11. `waving`
12. `facepalm`
13. `dancing`
14. `headbanging`
15. `vibing`
16. `sad`
17. `angry`
18. `nervous`
19. `excited`
20. `bored`
21. `love_eyes`
22. `embarrassed`
23. `mischievous`
24. `typing`
25. `reading`
26. `coding`
27. `meditating`
28. `exercising`
29. `eating`
30. `studying`
31. `dab`
32. `moonwalk`
33. `backflip`
34. `breakdance`
35. `sneeze`
36. `yawn`
37. `hiccup`
38. `hungry_wobble`
39. `sleepy_droop`
40. `happy_bounce`
41. `full_belly_pat`
42. `evolution_transition`

**Total: 42 states (15 existing + 27 new)**

### Animation Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Lottie / external animation library | Violates zero-dependency architecture | Pure SwiftUI `withAnimation` + `@State` |
| SpriteKit particle systems | Overkill for round creature; adds complexity | SwiftUI `Canvas` or simple `ZStack` overlays |
| Video-file animations | File size, no dynamic theming | Code-driven only |
| More than 5 simultaneous timers | Performance + fragility (existing concern in CONCERNS.md) | Consolidate to 2 timers + `Task`-based loops |
| Animations that cannot be reduced-motion disabled | Accessibility requirement | All new states must check `accessibilityReduceMotion` |
| Full-screen takeover animations | Companion must never block work | All animations constrained to character panel bounds |

### Animation Trigger Mapping

```
STAT-DRIVEN (checked every 60s by a new stat loop)
  hungry_wobble   ← hunger < 30
  sleepy_droop    ← energy < 30
  happy_bounce    ← hunger > 70 AND happiness > 70 AND energy > 70
  full_belly_pat  ← hunger > 90 AND within 60s of a feed action
  bored           ← idle > 20 min AND no care action recent
  yawn            ← energy 25–35 (pre-sleep transition)

APP-CONTEXT-DRIVEN (AppContextMonitor)
  typing          ← keyboard burst > 30 WPM in any app
  coding          ← Xcode/Cursor/VS Code frontmost + typing
  reading         ← browser/Notion/Obsidian frontmost, no typing for 30s
  studying        ← Study mode + keyboard activity
  meditating      ← Study mode idle 8+ min

RANDOM / EASTER EGG
  sneeze          ← 1/500 chance per idle tick (0.002 probability)
  hiccup          ← 1/300 chance in BrainRot mode
  moonwalk        ← Easter egg trigger "moonwalk" in chat; or Dance mode special move

INTERACTION
  eating          ← feed action (stat system)
  dab             ← Pomodoro complete; streak milestone; evolution
  backflip        ← evolution_transition start
  excited         ← positive intent detected; achievement
  love_eyes       ← "thank you" / Valentine intent; love Easter egg
  embarrassed     ← bot says wrong answer and self-corrects
  mischievous     ← Easter egg pool; BrainRot ambient
  breakdance      ← Dance mode > 5 min
```

---

## Domain 4: Multilingual UI (6 Languages)

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| All UI chrome localised (buttons, labels, menus) | Without this, non-English speakers see broken UI | Medium | `String(localized:)` throughout; Xcode String Catalog |
| RTL layout for Arabic and Urdu | SwiftUI layout breaks visually without this | Medium | `.environment(\.layoutDirection, .rightToLeft)` |
| NSLocalizedString / String(localized:) for all strings | Foundation of localisation infrastructure | Low | Must be done before translator handoff |
| Language follows system language by default | Standard macOS behaviour | Low | Automatic if `.lproj` bundles present |
| Text expansion resilience in layouts | German up to 30% longer; Arabic/Hindi can vary significantly | Medium | Avoid fixed widths; use flexible layouts |
| Separate `.lproj` folder per language | Standard Apple approach | Low | en, es, fr, ar, hi, ur |
| Xcode String Catalog (.xcstrings) | Modern approach (Xcode 15+); keeps strings in sync with code | Low | Preferred over legacy `Localizable.strings` |

### Differentiators (multilingual)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Romanized script toggle for Arabic, Hindi, Urdu | Diaspora/heritage speakers who speak but don't read native script | High | Parallel string set: `ar-Latn`, `hi-Latn`, `ur-Latn` |
| Personality name localisation | "HypeCoach" may not translate culturally; branded or adapted names | Medium | Per-language personality display name mapping |
| RTL-aware drag gesture (character position) | Floating panel should start on left side for RTL users | Low | Flip default `resetPosition()` origin for RTL locales |
| Calendar-aware date formats per locale | Focus stats, wrap-up, check-in dates display correctly | Low | `DateFormatter` with `locale` set from system |

### Anti-Features (multilingual)

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Translating all 400+ reaction strings | Massive ongoing maintenance burden; reaction flavour is English-native | Translate UI chrome only; keep reaction strings English; add RTL display wrapper |
| Auto-translate via LLM at runtime | Inconsistent, costly, breaks offline | Pre-translated static strings only |
| Custom font loading for non-Latin scripts | Unnecessary on macOS — system fonts cover Arabic, Hindi, Urdu | Use `.font(.system(...))` and let macOS handle script |
| Hardcoding text alignment (`.leading` / `.trailing`) | Breaks RTL | Use `.leading`/`.trailing` constraints, not `.left`/`.right` |
| Mixing RTL and LTR in same bubble without isolation | Bidi text renders incorrectly | Use `Text` with explicit `layoutDirection` where needed |

### Localisation Strategy Decision

The key decision documented in PROJECT.md — "Translate all 400+ reaction strings or keep English reactions with localised UI chrome only?" — has a clear answer from this research:

**Recommendation: Localise UI chrome only. Keep reaction strings in English.**

Rationale:
1. Reaction strings are personality/culture-specific; literal translation loses tone
2. 400 strings × 6 languages = 2,400 string units — maintenance burden for a 1-person team
3. Humour, Gen Z slang (BrainRot mode), and tech culture references do not translate well
4. Target users (developers, students in AR/HI/UR markets) typically have working English for tech content
5. UI chrome (buttons, settings, labels, stats) is where language barriers actually block usability

**Romanized toggle implementation:**
```
UserDefaults["RomanizedScriptEnabled"]: Bool   // per-user preference
// When true: use ar-Latn.lproj, hi-Latn.lproj, ur-Latn.lproj
// Requires manual strings only — no automatic transliteration at runtime
// Falls back to native script if Latn bundle missing
```

### RTL Layout Checklist (per WWDC22 "Get it right to left")

```
[ ] Use .leading / .trailing everywhere — never .left / .right
[ ] Test with Arabic scheme in Xcode (Edit Scheme → App Language → Arabic)
[ ] FlippedFlowLayout: HStack reverses automatically in RTL via SwiftUI
[ ] Icons: Use SF Symbols — they have built-in RTL variants for directional symbols
[ ] Custom drawn character: ClaudyCharacterView is symmetric — no RTL change needed
[ ] Floating panel default position: for RTL locales, default to bottom-LEFT not bottom-right
[ ] Scratchpad text alignment: use .natural alignment
[ ] Chat bubbles: user bubble trails; assistant bubble leads — flip for RTL
[ ] Number formatting: use NumberFormatter with locale — Arabic-Indic numerals are automatic
```

---

## Feature Dependencies

```
Tamagotchi stats (persistence) → Evolution stages (requires stat history)
Tamagotchi stats                → Stat-driven animation states (hungry_wobble etc.)
Evolution stages                → evolution_transition animation
Stat-driven animations          → Mood expressions (stat → animation mapping)
Personality blending slider     → Blended prompt generation
Blended prompt generation       → Blended ambient reaction pool
New animation states            → Expanded CharacterAnimationState enum
Expanded animation enum         → Updated ClaudyCharacterView drawing logic
RTL layout support              → Localised UI chrome (prerequisite: strings externalised)
Strings externalised            → All translation work
```

## MVP Recommendation per Pillar

### Pillar 2 (Tamagotchi)
Prioritise:
1. Three stats (hunger/happiness/energy) with persistent storage via SwiftData — the structural foundation
2. Feed + pet interactions — minimum viable care loop
3. Stat-driven mood expressions (`hungry_wobble`, `sleepy_droop`, `happy_bounce`) — makes stats feel alive
4. Visual indicator in character window (compact stat bar, dismissible)

Defer:
- Evolution stages: requires 2+ weeks of visual design work; ship in Pillar 2 Phase 2
- Care log / history: nice-to-have; defer to post-launch

### Pillar 1 (Personality Blending)
Prioritise:
1. Two-personality slider in Settings
2. Weighted prompt injection (the new `PersonalityBlendManager`)
3. Persist blend ratio

Defer:
- Named blend presets: can ship post-launch
- Ambient reaction pool blending: complex; ship after API blending validated

### Pillar 3 (Animations)
Prioritise first batch (highest trigger frequency + lowest draw complexity):
1. `sad`, `angry`, `nervous`, `excited`, `bored` — emotional core
2. `typing`, `coding` — app-context driven; most visible daily
3. `hungry_wobble`, `sleepy_droop`, `happy_bounce`, `full_belly_pat` — Tamagotchi dependency
4. `yawn`, `sneeze` — ambient delight, low complexity

Defer to second batch:
- `moonwalk`, `backflip`, `breakdance` — complex choreography
- `evolution_transition` — depends on evolution stage system
- `love_eyes`, `embarrassed`, `mischievous` — lower trigger frequency

### Pillar 4 (Multilingual)
Prioritise:
1. Xcode String Catalog infrastructure (`Localizable.xcstrings`)
2. `String(localized:)` sweep through all UI views
3. RTL layout audit (`.leading`/`.trailing` fix, direction environment)
4. English + Spanish + French first (largest reach, no RTL complexity)
5. Arabic, Hindi, Urdu second (RTL + new script complexity)

Defer:
- Romanized script toggle: nice differentiator but complex to maintain; post-launch
- Reaction string localisation: not recommended at all (see anti-features)

---

## Sources

- Tamagotchi Wiki — Care mechanics: https://tamagotchi.fandom.com/wiki/Care
- Tamagotchi Wiki — Health meter: https://tamagotchi.fandom.com/wiki/Health_meter
- TamaTalk — Tamagotchi Original Full Guide: https://www.tamatalk.com/threads/tamagotchi-original-full-guide.201737/
- TamaTalk — Tamagotchi Uni care mistakes: https://www.tamatalk.com/threads/tamagotchi-uni-care-mistakes-done-safely.202070/
- Hive.blog — "I solved the original 1997 Tamagotchi": https://hive.blog/hive-140217/@mustachepod/i-solved-the-original-1997-tamagotchi
- GitHub — AI-tamago (LLM virtual pet): https://github.com/ykhli/AI-tamago
- GitHub — GameHelix/tamagotchi (open source stat implementation): https://github.com/GameHelix/tamagotchi
- VirtualPetList — Should Virtual Pets Have a Hunger System: https://www.virtualpetlist.com/threads/should-virtual-pets-have-a-hunger-system.1455/
- PersonaFuse framework (NeurIPS 2025 workshop): https://arxiv.org/html/2509.07370v2
- PersonaLLM Workshop: https://personallmworkshop.github.io/
- Apple Developer — Get it right (to left) WWDC22: https://developer.apple.com/videos/play/wwdc2022/10107/
- Apple Developer — Streamline localized strings WWDC21: https://developer.apple.com/videos/play/wwdc2021/10221/
- Apple Developer — Localize your SwiftUI app WWDC21: https://developer.apple.com/videos/play/wwdc2021/10220/
- Kodeco — SwiftUI RTL: https://www.kodeco.com/books/swiftui-cookbook/v1.0/chapters/8-use-rtl-right-to-left-languages-in-swiftui
- Medium — Making apps compatible with RTL languages: https://novinfard.medium.com/make-your-ios-app-compatible-with-right-to-left-languages-in-swiftui-and-uikit-bdb164892ce3
- Japan House LA — How Tamagotchi Changed Digital Design: https://www.japanhousela.com/articles/how-tamagotchi-changed-digital-design-icon-japanese-tiny-toys-30th-anniversary-anniversary-bandai/
- TamaTalk — Digital Pets and Death (community discussion): https://www.tamatalk.com/threads/digital-pets-and-death.198872/

---

*Confidence Assessment*

| Area | Confidence | Reason |
|------|------------|--------|
| Tamagotchi stat mechanics (structure) | HIGH | Verified via Tamagotchi Wiki + TamaTalk community guides |
| Specific decay rate numbers | MEDIUM | Synthesised from Uni baby rates (hunger: 1/3 min, happiness: 1/5 min); scaled to 0-100 system |
| Evolution threshold specifics | MEDIUM | Original P1/P2 care mistake system well documented; mapping to continuous 0-100 is design synthesis |
| Personality blending approach | MEDIUM | Supported by PersonaFuse/NeurIPS research; practical implementation is novel for this project |
| Animation state list (trigger contexts) | HIGH | Derived from existing codebase (CONCERNS.md) + PROJECT.md requirements; no external verification needed |
| Animation drawing complexity estimates | MEDIUM | Based on existing 15-state pattern in CONCERNS.md; new states follow same structure |
| Multilingual RTL approach | HIGH | Apple official WWDC documentation + SwiftUI confirmed patterns |
| Romanized script toggle | LOW | No existing SwiftUI implementation reference found; design synthesis only |
| Reaction string localisation recommendation | MEDIUM | Multiple sources confirm maintenance burden; English-only is common industry pattern for tone-dependent content |
