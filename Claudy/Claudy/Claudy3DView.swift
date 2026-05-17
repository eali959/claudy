import SwiftUI
import RealityKit
import AppKit
import OSLog

// MARK: - ClaudyRealityView
//
// Renders the 3-D Claudy character using a pre-segmented USDZ model
// (Claudy_3D_Seg_Str_UV.usdz).  The model contains 8 named mesh parts:
//
//   tripo_part_4  → Body     (largest mesh, ~35 K polys)
//   tripo_part_0  → Arm L    (nub capsule, character's left side)
//   tripo_part_7  → Arm R    (nub capsule, character's right side)
//   tripo_part_2  → Leg L    (stubby cylinder, character's left)
//   tripo_part_5  → Leg R    (stubby cylinder, character's right)
//   tripo_part_1  → Eye L    (near-sphere sclera)
//   tripo_part_6  → Eye R    (near-sphere sclera)
//   tripo_part_3  → Mouth    (narrow curved mesh)
//
// All materials in the USDZ are placeholder grey; we replace them with
// correct colours via applyMaterial() after loading.  A single procedural
// dark-sphere pupil is added on top of each eye sclera.
//
// Scene graph (after finaliseAfterAdd):
//
//   root  (never moved — anchor for camera + lights)
//   ├── PerspectiveCamera  @ (0, 0, 5.0), FOV 50°
//   ├── keyLight / fillLight / rimLight  (DirectionalLightComponent)
//   └── rig  (receives mouse-tracking rotation — translation always preserved)
//       └── animRoot  ← torsoLoaded — body-animation target (identity at rest)
//           └── loaded  (USDZ root — carries fit-scale & recentre offset)
//               └── ParentNode
//                   ├── tripo_part_4  (body mesh)
//                   ├── shoulderL pivot → tripo_part_0  (arm L)
//                   ├── shoulderR pivot → tripo_part_7  (arm R)
//                   ├── hipL      pivot → tripo_part_2  (leg L)
//                   ├── hipR      pivot → tripo_part_5  (leg R)
//                   ├── tripo_part_1  (eye L sclera + procedural pupil)
//                   ├── tripo_part_6  (eye R sclera + procedural pupil)
//                   └── tripo_part_3  (mouth — untouched, left as USDZ geometry)
//
// Threading: all entity mutations are @MainActor.  RealityKit's update:
// closure is main-actor isolated.  No render-thread callbacks anywhere.

private let logger = Logger(subsystem: "com.claudy", category: "ClaudyRealityView")

// MARK: - LimbRig
//
// Math-based pivot rotation for arms/legs.  Avoids the
// `setParent(preservingWorldTransform: true)` drift bug by computing
// limb pose explicitly: rotate the limb's offset-from-pivot vector
// around the pivot, then apply rotation to the rest pose.
//
//     newPos = pivot + R(angle, axis) * (restPos - pivot)
//     newRot = R(angle, axis) * restRot
//
// All vectors are in the limb's PARENT-LOCAL space (same frame as
// `entity.position`), so no world-transform inversion is needed.
struct LimbRig {
    let entity:  Entity
    let restPos: SIMD3<Float>
    let restRot: simd_quatf
    let pivot:   SIMD3<Float>
    let axis:    SIMD3<Float>
}

// MARK: - View

struct ClaudyRealityView: View {

    // MARK: Interface — exact prop list expected by CharacterSceneView.
    let animationState:   CharacterAnimationState
    let isBlinking:       Bool
    /// V5.3 — drag-pleasure pose.  When true, the 3D eyes are hidden and the
    /// Canvas overlay draws U-shaped arcs (◡ ◡) like 2D Claudy's `arcEyeUp`
    /// happy-closed eyes.  Separate from isBlinking so the brief auto-blink
    /// can keep using the eye-flatten path while drag uses the arc overlay.
    let isHeldClosedEyes: Bool
    let irisOffset:       CGPoint
    let tickleIntensity:  TickleIntensity
    let danceMove:        DanceMove?
    let accessory:        CharacterAccessory
    let characterScale:   Double
    let isHovered:        Bool
    let hunger:           Float
    let happiness:        Float
    let energy:           Float
    let isTyping:         Bool
    let isSpeaking:       Bool
    let focusMode:        BehaviorMode
    let weatherCondition: WeatherCondition
    let spotifyPlaying:   Bool
    let spotifyGenre:     SpotifyGenre
    let pomodoroState:    PomodoroState
    var onTap:            (() -> Void)?
    var onDoubleTap:      (() -> Void)?

    // MARK: Internal state

    /// Scene root — holds camera + lights.  Never moved.
    @State private var characterRoot:    Entity? = nil
    /// Mouse-tracking rotation target.  Only rotation is written; translation
    /// is always preserved (see applyMouseTracking).
    @State private var characterRig:     Entity? = nil
    /// Top-level USDZ entity (child of rig).  Holds the fit-scale and
    /// recentre offset set in finaliseAfterAdd — do not animate directly.
    @State private var usdzRoot:         Entity? = nil
    /// Body-animation target (animRoot).  Sits between rig and usdzRoot at
    /// identity transform so returnToIdle() can safely reset it to Transform()
    /// without undoing the fit-scale applied to usdzRoot.
    /// All existing animation methods (sway, breathe, bob, celebrate, etc.)
    /// target this entity via `guard let body = torsoLoaded`.
    @State private var torsoLoaded:      Entity? = nil

    // Limb rigs — math-based pivot rotation (no setParent) — see LimbRig
    // struct + setLimbAngle() in the private extension.  Each rig stores
    // rest pose + pivot point + axis in `loaded`-local space, and the
    // animation methods rotate the limb position around the pivot vector.
    @State private var armRigL:          LimbRig? = nil
    @State private var armRigR:          LimbRig? = nil
    @State private var legRigL:          LimbRig? = nil
    @State private var legRigR:          LimbRig? = nil

    // Eye roots — original USDZ eye entities. Handle iris tracking ROTATION only.
    @State private var eyeRootL:         Entity? = nil
    @State private var eyeRootR:         Entity? = nil
    // V5.2 — Blink-scale wrappers inserted between original parent and eyeRootL/R.
    // Handle blink + eye-widen SCALE only. Separating rotation (eyeRootL/R) from
    // scale (eyeBlinkScalerL/R) onto different entities means each move(to:) call
    // targets a different entity → they never cancel each other mid-animation.
    @State private var eyeBlinkScalerL:  Entity? = nil
    @State private var eyeBlinkScalerR:  Entity? = nil
    // V5.12 — Per-eye REST scale.  Left eye is intentionally larger than the right
    // (Pixar-style doe-eyed asymmetry).  applyBlink and performEyeWiden both
    // reference these instead of overwriting absolutely, so the asymmetry
    // survives blink + widen + return-to-rest cycles.
    // Ratio 1.174 = eyeSizeLarge(27) / eyeSizeSmall(23) — matches 2D exactly.
    // Previously 1.06 (6%) which was barely perceptible; 1.174 (17%) reads clearly.
    @State private var eyeRestScaleL: Float = 1.174
    @State private var eyeRestScaleR: Float = 1.00
    @State private var pupilL:           ModelEntity? = nil
    @State private var pupilR:           ModelEntity? = nil
    // V5.12 — Safe iris tracking via TRANSLATION (not rotation).
    // The pupil entity moves a tiny clamped distance from its rest position
    // based on cursor location.  Translation is impossible to get wrong:
    // no quaternion math, no axis confusion, no chance of wall-eyed pupils.
    // Both eyes use the SAME offset so they always look in the same direction.
    @State private var pupilRestL:        SIMD3<Float> = .zero
    @State private var pupilRestR:        SIMD3<Float> = .zero
    @State private var pupilTrackOffset:  Float = 0       // max travel from rest, set after pupils added
    // Rest orientations of each eye entity — iris tracking rotates the eye
    // entity by a tiny angle so the pupil (fixed at +X in entity-local space)
    // stays locked on the sphere surface and can NEVER escape.
    @State private var eyeRestOrientL:   simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    @State private var eyeRestOrientR:   simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    @State private var eyeAxesDiscovered: Bool = false
    // Throttle — avoids queuing a move() every frame.
    @State private var lastRigNX:        Float = 9999
    @State private var lastRigNY:        Float = 9999
    @State private var lastTrackNX:      Float = 9999
    @State private var lastTrackNY:      Float = 9999
    // Accessory entity — anchored to the face anchor on `loaded`.
    // Recreated each time the `accessory` prop changes.
    @State private var accessoryEntity:  Entity? = nil
    @State private var accessoryAnchor:  Entity? = nil
    @State private var headRadiusFloat:  Float   = 0.5
    @State private var currentAccessory: CharacterAccessory = .none

    // Mouth — mouthRoot points at the USDZ mouth entity (tripo_part_3).
    // setMouthShape() applies scale/rotation deltas off mouthRest to morph
    // the existing sculpted mesh between shapes (no mesh replacement).
    @State private var mouthRoot:        Entity? = nil
    @State private var mouthMesh:        ModelEntity? = nil
    @State private var mouthRest:        Transform = Transform()
    @State private var currentMouthShape: AnimationConfig.MouthShape = .default
    /// In-flight close-task for pulseMouth — cancelled before re-firing so
    /// rapid back-to-back word boundaries don't stack competing animations.
    // V5.2 — mouthPulseCloseTask removed; lip-sync is now phoneme-driven via
    // lipSyncTask, and pulseMouth() just bumps mouth2DOpenAmount as a TTS accent.

    // ── 2D mouth overlay state ────────────────────────────────────────────
    // The USDZ mouth mesh (tripo_part_3) is hidden at load time.
    // A SwiftUI Canvas overlay draws a bezier arc that springs between
    // expressions.  All values are in the panel's own point space (150×150pt).
    @State private var mouth2DW:    CGFloat = 16    // arc width
    @State private var mouth2DC:    CGFloat = 5.5   // curve height (>0 smile, <0 frown)
    @State private var mouth2DGap:  CGFloat = 0     // vertical open-gap (0 = closed arc)
    @State private var mouth2DLW:   CGFloat = 2.0   // stroke width
    @State private var mouth2DOffX: CGFloat = 0     // expression offset (smirk etc.)
    /// Projected canvas Y — set ONCE in finaliseAfterAdd from the mouth mesh's
    /// resting world position.  Body sway is small enough (±7°) that the mouth
    /// appears stable at the static projection.
    @State private var mouth2DY:    CGFloat = 83    // fallback: 83 pt from top of panel
    // V5.2 — Lip-sync open amount (0…1).  Drives BOTH width and height of the
    // open-mouth ellipse during .talkingSync state.  Cycled through a 16-step
    // phoneme weight pattern at 90ms intervals — identical to 2D Claudy.
    @State private var mouth2DOpenAmount: CGFloat = 0
    @State private var lipSyncTask: Task<Void, Never>? = nil
    // V5.3 — Mouth Canvas opacity.  Faded to 0 explicitly during full-body
    // rotations (whoaTwirl, backflip, breakdance) so the screen-space mouth
    // overlay doesn't appear floating in front of a sideways/back-facing body.
    @State private var mouth2DOpacity: CGFloat = 1.0
    // V5.3 — Projected screen positions of the left/right eye centres,
    // computed once in finaliseAfterAdd from each eyeBlinkScalerL/R world
    // position.  Used by the U-arc overlay drawn during isHeldClosedEyes.
    @State private var eyeLProjX:  CGFloat = 60   // fallback approx
    @State private var eyeRProjX:  CGFloat = 90
    @State private var eyeProjY:   CGFloat = 62

    // Async-load gate.
    @State private var isLoaded:         Bool = false

    // Mouse tracking → rig yaw/pitch + iris offset.
    @State private var mouseNormX:       Float = 0
    @State private var mouseNormY:       Float = 0
    @State private var mouseMonitor:     Any? = nil   // global (cursor outside our window)
    @State private var mouseMonitorLocal: Any? = nil  // local (cursor over our floating panel)
    /// V4 polish — wall-clock of last cursor movement.  When the cursor
    /// has been stationary for >5s, the iris re-centres and Claud-y
    /// blinks once (looks like he gave up tracking).
    @State private var lastMouseMoveAt:  TimeInterval = 0

    // Animation tasks (cancelled on state change).
    @State private var bodyTask:         Task<Void, Never>? = nil
    @State private var breatheTask:      Task<Void, Never>? = nil   // idle micro-behaviors
    @State private var limbTask:         Task<Void, Never>? = nil   // arms idle breathe
    @State private var legBreatheTask:   Task<Void, Never>? = nil   // legs idle breathe (offset cycle)
    /// V4 FINAL — always-on ambient life: tiny breathing, eye saccades,
    /// mouth micro-shifts.  Runs for the entire app lifetime.
    @State private var ambientLifeTask:  Task<Void, Never>? = nil
    /// V4 FINAL — voice-mode listening breathe (separate from ambient so
    /// it can ride on top with a slightly bigger amplitude).
    @State private var voiceBreatheTask: Task<Void, Never>? = nil
    @State private var blinkTask:        Task<Void, Never>? = nil
    @State private var currentState:     CharacterAnimationState = .idle

    // MARK: Body

