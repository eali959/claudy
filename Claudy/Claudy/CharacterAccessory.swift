import SwiftUI

// MARK: - CharacterAccessory (ACC-01)

/// Accessories that can be equipped on Claud-y.
/// Persisted to UserDefaults via `DefaultsKeys.activeAccessory`.
enum CharacterAccessory: String, CaseIterable {
    case none          = "none"
    case glasses       = "glasses"
    case tintedSunnies = "tintedSunnies"
    case heisenbergHat = "heisenbergHat"
    case cinema3DGlasses = "cinema3DGlasses"
    case santaHat      = "santaHat"

    var displayName: String {
        switch self {
        case .none:            return "None"
        case .glasses:         return "Glasses"
        case .tintedSunnies:   return "Tinted Sunnies"
        case .heisenbergHat:   return "Heisenberg Hat"
        case .cinema3DGlasses: return "3D Cinema Glasses"
        case .santaHat:        return "Santa Hat"
        }
    }

    var icon: String {
        switch self {
        case .none:            return "minus.circle"
        case .glasses:         return "eyeglasses"
        case .tintedSunnies:   return "sunglasses"
        case .heisenbergHat:   return "hat.widebrim"
        case .cinema3DGlasses: return "movieclapper"
        case .santaHat:        return "gift.fill"
        }
    }

    /// Human-readable label appended to the VoiceOver accessibility description (ACC-05).
    var accessibilityLabel: String {
        self == .none ? "" : "wearing \(displayName)"
    }

    // MARK: - Persistence

    static var active: CharacterAccessory {
        get {
            let raw = UserDefaults.standard.string(forKey: DefaultsKeys.activeAccessory) ?? "none"
            return CharacterAccessory(rawValue: raw) ?? .none
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: DefaultsKeys.activeAccessory)
        }
    }
}

// MARK: - AccessoryOverlayView (ACC-02)

/// Pure SwiftUI overlay drawn above the face layer inside `ClaudyCharacterView`.
/// All geometry is relative to the character's bounding box, scaled by `scale`. (ACC-04)
struct AccessoryOverlayView: View {
    let accessory: CharacterAccessory
    /// Matches the character's current scale (from WindowManager.SizePreset.scale).
    let scale: CGFloat

    var body: some View {
        switch accessory {
        case .none:
            EmptyView()

        case .glasses:
            glassesView(tinted: false)

        case .tintedSunnies:
            glassesView(tinted: true)

        case .heisenbergHat:
            heisenbergHatView()

        case .cinema3DGlasses:
            cinema3DGlassesView()

        case .santaHat:
            santaHatView()
        }
    }

    // MARK: - 3D Cinema Glasses (anaglyph, v4)
    //
    // Wide cardboard frame — lens windows dominate.
    // Multi-piece white frame with a nose notch gap at the bottom-centre,
    // and large semi-transparent red/blue lens panes so the eyes show through
    // with a tint (not solid blocks that hide the eyes).
    // Pieces: top rail, left edge, right edge, narrow centre bridge, bottom-left
    // rail, bottom-right rail — bottom rails split, leaving the notch.

    @ViewBuilder
    private func cinema3DGlassesView() -> some View {
        let s = scale
        // Reference: white glossy plastic frame, wide bridge, vivid semi-transparent lenses.
        // Bridge ≈ 20% of frame width; lens inner edge aligns exactly with bridge outer edge.
        let frameColor = Color(red: 0.97, green: 0.97, blue: 0.97)    // bright white plastic
        let red  = Color(red: 0.95, green: 0.08, blue: 0.08).opacity(0.62)
        let blue = Color(red: 0.08, green: 0.18, blue: 0.95).opacity(0.62)

        // Geometry — reference proportions:
        //   eyeOffsetX = 14s (eye centre from frame centre, matches eyeSep in 3D)
        //   bridgeHalf = 3s  → total bridge = 6s (~11% of eyeSep, matching 3D r*0.22/r*0.53)
        //   lensHalf   = 11s → total lensW = 22s (inner edge at bridgeHalf ±3s ✓)
        let eyeOffsetX:  CGFloat = 14 * s
        let bridgeHalf:  CGFloat = 3 * s     // half-bridge = 3s, total bridge = 6s
        let lensHalf:    CGFloat = eyeOffsetX - bridgeHalf  // 11s — lens half-width
        let lensW:       CGFloat = lensHalf * 2             // 22s each pane
        let lensH:       CGFloat = 20 * s
        let border:      CGFloat = 3 * s
        let bridgeW:     CGFloat = bridgeHalf * 2           // 6s total bridge
        let noseNotchW:  CGFloat = 5 * s
        let frameW:      CGFloat = 2 * eyeOffsetX + lensW + 2 * border  // = 2*14+22+6 = 56s

        // Bottom rail halves
        let bottomHalfW: CGFloat = (frameW - noseNotchW) * 0.5
        let bottomHalfX: CGFloat = (noseNotchW + bottomHalfW) * 0.5

        ZStack {
            // 1. TOP rail
            RoundedRectangle(cornerRadius: 2 * s)
                .fill(frameColor)
                .frame(width: frameW, height: border)
                .offset(y: -(lensH + border) * 0.5)

            // 2. LEFT outer edge
            Rectangle()
                .fill(frameColor)
                .frame(width: border, height: lensH)
                .offset(x: -(frameW - border) * 0.5)

            // 3. RIGHT outer edge
            Rectangle()
                .fill(frameColor)
                .frame(width: border, height: lensH)
                .offset(x: (frameW - border) * 0.5)

            // 4. CENTRE bridge column
            Rectangle()
                .fill(frameColor)
                .frame(width: bridgeW, height: lensH)

            // 5. BOTTOM-LEFT rail (split, leaving nose notch)
            RoundedRectangle(cornerRadius: 2 * s)
                .fill(frameColor)
                .frame(width: bottomHalfW, height: border)
                .offset(x: -bottomHalfX, y: (lensH + border) * 0.5)

            // 6. BOTTOM-RIGHT rail
            RoundedRectangle(cornerRadius: 2 * s)
                .fill(frameColor)
                .frame(width: bottomHalfW, height: border)
                .offset(x: bottomHalfX, y: (lensH + border) * 0.5)

            // RED pane — semi-transparent
            RoundedRectangle(cornerRadius: 2 * s)
                .fill(red)
                .frame(width: lensW, height: lensH)
                .offset(x: -eyeOffsetX)

            // BLUE pane — semi-transparent
            RoundedRectangle(cornerRadius: 2 * s)
                .fill(blue)
                .frame(width: lensW, height: lensH)
                .offset(x: eyeOffsetX)
        }
        .offset(y: -12 * s)
    }

