# Claud-y Changelog

---

## v4.0.0 — 3D Claud-y, accessories, twirl, voice mode — 2026-05-17

> Claud-y is now a fully expressive 3D character with accessories, idle micro-behaviours, and a purpose-built floating voice overlay. Visual quality matched to the 2D version. Demo mode rebuilt for the V4 launch.

### V5.10–V5.11 — Final V4 polish + privacy ethos round (release-ready)

> Comprehensive end-to-end pass before release. Permission prompts deferred until users opt-in, voice-mode equaliser respects state, animation library expanded, response pools nearly doubled, optional local-save feature with per-data-type toggles, security + privacy review.

#### First-run UX — no scary permission prompts at launch
- **`GlobalHotkeyManager` defaults OFF for new installs.** Registering `addGlobalMonitorForEvents(.keyDown)` for ⌘⇧Space triggers the macOS Input Monitoring permission prompt — a confusing experience for new users. Users can opt-in via Settings → General. Existing users with it already enabled keep their preference.
- **`KeyboardMonitor` is now opt-in.** Same Input Monitoring concern. New "Keyboard reactions" toggle in Settings → General controls typing-burst / undo-streak / Caps Lock detection. Default OFF. Runtime toggle via `claudyKeyboardReactionsToggled` notification — no app restart needed.
- **Demo keyboard shortcuts opt-in.** Shift+Option+D / Shift+Option+V hold-to-trigger demos require Input Monitoring. Now controlled by "Demo keyboard shortcuts" toggle. Demo can still be started from Help and right-click menu.
- **`WeatherContextMonitor` opt-in.** Was triggering a Location permission prompt 90 s after launch. Now requires "Weather comments" toggle in Settings → Behaviour. Default OFF.

**Net effect:** new users get zero unexpected system permission prompts on first launch. Every prompt is now tied to an explicit user action.

#### Voice mode polish (V5.10)
- **Equaliser only animates when audio is being captured.** Previously the wave bars wiggled randomly via `Float.random` jitter even when voice mode was off — visually suggesting always-on audio. Now bars decay to flat (zero) unless `isVoiceModeActive AND (isListening OR isSpeaking)`.
- **Mic button pulse only fires while listening.** The scaling repeat-forever animation no longer plays when idle / thinking / speaking — only during active mic capture.
- **Wave bars start flat (0.0).** Previously initialised to 0.2 — visible at rest. Now invisible at rest.

#### Animation polish (V5.10)
- **Iris tracking permanently disabled** (with explanation). Per-eye rotation tracking had recurring axis-alignment bugs that pushed pupils to the sclera edge ("wall-eyed" look). The rig-level head yaw/pitch already gives Claudy a "looking at you" feel; pupils now welded to forward-gaze. No code path can move them off-centre.
- **`microLookAround` rebuilt as head turn**, not eye rotation. Previously rotated eye entities directly — same wall-eyed risk as iris tracking.
- **4 new idle micro-behaviours** added (was 8, now 12):
  - **Yawn** — slow open-mouth + body squash + close. Reads as "sleepy / relaxed".
  - **Scratch head** — left arm raises + head tilts. "Puzzled / thinking" without leaving idle.
  - **Double take** — quick tilt right, snap back, tilt right again. "Wait, did I see that?"
  - **Peek** — Claudy ducks down then pops back up. Playful curiosity.
- Idle micro frequency increased: 8–12 s → **6–10 s** for richer ambient life.

#### Response pool nearly doubled (V5.11)
- **`ReactionLibrary.json`** went from **728 → 1320 lines** of Companion-voice content (+592 lines, **+81 %**). Every category received fresh, voice-matched entries. Other language files (`_ar`, `_de`, `_es`, `_fr`) untouched (per-user preference for English-only expansion).

#### Optional local-save feature (V5.11)
- **New `ChatHistoryStore`** persists chat messages to `~/Library/Application Support/Claudy/chat_history.json` when enabled. **Off by default**. Restored on app launch. "Clear saved chat history" button removes the file.
- **Per-data-type toggles in Settings → Privacy & Storage**:
  - Chat history (NEW, default OFF)
  - Scratchpad notes (default ON, was always-on)
  - Tamagotchi state (default ON, was always-on)
  - Focus stats (default ON, was always-on)
  - Alarms / reminders (default ON, was always-on)