    var body: some View {
        ZStack {
            RealityView { content in
                if let root = await loadCharacter() {
                    content.add(root)
                    finaliseAfterAdd()
                }
            } update: { _ in
                guard isLoaded else { return }
                applyProps()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── 2D mouth overlay ──────────────────────────────────────────
            // Mirrors the 2D ClaudyCharacterView approach: thin stroked arcs
            // only — NO filled shapes (they read as dark voids against orange).
            // The USDZ mouth mesh is hidden at load time.
            // cy calibrated to the 3D face position in the 150×150 pt panel.
            Canvas { ctx, size in
                let cx  = size.width  * 0.5 + mouth2DOffX
                let cy  = mouth2DY
                let w   = mouth2DW
                let c   = mouth2DC
                let gap = mouth2DGap
                let lw    = mouth2DLW
                // Deep warm-brown — matches the body's painted-clay palette
                let ink   = Color(red: 0.22, green: 0.07, blue: 0.04)
                // Warm halo tint — tight bloom, low opacity so it reads as
                // soft shadow-press rather than spray paint
                let halo  = Color(red: 0.35, green: 0.10, blue: 0.04)

                if gap <= 0 {
                    // Closed expression — cubic bezier for natural smile shape.
                    // Two control points near the endpoints give tight corners
                    // (real mouth silhouette) vs addQuadCurve's rubber-band parabola
                    // that looked like a sharpie arc at bigSmile / hugeSmile sizes.
                    // SwiftUI Y-down: control BELOW (cy + c) = smile ∪.
                    let startP = CGPoint(x: cx - w * 0.5, y: cy)
                    let endP   = CGPoint(x: cx + w * 0.5, y: cy)
                    let ctrl1  = CGPoint(x: cx - w * 0.30, y: cy + c * 0.90)
                    let ctrl2  = CGPoint(x: cx + w * 0.30, y: cy + c * 0.90)
                    var path = Path()
                    path.move(to: startP)
                    path.addCurve(to: endP, control1: ctrl1, control2: ctrl2)
                    // 3-pass rendering — tight halos, not wide spray-paint:
                    // 1) Narrow outer shadow (depth cue only, barely visible)
                    ctx.stroke(path, with: .color(halo.opacity(0.07)),
                               style: StrokeStyle(lineWidth: lw * 2.4, lineCap: .round))
                    // 2) Soft inner press — gives the "painted into clay" feel
                    ctx.stroke(path, with: .color(halo.opacity(0.20)),
                               style: StrokeStyle(lineWidth: lw * 1.5, lineCap: .round))
                    // 3) Crisp main line — organic, no sharpie edge
                    ctx.stroke(path, with: .color(ink),
                               style: StrokeStyle(lineWidth: lw, lineCap: .round))
                } else if currentMouthShape == .talkingSync {
                    // Phoneme-driven lip-sync: filled oval with halo behind.
                    //   width  = 11 + amount * 6     (11…17 pt)
                    //   height = 2  + amount * 10    (2…12 pt)
                    let lipW = 11 + mouth2DOpenAmount * 6
                    let lipH = 2  + mouth2DOpenAmount * 10
                    let mainRect = CGRect(x: cx - lipW * 0.5, y: cy - lipH * 0.5,
                                          width: lipW, height: lipH)
                    let haloRect = mainRect.insetBy(dx: -1.5, dy: -1.5)
                    ctx.fill(Path(ellipseIn: haloRect), with: .color(halo.opacity(0.45)))
                    ctx.fill(Path(ellipseIn: mainRect), with: .color(ink))
                } else {
                    // Static open expressions (.tinyOpen, .mediumOpen, .wideOpen,
                    // .chewing) — fixed filled oval with halo.
                    let mainRect = CGRect(x: cx - w * 0.5, y: cy - gap, width: w, height: gap * 2)
                    let haloRect = mainRect.insetBy(dx: -1.5, dy: -1.5)
                    ctx.fill(Path(ellipseIn: haloRect), with: .color(halo.opacity(0.45)))
                    ctx.fill(Path(ellipseIn: mainRect), with: .color(ink))
                }
            }
            // V5.2 — 70ms easeInOut between phoneme frames.  Matches 2D's
            // .animation(.easeInOut(duration: 0.07), value: mouthOpenAmount)
            // smoothing so the lip-sync feels organic, not strobe-y.
            .animation(.easeInOut(duration: 0.07), value: mouth2DOpenAmount)
            // V5.3 — Hide the screen-space mouth overlay when the body is
            // rotating away from the camera (whoaTwirl, backflip, breakdance).
            // Without this, the mouth appears to float detached from a
            // sideways body — exactly the "mouth stays where it is" bug
            // reported in V4 demo mode.
            .opacity(mouth2DOpacity)
            .animation(.easeInOut(duration: 0.18), value: mouth2DOpacity)
            .allowsHitTesting(false)

            // V5.3 — U-arc closed-eye overlay.  Drawn ONLY during the
            // drag-pleasure pose (isHeldClosedEyes).  Mirrors 2D Claudy's
            // arcEyeUp render: a thin warm-brown quadratic curve arcing
            // upward like ◡, giving the same "closed eyes in pleasure"
            // look as 2D when being petted.  When this overlay is showing,
            // the 3D eye spheres are hidden via .isEnabled in onChange so
            // they don't bleed through.
            Canvas { ctx, size in
                guard isHeldClosedEyes else { return }
                let ink = Color(red: 0.22, green: 0.07, blue: 0.04)
                let arcW: CGFloat = 16
                let arcH: CGFloat = 11
                // Two arcs: ◡ ◡ — endpoints on top, control point ABOVE
                // them (cy - arcH * 0.9) which in SwiftUI Y-down means the
                // arc bulges UPWARD = U-shape.  Identical curvature to 2D's
                // arcEyeUp Path (move (0,9) → quad to (16,9) ctrl (8,-1)).
                for cx in [eyeLProjX, eyeRProjX] {
                    var path = Path()
                    let y0 = eyeProjY + arcH * 0.5
                    path.move(to: CGPoint(x: cx - arcW * 0.5, y: y0))
                    path.addQuadCurve(
                        to:      CGPoint(x: cx + arcW * 0.5, y: y0),
                        control: CGPoint(x: cx, y: y0 - arcH)   // control ABOVE = arc up
                    )
                    ctx.stroke(path, with: .color(ink),
                               style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
            }
            .opacity(isHeldClosedEyes ? 1 : 0)
            .animation(.easeInOut(duration: 0.10), value: isHeldClosedEyes)
            .allowsHitTesting(false)

            ClickableRealityShim(onTap: onTap, onDoubleTap: onDoubleTap)
        }
        .onAppear  { startMouseTracking() }
        .onDisappear {
            stopMouseTracking()
            cancelAllAnimations()
        }
        .onChange(of: animationState) { _, newState in
            guard isLoaded, newState != currentState else { return }
            currentState = newState
            handleStateChange(newState)
        }
        .onChange(of: isBlinking) { _, blinking in
            guard isLoaded else { return }
            applyBlink(blinking)
        }
        .onChange(of: isHeldClosedEyes) { _, held in
            guard isLoaded else { return }
            if held {
                // Drag started — hide eye spheres immediately so the sclera
                // disc doesn't bleed through the arc overlay.
                eyeBlinkScalerL?.isEnabled = false
                eyeBlinkScalerR?.isEnabled = false
            } else {
                // Drag ended — wait for the arc overlay's 0.10s fade-out to
                // finish before re-enabling the 3D spheres; otherwise the
                // sclera pops visible through the still-fading arc.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.12))
                    guard !isHeldClosedEyes else { return }
                    eyeBlinkScalerL?.isEnabled = true
                    eyeBlinkScalerR?.isEnabled = true
                }
            }
        }
        .onChange(of: mouseNormX) { _, _ in
            guard isLoaded else { return }
            applyMouseTracking()
        }
        .onChange(of: mouseNormY) { _, _ in
            guard isLoaded else { return }
            applyMouseTracking()
        }
        .onChange(of: accessory) { _, newAcc in
            guard isLoaded else { return }
            updateAccessory(newAcc)
        }
        .onReceive(NotificationCenter.default.publisher(for: .claudyVoiceMouthPulse)) { _ in
            // V4.0 — TTS word boundary → pulse the mouth open/closed for
            // visible lip-sync.  Fires during ANY TTS speech (auto-speak
            // replies, manual speak, voice mode).
            guard isLoaded else { return }
            pulseMouth()
        }
    }
}

// MARK: - Scene loading

private extension ClaudyRealityView {

    // ── Materials ─────────────────────────────────────────────────────────────
    // All USDZ parts ship with a placeholder grey (0.8, 0.8, 0.8) material.
    // These replace them via the recursive applyMaterial() helper.

    // ── Body palette — matched to 2D ClaudyCharacterView ─────────────────────
    //   2D body  = #C85C38  (0.784, 0.361, 0.220)
    //   2D limb  = #A84020  (0.659, 0.251, 0.125)
    //   2D shadow = #9A3520 (0.604, 0.208, 0.125)
    // 3D needs slightly higher roughness so the lit side reads at the 2D
    // body colour and the lit-shadow falls into the limb tone naturally.
    // ── PBR PALETTE ─────────────────────────────────────────────────────
    // PhysicallyBasedMaterial gives finer control: roughness (microsurface),
    // specular (highlight intensity), clearcoat (subtle top layer for shine).
    // Tuned to read like glazed clay — matte body with subtle sheen, not
    // plastic-shiny.  This is what gives the 3D character the "lively" feel
    // the 2D version naturally has.
    // V4.0 — slight gloss boost so Claudy reads as glazed clay / Pixar-toy
    // surface, not flat matte.  Lower roughness, stronger clearcoat layer,
    // higher specular reflectance.  Without this he looked dead vs the 2D
    // version's painterly highlights.
    // V4 colour parity — baseColor matched to the 2D character palette exactly:
    //   bodyColor  #C85C38 → (0.784, 0.361, 0.220)  — the primary terra-cotta orange
    //   limbColor  #A84020 → (0.659, 0.251, 0.125)  — deeper tone for arms/legs
    // PBR settings kept mild (roughness ~0.48, low metallic) so the body reads as
    // painted clay rather than plastic; clearcoat adds a subtle sheen highlight.
    static var orangeMat: PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        // V5.3 — RICHER, deeper terra-cotta.  Pushed saturation past 2D's flat
        // sRGB match (0.784, 0.361, 0.220) because PBR lighting always lifts
        // the apparent value — starting deeper means it lands at-2D after
        // light interaction.  Specular + clearcoat dropped further so the
        // body reads as painted ceramic, not glossy plastic.  Net result:
        // a deep, premium burnt-orange with subtle sheen, not a washed salmon.
        m.baseColor = .init(tint: NSColor(calibratedRed: 0.795, green: 0.310, blue: 0.155, alpha: 1.0))
        m.roughness = .init(floatLiteral: 0.62)        // matte-ier — kills plastic glare
        m.metallic  = .init(floatLiteral: 0.0)
        m.specular  = .init(floatLiteral: 0.28)        // was 0.45 — softer highlight
        m.clearcoat = .init(floatLiteral: 0.05)        // was 0.10 — barely-there gloss
        m.clearcoatRoughness = .init(floatLiteral: 0.55)
        return m
    }
    static var darkOrangeMat: PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        // V5.3 — Limbs deeper still.  2D limb is #A84020 (0.659, 0.251, 0.125).
        // Push baseColor below that so PBR lighting brings it back UP to match.
        m.baseColor = .init(tint: NSColor(calibratedRed: 0.560, green: 0.190, blue: 0.085, alpha: 1.0))
        m.roughness = .init(floatLiteral: 0.66)
        m.metallic  = .init(floatLiteral: 0.0)
        m.specular  = .init(floatLiteral: 0.25)
        m.clearcoat = .init(floatLiteral: 0.04)
        m.clearcoatRoughness = .init(floatLiteral: 0.55)
        return m
    }
    static var eyeWhiteMat: SimpleMaterial {
        SimpleMaterial(
            color: NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.95, alpha: 1.0),
            roughness: 0.35,
            isMetallic: false
        )
    }
    static var pupilMat: SimpleMaterial {
        // Shiny pure black — low roughness gives a crisp specular highlight
        // without the soft halo that the previous near-black colour created.
        SimpleMaterial(
            color: NSColor(calibratedRed: 0.02, green: 0.02, blue: 0.03, alpha: 1.0),
            roughness: 0.10,
            isMetallic: false
        )
    }
    // V4 polish — mouth reads as a deep warm interior with subtle gloss.
    // Slightly warmer red than the body, lower roughness for the wet-mouth
    // sheen, no metallic.  Adds a painterly "interior" feel that the 2D
    // version achieves with stroke shading.
    static var mouthMat: PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: NSColor(calibratedRed: 0.42, green: 0.08, blue: 0.04, alpha: 1.0))
        m.roughness = .init(floatLiteral: 0.55)
        m.metallic  = .init(floatLiteral: 0.0)
        m.specular  = .init(floatLiteral: 0.50)
        m.clearcoat = .init(floatLiteral: 0.15)   // tiny glaze for moisture
        m.clearcoatRoughness = .init(floatLiteral: 0.40)
        return m
    }
    // DEBUG axis-probe materials
    static var dbgRedMat:   SimpleMaterial { SimpleMaterial(color: .systemRed,   isMetallic: false) }
    static var dbgGreenMat: SimpleMaterial { SimpleMaterial(color: .systemGreen, isMetallic: false) }
    static var dbgBlueMat:  SimpleMaterial { SimpleMaterial(color: .systemBlue,  isMetallic: false) }

    // ── loadCharacter ─────────────────────────────────────────────────────────
    // Loads the USDZ and builds the scene graph.  No scaling, no material
    // assignment, no pivot work here — all of that requires visualBounds,
    // which is only valid after content.add() runs (finaliseAfterAdd).

    @MainActor
    func loadCharacter() async -> Entity? {
        guard !isLoaded else { return nil }
        do {
            let loaded = try await Entity(named: "Claudy_3D_Seg_Str_UV", in: Bundle.main)

            // root — never moved, anchors camera + lights.
            let root = Entity()
            root.name = "claudyRoot"

            // rig — receives mouse-tracking rotation only.  Translation is
            // always preserved; see the flagged note on applyMouseTracking.
            let rig = Entity()
            rig.name = "claudyRig"
            rig.addChild(loaded)
            root.addChild(rig)

            // Explicit perspective camera.  Without this, RealityView uses an
            // opaque auto-framing camera that silently clips anything added
            // after the initial entity — the root cause of previous invisible
            // limbs/eyes issues.
            let cam = PerspectiveCamera()
            cam.name = "claudyCamera"
            cam.camera.fieldOfViewInDegrees = 58   // wider view gives hat crowns headroom
            cam.camera.near = 0.05
            cam.camera.far  = 100
            // Camera at +Z looking toward origin (RealityKit default forward = -Z).
            // Closer camera (3.0 vs 5.0) so the character fills more of the frame.
            cam.position = SIMD3<Float>(0, 0, 3.0)
            root.addChild(cam)

            // Three-point lighting attached to root (not rig) so the shading
            // remains stable as the character sways with mouse tracking.
            attachLightingRig(to: root)

            characterRoot = root
            characterRig  = rig
            usdzRoot      = loaded
            // torsoLoaded is set in finaliseAfterAdd after animRoot is inserted.
            return root

        } catch {
            logger.error("ClaudyRealityView: failed to load Claudy_3D_Seg_Str_UV.usdz — \(error)")
            return nil
        }
    }

    // ── finaliseAfterAdd ──────────────────────────────────────────────────────
    // Called synchronously after content.add(root).  visualBounds() is valid
    // here.  Executes Steps 2a–2g from the implementation plan in order.

    @MainActor
    func finaliseAfterAdd() {
        guard let rig     = characterRig,
              let loaded  = usdzRoot
        else { return }

        // ── Step 2a: Orientation detection ───────────────────────────────────
        // The USDZ was authored with Z as the up axis AND the face pointing
        // along +X (confirmed by USD inspection: eyes at x=+0.206, body at
        // x≈-0.052, face direction = +X in Z-up world space).
        //
        // RealityKit may or may not auto-apply the Z→Y-up rotation, so we
        // detect it at runtime.  Regardless, we always need a second rotation
        // to swing the face from +X to +Z (toward the camera at z=+5.0).
        //
        // Two rotations applied in sequence via quaternion multiplication:
        //   1. zToY  = -90° around X  →  converts Z-up to Y-up
        //              (old Z=up → new Y=up, old Y → -new Z)
        //   2. faceZ = -90° around Y  →  swings face from +X to +Z
        //              (old +X face → new +Z face, visible to camera)
        // Together they produce the correct Y-up, camera-facing orientation.
        let rawBounds = loaded.visualBounds(relativeTo: rig)
        if rawBounds.extents.z > rawBounds.extents.y {
            print("[Claudy3D] Z-up detected — applying manual -90° X rotation + -90° Y face-toward-camera correction")
            let zToY   = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
            let faceZ  = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(0, 1, 0))
            // faceZ * zToY: apply zToY first, then faceZ.
            loaded.orientation = faceZ * zToY
        } else {
            // Already Y-up.  Face still points +X → apply face-toward-camera
            // correction only.
            print("[Claudy3D] Orientation OK (Y-up) — applying -90° Y face-toward-camera correction")
            loaded.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(0, 1, 0))
        }

        // ── Arms: use AUTHORED position ───────────────────────────────────────
        // Empirically: 1.18× → visible gap; 0.85× → arms buried.
        // Authored 1.0× is the visually-attached sweet spot.
        // No-op intentionally retained as a code-comment landmark.

        // ── Step 2b: Scale to fit ─────────────────────────────────────────────
        // Re-measure after the orientation fix.  The bounds are in rig (world Y-up)
        // space so extents.x = arm-to-arm width, extents.y = head-to-foot height.
        let bounds = loaded.visualBounds(relativeTo: rig)
        // Fit by whichever dimension is larger so arms are NEVER clipped horizontally.
        // Without this, arms (±X in world after rotation) were wider than the height
        // target and got cut off at the sides of the square frame.
        let characterHeight = max(bounds.extents.y, 0.001)
        let characterWidth  = max(bounds.extents.x, 0.001)
        // V4.0: target size reduced from 2.5 → 2.0 so accessories (hats / cap
        // dome) have real headroom above the body inside the camera frustum.
        // Without this, anything past `body.max.z` got clipped by the FOV.
        let targetSize: Float = 2.0
        let fitScale = min(max(targetSize / max(characterHeight, characterWidth), 0.05), 20.0)
        loaded.scale    = SIMD3<Float>(repeating: fitScale)
        // Centre the scaled mesh on the rig origin.
        loaded.position = -bounds.center * fitScale
        print("[Claudy3D] fitScale=\(fitScale)  h=\(characterHeight)m  w=\(characterWidth)m  bounds=\(bounds.extents)")

        // Insert animRoot between rig and loaded so that body animations
        // (sway, breathe, bob, jolt, etc.) can safely reset to Transform()
        // without undoing loaded's fit-scale / recentre.
        loaded.removeFromParent()
        let animRoot = Entity()
        animRoot.name = "claudyAnimRoot"
        animRoot.addChild(loaded)
        rig.addChild(animRoot)
        torsoLoaded = animRoot   // all existing animation methods target this

        // ── Step 2c: Find each part by its exact USD name ─────────────────────
        // Names confirmed from `python3 -c "from pxr import Usd…"` inspection.
        // Do not rename or guess.
        guard
            let bodyXform  = loaded.findEntity(named: "tripo_part_4"),
            let armLXform  = loaded.findEntity(named: "tripo_part_0"),
            let armRXform  = loaded.findEntity(named: "tripo_part_7"),
            let legLXform  = loaded.findEntity(named: "tripo_part_2"),
            let legRXform  = loaded.findEntity(named: "tripo_part_5"),
            let eyeLXform  = loaded.findEntity(named: "tripo_part_1"),
            let eyeRXform  = loaded.findEntity(named: "tripo_part_6"),
            let mouthXform = loaded.findEntity(named: "tripo_part_3")
        else {
            logger.error("ClaudyRealityView: one or more USDZ parts not found — check entity names")
            #if DEBUG
            print("[Claudy3D] Entity tree dump (looking for tripo_part_*):")
            debugEntityTree(loaded, indent: 0)
            #endif
            return
        }
        print("[Claudy3D] All 8 parts found ✓ (body/armL/armR/legL/legR/eyeL/eyeR/mouth)")

        // Apply correct colours.  All USDZ parts have placeholder grey.
        // Body uses the lit body tone, limbs use the deeper limb tone — same
        // two-tone split as the 2D character so the 3D version reads alike.
        applyMaterial(Self.orangeMat,     to: bodyXform)
        applyMaterial(Self.darkOrangeMat, to: armLXform)
        applyMaterial(Self.darkOrangeMat, to: armRXform)
        applyMaterial(Self.darkOrangeMat, to: legLXform)
        applyMaterial(Self.darkOrangeMat, to: legRXform)
        applyMaterial(Self.eyeWhiteMat, to: eyeLXform)
        applyMaterial(Self.eyeWhiteMat, to: eyeRXform)
        applyMaterial(Self.mouthMat,    to: mouthXform)

        // ── Step 2d: Add procedural pupils on top of each eye sclera ──────────
        // The eye meshes (tripo_part_1/6) are single spheres; no pupil is
        // baked in.  addPupil() creates a small dark sphere as a child of each
        // eye entity.  The offset is computed in the eye entity's LOCAL
        // coordinate space — see addPupil(to:) comment.
        //
        // Iris tracking uses ROTATION of the eye entity (eyeRestOrientL/R
        // stored below) so the pupil always stays locked to the sphere surface.
        // No pupilBase/eyeCentre measurements needed.
        let pL = addPupil(to: eyeLXform)
        let pR = addPupil(to: eyeRXform)

        // ── V5.2: Insert blink-scale wrapper entities ──────────────────────────
        // Move each eye's local transform onto a new wrapper Entity, then reset
        // the eye's transform to identity.  Result:
        //   parent → wrapperL  (holds original transform — scale-animated)
        //              └── eyeLXform  (now identity — rotation-animated)
        //                       └── pupilL → catchlights
        // World transform is unchanged; visual is identical at rest.
        let wrapperL = Entity()
        let wrapperR = Entity()
        if let parentL = eyeLXform.parent {
            wrapperL.transform = eyeLXform.transform
            // V5.12 — Pixar-style left-eye asymmetry: scale the left blink
            // wrapper by eyeRestScaleL (1.174) so the LEFT eye is visibly larger.
            // Matches the 2D character's eyeSizeLarge(27)/eyeSizeSmall(23) = 1.174
            // ratio.  Using the state var keeps wrapper + applyBlink in sync.
            // Scale applied to the SCALER wrapper so it doesn't fight blink/widen.
            wrapperL.transform.scale = SIMD3<Float>(eyeRestScaleL, eyeRestScaleL, eyeRestScaleL)
            eyeLXform.transform = Transform()
            parentL.addChild(wrapperL)
            wrapperL.addChild(eyeLXform)   // reparents eyeLXform under wrapper
        }
        if let parentR = eyeRXform.parent {
            wrapperR.transform = eyeRXform.transform
            // Right eye stays at identity (the smaller of the two)
            eyeRXform.transform = Transform()
            parentR.addChild(wrapperR)
            wrapperR.addChild(eyeRXform)
        }
        eyeBlinkScalerL = wrapperL
        eyeBlinkScalerR = wrapperR
        eyeRootL        = eyeLXform
        eyeRootR        = eyeRXform
        pupilL          = pL
        pupilR          = pR
        // V5.12 — Capture pupil rest positions + max-tracking-offset for the
        // safe translation-based iris tracking.  pupil.position was set in
        // addPupil to (eyeRadius * 1.05, 0, 0) in eye-local space.
        // Max offset = 8 % of eye radius — visible saccade, well inside the
        // sclera silhouette (which extends to ~48 % of eye radius from
        // pupil rest in any direction).
        pupilRestL = pL.position
        pupilRestR = pR.position
        // pL.position.x was set to eyeRadius * 1.05; recover eyeRadius from it.
        let eyeRadiusEstimate = pL.position.x / 1.05
        pupilTrackOffset = eyeRadiusEstimate * 0.08
        // Rest orientation is identity (eye's local transform was reset).
        eyeRestOrientL  = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        eyeRestOrientR  = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)

        // ── DEFERRED AXIS DISCOVERY ───────────────────────────────────────────
        // Compute eye-local camera-forward / up / right by transforming
        // world axes into each eye's local frame.  Run on next main-actor
        // tick so RealityKit's transform chain is fully resolved (synchronous
        // attempts during finaliseAfterAdd returned identity directions).
        // ── Deferred: materials + catchlights ────────────────────────────────
        // Runs after one frame so the transform chain is fully resolved.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            guard let eL = eyeRootL, let eR = eyeRootR else { return }

            // Apply unlit black to pupils
            let unlit = UnlitMaterial(color: .black)
            if var mc = pL.model { mc.materials = [unlit]; pL.model = mc }
            if var mc = pR.model { mc.materials = [unlit]; pR.model = mc }

            // Pupil radius (measured before adding children to avoid bounds inflation)
            let rL = pL.visualBounds(relativeTo: pL).extents.x * 0.5
            let rR = pR.visualBounds(relativeTo: pR).extents.x * 0.5

            // Catchlights: placed in PUPIL-LOCAL space.
            // eye-local +X = camera-forward, so surfL = forward push × radius.
            // Two small dots (primary upper-right, secondary lower-left).
            // Sized at 0.28× and 0.12× pupil radius — small enough that eye
            // rotation for iris tracking never pulls them outside the sclera.
            func norm(_ v: SIMD3<Float>) -> SIMD3<Float> {
                let l = simd_length(v); return l > 1e-4 ? v / l : v
            }
            let catchMat  = UnlitMaterial(color: NSColor(white: 1.0, alpha: 1.0))
            // Camera-forward in eye-local space = +X (confirmed by addPupil axis probe)
            let fwdL = norm(eL.convert(direction: SIMD3<Float>(0, 0, 1), from: nil))
            let fwdR = norm(eR.convert(direction: SIMD3<Float>(0, 0, 1), from: nil))
            let upL  = norm(eL.convert(direction: SIMD3<Float>(0, 1, 0), from: nil))
            let upR  = norm(eR.convert(direction: SIMD3<Float>(0, 1, 0), from: nil))
            let rtL  = norm(eL.convert(direction: SIMD3<Float>(1, 0, 0), from: nil))
            let rtR  = norm(eR.convert(direction: SIMD3<Float>(1, 0, 0), from: nil))

            let cPL = ModelEntity(mesh: .generateSphere(radius: rL * 0.28), materials: [catchMat])
            let cPR = ModelEntity(mesh: .generateSphere(radius: rR * 0.28), materials: [catchMat])
            let cSL = ModelEntity(mesh: .generateSphere(radius: rL * 0.12), materials: [catchMat])
            let cSR = ModelEntity(mesh: .generateSphere(radius: rR * 0.12), materials: [catchMat])
            let bL = fwdL * (rL * 0.20)   // forward bias past pupil surface
            let bR = fwdR * (rR * 0.20)
            let surfL = fwdL * rL; let surfR = fwdR * rR
            cPL.position = surfL + bL + upL * (rL * 0.30) + rtL * (rL * 0.26)
            cPR.position = surfR + bR + upR * (rR * 0.30) + rtR * (rR * 0.26)
            cSL.position = surfL + bL + upL * (-rL * 0.28) + rtL * (-rL * 0.24)
            cSR.position = surfR + bR + upR * (-rR * 0.28) + rtR * (-rR * 0.24)
            pL.addChild(cPL); pL.addChild(cSL)
            pR.addChild(cPR); pR.addChild(cSR)

            eyeAxesDiscovered = true
        }

        // ── Step 2e: Limb rigs (math-based pivot rotation) ────────────────────
        // For each limb we capture: rest position, rest rotation, the pivot
        // point (shoulder/hip in `loaded`-local Z-up coords), and the axis
        // we want to rotate around.  setLimbAngle() then computes:
        //     newPos = pivot + R(angle, axis) * (restPos - pivot)
        //     newRot = R(angle, axis) * restRot
        // No setParent / no preservingWorldTransform — works under any
        // combination of `loaded` scale + orientation + position.
        let bodyBox = bodyXform.visualBounds(relativeTo: loaded)
        let halfY   = bodyBox.extents.y * 0.5     // sideways half-width
        let topZ    = bodyBox.max.z               // top of body (Z-up)
        let botZ    = bodyBox.min.z               // bottom of body (Z-up)

        // Arms: pivot at body's top-side (shoulder).  Rotate around X axis
        // so the arm swings in the Y-Z plane (up/down for waving / breathing).
        //
        // V5.3 — pivot moved DEEPER inside the body (halfY * 0.78 instead of
        // V4's outside-body × 1.02).  Geometric reasoning:
        //   • Arm sphere centre is at restPos = halfY * ≈1.30 from body centre.
        //   • When the arm rotates θ around a pivot at distance P from body
        //     centre, the arm centre traces an arc of radius |restPos - P|.
        //   • Pivot OUTSIDE body (P > halfY) → arm arcs AWAY from body wall
        //     → visible gap at high angles (love eyes 31°, breakdance 37°).
        //   • Pivot INSIDE body (P ≈ 0.78 * halfY) → arm arcs AROUND body
        //     wall, always slightly OVERLAPPING → no gap at any angle.
        // Small overlap is invisible (arm sphere blends into body silhouette
        // since both share the same orange material).  This is what waving and
        // breathing animations have looked correct under all the way back to
        // V4 — the only artifact was the tiny gap that 1.02 left at large
        // angles.  0.78 closes that gap completely.
        // The 5% inward REST inset is no longer needed because the deeper
        // pivot keeps the arm tight to the body at rest too.
        armRigL = LimbRig(
            entity:  armLXform,
            restPos: armLXform.position,
            restRot: armLXform.orientation,
            pivot:   SIMD3<Float>(0, +halfY * 0.78, topZ - 0.05),
            axis:    SIMD3<Float>(1, 0, 0)
        )
        armRigR = LimbRig(
            entity:  armRXform,
            restPos: armRXform.position,
            restRot: armRXform.orientation,
            pivot:   SIMD3<Float>(0, -halfY * 0.78, topZ - 0.05),
            axis:    SIMD3<Float>(1, 0, 0)
        )
        // Legs: pivot at body's bottom (hip).  Rotate around Y axis so the
        // leg swings forward/backward in the X-Z plane (walking).
        legRigL = LimbRig(
            entity:  legLXform,
            restPos: legLXform.position,
            restRot: legLXform.orientation,
            pivot:   SIMD3<Float>(legLXform.position.x, legLXform.position.y, botZ + 0.02),
            axis:    SIMD3<Float>(0, 1, 0)
        )
        legRigR = LimbRig(
            entity:  legRXform,
            restPos: legRXform.position,
            restRot: legRXform.orientation,
            pivot:   SIMD3<Float>(legRXform.position.x, legRXform.position.y, botZ + 0.02),
            axis:    SIMD3<Float>(0, 1, 0)
        )

        // ── Step 2f: Mouth — hide USDZ mesh; 2D Canvas overlay takes over ────
        // The sculpted tripo_part_3 mesh is disabled at load.  The 2D mouth
        // overlay (Canvas in body) draws a live bezier arc driven by setMouthShape.
        mouthRoot = mouthXform
        mouthRest = mouthXform.transform
        mouthXform.isEnabled = false   // suppress USDZ mouth — 2D overlay replaces it

        // ── Accessory anchor — at body CENTRE ────────────────────────────────
        // Anchor sits at the geometric centre of the body bbox.  Each
        // accessory factory positions itself in this frame using:
        //   • +X = forward (face direction)  → glasses go here
        //   • +Y = sideways
        //   • +Z = up  → hats / caps go here
        // The factory uses `headRadius` (= body half-height) to scale its
        // own offsets, so geometry sits naturally on the head/face.
        let anchor = Entity()
        anchor.name = "claudyAccessoryAnchor"
        anchor.position = bodyBox.center
        loaded.addChild(anchor)
        accessoryAnchor = anchor
        headRadiusFloat = bodyBox.extents.z * 0.5

        // Spawn the initial accessory (if any) on next tick after scene settles.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            updateAccessory(accessory)
        }

        // ── Step 2g: Start animations ─────────────────────────────────────────
        isLoaded = true
        startIdleAnimation()
        // Initialise 2D mouth overlay to match current animation state.
        // currentMouthShape starts as .default so force-reset by clearing it first.
        currentMouthShape = .hugeSmile   // sentinel — any value ≠ target
        setMouthShape(animationState.animationConfig.mouthShape)

        // ── Project mouth + eye world positions → canvas X/Y ───────────────────
        // Camera at (0,0,3), FOV 58°, 150pt panel.  RealityKit Y-up → SwiftUI Y-down.
        // Runs after a settle delay so the transform chain is fully resolved.
        // V5.3 — also project eye centres for the U-arc closed-eye overlay.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            let camZ: Float   = 3.0
            let fovRad: Float = 58.0 * .pi / 180.0
            let frameW: Float = 150.0
            let frameH: Float = 150.0
            let focal         = (frameH * 0.5) / tan(fovRad * 0.5)
            // Mouth Y
            if let mouth = mouthRoot {
                let worldPos     = mouth.position(relativeTo: nil)
                let depthFromCam = camZ - worldPos.z
                if depthFromCam > 0.01 {
                    let projY = worldPos.y / depthFromCam * focal
                    mouth2DY  = CGFloat(frameH * 0.5 - projY)
                }
            }
            // Eye projections — for the U-arc overlay drawn during drag.
            if let eL = eyeBlinkScalerL, let eR = eyeBlinkScalerR {
                let wL  = eL.position(relativeTo: nil)
                let wR  = eR.position(relativeTo: nil)
                let dL  = camZ - wL.z
                let dR  = camZ - wR.z
                if dL > 0.01 && dR > 0.01 {
                    let lx = wL.x / dL * focal
                    let rx = wR.x / dR * focal
                    let ly = wL.y / dL * focal
                    eyeLProjX = CGFloat(frameW * 0.5 + lx)
                    eyeRProjX = CGFloat(frameW * 0.5 + rx)
                    eyeProjY  = CGFloat(frameH * 0.5 - ly)
                }
            }
        }
        // V4 FINAL — start the always-on ambient-life loop (tiny breathing,
        // iris saccades, mouth micro-drift).  Never cancelled until app exit.
        startAmbientLife()

        #if DEBUG
        print("[Claudy3D] finaliseAfterAdd complete — entity tree:")
        debugEntityTree(rig, indent: 0)
        #endif
    }

    // ── addPupil ──────────────────────────────────────────────────────────────
    /// Adds a dark procedural pupil sphere as a child of the given eye entity.
    ///
    /// IMPORTANT — coordinate space:
    /// The pupil's radius and Z-offset are computed entirely in `eyeEntity`'s
    /// LOCAL coordinate space (via `visualBounds(relativeTo: eyeEntity)`).
    /// This means the pupil stays correctly positioned regardless of the eye
    /// entity's world transform, scale, or rotation applied by animations.
    /// It is NOT computed in world space.
    @MainActor
    func addPupil(to eyeEntity: Entity) -> ModelEntity {
        // Measure the eye sclera mesh in the eye entity's OWN local frame.
        let localBounds = eyeEntity.visualBounds(relativeTo: eyeEntity)
        // CRITICAL — the eye mesh is NOT necessarily centred at the entity
        // origin.  We must offset from localBounds.center, not from (0,0,0).
        // Use the SMALLEST half-extent as the true sphere radius (the mesh is
        // approximately spherical but extents in different axes can vary
        // slightly; the smallest is the safe inscribed-sphere radius).
        // CONFIRMED via axis-probe (red sphere on +X showed up centred on
        // each eye when viewed from camera): eye-local +X IS camera-forward.
        // Pupil sits at offset eyeR × 0.55 along +X, with radius eyeR × 0.40.
        // Edge reach = 0.95 × eyeR — flush with the eye surface but never
        // protruding.  Iris tracking uses ROTATION of the eye entity, which
        // keeps the pupil locked to a fixed-radius sphere around the eye
        // centre → it can NEVER escape.
        let eyeRadius   = localBounds.extents.x * 0.5
        // Pupil pushed fully out past the eye surface for a crisp solid disc.
        // 0.52× eye radius — large enough to read clearly but still leaving
        // a visible white sclera ring around each pupil.
        let pupilRadius = eyeRadius * 0.52
        let pupil = makeSphere(radius: pupilRadius, material: Self.pupilMat)
        // Offset 1.05 × eyeR — pupil's NEAR edge sits 0.67 × eyeR past the
        // eye centre (well past the surface), FAR edge at 1.43 × eyeR.
        // No intersection with eye sphere → no chopping.
        pupil.position = SIMD3<Float>(eyeRadius * 1.05, 0, 0)
        eyeEntity.addChild(pupil)
        return pupil
    }

    // ── makePivot ─────────────────────────────────────────────────────────────
    /// Creates an animation pivot at the limb's attachment edge (shoulder / hip)
    /// and reparents the limb under it.
    ///
    /// All arithmetic is in ParentNode's LOCAL Z-up coordinate space.
    /// The USDZ children keep their original Z-up local transforms even though
    /// `loaded.orientation` rotates their appearance in the world.
    ///
    /// The correct attachment face is found by computing the vector from the
    /// limb centre to `bodyCenter` (the body mesh centre in the same local space).
    /// The dominant axis of that vector identifies which bounding-box face to use:
    ///   • Arms are offset from body in ±Y (Z-up local) → attachment face = min/max Y
    ///   • Legs are below the body in -Z (Z-up local) → attachment face = max Z
    ///
    /// World positions are logged before/after setParent to detect any drift.
    @MainActor
    func makePivot(for limb: Entity, bodyCenter: SIMD3<Float>, label: String) -> Entity {
        guard let parentNode = limb.parent else {
            logger.error("ClaudyRealityView: \(label) has no parent — skipping pivot")
            return Entity()
        }

        let boundsInParent = limb.visualBounds(relativeTo: parentNode)
        let limbCenter = boundsInParent.center

        // Vector from limb centre to body centre (in Z-up local space).
        // The dominant axis tells us which face of the bounding box is closest
        // to the body — that face is the joint / attachment edge.
        let toBody = bodyCenter - limbCenter
        let absX = abs(toBody.x); let absY = abs(toBody.y); let absZ = abs(toBody.z)

        let pivotPos: SIMD3<Float>
        if absZ >= absX && absZ >= absY {
            // Legs: Z-up body is above legs (-Z) → attach at max Z face of leg
            let pZ = toBody.z > 0 ? boundsInParent.max.z : boundsInParent.min.z
            pivotPos = SIMD3<Float>(limbCenter.x, limbCenter.y, pZ)
        } else if absY >= absX {
            // Arms: body is inward in ±Y → attach at the inward Y face
            let pY = toBody.y > 0 ? boundsInParent.max.y : boundsInParent.min.y
            pivotPos = SIMD3<Float>(limbCenter.x, pY, limbCenter.z)
        } else {
            // Fallback: X-dominant
            let pX = toBody.x > 0 ? boundsInParent.max.x : boundsInParent.min.x
            pivotPos = SIMD3<Float>(pX, limbCenter.y, limbCenter.z)
        }

        let pivot = Entity()
        pivot.name = "pivot_\(limb.name)"
        pivot.position = pivotPos
        parentNode.addChild(pivot)

        // ── Drift check ───────────────────────────────────────────────────────
        let beforeWorld = limb.position(relativeTo: nil)
        print("[Claudy3D] \(label) world pos BEFORE setParent: (\(String(format:"%.4f",beforeWorld.x)), \(String(format:"%.4f",beforeWorld.y)), \(String(format:"%.4f",beforeWorld.z)))")

        limb.setParent(pivot, preservingWorldTransform: true)

        let afterWorld = limb.position(relativeTo: nil)
        print("[Claudy3D] \(label) world pos AFTER  setParent: (\(String(format:"%.4f",afterWorld.x)), \(String(format:"%.4f",afterWorld.y)), \(String(format:"%.4f",afterWorld.z)))")

        return pivot
    }

    // ── attachLightingRig ─────────────────────────────────────────────────────

    @MainActor
    func attachLightingRig(to root: Entity) {
        // ── 4-LIGHT RIG TUNED FOR 2D PARITY ──────────────────────────────────
        // The 2D Claudy reads with rich orange highlight, soft shadow side,
        // clean rim separation.  Reproduce that with:
        //   • KEY: warm-white from upper-front-left, brighter than fill
        //   • FILL: from opposite side, ~50% of key — preserves shadow shape
        //   • RIM: cool from back-top, defines the silhouette edge
        //   • BOUNCE: warm from below, lifts chin/legs out of black
        // Total intensity: ~4500 lumens — punchy but not overexposed.

        // ── V5.3 PREMIUM 4-LIGHT RIG ─────────────────────────────────────
        // Calibrated against the deeper baseColor (0.795, 0.310, 0.155).
        // Key is warm-soft (not bright-white) so the orange stays orange.
        // Rim is the hero light — defines the silhouette glow that makes
        // 3D Claud-y read as "lit from a real environment", not floating.
        // Bounce adds warmth from below so the chin doesn't sink into shadow.
        let key = Entity()
        var keyComp = DirectionalLightComponent()
        keyComp.color     = NSColor(calibratedRed: 1.0, green: 0.93, blue: 0.83, alpha: 1.0)
        keyComp.intensity = 1150     // V5.3 — softer key, lets baseColor sing
        key.components.set(keyComp)
        key.orientation = simd_quatf(angle:  Float.pi * 0.22, axis: [1, 0, 0])
                        * simd_quatf(angle: -Float.pi * 0.22, axis: [0, 1, 0])
        root.addChild(key)

        // Fill: warm window-light tone.  Lifts the shadow side just enough
        // to keep the body readable without flattening contrast.
        let fill = Entity()
        var fillComp = DirectionalLightComponent()
        fillComp.color     = NSColor(calibratedRed: 0.98, green: 0.95, blue: 0.91, alpha: 1.0)
        fillComp.intensity = 480     // V5.3 — slightly softer
        fill.components.set(fillComp)
        fill.orientation = simd_quatf(angle: Float.pi * 0.10, axis: [1, 0, 0])
                         * simd_quatf(angle: Float.pi * 0.36, axis: [0, 1, 0])
        root.addChild(fill)

        // Rim: cool-blue silhouette glow — the "premium 3D look" comes from
        // a clear separation edge.  Bumped slightly above V5 because the
        // deeper baseColor can absorb more rim before it competes.
        let rim = Entity()
        var rimComp = DirectionalLightComponent()
        rimComp.color     = NSColor(calibratedRed: 0.80, green: 0.89, blue: 1.0, alpha: 1.0)
        rimComp.intensity = 820     // V5.3 — bumped from 750 for stronger silhouette
        rim.components.set(rimComp)
        rim.orientation = simd_quatf(angle: -Float.pi * 0.50, axis: [1, 0, 0])
                        * simd_quatf(angle:  Float.pi * 0.55, axis: [0, 1, 0])
        root.addChild(rim)

        // Bounce — warm orange floor reflection.  Subtle but essential —
        // without it the chin and feet drop into a heavy shadow that reads
        // as "floating in space".
        let bounce = Entity()
        var bounceComp = DirectionalLightComponent()
        bounceComp.color     = NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.50, alpha: 1.0)
        bounceComp.intensity = 230     // V5.3 — warmer + slightly brighter
        bounce.components.set(bounceComp)
        bounce.orientation = simd_quatf(angle: -Float.pi * 0.78, axis: [1, 0, 0])
        root.addChild(bounce)
    }

    // ── applyMaterial ─────────────────────────────────────────────────────────
    /// Recursively replaces every ModelComponent's materials with the supplied
    /// material.  Guarantees uniform colour across whatever node hierarchy the
    /// USDZ exported, regardless of how many sub-meshes it has.
    func applyMaterial(_ material: RealityKit.Material, to entity: Entity) {
        if var model = entity.components[ModelComponent.self] {
            model.materials = Array(repeating: material, count: max(model.materials.count, 1))
            entity.components.set(model)
        }
        for child in entity.children {
            applyMaterial(material, to: child)
        }
    }

    // ── makeSphere ────────────────────────────────────────────────────────────
    func makeSphere(radius: Float, material: SimpleMaterial) -> ModelEntity {
        ModelEntity(mesh: .generateSphere(radius: radius), materials: [material])
    }

    // ── makeMouthMesh ─────────────────────────────────────────────────────────
    // Kept to satisfy setMouthShape() — which is a no-op because mouthRoot==nil.
    // None of this code executes at runtime with the USDZ-mouth approach.
    func makeMouthMesh(for shape: AnimationConfig.MouthShape, scale halfW: Float) -> ModelEntity {
        switch shape {
        case .bigSmile, .hugeSmile, .vibeSmile, .smirk, .default:
            let wMul: Float = { switch shape {
                case .hugeSmile: return 0.55
                case .bigSmile:  return 0.48
                case .smirk:     return 0.32
                case .vibeSmile: return 0.38
                default:         return 0.38
            }}()
            let mesh = MeshResource.generateBox(width: halfW * wMul, height: halfW * 0.07,
                                                depth: halfW * 0.05, cornerRadius: halfW * 0.05)
            let m = ModelEntity(mesh: mesh, materials: [Self.mouthMat])
            if shape == .smirk  { m.transform.rotation = simd_quatf(angle:  0.18, axis: [0,0,1]) }
            if shape == .default { m.transform.rotation = simd_quatf(angle: 0.08, axis: [0,0,1]) }
            return m
        case .sadCurve, .flatLine, .sleepLine:
            let h: Float = (shape == .sleepLine) ? halfW * 0.025 : halfW * 0.04
            let w: Float = (shape == .flatLine)  ? halfW * 0.32  : halfW * 0.30
            let mesh = MeshResource.generateBox(width: w, height: h,
                                                depth: halfW * 0.03, cornerRadius: h * 0.5)
            let m = ModelEntity(mesh: mesh, materials: [Self.mouthMat])
            if shape == .sadCurve { m.transform.rotation = simd_quatf(angle: -0.3, axis: [1,0,0]) }
            return m
        case .tinyOpen, .mediumOpen, .wideOpen, .talkingSync:
            let r: Float = { switch shape {
                case .tinyOpen:   return halfW * 0.06
                case .mediumOpen: return halfW * 0.10
                case .wideOpen:   return halfW * 0.14
                default:          return halfW * 0.09
            }}()
            let m = ModelEntity(mesh: .generateSphere(radius: r), materials: [Self.mouthMat])
            m.transform.scale = SIMD3<Float>(1.0, 0.85, 0.55)
            return m
        case .rockMouth, .effortGrin, .chewing:
            let mesh = MeshResource.generateBox(width: halfW * 0.50, height: halfW * 0.10,
                                                depth: halfW * 0.04, cornerRadius: halfW * 0.03)
            return ModelEntity(mesh: mesh, materials: [Self.mouthMat])
        }
    }

    #if DEBUG
    func debugEntityTree(_ entity: Entity, indent: Int) {
        let pad   = String(repeating: "  ", count: indent)
        let model = entity.components[ModelComponent.self] != nil ? " [MODEL]" : ""
        let name  = entity.name.isEmpty ? "<unnamed>" : entity.name
        let p     = entity.position
        print("ClaudyTree: \(pad)\(name) pos=(\(String(format:"%.3f",p.x)),\(String(format:"%.3f",p.y)),\(String(format:"%.3f",p.z)))\(model)")
        for child in entity.children { debugEntityTree(child, indent: indent + 1) }
    }
    #endif
}