    // MARK: - Glasses (V4 final: gold wire frame, circular lenses, arched nose bridge)
    //
    // Reference: gold wire-frame round sunnies.
    //   • Polished metallic gold frame (same for glasses + tinted sunnies)
    //   • Perfectly circular lenses — same diameter for both eyes
    //   • Arched U-nose-bridge: two angled arms meeting at a dip below centre
    //   • Slim gold temple arms

    @ViewBuilder
    private func glassesView(tinted: Bool) -> some View {
        // Dark near-black tint for sunnies; clear for regular glasses
        let lensColor = tinted
            ? Color(red: 0.03, green: 0.04, blue: 0.08).opacity(0.75)
            : Color.clear
        let gold = Color(red: 0.90, green: 0.70, blue: 0.20)
        let s = scale

        // Lens geometry
        // Both lenses same size (circular) — 22 pt diameter at scale 1
        let lensD:    CGFloat = 22 * s
        let leftX:    CGFloat = -20 * s
        let rightX:   CGFloat = +22 * s

        // Arch bridge geometry:
        //   Inner edges:  left = -9s, right = +11s, gap-centre = +1s
        //   Half-span from gap-centre = 10s, dip = 4s
        //   Angle from horizontal = atan2(4, 10) ≈ 21.8°
        let archAngle = CGFloat(atan2(4.0, 10.0))   // ≈ 0.38 rad

        ZStack {
            // Left lens — perfectly circular
            Circle()
                .fill(lensColor)
                .overlay(Circle().stroke(gold, lineWidth: 1.6 * s))
                .frame(width: lensD, height: lensD)
                .offset(x: leftX)

            // Right lens — same size
            Circle()
                .fill(lensColor)
                .overlay(Circle().stroke(gold, lineWidth: 1.6 * s))
                .frame(width: lensD, height: lensD)
                .offset(x: rightX)

            // Arched bridge — two arms forming a V-dip at the nose
            // Left arm: from gap-centre (+1s, +2s) toward left inner edge (-9s, 0)
            Rectangle().fill(gold)
                .frame(width: 10.8 * s, height: 1.4 * s)
                .rotationEffect(.radians(Double(archAngle)))
                .offset(x: -4 * s, y: 2 * s)
            // Right arm: from gap-centre (+1s, +2s) toward right inner edge (+11s, 0)
            Rectangle().fill(gold)
                .frame(width: 10.8 * s, height: 1.4 * s)
                .rotationEffect(.radians(-Double(archAngle)))
                .offset(x: 6 * s, y: 2 * s)

            // Temple arms — thin gold wire
            Rectangle().fill(gold)
                .frame(width: 12 * s, height: 1.4 * s)
                .offset(x: -39 * s)
            Rectangle().fill(gold)
                .frame(width: 12 * s, height: 1.4 * s)
                .offset(x: 41 * s)
        }
        .offset(y: -12 * s)   // eye level offset
    }

    // MARK: - Heisenberg Hat (V4 final: wide flat brim, short tapered crown)
    //
    // Reference: pork-pie / Heisenberg black felt hat.
    //   • Very wide flat brim (82 * s vs old 62 * s)
    //   • Short crown — 24 pt (was 30 pt), with subtle top shading for depth
    //   • Thin grosgrain band near base of crown