- `ScratchpadManager.save()` now respects the toggle — opt-out users get session-only notes.

#### UI surface polish (V5.10)
- **Pomodoro complete state** — sealed checkmark with subtle pulse celebration (was plain checkmark).
- **Scratchpad sheet** — note count shown in header (e.g. "Scratchpad (12)").
- `ScratchpadManager.clearAllNotes()` added for the bulk delete confirmation flow.

#### Bug fixes (V5.10)
- **`ChatViewModel.announcePersonalityChange`** Task made explicit `@MainActor [weak self]` — eliminates ambiguity in Swift concurrency inheritance.
- **`PomodoroTimerBadge` body** broken into smaller computed views to satisfy SwiftUI's type-check budget.

#### Security + privacy review (V5.11)
- **Network endpoints whitelisted**: `api.anthropic.com`, `api.openai.com`, `generativelanguage.googleapis.com`, `api.deepseek.com`, `api.spotify.com` (only when authenticated), `api.open-meteo.com` (only when weather enabled), `localhost:11434/1234` (Ollama / LM Studio).
- **No plain HTTP** except `localhost` (correct — local-only, never leaves the device).
- **No hardcoded secrets** — only placeholder strings in `KeychainService.keyPlaceholder`.
- **Zero force-unwraps / `try!` / `as!`** in app code.
- **Keychain reads gated** to user actions only (field focus + "Load saved key" button + actual API calls). No eager reads.
- **All user data on-device by default** — chat opt-in, weather opt-in, location opt-in, mic opt-in, speech opt-in.

### V5.2 — final 3D polish round (resolves all reported eye/mouth/body anomalies)

> Six interlocking root-cause fixes for 3D Claud-y. Each one alone wasn't enough — together they fix every reported symptom: eyes going huge or invisible, mouth stuck open or shut, body drifting in slow 360° spins, smile flashing huge during transitions.