// MARK: - Accessory swap

private extension ClaudyRealityView {

    /// Replace the current accessory entity with one for `acc`.  Removes
    /// the previous entity (if any), builds a fresh procedural accessory
    /// via `ClaudyAccessory3D`, parents it under `accessoryAnchor`.
    @MainActor
    func updateAccessory(_ acc: CharacterAccessory) {
        guard let anchor = accessoryAnchor else { return }
        accessoryEntity?.removeFromParent()
        accessoryEntity = nil
        currentAccessory = acc
        if let newEntity = ClaudyAccessory3D.build(acc, headRadius: headRadiusFloat) {
            anchor.addChild(newEntity)
            accessoryEntity = newEntity
        }
        // V4 FINAL — re-discover eye axes after accessory swap.  Even
        // small layout shifts can invalidate the cached eye-forward /
        // eye-up vectors captured at startup, leaving pupils stuck
        // off-centre.  Re-running discovery on every accessory change
        // (with a 50ms settle delay) keeps pupils at clean rest.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            refreshEyeAxes()
        }
    }

    /// Snap eye entities back to rest orientation and reset the tracking throttle.
    /// Called after any layout-shift event (accessory swap, etc.).  Since iris
    /// tracking is rotation-based (eyeRestOrientL/R), no axis re-discovery is
    /// needed — just smoothly return to the stored rest quaternion.
    @MainActor
    func refreshEyeAxes() {
        guard let eL = eyeRootL, let eR = eyeRootR else { return }
        var tformL = eL.transform; tformL.rotation = eyeRestOrientL
        var tformR = eR.transform; tformR.rotation = eyeRestOrientR
        eL.move(to: tformL, relativeTo: eL.parent, duration: 0.25, timingFunction: .easeInOut)
        eR.move(to: tformR, relativeTo: eR.parent, duration: 0.25, timingFunction: .easeInOut)
        // Reset throttle so next mouse update fires immediately
        lastTrackNX = 9999; lastTrackNY = 9999
    }
}