    @ViewBuilder
    private func heisenbergHatView() -> some View {
        let s = scale
        let hatColor   = Color(red: 0.13, green: 0.11, blue: 0.10)
        let hatShade   = Color(red: 0.08, green: 0.07, blue: 0.06)   // darker for depth
        let bandColor  = Color(red: 0.36, green: 0.26, blue: 0.14)

        ZStack(alignment: .bottom) {
            // Wide flat brim — prominent, clearly wider than crown
            Capsule()
                .fill(hatColor)
                .frame(width: 84 * s, height: 7 * s)

            // Crown — short, with subtle top-edge shadow to imply taper
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 5 * s)
                    .fill(hatColor)
                    .frame(width: 40 * s, height: 24 * s)
                // Top shading stripe — suggests the slight crown indent
                RoundedRectangle(cornerRadius: 5 * s)
                    .fill(hatShade.opacity(0.60))
                    .frame(width: 38 * s, height: 5 * s)
            }
            .offset(y: -8 * s)

            // Thin grosgrain band
            Rectangle()
                .fill(bandColor)
                .frame(width: 42 * s, height: 4 * s)
                .offset(y: -8 * s)
        }
        // -(36 + 12*s): ZStack layout height = 24*s (crown tallest), half = 12*s.
        // Brim layout bottom = outer_offset + 12*s = -36 = body top at all scales.
        // Screen check: (-36 - 12s + 12s) × s_ext = -36s = body top in screen. ✓
        .offset(y: -(36 + 12 * s))
    }

    // MARK: - Santa Hat (V4 polish)

    @ViewBuilder
    private func santaHatView() -> some View {
        let s = scale
        let red       = Color(red: 0.78, green: 0.13, blue: 0.18)
        let redShadow = Color(red: 0.55, green: 0.08, blue: 0.12)
        let white     = Color(red: 0.96, green: 0.96, blue: 0.96)
        let whiteShadow = Color(red: 0.82, green: 0.82, blue: 0.82)

        ZStack {
            // Cone body — drooping forward slightly via bezier path
            // Path defines a curving triangle from base (wide) to tip (narrow)
            // tip droops to character's right.
            ZStack {
                // shadow side (back)
                SantaHatCone(droop: 18 * s)
                    .fill(redShadow)
                    .frame(width: 78 * s, height: 78 * s)
                    .offset(x: 1 * s, y: 1 * s)
                // main red body
                SantaHatCone(droop: 18 * s)
                    .fill(red)
                    .frame(width: 78 * s, height: 78 * s)
                // subtle highlight
                SantaHatCone(droop: 18 * s)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.18), .clear],
                                          startPoint: .top, endPoint: .bottom))
                    .frame(width: 78 * s, height: 78 * s)
            }

            // Pom-pom on tip — positioned at the curve end (down-right)
            ZStack {
                Circle().fill(whiteShadow).frame(width: 14 * s, height: 14 * s).offset(x: 1, y: 1)
                Circle().fill(white).frame(width: 14 * s, height: 14 * s)
                Circle().fill(Color.white.opacity(0.35))
                    .frame(width: 5 * s, height: 5 * s)
                    .offset(x: -2 * s, y: -2 * s)
            }
            .offset(x: 22 * s, y: -8 * s)

            // White fluffy band at the BASE of the hat
            RoundedRectangle(cornerRadius: 10 * s)
                .fill(white)
                .frame(width: 86 * s, height: 14 * s)
                .overlay(
                    RoundedRectangle(cornerRadius: 10 * s)
                        .stroke(whiteShadow, lineWidth: 0.5)
                )
                .offset(y: 30 * s)
        }
        // -(36 + 23*s): band render center = outer_offset + 30*s, half-height = 7*s.
        // Band TOP = outer_offset + 23*s = -36 = body top → band sits just inside head
        // (natural hat-on-head look, base band wraps around top of head).
        // Screen check: (-36 - 23s + 23s) × s_ext = -36s ✓
        .offset(y: -(36 + 23 * s))
    }
}

// Custom cone shape with a droop (top-right curve away from vertical)
private struct SantaHatCone: Shape {
    var droop: CGFloat       // sideways droop of the tip
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let baseY = rect.maxY * 0.85          // base sits a bit above bottom
        let tipX  = rect.midX + droop          // tip pulled to the right
        let tipY  = rect.minY * 0.05
        path.move(to: CGPoint(x: rect.minX + 4, y: baseY))      // base-left
        path.addQuadCurve(to: CGPoint(x: tipX, y: tipY),         // up to tip
                          control: CGPoint(x: rect.midX - 4, y: rect.midY * 0.4))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 4, y: baseY), // down right
                          control: CGPoint(x: rect.midX + 14, y: rect.midY * 0.6))
        path.closeSubpath()
        return path
    }
}