- **Eye blink-scale wrapper architecture.** Each eye is now wrapped in a dedicated `eyeBlinkScalerL/R` entity inserted between the original parent and the USDZ eye entity. The wrapper handles SCALE (blink, eye-widen). The original eye handles ROTATION (iris tracking, recentre). **Root cause fixed:** previously five different functions (`applyBlink`, `performEyeWiden`, `applyMouseTracking`, `recentreEyesIfCursorIdle`, `refreshEyeAxes`) all called `move(to:)` on the same entity. RealityKit cancels in-flight `move(to:)` calls when a new one fires on the same entity, so they perpetually cancelled each other mid-animation, leaving eyes stuck at half-blink (looked like "eyes closed and won't reopen") or stuck at scale 1.18 (looked like "eyes go huge and stay huge"). Two separate entities = no collision, ever.
- **`setBodyTask(_:)` helper replaces 16 raw `bodyTask = Task {…}` reassignments.** Swift Tasks are NOT auto-cancelled when their handle variable is overwritten. So every `performJolt`, `performCelebrate`, `performSway`, `performBackflip`, etc. was leaving the previous body animation Task running as a zombie, fighting the new one via concurrent `body.move(to:)` calls. The helper does `bodyTask?.cancel(); bodyTask = Task {…}` atomically so only one body loop is ever running. **Eliminates erratic body rotation drift and slow 360° spins.**
- **Phoneme-driven lip-sync matching 2D Claudy.** Implemented the same 16-step phoneme weight pattern (`[0.05, 0.15, 0.45, 0.65, 0.85, …]`) that 2D Claudy uses, ticked at 90ms intervals (~11 phonemes/sec), driving BOTH width (16…25 pt) AND height (3…17 pt) of the open-mouth ellipse. 70ms easeInOut between phonemes. Loop starts on `setMouthShape(.talkingSync)`, stops cleanly when shape leaves talkingSync. **Mouth now actually opens and closes naturally during talking — not a frozen oval.** TTS word-boundary `pulseMouth()` layers a brief peak (0.9) on top when real speech is driving, providing speech accent.
- **Critically damped mouth-shape spring (`dampingFraction: 1.0`).** Previous `0.72` damping caused brief overshoots during expression transitions — going from `default` (16 pt) to `bigSmile` (22 pt) momentarily hit ~28 pt before settling. **Eliminates the "smile width gets huge and creepy" flash.**
- **Killed the per-frame mouth re-projection feedback loop.** `applyProps()` (called from RealityView's `update:` closure) was writing `@State` vars `mouth2DY` and `mouth2DTrackX` every frame, which triggered SwiftUI body re-renders, which re-fired `update:`, which fired `applyProps` again — a continuous re-render loop at 60+ fps that destabilised every other animation timing. Mouth position is now projected ONCE in `finaliseAfterAdd` from the resting world position. Body sway is small (±7°) so the static projection looks visually correct.
- **Removed horizontal mouth tracking (`mouth2DTrackX`).** Was contributing to mouth wobble across the face during body sway. Mouth now stays centered horizontally; expression-specific offsets (smirk's `offX: 3`) still work via `mouth2DOffX`.
- **`recentreEyesIfCursorIdle` defers `@State` writes via Task.** Same SwiftUI rule: cannot mutate `@State` from inside `update:` closure. The eye-recentre's `lastTrackNX/Y = 0` writes are now deferred to the next main-actor tick.

**Net result:** zero warnings, zero errors, eyes stay round and stable, mouth lip-syncs naturally during talking, body holds its rotation, smile transitions are snap-clean.

### Accessory visual overhaul — gold wire glasses, wide Heisenberg brim, rounder cap dome (2D + 3D parity)

**Gold wire-frame glasses (`.glasses` + `.tintedSunnies`).**
- 3D: New `glassesGoldPBR` material — polished metallic gold (metallic 1.0, roughness 0.10, warm gold tint). Frame wire halved (`r×0.05 → r×0.030`). Perfectly circular lenses — both eyes same `r×0.30` radius. Straight bridge replaced with an **arched nose bridge**: two gold box-segments angle down from each lens's inner edge to a shared low-point at the nose, forming a proper U-arch (`archDipZ = r×0.055`). Arch orientation computed via `simd_quatf(from:to:)` for exact alignment.
- 2D: Gold frame color (`0.90, 0.70, 0.20`). Lenses now `Circle()` (was `RoundedRectangle`) — identical diameter for both eyes. Arched bridge rendered as two `Rectangle` arms each rotated `±atan2(4, 10) ≈ 21.8°`, meeting at a 4pt nose dip.

**Heisenberg hat wide-brim rebuild.**
- 3D: Brim radius `r×1.05 → r×1.42` (much wider, clearly pork-pie). Crown split into two stacked cylinders (`r×0.62` base + `r×0.56` top) giving a genuine inward taper. Total crown height shortened `r×0.30 → r×0.24`. Pinch indent updated to match narrowed top radius. Matte black felt impression kept (`hatBlackPBR`, roughness 0.55).
- 2D: Brim widened `62 → 84 * s`. Crown shortened to `24 * s` (was 30). Top-edge shading stripe (`hatShade 0.60 opacity`) implies the crown's tapered indent without a custom shape. Grosgrain band stays.

**Baseball cap rounder dome + prominent brim.**
- 3D: Dome flatness `0.40 → 0.60` (correct rounded cap profile). Added `sweatband` ring cylinder at base. Brim extended to 7 segments (was 5), reach `r×0.85 → r×0.98`, width `r×1.05 → r×1.12`. Button moved flush with dome apex.
- 2D: Dome `54×30 → 58×40` — matches real cap proportions. Brim reach `44 → 50 * s`. Three subtle panel-seam `Capsule` lines (`1.2 * s` wide) radiating across the dome for fabric detail. Backward cap brim enlarged `34 → 40 * s`, correctly peeking behind.

### Final V4.0 release pass — living character + bug fixes + .app deliverable

**Issue 1 — Cinema 3D glasses, clean H-frame rebuild.** Replaced the puffy-rectangle frame with a proper 5-strip H-shape: top bar, bottom bar, outer-left edge, outer-right edge, slim nose-bridge strip. Frame strip thickness halved (`r×0.05 → r×0.025`). Sharp cardboard corners (`cornerRadius r×0.06 → r×0.02`). Saturated cyan (`0.92, 0.95, α 0.45`) and red (`1.0, 0.08, 0.05, α 0.45`) lens tints. Subtle 0.05 rad temple bow (was 0.09 — overshooting). Matches the canonical cardboard 3D-glasses reference photo.

**Issue 2 — Demo twirl, strict phased animation.** Eliminated the LERP-mismatch artifact where concurrent body rotation + limb interpolation made arms/legs visually merge with the body. New phase rule: **zero concurrent limb-and-body animation**. 10-phase timeline: arm pose → settle → blink → 4× (rotation → step interstitial → step reset). Body Y-bob removed (was compounding the issue). Total runtime ~4.3s — deliberate, not rushed.

**Issue 3 — Double-click chat regression FIXED.** Migrated click handling from NSView (`_ClickableOverlayView.mouseDown`) to SwiftUI native `.onTapGesture(count: 2)` + `.onTapGesture(count: 1)` + `.simultaneousGesture(DragGesture(minDistance: 5))`. The NSView shim now only handles `window.makeKey()`. Native count-2 deferral implements the click-promotion pattern correctly; the previous approach was being intercepted by SwiftUI's parent gesture chain.

**Issue 4 — Pupils stay centred after accessory swap.** New `refreshEyeAxes()` re-runs the same axis-discovery logic used at startup (camera-forward, up, right vectors via `convert(direction:from: nil)`), re-computes pupil base positions, smooth-snaps pupils back, and resets the iris-tracking throttle. Called automatically 50ms after every `updateAccessory(_:)` call. Fixes the "stuck pupil after putting glasses on" bug.

**Issue 5 — Living, breathing character (ambient life pyramid):**
- **Always-on ambient task** (`startAmbientLife()`) runs three concurrent loops for the entire app lifetime — never cancelled by state changes:
  - Iris saccades: ±0.0005m random offsets every 0.7-1.4s
  - Mouth micro-drift: brief `vibeSmile` flash every 6-10s when mouth is at default
- **Voice listening breathe**: when `voiceCharacterState == .listening` AND voice mode is active, body Y oscillates ±0.015m on a 3.0s cycle. Started/stopped via `startVoiceBreathe()` / `stopVoiceBreathe()`.
- **Anticipation prep frames**: `.surprised`/`.celebrating` states now run a 60ms body squash (`scale 1.04, 1.04, 0.95`) BEFORE the main reaction. Classic animation principle — "the prep before the action".
- **Demo timing rebalance**: Scene 1 trimmed `3.0 → 2.2s`; Scene 2 reveal — bubble fires AFTER the (now 4.3s phased) twirl completes, not during; Scene 4b voice extended `3.8 → 5.0s`; Scene 9 carousel per-item `1.7 → 2.3s` and **Santa hat added** to the carousel.

**Issue 6 — Accessory polish.** Round-glasses ring now built from 24 box-segments (was 16) for smoother circular silhouette. All accessory anchor offsets verified consistent.

**Issue 7 — Local `.app` deliverable.** Signed `Claudy-v4.0-Local.zip` (96 MB) at the project root. Ad-hoc signed (no Apple notarization) — first launch may need right-click → Open to bypass Gatekeeper. Subsequent launches work normally.


- **Pupil sticking after fast mouse moves.** Reduced iris yaw amplitude (0.45 → 0.30) and pitch (0.40 → 0.28) so pupils can never reach the eye-sphere silhouette edge. Re-centre idle threshold lowered from 5s → 2s. Added a force-tracking-update path: when pupils have drifted >0.005m from their target base, the next applyMouseTracking runs even if the throttle gate would normally skip — fixes the "stuck pupil after fast sweep" bug.
- **Double-click chat regression.** `_ClickableOverlayView.mouseDown` now defers single-tap by 250ms via a `DispatchWorkItem`. If a second click arrives within that window, the pending work item is cancelled and `onDoubleTap` fires instead. Stops calling `super.mouseDown(with:)` since we've fully handled the gesture.
- **Arm-body gap during animations.** Arm pivot moved OUTWARD (`halfY * 0.95 → × 1.02`) so the inner edge of the arm sphere stays touching the body wall through any rotation. Wave amplitudes trimmed (-1.45 → -0.65 max), dance armOut 0.55 → 0.45, breakdance flares 0.85 → 0.65 — peak swings now stay close to the body silhouette.
- **Round glasses (`.glasses` + `.tintedSunnies`)** rebuilt with a proper torus-style ring rim (16 box-segments around the lens edge), translucent disc lens just in front, bridge piece, and temple arms extending back. PBR plastic frame material picks up studio lighting properly.
- **Cinema 3D glasses** matched to the canonical cardboard reference photo: rectangular with thin white border (frame border tightened ×2.0 → ×1.0), saturated cyan/red lens tints (alpha 0.45), bridge shrunk to a small piece between lenses, temple arms bowed outward by ~5° as in the reference.
- **Cap visor** rebuilt with a curved profile — 5 thin overlapping segments at varying pitch/Z-dip create a smooth baseball-brim arc (no more flat ramp). Added a small button on top of the dome for cap detail. PBR cap material.
- **Heisenberg pork-pie pinch.** Added a slightly smaller indented disc on top of the crown so the hat reads as a proper pork-pie not a flat-top cylinder. PBR black + slightly-grey grosgrain band.
- **NEW: Santa Hat accessory.** `.santaHat` case in both 2D and 3D:
  - 2D: SwiftUI Path-based cone with sideways droop, white fluffy band rectangle, pom-pom circle with highlight, gradient overlay
  - 3D: 6 stacked cylinders for the cone (procedural since RealityKit has no cone primitive), white fluffy base band, pom-pom sphere on the tip, ~12° forward droop + 5° sideways kink for that classic Santa hat flop
  - Velvet PBR red (`#C8202E`) + fluffy white materials
  - Wired into all picker UIs automatically via `CharacterAccessory.allCases`

### Deferred-items round (10 fixes)
- **3D thinking dots overlay.** Three bouncing terra-cotta dots float above 3D Claud-y while chat is mid-stream. Mirrors the 2D character's `.thinkingDots` eye state without swapping USDZ pupil materials at runtime. Fades in/out with a `.scale + .opacity` transition.
- **3D confetti burst.** Lightweight pure-SwiftUI confetti (28 pieces, mix of rectangles + circles, terra-cotta + accent palette) rains from above the character on `.celebrating` / `.happyBounce` / `.excited`. Triggered by the existing `triggerConfetti()` flow with a new `confettiTriggerID` so SwiftUI re-creates the burst on every fire.
- **Heart-shape eyes for `.loveEyes`.** Pupils tinted bright red (`#F22634`) during the love state via a runtime `setPupilColor(_:)` swap. Restores to black via `cancelAllAnimations()`.
- **Far-cursor iris re-centre.** When the cursor has been stationary for >5s, pupils drift back to their base position over 0.40s. Polled from `applyProps()` (RealityView's update tick) so it works even when the mouse isn't moving.
- **Twirl Y-bob + eye-close mid-spin.** Body subtly lifts (+0.04) on odd quarter-turns, dips (-0.02) on even — breaks up the rigid-pole-spin look. Eyes close at quarter 2 (apex) and snap open at the start of quarter 3 — reads as "Claud-y bracing for the spin".
- **Demo Mode voice scene.** New 4s scene 4b inserted between Local LLM and Pomodoro: shows "Talk to me — voice mode 🎙" with Claud-y in the listening pose. Scene 6 BrainRot trimmed from 6.5s → 4.5s to make room.
- **Settings search bar.** Live filter at the top of Settings — type "voice", "ollama", "pomodoro", etc. and only matching sections render. Each section has a keyword vocabulary so the search is robust.
- **Help search bar + replay-V4-demo button.** Search filters help rows by title or body match (case-insensitive). The "Replay V4 demo" button right next to the search field triggers the demo from inside Help.
- **Status-bar voice indicator.** When voice mode is active, the menu bar drop-down shows "🎙 Voice mode active" with a waveform icon between the Mode header and the Switchers section. Refreshed each time the menu opens.
- **Pupil halo removed.** The 1.05× iris halo from the previous polish round was creating a "double-pupil" visual artifact at common viewing angles. Removed entirely — single pupil with the catchlight is cleaner.

### Polish pass (final, pre-release)
- **Eyes ↔ 2D parity.** Catchlight moved to upper-RIGHT (Pixar / 2D convention) and bumped from 0.13× → 0.18× eye radius. Added a SECOND smaller "moisture" dot in the lower-left for that classic doll-eye wet feel.
- **Pupil depth.** Pupil is now two stacked unlit spheres — pure-black core + slightly-lighter dark-brown halo at 1.05× — gives subtle iris-like depth without changing silhouette.
- **Body material.** Clearcoat lowered (0.35 → 0.25), roughness raised (0.42 → 0.48). Reads as painted clay, not plastic.
- **Lighting refined.** Key 1900, fill 850 (warmer), rim BUMPED to 1100 (cool blue silhouette glow — single biggest contributor to the 2D-style outline feel), bounce warmer + brighter (220 → 280).
- **Mouth.** Switched to PhysicallyBasedMaterial with a slight clearcoat for moisture. Deeper warm red so it reads as an interior, not just a flat painted line.
- **Idle breathe staggered.** Arms cycle at 2.2s, legs offset by 0.85s on a slower 2.6s cycle. Body no longer feels mechanical. Leg amp halved (0.06 → 0.03) so the weight shift is gentle, not a march.
- **8 idle micro-behaviors** (was 4). Added: look-around (eye-sweep), sigh (Y compress), glance + smirk, double blink. Picked at random every 8-12s during idle.
- **Surprise eye-widen.** `.surprised`/`.alert`/`.nervous`/`.hiccup` now scale eyes 1.0 → 1.18 → 1.0 over 0.32s on top of the body jolt.
- **Right-click menu reorganised** into clear visual groups: Primary actions (Chat, Talk to Claud-y) → Appearance (2D/3D, Accessory, Size) → Behaviour (Personality, Mode) → AI (Cloud API, Local LLM) → Tamagotchi → Tools → Settings/Help → Quit. Consistent SF Symbol icons across every entry.
- **Voice overlay live transcript.** While listening, the panel shows what Claud-y is hearing live in italic — confirms the mic is actually picking up your voice (was the source of "is this even working?").
- **Mouse-tracking timestamp** captured for the upcoming "give up after 5s idle" iris re-centre.

### Final polish round
- **TTS-driven mouth lip-sync everywhere.** New `pulseMouth()` method in Claudy3DView subscribes to `.claudyVoiceMouthPulse` (fired on every TTS word boundary). Mouth briefly opens then closes per word, regardless of whether speech was triggered by voice mode, auto-speak replies, or a manual call.
- **Glossier surface.** PBR roughness 0.55 → 0.42, specular 0.55 → 0.75, clearcoat 0.18 → 0.35. Body now reads as glazed clay / Pixar toy, not flat matte.
- **Voice mode actually works end-to-end.** Tap mic in overlay → `VoiceModeManager.startListeningSession()` opens the AVAudioEngine + SFSpeechRecognizer pipeline → tap again → `stopListeningAndSubmit()` posts the transcript via `.claudyVoiceTranscriptReady` → CharacterRootView routes it through chat → AI replies (cloud or local) → on streaming complete, `VoiceManager.shared.speak(reply)` plays TTS with lip-sync. Works on both Cloud API and Local LLM providers.
- **State machine fix** — when no mic / no TTS / no AI in flight, voice mode shows "Listening" (inviting next tap), not "Thinking" (looked frozen).
- **Twirl re-animated.** Four 90° steps (predictable quaternion path, no over-the-top swing), arms locked at T-pose throughout (1.4 rad clamp lifted to 1.6), legs hard-snapped to rest. Slow 2.5s total — reads as deliberate "whoa".
- **Demo Mode** opens with 2D Claud-y already wearing cinema 3D glasses (no jarring 3D→2D→3D flash before the matrix glitch).
- **Hat geometry** tuned to fit the tight viewport — pork-pie crown short and sunk into the head silhouette so the brim and crown both stay visible. Heisenberg hat is BLACK (Walter White canon).
- **Cap geometry** rebuilt — half-dome on top, baseball-cap brim attached at the brow line (not inside the dome), gentle downward tilt for proper visor curve, brim extends past the front face.
- **Glasses** — switched lenses from boxes (square) to cylinder discs (true round). Lens depth fully separated from frame depth (no z-fighting shimmer). Tint dropped to 0.40 alpha so eyes/pupils show clearly through.
- **Iris pitch direction fixed** — was inverted (mouse-up was making pupils look down). Amplitudes increased so vertical tracking is clearly visible. Throttle gate tightened so small mouse motions still register.

### Polish round (post-initial-V4)
- **PBR materials.** Replaced SimpleMaterial with PhysicallyBasedMaterial for body and limbs — adds a subtle clearcoat layer (0.18) and tuned specular (0.55) for that "glazed clay" look. Stops 3D Claud-y from looking washed-out vs the 2D version.
- **Pixar-style pupil catchlights.** Each eye gets a tiny white sphere on the upper-left of the pupil's surface — the single biggest detail for "alive" eyes.
- **Accessory orientation FIXED.** All accessories were laid out in Y-up world coordinates but the character's anchor lives in Z-up local space, so hats sat sideways and visors floated in the middle of the head. Rewrote all accessory factories to use Z-up consistently. Hats now sit on top of the head, glasses on the face, temple arms pointing back along Y.
- **Right-click menu split.** "Cloud API" and "Local LLM" are now SEPARATE menu sections (was one combined "AI Provider" submenu). "Talk to Claud-y…" promoted to a top-level menu item — the preferred entry to voice mode.
- **Floating voice overlay.** New `VoiceOverlayController` + `VoiceOverlayPanel.swift` — a compact docked floating panel that sits directly BELOW Claud-y when voice mode is active. Pulsing mic button, animated waveform bars, status caption. Replaces the old full-sheet voice UI.
- **Listening / speaking poses for the character.** When voice mode enters listening state, Claud-y switches to `.alert` (wide focused eyes); when speaking, `.talking` (mouth animates per TTS word boundary). Driven by a new `claudyVoiceStateChanged` notification.
- **Real lip-sync.** `VoiceModeManager.mouthPulse` now driven by `AVSpeechSynthesizer`'s `willSpeakRangeOfSpeechString` word-boundary callback (peak then exponential decay over ~180ms). Replaces the previous sine-wave approximation.
- **3D upgrades for backflip, breakdance, loveEyes.** All three previously fell back to body-only animations. Now: backflip is a real 360° forward flip around world X with arm/leg tuck; breakdance is a continuous Y-axis spin with alternating limb flares; loveEyes is a smitten sway with arms-presented pose.
- **Matrix glitch overlay** (`MatrixGlitchOverlay.swift`). Procedural SwiftUI: green character columns scrolling, scan lines, chromatic aberration pulses. Used during the V4 demo's 2D→3D transition. No textures, no Metal shaders, ~80 lines.
- **Demo Mode V4 refresh.** New scene 2 actually does the 2D→matrix-glitch→3D→whoaTwirl sequence the V4 narrative was always supposed to have. `overlaysSuppressed` flag set during demo so chat panels / settings sheets can't interrupt.
- **In-app Help v4.0 section** added describing all the above for users.

### Highlights
- **3D character (Claudy3DView).** Pre-segmented USDZ rendered via RealityKit. 8 USDZ parts auto-coloured (terra-cotta body `#9f4124`, darker limbs `#791c16`), procedural pupils placed via deferred-tick camera-forward axis discovery, mouth animated via per-shape transform morphing.
- **Soft 4-light studio rig** (key + fill + rim + floor bounce) tuned to match the 2D character's lit/shadow ratio.
- **Mouse tracking — same-screen + multi-screen.** Adds local NSEvent monitor in addition to global, picks the screen the cursor is actually on via `NSScreen.screens.first(where: contains)` not `NSScreen.main`. Throttled (delta gate) to keep CPU low.
- **Iris tracking via deferred-axis discovery.** Pupil sphere is biased 25% toward the face midline so the gaze reads as natural rather than wall-eyed. Pupils use UnlitMaterial — no specular halo, no white-ring artifact.
- **Accessory system in 3D.** New `ClaudyAccessory3D` factory builds procedural geometry for all 7 accessories. The `cinema3DGlasses` accessory is now CLASSIC RECTANGULAR (white cardboard frame, cyan + red anaglyph lenses, temple arms). All 2D accessories ship in 3D too — full parity.
- **Whoa twirl animation (`.whoaTwirl`).** Plants feet, raises arms in Y, rotates body 360° around world Y over 1.4s, opens mouth wide. Used as the centrepiece of the V4 demo and available as a triggerable state.
- **Idle micro-behaviours.** Every 8-12s during `.idle` Claud-y picks one of: head shake, small jump, arm stretch, slow nod. Makes the character feel alive without being noisy.
- **LimbRig system.** Math-based pivot rotation for arms/legs (no `setParent(preservingWorldTransform:)` drift). Idle breathes both arms AND legs (visible weight-shift). Walking syncs leg/arm swing in opposite phase. Exercising / celebrating / dancing have their own multi-limb dispatchers.
- **Mouth = single-line dark orange.** Replaces the chocolate-brown mouth that read as a separate object. Now matches the body palette.
- **VoiceModeManager.** New singleton coordinates voice exchange UX:
  - States: off / listening / thinking / speaking
  - Mouth-pulse stub (sine-wave approximation; will upgrade to mic-amplitude tap when AVAudioEngine metering is wired)
  - Push-to-talk hotkey (default ⌘⇧V, configurable)
  - Local-only privacy toggle (`VoiceModeLocalOnly`)
- **Demo Mode V4** rebuilt with overlay-suppression flag (`overlaysSuppressed`) so chat panels, settings sheets, and ambient bubbles do NOT interrupt the demo. Companion Remotion script (`claudy_v4_demo.script.md`) is shipped as production-ready.
- **Menu refactor.** Three-axis status header at the top: AI · Personality · Mode. Removes the previous confusion between "API mode" and "Companion mode" — they are independent axes now clearly labelled.

### Visual fidelity
- Body colour deepened from washed-out terracotta to richer `#9f4124` matching 2D.
- Limb colour (`#791c16`) matches 2D `#A84020` palette for proper two-tone read.
- Material roughness raised to 0.80 so the character reads as matte clay, not plastic.
- Lighting intensities lowered (key 1100, fill 750, rim 380, bounce 180) for studio-soft gradient shadows.

### Performance
- Mouse tracking + iris tracking throttled with delta gates (no per-frame `move()` queueing).
- Pupil meshes generated once at startup, never replaced after axis discovery.
- Limb angles clamped to ±0.9 rad so arms/legs can never swing far enough to visually detach from the body.
- 60fps stable on M-series Macs with full 4-light rig.

### Honest limitations
- VoiceModeManager mouth pulse is a sine approximation — actual mic-amplitude tap requires AVAudioEngine metering hookup which is in the next release.
- 3D backflip / breakdance / loveEyes are still using their previous body-only animations — full 3D upgrades are deferred.
- Demo Mode V4 timing matches the Remotion script but the in-app version doesn't yet pre-flight the matrix-glitch shader (uses a simplified white-flash transition instead).

### Files added
- `Claudy/Claudy/ClaudyAccessory3D.swift` — accessory factory
- `Claudy/Claudy/VoiceModeManager.swift` — voice mode coordinator
- `RENDERER_PARITY.md` — 2D vs 3D feature audit
- `claudy_v4_demo.script.md` — Remotion video script
- `MICO_RESEARCH.md` — voice-assistant design research

### Files materially changed
- `Claudy/Claudy/Claudy3DView.swift` — accessories wired, whoa twirl, idle micros, axis discovery, multi-screen tracking, throttling, lighting + colour tuning
- `Claudy/Claudy/CharacterAnimationState.swift` — `.whoaTwirl` state added
- `Claudy/Claudy/AppDelegate.swift` — three-axis menu header, refresh on open
- `Claudy/Claudy/DemoModeManager.swift` — `overlaysSuppressed` flag

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