// MARK: - Idle animation
// ⚠️  ALL methods in this extension are UNCHANGED from the original.

private extension ClaudyRealityView {

    func startIdleAnimation() {
        cancelAllAnimations()
        guard let body = torsoLoaded else { return }

        // ── Single unified body loop — rotation + scale in ONE task ──────────
        // Previously separate bodyTask (sway) + breatheTask (scale) both called
        // body.move(to:) on the same entity.  In RealityKit, move(to:) cancels
        // any in-flight move on that entity, so they fought each other and the
        // rotation compounded over time, causing erratic 360° drifts.
        // Fix: one task owns the body transform, composing yaw + roll + scale
        // together each tick on top of IDENTITY (never reads body.transform).
        setBodyTask {
            let yawAmp:   Float  = Float(7.0 * .pi / 180)
            let rollAmp:  Float  = Float(1.4 * .pi / 180)
            let yawPeriod:  Double = 4.6
            let rollPeriod: Double = 3.1
            let breathePeriod: Double = 1.8
            let tick: Double = 0.3   // fine-grained so all three phase smoothly
            var yawLeft = true; var rollLeft = true; var inhale = true
            var yawElapsed = 0.0; var rollElapsed = 0.0; var breathElapsed = 0.0
            while !Task.isCancelled {
                let destYaw   = yawLeft  ? yawAmp  : -yawAmp
                let destRoll  = rollLeft ? rollAmp : -rollAmp
                let destScale: Float = inhale ? 1.015 : 0.985
                let yaw  = simd_quatf(angle: destYaw,  axis: SIMD3<Float>(0, 1, 0))
                let roll = simd_quatf(angle: destRoll, axis: SIMD3<Float>(0, 0, 1))
                var t = Transform()
                t.rotation = yaw * roll
                t.scale    = SIMD3<Float>(repeating: destScale)
                body.move(to: t, relativeTo: body.parent, duration: tick, timingFunction: .easeInOut)
                try? await Task.sleep(for: .seconds(tick))
                yawElapsed    += tick
                rollElapsed   += tick
                breathElapsed += tick
                if yawElapsed    >= yawPeriod    { yawLeft.toggle();  yawElapsed    = 0 }
                if rollElapsed   >= rollPeriod   { rollLeft.toggle(); rollElapsed   = 0 }
                if breathElapsed >= breathePeriod { inhale.toggle();  breathElapsed = 0 }
            }
        }
        // breatheTask is now merged into bodyTask above — keep breatheTask nil
        // so cancelAllAnimations() doesn't double-cancel.

        performIdleLimbBreathe()
    }

