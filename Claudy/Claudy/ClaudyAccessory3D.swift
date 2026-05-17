import RealityKit
import AppKit
import SwiftUI

// MARK: - ClaudyAccessory3D
//
// Procedural 3-D accessory factory.  All accessories live in the
// CHARACTER'S Z-UP LOCAL FRAME:
//   • +X local = face-forward (toward camera in world)
//   • +Y local = sideways (left-right)
//   • +Z local = up (vertical in world)
//
// Anchor sits at body centre; each factory positions itself relative to
// that.  PBR materials used throughout so accessories pick up the same
// studio lighting as the body.
@MainActor
enum ClaudyAccessory3D {

    static func build(_ accessory: CharacterAccessory, headRadius r: Float) -> Entity? {
        switch accessory {
        case .none:              return nil
        case .glasses:           return buildGlasses(r: r, tinted: false)
        case .tintedSunnies:     return buildGlasses(r: r, tinted: true)
        case .heisenbergHat:     return buildHeisenbergHat(r: r)
        case .cinema3DGlasses:   return buildCinema3DGlasses(r: r)
        case .santaHat:          return buildSantaHat(r: r)
        }
    }

    // MARK: - Materials (allocated once)

    private static let blackMat  = UnlitMaterial(color: .black)
    private static let whiteMat  = UnlitMaterial(color: NSColor(white: 0.97, alpha: 1.0))