    func cancelAllAnimations() {
        bodyTask?.cancel();        bodyTask = nil
        breatheTask?.cancel();     breatheTask = nil
        limbTask?.cancel();        limbTask = nil
        legBreatheTask?.cancel();  legBreatheTask = nil
        // Cancel ambient life so mood-pops don't compete with state animations.
        // startAmbientLife() is restarted from returnToIdle() when calm returns.
        ambientLifeTask?.cancel(); ambientLifeTask = nil
        // V5.3 — lipSyncTask is NOT cancelled here.  It is owned by
        // setMouthShape's reconcile logic — kept alive whenever the mouth
        // shape is .talkingSync, stopped automatically when shape leaves it.
        // Cancelling it here was the root cause of the "lip-sync stops after
        // one state change" bug because handleStateChange calls
        // cancelAllAnimations BEFORE setMouthShape, so the loop died and was
        // never restarted when the character re-entered talking.
        // V5.3 — restore mouth overlay opacity in case a rotation animation
        // (whoaTwirl / backflip / breakdance) was interrupted mid-spin.
        mouth2DOpacity = 1.0
        // V4 — restore pupil colour in case loveEyes left it red
        setPupilColor(.black)
        snapLimbsToRest()
    }

    /// V5.2 — Helper that GUARANTEES a previous bodyTask is cancelled before
    /// the new one starts.  Raw `bodyTask = Task {...}` reassignment leaves
    /// the previous Task running (Swift Tasks are not auto-cancelled when
    /// their handle is overwritten), so multiple body animation loops were
    /// concurrently calling body.move(to:) and fighting each other —
    /// the root cause of erratic body rotation drift.
    func setBodyTask(_ work: @escaping @MainActor () async -> Void) {
        bodyTask?.cancel()
        bodyTask = Task { @MainActor in await work() }
    }

    func snapLimbsToRest() {
        for rig in [armRigL, armRigR, legRigL, legRigR] {
            guard let r = rig else { continue }
            var t = r.entity.transform
            t.translation = r.restPos
            t.rotation    = r.restRot
            r.entity.move(to: t, relativeTo: r.entity.parent,
                          duration: 0.18, timingFunction: .easeOut)
        }
    }

    /// Rotate a limb by `angle` rad around its pivot.  Pure math, no
    /// setParent — the limb stays a direct child of `loaded`.
    /// Angle is clamped to ±1.6 rad (~92°) so the limb can reach T-pose
    /// (arms straight out horizontal) but can't swing beyond that and
    /// detach from the body.
    func setLimbAngle(_ rig: LimbRig, angle: Float, duration: Double) {
        let clamped = max(-1.6, min(1.6, angle))
        let R   = simd_quatf(angle: clamped, axis: rig.axis)
        let off = rig.restPos - rig.pivot
        let newPos = rig.pivot + R.act(off)
        let newRot = R * rig.restRot
        var t = rig.entity.transform
        t.translation = newPos
        t.rotation    = newRot
        rig.entity.move(to: t, relativeTo: rig.entity.parent,
                        duration: duration, timingFunction: .easeInOut)
    }

    func performIdleLimbBreathe() {
        guard let aL = armRigL, let aR = armRigR else { return }
        // V4 polish — STAGGERED cycles so the body doesn't feel mechanical.
        // Arms breathe at 2.2s, legs offset by 0.85s on a slower 2.6s
        // cycle.  Arms only swing outward (no inward+down).  Legs use a
        // tiny weight shift, not a march.
        let armCycle:    Double = 2.2
        let legCycle:    Double = 2.6
        let legOffset:   Double = 0.85
        let armOpenAmp:  Float  = 0.09
        let armRestAmp:  Float  = 0.02
        let legAmp:      Float  = 0.03

        // Arm task
        limbTask = Task { @MainActor in
            var open = true
            while !Task.isCancelled {
                setLimbAngle(aL, angle: open ?  armOpenAmp : armRestAmp, duration: armCycle)
                setLimbAngle(aR, angle: open ? -armOpenAmp : -armRestAmp, duration: armCycle)
                try? await Task.sleep(for: .seconds(armCycle))
                open.toggle()
            }
        }

        // Leg task — its OWN slot (legBreatheTask) so idle micros (breatheTask)
        // can run concurrently without one cancelling the other.
        if let lL = legRigL, let lR = legRigR {
            legBreatheTask?.cancel()
            legBreatheTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(legOffset))
                var shift = true
                while !Task.isCancelled {
                    setLimbAngle(lL, angle: shift ?  legAmp : -legAmp, duration: legCycle)
                    setLimbAngle(lR, angle: shift ? -legAmp :  legAmp, duration: legCycle)
                    try? await Task.sleep(for: .seconds(legCycle))
                    shift.toggle()
                }
            }
        }
    }

    func performArmWave() {
        guard let arm = armRigR else { return }
        // V4 final — amplitudes trimmed (was -0.85 max → -0.65) so the arm
        // doesn't separate from the body silhouette at peak swing.
        limbTask = Task { @MainActor in
            // Wave amplitude capped at 0.28 rad — avoids arms going behind body
            setLimbAngle(arm, angle: -0.20, duration: 0.35)
            try? await Task.sleep(for: .milliseconds(380))
            for _ in 0..<3 {
                guard !Task.isCancelled else { break }
                setLimbAngle(arm, angle: -0.28, duration: 0.22)
                try? await Task.sleep(for: .milliseconds(240))
                setLimbAngle(arm, angle: -0.14, duration: 0.22)
                try? await Task.sleep(for: .milliseconds(240))
            }
            setLimbAngle(arm, angle: 0, duration: 0.4)
        }
    }

    func performLegWalk() {
        guard let lL = legRigL, let lR = legRigR else { return }
        limbTask = Task { @MainActor in
            let amp: Float = 0.35
            let half: Double = 0.25
            var fwd = true
            while !Task.isCancelled {
                setLimbAngle(lL, angle: fwd ?  amp : -amp, duration: half)
                setLimbAngle(lR, angle: fwd ? -amp :  amp, duration: half)
                try? await Task.sleep(for: .seconds(half))
                fwd.toggle()
            }
        }
    }

    func performLimbDance() {
        guard let aL = armRigL, let aR = armRigR,
              let lL = legRigL, let lR = legRigR else { return }
        limbTask = Task { @MainActor in
            // Arm angle capped at 0.25 rad (≈14°) — larger angles swing arms
            // along the propeller arc (pivot axis = face-forward X), causing them
            // to appear behind/below the body and merge with the legs visually.
            let armOut: Float = 0.25
            let legBounce: Float = 0.18
            var beat = false
            while !Task.isCancelled {
                setLimbAngle(aL, angle: beat ?  armOut : -0.12,       duration: 0.28)
                setLimbAngle(aR, angle: beat ?  0.12   : -armOut,     duration: 0.28)
                setLimbAngle(lL, angle: beat ?  legBounce : -legBounce, duration: 0.28)
                setLimbAngle(lR, angle: beat ? -legBounce :  legBounce, duration: 0.28)
                try? await Task.sleep(for: .milliseconds(300))
                beat.toggle()
            }
        }
    }

    /// Both legs bounce up/down together (jumping/exercising/celebrating).
    func performLegBounce() {
        guard let lL = legRigL, let lR = legRigR else { return }
        limbTask = Task { @MainActor in
            var up = true
            while !Task.isCancelled {
                let a: Float = up ? 0.20 : -0.05
                setLimbAngle(lL, angle: a, duration: 0.30)
                setLimbAngle(lR, angle: a, duration: 0.30)
                try? await Task.sleep(for: .milliseconds(320))
                up.toggle()
            }
        }
    }

    /// V4 FINAL-FINAL — simplest possible 360° twirl.
    /// Body rotates a full revolution in ONE smooth quaternion animation.
    /// Limbs are SNAPPED to rest at the start, then NEVER touched during
    /// the rotation.  No phasing, no leg-stepping, no Y-bob.  Eliminates
    /// every LERP-mismatch artifact that caused arm/leg merges.
    /// Mouth: `.wideOpen` via AnimationConfig.  Eyes: `.wideSurprised`.
    func performWhoaTwirl() {
        guard let body = torsoLoaded else { return }

        // Snap limbs to rest INSTANTLY — clean starting state
        if let lL = legRigL { snapLimbToRest(lL) }
        if let lR = legRigR { snapLimbToRest(lR) }

        setBodyTask {
            // 0.0-0.30s: arms spread wide — anticipation pose
            if let aL = armRigL, let aR = armRigR {
                setLimbAngle(aL, angle:  0.28, duration: 0.30)
                setLimbAngle(aR, angle: -0.28, duration: 0.30)
            }
            // V5.3 — Fade out the 2D mouth overlay BEFORE the spin starts.
            // The Canvas mouth lives in screen space and does not rotate
            // with the body, so leaving it visible while the body spins
            // produces a "detached floating mouth" artifact.
            mouth2DOpacity = 0
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }

            // ── TRUE 360° SPIN: two sequential 180° moves ────────────────────
            // simd_quatf(angle: 2*.pi) = antipodal identity quaternion.
            // RealityKit's slerp normalises it to identity → NO rotation at all.
            // Fix: animate to 180° (first half), then back to 0° (second half).
            // Each slerp is a well-defined 180° arc with no ambiguity.

            // First 180° (0.30-1.60s): spin to back face
            let halfSpin = simd_quatf(angle: Float.pi, axis: SIMD3<Float>(0, 1, 0))
            var t1 = Transform()
            t1.rotation = halfSpin
            body.move(to: t1, relativeTo: body.parent,
                      duration: 1.20, timingFunction: .easeIn)
            try? await Task.sleep(for: .milliseconds(1220))
            guard !Task.isCancelled else { return }

            // Second 180° (1.60-2.90s): complete spin back to face-forward
            // Use explicit identity — do NOT read body.transform mid-animation.
            body.move(to: Transform(), relativeTo: body.parent,
                      duration: 1.20, timingFunction: .easeOut)
            try? await Task.sleep(for: .milliseconds(1220))
            guard !Task.isCancelled else { return }
            // V5.3 — Restore mouth as the body returns to face-forward.
            mouth2DOpacity = 1.0

            // Settle: hard-snap to identity so no floating-point residue remains
            body.transform = Transform()
            if let aL = armRigL, let aR = armRigR {
                setLimbAngle(aL, angle: 0, duration: 0.35)
                setLimbAngle(aR, angle: 0, duration: 0.35)
            }
            try? await Task.sleep(for: .milliseconds(380))
            guard !Task.isCancelled else { return }

            // Return to living, breathing idle — this is what was missing and
            // caused the character to be completely static after the twirl.
            returnToIdle()
        }
    }

    /// Hard-snap a limb to its rest pose with no animation interpolation.
    private func snapLimbToRest(_ rig: LimbRig) {
        var t = rig.entity.transform
        t.translation = rig.restPos
        t.rotation    = rig.restRot
        rig.entity.transform = t
    }

    /// V4 — proper 3D backflip: body rotates 360° around world X (forward
    /// flip), arms swing back, legs tuck slightly.  ~1.0s total.
    func performBackflip() {
        guard let body = torsoLoaded else { return }
        if let aL = armRigL, let aR = armRigR {
            setLimbAngle(aL, angle: -0.5, duration: 0.30)
            setLimbAngle(aR, angle:  0.5, duration: 0.30)
        }
        if let lL = legRigL, let lR = legRigR {
            setLimbAngle(lL, angle: 0.40, duration: 0.30)
            setLimbAngle(lR, angle: 0.40, duration: 0.30)
        }
        setBodyTask {
            try? await Task.sleep(for: .milliseconds(150))
            // Pause iris tracking during the flip — when face points away from
            // camera the pupils are behind the sclera and look wrong if tracking runs.
            eyeAxesDiscovered = false
            // V5.3 — fade out the screen-space mouth overlay during the flip.
            mouth2DOpacity = 0
            // Z-up: axis [0,1,0] = sideways Y → flips body forward/back (true backflip)
            // axis [1,0,0] was wrong: rolled body sideways like a cartwheel
            let half = simd_quatf(angle: .pi, axis: [0, 1, 0])
            var t1 = body.transform; t1.rotation = half
            body.move(to: t1, relativeTo: body.parent, duration: 0.45, timingFunction: .easeInOut)
            try? await Task.sleep(for: .milliseconds(450))
            let full = simd_quatf(angle: 2 * .pi, axis: [0, 1, 0])
            var t2 = body.transform; t2.rotation = full
            body.move(to: t2, relativeTo: body.parent, duration: 0.45, timingFunction: .easeInOut)
            try? await Task.sleep(for: .milliseconds(480))
            var t3 = body.transform; t3.rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
            body.move(to: t3, relativeTo: body.parent, duration: 0.30, timingFunction: .easeOut)
            try? await Task.sleep(for: .milliseconds(310))
            // Re-enable iris tracking after body returns to rest
            eyeAxesDiscovered = true
            // V5.3 — restore mouth overlay
            mouth2DOpacity = 1.0
        }
    }

    /// V4 — proper 3D breakdance: continuous Y-axis spin + body bob +
    /// alternating arm/leg flares.  Loops until cancelled.
    func performBreakdance() {
        guard let body = torsoLoaded else { return }
        // V5.3 — fade mouth overlay; breakdance loops indefinitely so the mouth
        // stays hidden until cancelAllAnimations / returnToIdle restores opacity.
        mouth2DOpacity = 0
        setBodyTask {
            var spin: Float = 0
            while !Task.isCancelled {
                spin += .pi / 2
                let r = simd_quatf(angle: spin, axis: [0, 1, 0])
                var t = body.transform
                t.rotation = r
                t.translation.y = 0.04 * sin(Float(spin) * 0.5)  // bob
                body.move(to: t, relativeTo: body.parent, duration: 0.30, timingFunction: .linear)
                try? await Task.sleep(for: .milliseconds(280))
            }
        }
        limbTask = Task { @MainActor in
            var beat = false
            while !Task.isCancelled {
                if let aL = armRigL, let aR = armRigR {
                    // V4 final — trimmed 0.85 → 0.65 to avoid arm-body gap
                    setLimbAngle(aL, angle: beat ?  0.65 : -0.25, duration: 0.28)
                    setLimbAngle(aR, angle: beat ? -0.25 :  0.65, duration: 0.28)
                }
                if let lL = legRigL, let lR = legRigR {
                    setLimbAngle(lL, angle: beat ? -0.25 :  0.25, duration: 0.28)
                    setLimbAngle(lR, angle: beat ?  0.25 : -0.25, duration: 0.28)
                }
                try? await Task.sleep(for: .milliseconds(290))
                beat.toggle()
            }
        }
    }

    /// V4 polish — heart-eye treatment: pupils tinted RED during the love
    /// state, a SwiftUI heart-glyph overlay (in CharacterSceneView) sits
    /// over each eye for the visible heart silhouette.  Pose: smitten
    /// sway with arms held out.
    func performLoveEyes(_ body: Entity) {
        if let aL = armRigL, let aR = armRigR {
            setLimbAngle(aL, angle:  0.55, duration: 0.45)
            setLimbAngle(aR, angle: -0.55, duration: 0.45)
        }
        // Swap pupil material to bright red for the love state
        setPupilColor(NSColor(calibratedRed: 0.95, green: 0.15, blue: 0.30, alpha: 1.0))

        setBodyTask {
            var left = true
            while !Task.isCancelled {
                let r = simd_quatf(angle: left ? 0.06 : -0.06, axis: [0, 0, 1])
                var t = body.transform
                t.rotation = r
                t.scale = SIMD3(repeating: left ? 1.025 : 1.0)
                body.move(to: t, relativeTo: body.parent, duration: 1.1, timingFunction: .easeInOut)
                try? await Task.sleep(for: .seconds(1.1))
                left.toggle()
            }
        }
    }

    /// Swap the pupil unlit material colour.  Used by loveEyes (red) and
    /// reverted to black on cancelAllAnimations / returnToIdle.
    func setPupilColor(_ color: NSColor) {
        let m = UnlitMaterial(color: color)
        if var mc = pupilL?.model { mc.materials = [m]; pupilL?.model = mc }
        if var mc = pupilR?.model { mc.materials = [m]; pupilR?.model = mc }
    }

    /// V4 FINAL — Always-on ambient life.  Tiny non-disruptive motion that
    /// runs underneath every state.  Never cancelled by cancelAllAnimations.
    /// Three concurrent micro-loops:
    ///   • Iris saccades — pupil ±0.0005m random offset every 0.7-1.4s
    ///   • Mouth micro-drift — brief vibeSmile every 6-10s, smirk every 15-25s
    ///   • Pupil drift — small noise every 1.5s on top of cursor tracking
    @MainActor
    func startAmbientLife() {
        ambientLifeTask?.cancel()
        ambientLifeTask = Task { @MainActor in
            // Wait for axis discovery to settle before touching pupils
            try? await Task.sleep(for: .milliseconds(300))

            // V4 FINAL-FINAL — saccade loop REMOVED.  It was conflicting
            // with iris-tracking's move(to:) calls and causing pupil race
            // conditions where one eye would land at an extreme while the
            // other settled at base.  The natural cursor jitter already
            // provides organic motion.

            // Sub-loop A: mouth micro-drift (smile flash every 6-10s)
            let mouthTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(.random(in: 6...10)))
                    guard !Task.isCancelled, currentMouthShape == .default else { continue }
                    setMouthShape(.vibeSmile)
                    try? await Task.sleep(for: .milliseconds(800))
                    guard !Task.isCancelled else { break }
                    setMouthShape(.default)
                }
            }

            // Sub-loop B: ambient mood pops — occasional nod / smile / blink / smirk.
            // IMPORTANT: do NOT call performCelebrate / performAnticipation / returnToIdle
            // here — those all modify bodyTask and fight the state machine, causing
            // the character to go sideways or freeze.  Stick to micro-behaviors that
            // use body.move() directly without claiming the bodyTask slot.
            let moodTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(.random(in: 8...14)))
                while !Task.isCancelled {
                    guard !Task.isCancelled else { break }
                    let pick = Int.random(in: 0...4)
                    switch pick {
                    case 0:
                        // Big smile + nod — warm and friendly
                        guard let body = torsoLoaded else { break }
                        setMouthShape(.bigSmile)
                        await microNod(body)
                        setMouthShape(.default)
                    case 1:
                        // Tiny jump with grin
                        guard let body = torsoLoaded else { break }
                        setMouthShape(.effortGrin)
                        await microJump(body)
                        try? await Task.sleep(for: .milliseconds(250))
                        setMouthShape(.default)
                    case 2:
                        // Arm stretch (only touches limbTask, not bodyTask)
                        await microArmStretch()
                    case 3:
                        // Double blink — thoughtful
                        await microDoubleBlink()
                    case 4:
                        // Glance + smirk — cheeky
                        guard let body = torsoLoaded else { break }
                        await microGlanceSmirk(body)
                    default: break
                    }
                    try? await Task.sleep(for: .seconds(.random(in: 18...26)))
                }
            }

            // Wait for the parent task to be cancelled before tearing
            // down the sub-tasks.  Sleep loop here is just a holder.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
            }
            mouthTask.cancel()
            moodTask.cancel()
        }
    }

    /// V4 FINAL — Voice-mode listening pose: gentle Y-position breathe
    /// (±0.015m on a 3.0s cycle).  Started when voiceCharacterState
    /// becomes .listening; cancelled on any other state.
    @MainActor
    func startVoiceBreathe() {
        voiceBreatheTask?.cancel()
        guard let body = torsoLoaded else { return }
        voiceBreatheTask = Task { @MainActor in
            var up = true
            while !Task.isCancelled {
                var t = body.transform
                t.translation.y = up ? 0.015 : -0.015
                body.move(to: t, relativeTo: body.parent,
                          duration: 1.5, timingFunction: .easeInOut)
                try? await Task.sleep(for: .seconds(1.5))
                up.toggle()
            }
        }
    }

    @MainActor
    func stopVoiceBreathe() {
        voiceBreatheTask?.cancel()
        voiceBreatheTask = nil
        // Reset body Y if we left it offset
        guard let body = torsoLoaded else { return }
        var t = body.transform
        t.translation.y = 0
        body.move(to: t, relativeTo: body.parent,
                  duration: 0.30, timingFunction: .easeInOut)
    }

    /// V4 FINAL — Anticipation prep frame: brief body squash before a
    /// high-amplitude reaction (surprise / celebrate / jolt).  60ms.
    /// V5.3 — squash softened (1.04→1.025, 0.95→0.97).  Larger non-uniform
    /// scale was creating brief arm-body misalignment because the body
    /// became visibly flatter than the arm spheres for a frame or two.
    /// Subtle squash still reads as "anticipation" without the artifact.
    @MainActor
    func performAnticipation(_ body: Entity) async {
        var squash = body.transform
        squash.scale = SIMD3<Float>(1.025, 1.025, 0.97)
        body.move(to: squash, relativeTo: body.parent,
                  duration: 0.06, timingFunction: .easeOut)
        try? await Task.sleep(for: .milliseconds(70))
    }

    /// Idle micro-behaviors fired periodically during `.idle` to make
    /// Claudy feel alive — small head shake, subtle jump, look-around.
    /// Picks one random micro every 8-12 seconds.
    func performIdleMicroBehaviors() {
        guard let body = torsoLoaded else { return }
        breatheTask?.cancel()  // reuse breatheTask slot for micros
        breatheTask = Task { @MainActor in
            while !Task.isCancelled {
                // V5.10 — slightly more frequent (6-10s vs 8-12s) for richer life
                try? await Task.sleep(for: .seconds(.random(in: 6...10)))
                guard !Task.isCancelled else { break }
                // V5.10 — 12 idle micros (was 8) for noticeably richer ambient life.
                let pick = Int.random(in: 0...11)
                switch pick {
                case 0:
                    await microHeadShake(body)
                case 1:
                    await microJump(body)
                case 2:
                    await microArmStretch()
                case 3:
                    await microNod(body)
                case 4:
                    // Look around — now safe (head turn, not eye rotation)
                    await microLookAround(body)
                case 5:
                    await microSigh(body)
                case 6:
                    await microGlanceSmirk(body)
                case 7:
                    await microDoubleBlink()
                case 8:
                    // V5.10 NEW — yawn (sleepy / relaxed)
                    await microYawn(body)
                case 9:
                    // V5.10 NEW — scratch head (puzzled / thinking)
                    await microScratchHead(body)
                case 10:
                    // V5.10 NEW — double take (surprise reaction)
                    await microDoubleTake(body)
                case 11:
                    // V5.10 NEW — peek (playful curiosity)
                    await microPeek(body)
                default: break
                }
            }
        }
    }

    // ── Idle micro-behavior helpers (V4 polish) ──────────────────────────

    @MainActor private func microHeadShake(_ body: Entity) async {
        let shake1  = simd_quatf(angle:  0.10, axis: [0, 1, 0])
        let shake2  = simd_quatf(angle: -0.10, axis: [0, 1, 0])
        let neutral = simd_quatf(angle: 0,     axis: [0, 1, 0])
        var t = body.transform; t.rotation = shake1
        body.move(to: t, relativeTo: body.parent, duration: 0.25, timingFunction: .easeInOut)
        try? await Task.sleep(for: .milliseconds(260))
        var t2 = body.transform; t2.rotation = shake2
        body.move(to: t2, relativeTo: body.parent, duration: 0.25, timingFunction: .easeInOut)
        try? await Task.sleep(for: .milliseconds(260))
        var t3 = body.transform; t3.rotation = neutral
        body.move(to: t3, relativeTo: body.parent, duration: 0.25, timingFunction: .easeInOut)
    }

    @MainActor private func microJump(_ body: Entity) async {
        var up = body.transform; up.translation.y += 0.05
        body.move(to: up, relativeTo: body.parent, duration: 0.20, timingFunction: .easeOut)
        try? await Task.sleep(for: .milliseconds(220))
        var down = body.transform; down.translation.y -= 0.05
        body.move(to: down, relativeTo: body.parent, duration: 0.20, timingFunction: .easeIn)
    }

    @MainActor private func microArmStretch() async {
        guard let aL = armRigL, let aR = armRigR else { return }
        // Kept small (0.28 rad ≈ 16°) — larger angles swing arms behind the body
        // along the propeller arc, making them appear behind/below the legs.
        setLimbAngle(aL, angle:  0.28, duration: 0.50)
        setLimbAngle(aR, angle: -0.28, duration: 0.50)
        try? await Task.sleep(for: .milliseconds(900))
        setLimbAngle(aL, angle: 0, duration: 0.45)
        setLimbAngle(aR, angle: 0, duration: 0.45)
    }

    @MainActor private func microNod(_ body: Entity) async {
        let down    = simd_quatf(angle:  0.12, axis: [1, 0, 0])
        let up      = simd_quatf(angle: -0.05, axis: [1, 0, 0])
        let neutral = simd_quatf(angle:  0,    axis: [1, 0, 0])
        var t = body.transform; t.rotation = down
        body.move(to: t, relativeTo: body.parent, duration: 0.20, timingFunction: .easeOut)
        try? await Task.sleep(for: .milliseconds(220))
        var t2 = body.transform; t2.rotation = up
        body.move(to: t2, relativeTo: body.parent, duration: 0.20, timingFunction: .easeInOut)
        try? await Task.sleep(for: .milliseconds(220))
        var t3 = body.transform; t3.rotation = neutral
        body.move(to: t3, relativeTo: body.parent, duration: 0.20, timingFunction: .easeOut)
    }

    /// V5.10 — "Look around" reimplemented as a HEAD TURN, not eye rotation.
    /// Rotating the eye entities directly was the source of the wall-eyed
    /// pupil bug (iris tracking is now permanently disabled).  Turning the
    /// whole head + body left → right → centre achieves the same "Claudy
    /// is curious about something off-screen" feel without ever touching
    /// the eye orientations.
    @MainActor private func microLookAround(_ body: Entity) async {
        // Z-up local: rotation around +Z = yaw (the "look left/right" axis)
        let leftQ    = simd_quatf(angle:  0.18, axis: SIMD3<Float>(0, 0, 1))
        let rightQ   = simd_quatf(angle: -0.18, axis: SIMD3<Float>(0, 0, 1))
        let neutralQ = simd_quatf(angle:  0,    axis: SIMD3<Float>(0, 0, 1))
        var t = body.transform; t.rotation = leftQ
        body.move(to: t, relativeTo: body.parent, duration: 0.35, timingFunction: .easeInOut)
        try? await Task.sleep(for: .milliseconds(380))
        var t2 = body.transform; t2.rotation = rightQ
        body.move(to: t2, relativeTo: body.parent, duration: 0.45, timingFunction: .easeInOut)
        try? await Task.sleep(for: .milliseconds(480))
        var t3 = body.transform; t3.rotation = neutralQ
        body.move(to: t3, relativeTo: body.parent, duration: 0.35, timingFunction: .easeInOut)
    }

    // ── V5.10 — NEW idle micro-behaviors for richer ambient life ────────────

    /// Yawn — slow open mouth + sigh body squash + close mouth.  Reads as
    /// "Claudy is sleepy/relaxed" — adds variety beyond just smiles.
    @MainActor private func microYawn(_ body: Entity) async {
        let prevMouth = currentMouthShape
        setMouthShape(.wideOpen)
        var compress = body.transform
        compress.scale = SIMD3<Float>(1.02, 0.94, 1.02)
        body.move(to: compress, relativeTo: body.parent, duration: 0.55, timingFunction: .easeOut)
        try? await Task.sleep(for: .milliseconds(700))
        setMouthShape(prevMouth)
        var release = body.transform
        release.scale = SIMD3<Float>(1, 1, 1)
        body.move(to: release, relativeTo: body.parent, duration: 0.50, timingFunction: .easeIn)
    }

    /// Scratch-head — left arm raises briefly, head tilts slightly, then
    /// arm lowers.  Suggests "thinking" or "puzzled" without leaving idle.
    @MainActor private func microScratchHead(_ body: Entity) async {
        guard let aL = armRigL else { return }
        let tilt = simd_quatf(angle: 0.10, axis: SIMD3<Float>(1, 0, 0))
        var t = body.transform; t.rotation = tilt
        body.move(to: t, relativeTo: body.parent, duration: 0.25, timingFunction: .easeOut)
        setLimbAngle(aL, angle: 0.95, duration: 0.30)
        try? await Task.sleep(for: .milliseconds(700))
        setLimbAngle(aL, angle: 0, duration: 0.30)
        var rev = body.transform; rev.rotation = simd_quatf(angle: 0, axis: [1, 0, 0])
        body.move(to: rev, relativeTo: body.parent, duration: 0.25, timingFunction: .easeInOut)
    }

    /// Double take — quick tilt right, snap back, tilt right again, hold.
    /// Suggests "wait, did I see that?" Surprise reaction.
    @MainActor private func microDoubleTake(_ body: Entity) async {
        let tilt = simd_quatf(angle: -0.14, axis: SIMD3<Float>(0, 0, 1))
        let neutral = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1))
        var t1 = body.transform; t1.rotation = tilt
        body.move(to: t1, relativeTo: body.parent, duration: 0.10, timingFunction: .easeOut)
        try? await Task.sleep(for: .milliseconds(120))
        var t2 = body.transform; t2.rotation = neutral
        body.move(to: t2, relativeTo: body.parent, duration: 0.08, timingFunction: .easeIn)
        try? await Task.sleep(for: .milliseconds(100))
        var t3 = body.transform; t3.rotation = tilt
        body.move(to: t3, relativeTo: body.parent, duration: 0.18, timingFunction: .easeInOut)
        try? await Task.sleep(for: .milliseconds(280))
        var t4 = body.transform; t4.rotation = neutral
        body.move(to: t4, relativeTo: body.parent, duration: 0.30, timingFunction: .easeInOut)
    }

    /// Peek — Claudy ducks down briefly then pops back up, like peeking
    /// behind a wall.  Playful curiosity behavior.
    @MainActor private func microPeek(_ body: Entity) async {
        var down = body.transform
        down.translation.y -= 0.03
        down.scale = SIMD3<Float>(1.05, 0.92, 1.05)
        body.move(to: down, relativeTo: body.parent, duration: 0.25, timingFunction: .easeOut)
        try? await Task.sleep(for: .milliseconds(450))
        var up = body.transform
        up.translation.y = 0
        up.scale = SIMD3<Float>(1, 1, 1)
        body.move(to: up, relativeTo: body.parent, duration: 0.25, timingFunction: .easeIn)
    }

    @MainActor private func microSigh(_ body: Entity) async {
        var compress = body.transform
        compress.scale = SIMD3<Float>(1.02, 0.97, 1.02)   // slight squash
        body.move(to: compress, relativeTo: body.parent, duration: 0.50, timingFunction: .easeOut)
        try? await Task.sleep(for: .milliseconds(520))
        var release = body.transform
        release.scale = SIMD3<Float>(1, 1, 1)
        body.move(to: release, relativeTo: body.parent, duration: 0.55, timingFunction: .easeIn)
    }

    @MainActor private func microGlanceSmirk(_ body: Entity) async {
        // Slight upward head tilt + smirk mouth for ~1.2s, then revert
        let glance = simd_quatf(angle: -0.10, axis: [1, 0, 0])
        var t = body.transform; t.rotation = glance
        body.move(to: t, relativeTo: body.parent, duration: 0.30, timingFunction: .easeInOut)
        let prevMouth = currentMouthShape
        setMouthShape(.smirk)
        try? await Task.sleep(for: .milliseconds(1200))
        setMouthShape(prevMouth)
        var rev = body.transform; rev.rotation = simd_quatf(angle: 0, axis: [1, 0, 0])
        body.move(to: rev, relativeTo: body.parent, duration: 0.30, timingFunction: .easeInOut)
    }

    /// V4 polish — brief eye-widen pop for `.surprised` and friends.
    /// Scales eyes up to 1.18 then back to 1.0 over ~0.32s.
    /// V5.2 — Targets the blink-scale wrapper, not the eye root, so it doesn't
    /// fight iris tracking.  Previously eye stayed stuck at 1.18 (eyes BIG)
    /// when iris tracking cancelled the rest-back move(to:) mid-flight.
    @MainActor func performEyeWiden() {
        guard let sL = eyeBlinkScalerL, let sR = eyeBlinkScalerR else { return }
        // V5.12 — Multiply REST scale by the widen factor so left-eye
        // asymmetry is preserved.
        let widenFactor: Float = 1.18
        var bigL = sL.transform
        bigL.scale = SIMD3<Float>(repeating: eyeRestScaleL * widenFactor)
        var bigR = sR.transform
        bigR.scale = SIMD3<Float>(repeating: eyeRestScaleR * widenFactor)
        sL.move(to: bigL, relativeTo: sL.parent, duration: 0.10, timingFunction: .easeOut)
        sR.move(to: bigR, relativeTo: sR.parent, duration: 0.10, timingFunction: .easeOut)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard let sL = eyeBlinkScalerL, let sR = eyeBlinkScalerR else { return }
            var rL = sL.transform
            rL.scale = SIMD3<Float>(repeating: eyeRestScaleL)
            var rR = sR.transform
            rR.scale = SIMD3<Float>(repeating: eyeRestScaleR)
            sL.move(to: rL, relativeTo: sL.parent, duration: 0.16, timingFunction: .easeIn)
            sR.move(to: rR, relativeTo: sR.parent, duration: 0.16, timingFunction: .easeIn)
        }
    }

    @MainActor private func microDoubleBlink() async {
        // Two quick blinks via the existing applyBlink path
        applyBlink(true)
        try? await Task.sleep(for: .milliseconds(80))
        applyBlink(false)
        try? await Task.sleep(for: .milliseconds(120))
        applyBlink(true)
        try? await Task.sleep(for: .milliseconds(80))
        applyBlink(false)
    }

    /// Walking with synced arm swing (opposite phase to legs).
    func performLegWalkWithArms() {
        guard let lL = legRigL, let lR = legRigR,
              let aL = armRigL, let aR = armRigR else { return }
        limbTask = Task { @MainActor in
            let legAmp: Float = 0.42   // bigger leg swing = clearly striding (was 0.35)
            let armAmp: Float = 0.20   // natural counter-swing (was 0.25, slightly smaller)
            let half: Double  = 0.30   // matched to body sway period (was 0.25)
            var fwd = true
            while !Task.isCancelled {
                setLimbAngle(lL, angle: fwd ?  legAmp : -legAmp, duration: half)
                setLimbAngle(lR, angle: fwd ? -legAmp :  legAmp, duration: half)
                // Arms swing OPPOSITE to legs — natural gait cross-pattern
                setLimbAngle(aL, angle: fwd ? -armAmp :  armAmp, duration: half)
                setLimbAngle(aR, angle: fwd ?  armAmp : -armAmp, duration: half)
                try? await Task.sleep(for: .seconds(half))
                fwd.toggle()
            }
        }
    }

    func returnToIdle() {
        guard let body = torsoLoaded else { return }
        // Hard-snap to identity THEN animate to the first sway target — this
        // ensures no residual rotation from a cancelled animation compounds.
        body.transform = Transform()
        body.move(to: Transform(), relativeTo: body.parent, duration: 0.4, timingFunction: .easeOut)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            startIdleAnimation()
            performIdleMicroBehaviors()
            // Restart ambient life — it was cancelled by cancelAllAnimations()
            // so mood-pops and mouth-drift resume once we're calm again.
            startAmbientLife()
        }
    }
}