    // v4 — Deep matte felt for the Heisenberg.
    //   baseColor: #1A1A1A (0.102) — spec-exact near-black
    //   roughness: 0.88 — very matte felt, light scatters not shines
    //   specular:  0.14 — barely-there ambient highlight, no plastic look
    //   clearcoat: 0.0  — felt has no varnish layer
    private static var hatBlackPBR: PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: NSColor(white: 0.102, alpha: 1.0))
        m.roughness = .init(floatLiteral: 0.88)
        m.metallic  = .init(floatLiteral: 0.0)
        m.specular  = .init(floatLiteral: 0.14)
        m.clearcoat = .init(floatLiteral: 0.0)
        return m
    }
    /// Grosgrain band — slightly lighter than the felt so it catches small
    /// highlights as a separate plane (woven ribbon vs matte felt contrast).
    private static var hatBandPBR: PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: NSColor(white: 0.08, alpha: 1.0))
        m.roughness = .init(floatLiteral: 0.48)
        m.metallic  = .init(floatLiteral: 0.0)
        m.specular  = .init(floatLiteral: 0.42)
        return m
    }
    // Frame material for round glasses — black plastic (kept for potential future use)
    private static var glassesFramePBR: PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: NSColor(white: 0.10, alpha: 1.0))
        m.roughness = .init(floatLiteral: 0.30)
        m.metallic  = .init(floatLiteral: 0.0)
        m.specular  = .init(floatLiteral: 0.65)
        m.clearcoat = .init(floatLiteral: 0.20)
        m.clearcoatRoughness = .init(floatLiteral: 0.30)
        return m
    }
    // Frame material for gold wire-frame glasses — polished metallic gold
    private static var glassesGoldPBR: PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: NSColor(calibratedRed: 0.92, green: 0.72, blue: 0.22, alpha: 1.0))
        m.roughness = .init(floatLiteral: 0.10)
        m.metallic  = .init(floatLiteral: 1.0)
        m.specular  = .init(floatLiteral: 0.98)
        return m
    }
    // Santa hat materials
    private static var santaRedPBR: PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: NSColor(calibratedRed: 0.78, green: 0.13, blue: 0.18, alpha: 1.0))
        m.roughness = .init(floatLiteral: 0.52)
        m.metallic  = .init(floatLiteral: 0.0)
        m.specular  = .init(floatLiteral: 0.55)
        m.clearcoat = .init(floatLiteral: 0.18)   // velvet sheen
        m.clearcoatRoughness = .init(floatLiteral: 0.40)
        return m
    }
    private static var santaWhitePBR: PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: NSColor(white: 0.96, alpha: 1.0))
        m.roughness = .init(floatLiteral: 0.85)   // fluffy fur
        m.metallic  = .init(floatLiteral: 0.0)
        m.specular  = .init(floatLiteral: 0.30)
        return m
    }

    // v4 — Cinema 3D anaglyph lenses — SEMI-TRANSPARENT tinted glass.
    // Real cardboard 3D glasses have see-through coloured film: you see the
    // eye behind the lens with a red/blue tint, not a solid block.  Opacity
    // 0.45 lets the sclera + pupil show through while still reading as a
    // saturated coloured lens.  No emissive — emissive would brighten the
    // lens and wash out the see-through eye.
    // Reference: vivid red/blue film — eyes clearly visible through, just tinted.
    // Opacity 0.62 gives saturated colour while keeping iris + pupil readable.
    private static var blueLensPBR: PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: NSColor(calibratedRed: 0.08, green: 0.18, blue: 0.95, alpha: 1.0))
        m.blending  = .transparent(opacity: .init(floatLiteral: 0.62))
        m.roughness = .init(floatLiteral: 0.10)
        m.metallic  = .init(floatLiteral: 0.0)
        m.specular  = .init(floatLiteral: 0.90)
        m.clearcoat = .init(floatLiteral: 0.55)
        m.clearcoatRoughness = .init(floatLiteral: 0.06)
        return m
    }
    private static var redLensPBR: PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: NSColor(calibratedRed: 0.95, green: 0.08, blue: 0.08, alpha: 1.0))
        m.blending  = .transparent(opacity: .init(floatLiteral: 0.62))
        m.roughness = .init(floatLiteral: 0.10)
        m.metallic  = .init(floatLiteral: 0.0)
        m.specular  = .init(floatLiteral: 0.90)
        m.clearcoat = .init(floatLiteral: 0.55)
        m.clearcoatRoughness = .init(floatLiteral: 0.06)
        return m
    }
    /// Inner socket — dark interior visible inside the lens tube before
    /// the coloured lens disc.  Reads as the "lens recess shadow".
    private static var lensSocketMat: UnlitMaterial {
        UnlitMaterial(color: NSColor(white: 0.05, alpha: 1.0))
    }

    // Cylinder helpers — generateCylinder defaults to Y-axis
    private static func upCylinder(height: Float, radius: Float, material: RealityKit.Material) -> ModelEntity {
        let cyl = ModelEntity(mesh: .generateCylinder(height: height, radius: radius),
                              materials: [material])
        cyl.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))   // Y-axis → Z-axis
        return cyl
    }
    /// Disc oriented to face FORWARD (+X) — used for round-glasses lens.
    private static func forwardDisc(radius: Float, depth: Float, material: RealityKit.Material) -> ModelEntity {
        let cyl = ModelEntity(mesh: .generateCylinder(height: depth, radius: radius),
                              materials: [material])
        cyl.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 0, 1))   // Y-axis → X-axis
        return cyl
    }
    /// Forward-facing torus-ish RING built from a thin outer disc with a
    /// smaller "hole" disc punched into it via material trickery.  Since
    /// RealityKit lacks a native torus primitive, we layer two discs of
    /// different radii and slightly different depths.
    private static func forwardRing(outerRadius: Float, innerRadius: Float,
                                    depth: Float, material: RealityKit.Material) -> Entity {
        let parent = Entity()
        // V4 FINAL — 24 segments (was 16) for smoother circular silhouette
        let segments = 24
        let segWidth: Float = 2 * .pi * outerRadius / Float(segments) * 1.10  // overlap
        let ringThick = outerRadius - innerRadius
        for i in 0..<segments {
            let angle = (Float(i) / Float(segments)) * 2 * .pi
            let cy = cos(angle) * (innerRadius + ringThick * 0.5)
            let cz = sin(angle) * (innerRadius + ringThick * 0.5)
            let seg = ModelEntity(
                mesh: .generateBox(size: SIMD3<Float>(depth, segWidth, ringThick),
                                   cornerRadius: ringThick * 0.4),
                materials: [material]
            )
            seg.position = SIMD3<Float>(0, cy, cz)
            // Rotate each segment to be tangent to the ring
            seg.orientation = simd_quatf(angle: angle + .pi / 2, axis: SIMD3<Float>(1, 0, 0))
            parent.addChild(seg)
        }
        return parent
    }

    /// Forward-facing ROUNDED RECTANGLE frame — built from 4 thin edges
    /// (top, bottom, left, right).  Used by the cinema 3D glasses so each
    /// lens is framed by a rounded-rectangle border instead of a circle.
    /// Outer rect = (width × height); inner cut-out leaves frameThick
    /// border on every side.
    private static func forwardRectFrame(
        width: Float, height: Float,
        frameThick: Float, depth: Float,
        cornerRadius: Float,
        material: RealityKit.Material
    ) -> Entity {
        let parent = Entity()
        // Top + bottom horizontal edges — full width
        let topBottom = SIMD3<Float>(depth, width, frameThick)
        let top = ModelEntity(mesh: .generateBox(size: topBottom, cornerRadius: cornerRadius),
                              materials: [material])
        top.position = SIMD3<Float>(0, 0,  height * 0.5 - frameThick * 0.5)
        let bot = ModelEntity(mesh: .generateBox(size: topBottom, cornerRadius: cornerRadius),
                              materials: [material])
        bot.position = SIMD3<Float>(0, 0, -height * 0.5 + frameThick * 0.5)
        // Left + right vertical edges — height MINUS the two horizontal edge
        // thicknesses to avoid corner double-stacking.
        let leftRight = SIMD3<Float>(depth, frameThick, height - frameThick * 2)
        let left = ModelEntity(mesh: .generateBox(size: leftRight, cornerRadius: cornerRadius * 0.5),
                               materials: [material])
        left.position = SIMD3<Float>(0, -width * 0.5 + frameThick * 0.5, 0)
        let right = ModelEntity(mesh: .generateBox(size: leftRight, cornerRadius: cornerRadius * 0.5),
                                materials: [material])
        right.position = SIMD3<Float>(0,  width * 0.5 - frameThick * 0.5, 0)
        parent.addChild(top)
        parent.addChild(bot)
        parent.addChild(left)
        parent.addChild(right)
        return parent
    }

    // MARK: - Round glasses (V4 final: gold thin wire frame, perfectly circular, arched bridge)
    //
    // Reference: gold wire-frame round sunnies — polished metallic wire, circular lenses,
    // arched U-nose-bridge that dips below the lens centres, slim temple arms.

    private static func buildGlasses(r: Float, tinted: Bool) -> Entity {
        let parent = Entity()
        parent.name = tinted ? "tintedSunnies" : "glasses"

        // V4 CALIBRATED — values derived from actual USDZ geometry (Python pxr inspection):
        //   eyeCenter anchor-local: x=r*0.836 (face-fwd), y=r*0.532 (sideways), z=r*0.318 (up)
        //   eyeRadius = r*0.298  pupilTipX = r*(0.836+0.298*0.85) = r*1.089
        //   faceFrontX must be > r*1.089 so ring is in front of pupil (not behind it).
        let lensRadius:  Float = r * 0.40          // >eyeRadius r*0.298 so ring fully frames eye
        let frameThick:  Float = r * 0.028          // thin gold wire
        let frameDepth:  Float = r * 0.028
        let separation:  Float = r * 0.53          // matches actual eye Y offset r*0.532
        let lensDepth:   Float = frameDepth * 0.50

        // v4 — Both lens variants read as proper sunglasses:
        //   • .glasses        → medium smoked grey (pupils faintly visible)
        //   • .tintedSunnies  → very dark smoked black (opaque Lennon shades)
        let lensMat: RealityKit.Material = {
            var m = PhysicallyBasedMaterial()
            if tinted {
                m.baseColor = .init(tint: NSColor(calibratedRed: 0.06, green: 0.06, blue: 0.08, alpha: 1.0))
                m.blending  = .transparent(opacity: .init(floatLiteral: 0.88))
            } else {
                m.baseColor = .init(tint: NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.13, alpha: 1.0))
                m.blending  = .transparent(opacity: .init(floatLiteral: 0.62))
            }
            m.roughness = .init(floatLiteral: 0.12)         // glassy
            m.metallic  = .init(floatLiteral: 0.0)
            m.specular  = .init(floatLiteral: 0.95)
            m.clearcoat = .init(floatLiteral: 0.85)         // big shine on top
            m.clearcoatRoughness = .init(floatLiteral: 0.05)
            return m
        }()

        // Ring-style rim — 24 segments for smooth circle silhouette
        let ringL = forwardRing(outerRadius: lensRadius + frameThick,
                                innerRadius: lensRadius,
                                depth: frameDepth,
                                material: glassesGoldPBR)
        let ringR = forwardRing(outerRadius: lensRadius + frameThick,
                                innerRadius: lensRadius,
                                depth: frameDepth,
                                material: glassesGoldPBR)
        // Translucent lens disc just inside each ring
        let lensL = forwardDisc(radius: lensRadius, depth: lensDepth, material: lensMat)
        let lensR = forwardDisc(radius: lensRadius, depth: lensDepth, material: lensMat)

        // FLAT nose bridge — single horizontal box connecting the inner ring edges.
        // The gap between the two rings (archSpanY * 2 = separation*2 - lensRadius*2 - frameThick*2)
        // is the natural bridge span.  A flat box is far cleaner than the previous
        // 2-segment arch, which had archSpanY ≈ r*0.032 (nearly zero) producing two
        // near-vertical knife-blade spikes at the nose.
        let innerGap: Float = (separation - lensRadius - frameThick) * 2  // = r*0.204 with calibrated values
        let bridgeSize = SIMD3<Float>(frameDepth * 0.80,
                                      max(innerGap, r * 0.06),  // floor so bridge is always visible
                                      frameThick * 1.8)
        let bridge = ModelEntity(mesh: .generateBox(size: bridgeSize,
                                                    cornerRadius: frameThick * 0.6),
                                 materials: [glassesGoldPBR])

        // Temple arms — thin gold wire, extend back from outer edge of each ring
        let templeLen:   Float = r * 1.05
        let templeThick: Float = frameThick * 0.90
        let templeSize   = SIMD3<Float>(templeLen, templeThick, templeThick)
        let templeL = ModelEntity(mesh: .generateBox(size: templeSize,
                                                     cornerRadius: templeThick * 0.45),
                                  materials: [glassesGoldPBR])
        let templeR = ModelEntity(mesh: .generateBox(size: templeSize,
                                                     cornerRadius: templeThick * 0.45),
                                  materials: [glassesGoldPBR])

        // ── Positioning ── (all calibrated to real USDZ eye positions)
        let faceFrontX: Float = r * 1.15  // was r*0.95 — must be > pupilTipX r*1.089
        let eyeLevelZ:  Float = r * 0.32  // was r*0.35 — actual eye Z = r*0.318
        let frameCx:    Float = faceFrontX + frameDepth * 0.5
        let lensCx:     Float = faceFrontX + frameDepth + lensDepth * 0.5 + 0.001

        ringL.position  = SIMD3<Float>(frameCx, -separation, eyeLevelZ)
        ringR.position  = SIMD3<Float>(frameCx,  separation, eyeLevelZ)
        lensL.position  = SIMD3<Float>(lensCx,  -separation, eyeLevelZ)
        lensR.position  = SIMD3<Float>(lensCx,   separation, eyeLevelZ)

        bridge.position = SIMD3<Float>(frameCx, 0, eyeLevelZ)

        templeL.position = SIMD3<Float>(faceFrontX - templeLen * 0.5,
                                        -(separation + lensRadius + templeThick * 0.5),
                                        eyeLevelZ - templeThick * 0.3)
        templeR.position = SIMD3<Float>(faceFrontX - templeLen * 0.5,
                                         (separation + lensRadius + templeThick * 0.5),
                                        eyeLevelZ - templeThick * 0.3)

        parent.addChild(ringL); parent.addChild(ringR)
        parent.addChild(lensL); parent.addChild(lensR)
        parent.addChild(bridge)
        parent.addChild(templeL); parent.addChild(templeR)
        return parent
    }

    // MARK: - Cinema 3D glasses (v4 — reference-accurate white plastic frame)
    //
    // Reference image analysis:
    //   • WHITE GLOSSY PLASTIC frame — not matte cardboard
    //   • Bridge is WIDE (≈20% of total frame width) — most common mistake is too narrow
    //   • Lens inner edges ALIGN with bridge outer edges — no overlap, clean separation
    //   • Large vivid semi-transparent red/blue lenses — eyes clearly visible through them
    //   • Prominent rounded corners on frame pieces
    //   • Nose notch at bottom-centre of bridge (split bottom rail)
    //
    // 6-piece white frame:
    //   1. Top rail (full width)
    //   2. Left outer edge
    //   3. Right outer edge
    //   4. Bridge column (WIDE — clearly separates the two lenses)
    //   5. Bottom-LEFT rail (split, nose notch gap)
    //   6. Bottom-RIGHT rail (split, nose notch gap)
    //
    //   eye centre: x=r*0.836, y=±r*0.532, z=r*0.318
    private static func buildCinema3DGlasses(r: Float) -> Entity {
        let parent = Entity()
        parent.name = "cinema3DGlasses"

        let eyeSep:      Float = r * 0.53    // calibrated eye Y centre

        // Bridge geometry — reference shows bridge ≈ 20% of frame width.
        // Lens inner edge is set to EXACTLY the bridge outer edge (eyeSep − bridgeW/2)
        // so the coloured area starts right where the white bridge ends → clean split.
        let bridgeW:     Float = r * 0.22    // wide bridge: 0.11r each side from centre
        let lensHalfW:   Float = eyeSep - bridgeW * 0.5   // = r*0.42 — lens pane half-width
        let lensW:       Float = lensHalfW * 2             // = r*0.84 — each pane width
        let lensH:       Float = r * 0.65
        let frameBorder: Float = r * 0.072   // outer border thickness
        let noseNotchW:  Float = r * 0.20    // nose notch width (proportional to bridge)
        let frameDepth:  Float = r * 0.062   // frame front-to-back depth
        let lensDepth:   Float = r * 0.025   // lens pane thickness
        let outerCornerR: Float = r * 0.055  // rounded corners (reference is clearly rounded)
        let lensCornerR:  Float = r * 0.032

        // GLOSSY WHITE PLASTIC — reference shows smooth, slightly shiny surface
        var plasticMat = PhysicallyBasedMaterial()
        plasticMat.baseColor = .init(tint: NSColor(white: 0.97, alpha: 1.0))
        plasticMat.roughness = .init(floatLiteral: 0.22)
        plasticMat.metallic  = .init(floatLiteral: 0.0)
        plasticMat.specular  = .init(floatLiteral: 0.72)
        plasticMat.clearcoat = .init(floatLiteral: 0.35)
        plasticMat.clearcoatRoughness = .init(floatLiteral: 0.12)

        // Full outer frame dimensions
        let frameW: Float = 2 * (eyeSep + lensHalfW + frameBorder)   // = 2*(0.53+0.42+0.072) = 2.044r
        let eyeLevelZ:   Float = r * 0.32
        let topZ:        Float = eyeLevelZ + lensH * 0.5 + frameBorder * 0.5
        let botZ:        Float = eyeLevelZ - lensH * 0.5 - frameBorder * 0.5
        let faceFrontX:  Float = r * 1.15
        let frameCx:     Float = faceFrontX + frameDepth * 0.5
        let lensCx:      Float = frameCx + frameDepth * 0.5 + lensDepth * 0.5 + r * 0.002

        // ── 1. TOP rail (full width) ──────────────────────────────────────────
        let topRail = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(frameDepth, frameW, frameBorder),
                               cornerRadius: outerCornerR),
            materials: [plasticMat])
        topRail.position = SIMD3<Float>(frameCx, 0, topZ)
        parent.addChild(topRail)

        // ── 2. LEFT outer edge ────────────────────────────────────────────────
        let leftEdge = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(frameDepth, frameBorder, lensH),
                               cornerRadius: outerCornerR),
            materials: [plasticMat])
        leftEdge.position = SIMD3<Float>(frameCx, -(frameW * 0.5 - frameBorder * 0.5), eyeLevelZ)
        parent.addChild(leftEdge)

        // ── 3. RIGHT outer edge ───────────────────────────────────────────────
        let rightEdge = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(frameDepth, frameBorder, lensH),
                               cornerRadius: outerCornerR),
            materials: [plasticMat])
        rightEdge.position = SIMD3<Float>(frameCx, frameW * 0.5 - frameBorder * 0.5, eyeLevelZ)
        parent.addChild(rightEdge)

        // ── 4. CENTRE bridge — WIDE, matches reference proportions ────────────
        // Full-height column; nose notch formed by the split bottom rail below.
        let bridge = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(frameDepth, bridgeW, lensH),
                               cornerRadius: outerCornerR * 0.6),
            materials: [plasticMat])
        bridge.position = SIMD3<Float>(frameCx, 0, eyeLevelZ)
        parent.addChild(bridge)

        // ── 5+6. BOTTOM rails — split, nose notch gap at centre ──────────────
        let bottomInner: Float = noseNotchW * 0.5
        let bottomOuter: Float = frameW * 0.5
        let bottomHalfW: Float = bottomOuter - bottomInner
        let bottomHalfY: Float = bottomInner + bottomHalfW * 0.5

        let botLeft = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(frameDepth, bottomHalfW, frameBorder),
                               cornerRadius: outerCornerR),
            materials: [plasticMat])
        botLeft.position = SIMD3<Float>(frameCx, -bottomHalfY, botZ)
        parent.addChild(botLeft)

        let botRight = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(frameDepth, bottomHalfW, frameBorder),
                               cornerRadius: outerCornerR),
            materials: [plasticMat])
        botRight.position = SIMD3<Float>(frameCx, bottomHalfY, botZ)
        parent.addChild(botRight)

        // ── RED lens pane — LEFT eye (−Y), inner edge flush with bridge edge ──
        // Pane centre = −eyeSep; inner edge = −eyeSep + lensHalfW = −bridgeW/2. ✓
        let redPane = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(lensDepth, lensW, lensH),
                               cornerRadius: lensCornerR),
            materials: [redLensPBR])
        redPane.position = SIMD3<Float>(lensCx, -eyeSep, eyeLevelZ)
        parent.addChild(redPane)

        // ── BLUE lens pane — RIGHT eye (+Y), inner edge flush with bridge edge ─
        let bluePane = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(lensDepth, lensW, lensH),
                               cornerRadius: lensCornerR),
            materials: [blueLensPBR])
        bluePane.position = SIMD3<Float>(lensCx, eyeSep, eyeLevelZ)
        parent.addChild(bluePane)

        return parent
    }

    // MARK: - Heisenberg hat (v4 rebuild)
    //
    // v4 spec:
    //   • Near-black #1A1A1A felt — hatBlackPBR updated to exact value
    //   • Single clean crown cylinder — no two-stack ledge artefact
    //   • Full 360° brim r×1.50 with a thin curl ring at the outer edge
    //   • Level — no forward tilt
    //   • Grosgrain band at crown base

    private static func buildHeisenbergHat(r: Float) -> Entity {
        let parent = Entity()
        parent.name = "heisenbergHat"

        // Brim — flat disc, thin
        let brimH: Float = r * 0.040
        let brimR: Float = r * 1.50

        // Single crown — one clean cylinder avoids the visible joint ledge
        // of the old two-stack design.  Pork-pie crowns are relatively short.
        let crownR: Float = r * 0.68
        let crownH: Float = r * 0.72

        let bandH:  Float = r * 0.085

        let bodyTop:       Float = r * 1.02
        let brimZ:         Float = bodyTop + brimH * 0.5
        let crownBaseZ:    Float = bodyTop + brimH
        let crownCentreZ:  Float = crownBaseZ + crownH * 0.5
        let bandZ:         Float = crownBaseZ + bandH * 0.5

        // Brim disc
        let brim = upCylinder(height: brimH, radius: brimR, material: hatBlackPBR)
        brim.position = SIMD3<Float>(0, 0, brimZ)
        parent.addChild(brim)

        // Brim-edge curl ring — thin cylinder at the very outer edge of the brim,
        // positioned just above the brim top.  Reads as an upward-curled brim lip
        // from any camera angle without needing a torus primitive.
        let curlH: Float = r * 0.022
        let curl = upCylinder(height: curlH, radius: brimR + r * 0.008, material: hatBlackPBR)
        curl.position = SIMD3<Float>(0, 0, brimZ + brimH * 0.5 + curlH * 0.5)
        parent.addChild(curl)

        // Crown — single cylinder
        let crown = upCylinder(height: crownH, radius: crownR, material: hatBlackPBR)
        crown.position = SIMD3<Float>(0, 0, crownCentreZ)
        parent.addChild(crown)

        // Flat cap on crown top — thin flattened sphere closes the top cleanly
        let crownCap = ModelEntity(mesh: .generateSphere(radius: crownR),
                                   materials: [hatBlackPBR])
        crownCap.scale    = SIMD3<Float>(1, 1, 0.16)   // very flat disc
        crownCap.position = SIMD3<Float>(0, 0, crownBaseZ + crownH)
        parent.addChild(crownCap)

        // Grosgrain band — slightly proud of crown so it catches highlights
        let band = upCylinder(height: bandH, radius: crownR + r * 0.012, material: hatBandPBR)
        band.position = SIMD3<Float>(0, 0, bandZ)
        parent.addChild(band)

        // Pork-pie pinch — very flat disc pressed into crown top centre
        let pinch = upCylinder(height: r * 0.016, radius: crownR * 0.48, material: hatBandPBR)
        pinch.position = SIMD3<Float>(0, 0, crownBaseZ + crownH - r * 0.006)
        parent.addChild(pinch)

        // Sits perfectly level — no tilt
        return parent
    }

    // MARK: - Santa Hat (V4, NEW)

    private static func buildSantaHat(r: Float) -> Entity {
        let parent = Entity()
        parent.name = "santaHat"

        // Stacked-cylinder cone (5 stacks) — RealityKit lacks a primitive cone.
        // Each stack tapers narrower as it goes up.  Slight forward droop
        // accomplished by tilting the parent.
        let stacks = 6
        let coneTotalH: Float = r * 1.1
        let baseR: Float = r * 0.78
        let tipR:  Float = r * 0.06
        let bodyTop: Float = r * 0.95   // body top from centre

        for i in 0..<stacks {
            let frac0 = Float(i) / Float(stacks)
            let frac1 = Float(i + 1) / Float(stacks)
            // Average radius for this stack — taper linearly
            let radius0 = baseR + (tipR - baseR) * frac0
            let radius1 = baseR + (tipR - baseR) * frac1
            let avgR = (radius0 + radius1) * 0.5
            let stackH = coneTotalH / Float(stacks)
            let stack = upCylinder(height: stackH * 1.1, radius: avgR, material: santaRedPBR)
            // Z position: stacks start at body top + half-stack and go up
            stack.position = SIMD3<Float>(0, 0,
                                          bodyTop + stackH * (Float(i) + 0.5))
            parent.addChild(stack)
        }

        // White fluffy band at base — slightly wider than baseR so it
        // hides the brim seam between hat and head.
        let bandH: Float = r * 0.18
        let band = upCylinder(height: bandH, radius: baseR + r * 0.04, material: santaWhitePBR)
        band.position = SIMD3<Float>(0, 0, bodyTop + bandH * 0.5)
        parent.addChild(band)

        // Pom-pom on the tip
        let pom = ModelEntity(mesh: .generateSphere(radius: r * 0.16),
                              materials: [santaWhitePBR])
        pom.position = SIMD3<Float>(0, 0, bodyTop + coneTotalH + r * 0.02)
        parent.addChild(pom)

        // Slight forward droop — tilt the WHOLE hat ~12° toward +X (front)
        // and add a subtle Z-axis kink so the tip flops sideways.
        let droopForward = simd_quatf(angle: -0.18, axis: SIMD3<Float>(0, 1, 0))
        let droopSide    = simd_quatf(angle: -0.10, axis: SIMD3<Float>(1, 0, 0))
        parent.orientation = droopForward * droopSide

        return parent
    }
}