// MARK: - Mouse tracking
// ⚠️  applyMouseTracking is FLAGGED MODIFIED (from the previous session):
//    • Target changed from `characterRoot` → `characterRig` (correct target
//      for mouse-look; root holds camera + lights and should not rotate).
//    • Transform written as `t = rig.transform; t.rotation = …; rig.move(to: t…)`
//      instead of `Transform(rotation:…)` — this preserves translation and
//      prevents the (0,0,0) zeroing bug that made parts invisible.
//    All other mouse-tracking code is unchanged.

private extension ClaudyRealityView {

    func startMouseTracking() {
        // Global monitor: fires when cursor is OUTSIDE any of our windows.
        // Local monitor: fires when cursor is INSIDE our floating panel.
        // Without both, Claudy can't track the cursor when it crosses onto
        // his own window — and he wouldn't react when on the same screen if
        // the user only ever hovered the panel.
        // Multi-screen: NSScreen.main is the focused screen, NOT the screen
        // the cursor is on.  We pick the screen via NSScreen.screens lookup.
        if mouseMonitor == nil {
            mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [self] event in
                let pt = NSEvent.mouseLocation        // global (screen) coordinates
                Task { @MainActor in updateMouseNorm(globalPoint: pt) }
            }
        }
        if mouseMonitorLocal == nil {
            mouseMonitorLocal = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [self] event in
                let pt = NSEvent.mouseLocation
                Task { @MainActor in updateMouseNorm(globalPoint: pt) }
                return event   // pass through, don't swallow
            }
        }
    }

    /// Convert a global screen-space mouse point into nx/ny ∈ [-1, 1] for the
    /// SCREEN THE CURSOR IS ACTUALLY ON.  Falls back to NSScreen.main if
    /// the point doesn't lie within any screen frame (e.g. mid-transition).
    @MainActor
    func updateMouseNorm(globalPoint pt: NSPoint) {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pt) })
                  ?? NSScreen.main
        guard let frame = screen?.frame else { return }
        mouseNormX = Float((pt.x - frame.midX) / (frame.width  * 0.5))
        mouseNormY = Float((pt.y - frame.midY) / (frame.height * 0.5))
        lastMouseMoveAt = Date().timeIntervalSince1970   // V4 — for "give up" timer
    }

    func stopMouseTracking() {
        if let m = mouseMonitor      { NSEvent.removeMonitor(m); mouseMonitor = nil }
        if let m = mouseMonitorLocal { NSEvent.removeMonitor(m); mouseMonitorLocal = nil }
    }

    /// Re-centre eyes by snapping eye entities back to rest orientation.
    /// V5.2 — @State writes (lastTrackNX/Y) deferred via Task because this
    /// function is called from RealityView's update: closure (via applyProps),
    /// where direct @State mutation is a SwiftUI violation.
    /// V5.9 — No-op since iris tracking is permanently disabled.  Kept so
    /// the call from applyProps() compiles without further plumbing changes.
    func recentreEyesIfCursorIdle() {
        // Eyes never move from rest — no recentring needed.
    }

    func applyMouseTracking() {
        let nx = max(-1, min(1, mouseNormX))
        let ny = max(-1, min(1, mouseNormY))

        // ── Rig: whole-head yaw/pitch ─────────────────────────────────────────
        // The HEAD still subtly tracks the cursor — small comforting motion.
        // ±4° yaw + ±2° pitch.  Pupils inside the head don't move (see below).
        let rigDelta = abs(nx - lastRigNX) + abs(ny - lastRigNY)
        if rigDelta > 0.02, let rig = characterRig {
            lastRigNX = nx; lastRigNY = ny
            let yaw   = simd_quatf(angle:  nx * .pi / 45, axis: [0, 1, 0])
            let pitch = simd_quatf(angle: -ny * .pi / 90, axis: [1, 0, 0])
            var t = rig.transform; t.rotation = yaw * pitch
            rig.move(to: t, relativeTo: rig.parent, duration: 0.55, timingFunction: .easeOut)
        }

        // ── Iris: SAFE TRANSLATION TRACKING (V5.12) ─────────────────────────
        // After repeated rotation-based tracking failures (wall-eyed pupils),
        // V5.12 switches to direct translation: move each pupil entity a
        // tightly-bounded offset from its rest position based on cursor
        // location.  Both pupils get the SAME offset — they always look the
        // same direction.  Translation is impossible to mis-align: there's
        // no quaternion math, no axis confusion, no chance of one eye
        // diverging from the other.
        //
        // Geometry: pupil rest is at eye-local (eyeRadius * 1.05, 0, 0).
        // Y-axis = sideways (left/right), Z-axis = up/down.
        // Max offset = 8 % of eye radius (set in finaliseAfterAdd) → visible
        // saccade, but the pupil stays well inside the sclera silhouette.
        guard let pL = pupilL, let pR = pupilR, pupilTrackOffset > 0 else { return }
        let dy = nx * pupilTrackOffset                   // sideways
        let dz = ny * pupilTrackOffset                   // up/down
        // Both eyes get the same offset — never wall-eyed
        pL.position = pupilRestL + SIMD3<Float>(0, dy, dz)
        pR.position = pupilRestR + SIMD3<Float>(0, dy, dz)
    }

    /// V5.9 — recentreEyesIfCursorIdle is now a no-op because iris tracking
    /// is permanently disabled (see comment in applyMouseTracking).
    /// Kept as a function so existing callsites (applyProps and the start of
    /// applyMouseTracking) compile without further edits.
    func _eyeRecentreNoOp() {}
}

// MARK: - Prop application (update: closure)
// ⚠️  UNCHANGED.

private extension ClaudyRealityView {

    func applyProps() {
        // Re-centre eyes if cursor has been idle.  Read-only (no @State writes).
        recentreEyesIfCursorIdle()
        // V5.2 — Mouth position is projected ONCE in finaliseAfterAdd from the
        // mesh's resting world position, NOT every frame.  The previous
        // per-frame projection wrote @State from inside the RealityView update:
        // closure, which triggered SwiftUI body re-renders → fired the update:
        // closure again → infinite render loop at 60+fps that destabilised
        // every other animation timing.  Body sway is small (±7°) so the mouth's
        // apparent screen position barely moves — static projection looks correct.
    }

    func applyBlink(_ blinking: Bool) {
        guard let sL = eyeBlinkScalerL, let sR = eyeBlinkScalerR else { return }
        pupilL?.isEnabled = !blinking
        pupilR?.isEnabled = !blinking
        // V5.12 — Multiply the per-eye REST scale by the blink factor so the
        // left-eye 1.06× asymmetry survives every blink cycle.  Z-axis
        // squishes vertically (Z-up local frame); X & Y stay at rest scale.
        let blinkZ: Float = blinking ? 0.03 : 1.0
        var tL = sL.transform
        tL.scale = SIMD3<Float>(eyeRestScaleL, eyeRestScaleL, eyeRestScaleL * blinkZ)
        var tR = sR.transform
        tR.scale = SIMD3<Float>(eyeRestScaleR, eyeRestScaleR, eyeRestScaleR * blinkZ)
        let dur = blinking ? 0.07 : 0.10
        sL.move(to: tL, relativeTo: sL.parent, duration: dur, timingFunction: .easeOut)
        sR.move(to: tR, relativeTo: sR.parent, duration: dur, timingFunction: .easeOut)
    }

    // ── 2D mouth helpers ─────────────────────────────────────────────────────

    /// Param bag for the 2D bezier mouth overlay.
    /// width  = arc span in pt (150×150 panel space)
    /// curve  = control-point height (+ = smile, − = frown, 0 = flat)
    /// gap    = open-ellipse half-height (0 = closed arc)
    /// lineW  = stroke width
    /// offX   = horizontal centre shift (smirk)
    private struct MouthParam {
        let width: CGFloat; let curve: CGFloat; let gap: CGFloat
        let lineW: CGFloat; let offX: CGFloat
    }

    private func mouth2DParams(for shape: AnimationConfig.MouthShape) -> MouthParam {
        // V5.2 — Dimensions match 2D ClaudyCharacterView verbatim.  Earlier the
        // 3D widths were scaled up ~22% under the false assumption that 3D
        // Claudy's face filled more of the panel than 2D's.  In practice the
        // perspective camera + size preset render Claudy at similar pt size,
        // so any upscaling pushed the smile past the visible face — producing
        // the "huge creepy smile" symptom.  Numbers below are 1:1 with the
        // values in ClaudyCharacterView.swift's mouth view.
        switch shape {
        case .default:     return MouthParam(width: 13, curve: 5,   gap: 0, lineW: 2.0, offX: 0)
        case .vibeSmile:   return MouthParam(width: 12, curve: 5,   gap: 0, lineW: 1.8, offX: 0)
        case .bigSmile:    return MouthParam(width: 18, curve: 7,   gap: 0, lineW: 2.0, offX: 0)  // lineW 2.5→2.0
        case .hugeSmile:   return MouthParam(width: 22, curve: 8,   gap: 0, lineW: 2.5, offX: 0)  // lineW 3.0→2.5
        case .effortGrin:  return MouthParam(width: 16, curve: 6,   gap: 0, lineW: 2.0, offX: 0)  // lineW 2.5→2.0
        case .smirk:       return MouthParam(width: 14, curve: 5,   gap: 0, lineW: 2.0, offX: 2)
        case .flatLine:    return MouthParam(width: 14, curve: 0,   gap: 0, lineW: 2.0, offX: 0)
        case .sleepLine:   return MouthParam(width: 10, curve: 2,   gap: 0, lineW: 1.5, offX: 0)
        case .sadCurve:    return MouthParam(width: 14, curve: -5,  gap: 0, lineW: 2.0, offX: 0)
        case .rockMouth:   return MouthParam(width: 20, curve: 8,   gap: 0, lineW: 2.5, offX: 0)  // curve+lineW reduced
        // Open states (gap > 0 → filled oval).  Sizes match 2D 1:1 too.
        case .tinyOpen:    return MouthParam(width: 8,  curve: 0,   gap: 3,  lineW: 2.0, offX: 0)
        case .mediumOpen:  return MouthParam(width: 9,  curve: 0,   gap: 4,  lineW: 2.0, offX: 0)
        case .talkingSync: return MouthParam(width: 11, curve: 0,   gap: 4,  lineW: 2.0, offX: 0)
        case .wideOpen:    return MouthParam(width: 13, curve: 0,   gap: 6,  lineW: 2.0, offX: 0)
        case .chewing:     return MouthParam(width: 10, curve: 0,   gap: 3,  lineW: 2.0, offX: 0)
        }
    }

    /// Drive the 2D Canvas mouth overlay.  The USDZ mouth mesh is hidden.
    /// V5.3 — Lip-sync lifecycle is SELF-HEALING.  Every call to setMouthShape
    /// re-evaluates whether the lip-sync loop should be running, regardless of
    /// previous shape.  This fixes the "lip-sync stops working after one state
    /// change" bug — previously cancelAllAnimations() killed lipSyncTask on
    /// every state change, but setMouthShape only restarted it on a STRICT
    /// not-talkingSync → talkingSync transition.  Re-entering talking after a
    /// brief other state left lipSyncTask dead and the mouth frozen open.
    func setMouthShape(_ shape: AnimationConfig.MouthShape) {
        let shapeChanged = shape != currentMouthShape
        currentMouthShape = shape
        if shapeChanged {
            let p = mouth2DParams(for: shape)
            withAnimation(.spring(response: 0.25, dampingFraction: 1.0)) {
                mouth2DW    = p.width
                mouth2DC    = p.curve
                mouth2DGap  = p.gap
                mouth2DLW   = p.lineW
                mouth2DOffX = p.offX
            }
        }
        // Lip-sync lifecycle: ALWAYS reconcile, not just on transition.
        if shape == .talkingSync {
            // Start (or keep running) the phoneme loop.  Idempotent — if
            // lipSyncTask is already alive we leave it; if cancelled or never
            // started we kick it off.  This guarantees the mouth lip-syncs
            // every time the character is talking, no matter how many
            // intermediate states fired in between.
            if lipSyncTask == nil || lipSyncTask?.isCancelled == true {
                startTalkingLipSync()
            }
        } else {
            // Any non-talking shape: stop the loop and fade open-amount to 0.
            if lipSyncTask != nil {
                stopTalkingLipSync()
            }
        }
    }

    /// V5.2 — Phoneme-driven lip-sync loop.  Identical to 2D ClaudyCharacterView's
    /// startTalkingAnimation: cycles through a 16-step weight pattern at 90ms
    /// tick.  Pattern is hand-tuned to favour mid-open over fully-open or
    /// fully-closed, mimicking real speech rhythm.
    func startTalkingLipSync() {
        lipSyncTask?.cancel()
        let shapes: [CGFloat] = [
            0.05, 0.15, 0.45, 0.65, 0.85, 0.55, 0.30, 0.70,
            0.10, 0.50, 0.90, 0.40, 0.20, 0.75, 0.35, 0.60,
        ]
        var i = 0
        lipSyncTask = Task { @MainActor in
            // Tiny initial delay so the mouth settles to talkingSync rest before
            // the first phoneme; avoids visible "snap" at talk-start.
            try? await Task.sleep(for: .milliseconds(40))
            while !Task.isCancelled {
                mouth2DOpenAmount = shapes[i % shapes.count]
                i += 1
                try? await Task.sleep(for: .milliseconds(90))
            }
        }
    }

    /// V5.2 — Stop the phoneme loop and fade the open-amount back to 0.
    /// Called automatically when shape leaves .talkingSync.  100ms fade keeps
    /// the close visually smooth instead of snapping shut.
    func stopTalkingLipSync() {
        lipSyncTask?.cancel()
        lipSyncTask = nil
        withAnimation(.easeInOut(duration: 0.10)) { mouth2DOpenAmount = 0 }
    }

    /// V5.2 — TTS word-boundary signal (from VoiceManager).  When TTS is
    /// driving real speech, briefly bump the open amount to a high value so
    /// each spoken word punctuates the underlying phoneme rhythm.  In
    /// non-voice mode the phoneme loop alone provides motion; this just
    /// adds a real-speech accent on top when present.
    func pulseMouth() {
        guard currentMouthShape == .talkingSync else { return }
        withAnimation(.easeOut(duration: 0.05)) { mouth2DOpenAmount = 0.9 }
    }
}

// MARK: - Animation state dispatcher
// ⚠️  UNCHANGED.

private extension ClaudyRealityView {

    func handleStateChange(_ state: CharacterAnimationState) {
        cancelAllAnimations()
        guard let body = torsoLoaded else { return }

        setMouthShape(state.animationConfig.mouthShape)

        // V4 FINAL — voice listening pose runs a breathe cycle on top of
        // the alert state.  Other states stop the breathe.
        if state == .alert && VoiceModeManager.shared.isVoiceModeActive {
            startVoiceBreathe()
        } else {
            stopVoiceBreathe()
        }

        switch state {
        case .idle:
            returnToIdle()
        case .thinking:
            performSway(body, angleDeg: 0.8, duration: 4.5)
        case .talking, .typing, .reading, .coding, .studying:
            performBob(body, scaleDelta: 0.012, duration: 0.35)
        case .sleeping:
            performSag(body)
        case .celebrating, .happyBounce, .evolutionShimmer, .excited:
            // V4 FINAL — anticipation prep before celebrate
            Task { @MainActor in
                await performAnticipation(body)
                performCelebrate(body)
                performLegBounce()
            }
        case .surprised, .alert, .nervous, .hiccup:
            // V4 FINAL — anticipation prep before jolt
            Task { @MainActor in
                await performAnticipation(body)
                performJolt(body)
                performEyeWiden()
            }
        case .confused, .embarrassed:
            tiltBodyForward(0.10)
        case .drowsy, .sleepyDroop, .bored:
            performSag(body)
        case .angry:
            performShake(body)
        case .sad:
            performSag(body)
            tiltBodyForward(0.12)
        case .tickled:
            performTickle(body)
        case .waving:
            performArmWave()
            performBob(body, scaleDelta: 0.008, duration: 0.4)
        case .dancing, .dab, .vibing:
            performDance(body)
            performLimbDance()
        case .headbanging:
            performHeadBang(body)
        case .hungryWobble, .fullBellyPat:
            performWobble(body)
        case .mischievous:
            performSway(body, angleDeg: 1.5, duration: 2.0)
        case .meditating:
            performSway(body, angleDeg: 0.5, duration: 5.0)
        case .exercising:
            performBob(body, scaleDelta: 0.025, duration: 0.22)
            performLegBounce()
        case .eating:
            performWobble(body)
        case .facepalm:
            tiltBodyForward(0.2)
            performSag(body)
        case .moonwalk:
            performLateralGlide(body)
        case .backflip:
            performBackflip()
        case .breakdance:
            performBreakdance()
        case .loveEyes:
            performLoveEyes(body)
        case .sneeze, .yawn:
            performJolt(body)
        case .walking:
            // Body sway period matches leg stride (0.30 s) so the lean
            // synchronises with each footfall instead of drifting out of phase.
            performSway(body, angleDeg: 1.5, duration: 0.30)
            performLegWalkWithArms()   // legs + arms swing in sync
        case .whoaTwirl:
            performWhoaTwirl()
        }
    }

    private func performSway(_ body: Entity, angleDeg: Float, duration: Double) {
        let angle = angleDeg * .pi / 180
        setBodyTask {
            var left = true
            while !Task.isCancelled {
                let t = Transform(rotation: simd_quatf(angle: left ? angle : -angle, axis: [0, 0, 1]))
                body.move(to: t, relativeTo: body.parent, duration: duration, timingFunction: .easeOut)
                try? await Task.sleep(for: .seconds(duration))
                left.toggle()
            }
        }
    }

    private func performBob(_ body: Entity, scaleDelta: Float, duration: Double) {
        setBodyTask {
            var up = true
            while !Task.isCancelled {
                let s: Float = up ? 1 + scaleDelta : 1 - scaleDelta
                var t = body.transform; t.scale = SIMD3<Float>(repeating: s)
                body.move(to: t, relativeTo: body.parent, duration: duration, timingFunction: .easeOut)
                try? await Task.sleep(for: .seconds(duration))
                up.toggle()
            }
        }
    }

    private func performCelebrate(_ body: Entity) {
        // V5.3 — Reduced bounce amplitudes: 1.15 ↔ 0.92 → 1.08 ↔ 0.96.  The
        // larger bounce was making the arm-body gap visible because any tiny
        // misalignment between the arm sphere and the body wall flashed at
        // the bounce extremes.  Smaller amplitude keeps the joyful pop while
        // making any residual gap imperceptible.  Also rounder timing
        // (0.20 / 0.16) feels more buoyant than the old jittery 0.18 / 0.12.
        setBodyTask {
            for _ in 0..<4 {
                guard !Task.isCancelled else { break }
                var tUp = body.transform; tUp.scale = SIMD3<Float>(repeating: 1.08)
                body.move(to: tUp, relativeTo: body.parent, duration: 0.20, timingFunction: .easeOut)
                try? await Task.sleep(for: .milliseconds(220))
                var tDn = body.transform; tDn.scale = SIMD3<Float>(repeating: 0.96)
                body.move(to: tDn, relativeTo: body.parent, duration: 0.16, timingFunction: .easeIn)
                try? await Task.sleep(for: .milliseconds(180))
            }
            returnToIdle()
        }
    }

    private func performJolt(_ body: Entity) {
        setBodyTask {
            var tUp = body.transform
            tUp.translation.z += 0.10  // Z-up: Z = up; was .y which launched body sideways
            tUp.scale = SIMD3<Float>(repeating: 1.1)
            body.move(to: tUp, relativeTo: body.parent, duration: 0.08, timingFunction: .easeOut)
            try? await Task.sleep(for: .milliseconds(100))
            body.move(to: Transform(), relativeTo: body.parent, duration: 0.3, timingFunction: .easeIn)
            try? await Task.sleep(for: .milliseconds(350))
            returnToIdle()
        }
    }

    private func performSag(_ body: Entity) {
        var t = Transform()
        t.translation.z = -0.07  // Z-up: Z = up/down; was .y which slid body sideways
        t.scale = SIMD3<Float>(repeating: 0.96)
        body.move(to: t, relativeTo: body.parent, duration: 1.2, timingFunction: .easeOut)
    }

    private func performShake(_ body: Entity) {
        setBodyTask {
            for _ in 0..<5 {
                guard !Task.isCancelled else { break }
                // Z-up: Y = sideways; was .x which rocked body forward/back (invisible from front)
                var tL = body.transform; tL.translation.y = -0.06
                body.move(to: tL, relativeTo: body.parent, duration: 0.07, timingFunction: .easeOut)
                try? await Task.sleep(for: .milliseconds(80))
                var tR = body.transform; tR.translation.y =  0.06
                body.move(to: tR, relativeTo: body.parent, duration: 0.07, timingFunction: .easeOut)
                try? await Task.sleep(for: .milliseconds(80))
            }
            returnToIdle()
        }
    }

    private func performTickle(_ body: Entity) {
        setBodyTask {
            for _ in 0..<8 {
                guard !Task.isCancelled else { break }
                let t = Transform(rotation: simd_quatf(angle: Float.random(in: -0.08...0.08), axis: [0, 0, 1]))
                body.move(to: t, relativeTo: body.parent, duration: 0.06, timingFunction: .easeOut)
                try? await Task.sleep(for: .milliseconds(70))
            }
            returnToIdle()
        }
    }

    /// V5.12 — Polished dance: 4-beat cycle with tilt + bounce + scale variety,
    /// not just a left/right rock.  Reads as actually dancing, not just swaying.
    /// Beats:
    ///   1. Tilt LEFT, lift up, scale up (the hop)
    ///   2. Tilt RIGHT, fall down, scale down (the dip)
    ///   3. Tilt LEFT a bit less, slight lift (counter-step)
    ///   4. Tilt RIGHT, bounce up, scale up (peak)
    private func performDance(_ body: Entity) {
        setBodyTask {
            // 4-beat cycle for variety
            let beats: [(angle: Float, lift: Float, scale: Float)] = [
                ( 0.22,  0.05, 1.07),   // 1. LEFT + UP + BIG
                (-0.18, -0.03, 0.94),   // 2. RIGHT + DOWN + SMALL
                ( 0.12,  0.02, 1.02),   // 3. LEFT (subtle) + slight up
                (-0.24,  0.06, 1.08)    // 4. RIGHT + PEAK
            ]
            var i = 0
            while !Task.isCancelled {
                let b = beats[i % beats.count]
                var t = Transform(rotation: simd_quatf(angle: b.angle, axis: [0, 0, 1]))
                t.translation.y = b.lift
                t.scale = SIMD3<Float>(repeating: b.scale)
                body.move(to: t, relativeTo: body.parent, duration: 0.26, timingFunction: .easeOut)
                try? await Task.sleep(for: .milliseconds(280))
                i += 1
            }
        }
    }

    /// V5.12 — Polished headbang: alternates aggressive forward nods with
    /// a SIDE-tilt (not just straight nods) for that real "bobbing your head
    /// to a track" feel.  Also adds a tiny scale punch on the down-beat.
    private func performHeadBang(_ body: Entity) {
        setBodyTask {
            var leftSide = true
            while !Task.isCancelled {
                // Combined nod + small side tilt + brief scale punch
                let nodAxis: SIMD3<Float> = [0, 1, 0]                 // pitch forward
                let sideAxis: SIMD3<Float> = [0, 0, 1]                // tilt L/R
                let nod  = simd_quatf(angle: -0.32, axis: nodAxis)
                let side = simd_quatf(angle: leftSide ? 0.10 : -0.10, axis: sideAxis)
                var tDown = Transform()
                tDown.rotation = nod * side
                tDown.scale = SIMD3<Float>(repeating: 1.04)
                body.move(to: tDown, relativeTo: body.parent, duration: 0.10, timingFunction: .easeIn)
                try? await Task.sleep(for: .milliseconds(120))
                // Snap back to neutral
                body.move(to: Transform(), relativeTo: body.parent, duration: 0.10, timingFunction: .easeOut)
                try? await Task.sleep(for: .milliseconds(110))
                leftSide.toggle()
            }
        }
    }

    private func performWobble(_ body: Entity) {
        setBodyTask {
            for _ in 0..<6 {
                guard !Task.isCancelled else { break }
                // Z-up: Y = sideways; was .x which rocked body forward/back
                var t = body.transform; t.translation.y = 0.05
                body.move(to: t, relativeTo: body.parent, duration: 0.15, timingFunction: .easeOut)
                try? await Task.sleep(for: .milliseconds(170))
                var t2 = body.transform; t2.translation.y = -0.05
                body.move(to: t2, relativeTo: body.parent, duration: 0.15, timingFunction: .easeOut)
                try? await Task.sleep(for: .milliseconds(170))
            }
            returnToIdle()
        }
    }

    private func tiltBodyForward(_ pitch: Float) {
        guard let body = torsoLoaded else { return }
        // Z-up frame: axis [0,1,0] = sideways (Y) → pitches body toward/away from camera
        // axis [1,0,0] was wrong: rotated around face-forward X = rolled body sideways
        let t = Transform(rotation: simd_quatf(angle: pitch, axis: [0, 1, 0]))
        body.move(to: t, relativeTo: body.parent, duration: 0.4, timingFunction: .easeOut)
    }

    private func performLateralGlide(_ body: Entity) {
        setBodyTask {
            while !Task.isCancelled {
                // Z-up: Y = sideways; was .x which pushed body forward/back (invisible from front)
                var tL = body.transform; tL.translation.y = -0.15
                body.move(to: tL, relativeTo: body.parent, duration: 1.2, timingFunction: .easeOut)
                try? await Task.sleep(for: .seconds(1.3))
                var tR = body.transform; tR.translation.y =  0.15
                body.move(to: tR, relativeTo: body.parent, duration: 1.2, timingFunction: .easeOut)
                try? await Task.sleep(for: .seconds(1.3))
            }
        }
    }

    private func performSpinBob(_ body: Entity) {
        setBodyTask {
            while !Task.isCancelled {
                let t = Transform(rotation: simd_quatf(angle: .pi * 2, axis: [0, 1, 0]))
                body.move(to: t, relativeTo: body.parent, duration: 0.45, timingFunction: .easeOut)
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
}

// MARK: - ClickableRealityShim
// ⚠️  UNCHANGED.

struct ClickableRealityShim: NSViewRepresentable {
    var onTap:       (() -> Void)?
    var onDoubleTap: (() -> Void)?

    func makeNSView(context: Context) -> _ClickableOverlayView {
        let v = _ClickableOverlayView()
        v.onTap       = onTap
        v.onDoubleTap = onDoubleTap
        return v
    }

    func updateNSView(_ nsView: _ClickableOverlayView, context: Context) {
        nsView.onTap       = onTap
        nsView.onDoubleTap = onDoubleTap
    }

    final class _ClickableOverlayView: NSView {
        var onTap:       (() -> Void)?
        var onDoubleTap: (() -> Void)?
        override var acceptsFirstResponder: Bool { true }

        // V4 FINAL — NSView shim is now ONLY for window focus.  Click
        // handling moves to SwiftUI's onTapGesture(count:) in
        // CharacterSceneView, which uses native click-deferral and is
        // immune to the SwiftUI/AppKit gesture-priority interception that
        // was breaking double-click → chat in 3D mode.
        override func mouseDown(with event: NSEvent) {
            window?.makeKey()
            super.mouseDown(with: event)   // forward, do NOT swallow
        }

        override func rightMouseDown(with event: NSEvent) {
            super.rightMouseDown(with: event)
        }
    }
}
