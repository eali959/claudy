import SwiftUI

// MARK: - CharacterAccessory (ACC-01)

/// Accessories that can be equipped on Claud-y.
/// Persisted to UserDefaults via `DefaultsKeys.activeAccessory`.
enum CharacterAccessory: String, CaseIterable {
    case none          = "none"
    case glasses       = "glasses"
    case tintedSunnies = "tintedSunnies"
    case heisenbergHat = "heisenbergHat"
    case capForward    = "capForward"
    case capBackward   = "capBackward"

    var displayName: String {
        switch self {
        case .none:          return "None"
        case .glasses:       return "Glasses"
        case .tintedSunnies: return "Tinted Sunnies"
        case .heisenbergHat: return "Heisenberg Hat"
        case .capForward:    return "Cap (Forward)"
        case .capBackward:   return "Cap (Backward)"
        }
    }

    var icon: String {
        switch self {
        case .none:          return "minus.circle"
        case .glasses:       return "eyeglasses"
        case .tintedSunnies: return "sunglasses"
        case .heisenbergHat: return "hat.widebrim"
        case .capForward:    return "graduationcap.fill"
        case .capBackward:   return "graduationcap"
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

        case .capForward:
            capView(backward: false)

        case .capBackward:
            capView(backward: true)
        }
    }

    // MARK: - Glasses

    @ViewBuilder
    private func glassesView(tinted: Bool) -> some View {
        let lensColor = tinted
            ? Color(red: 0.05, green: 0.55, blue: 0.35).opacity(0.65)
            : Color.clear
        let frameColor = Color(red: 0.18, green: 0.10, blue: 0.06)
        let s = scale

        // Eye positions from CharacterGeometry:
        //   HStack(spacing:17) with eyeSizeLarge=27 and eyeSizeSmall=23
        //   Total HStack width = 67; centered in 130pt frame
        //   Left eye center  ≈ x = -20, Right eye center ≈ x = +22
        ZStack {
            // Left lens — centered over the larger left eye
            RoundedRectangle(cornerRadius: 5 * s)
                .fill(lensColor)
                .overlay(RoundedRectangle(cornerRadius: 5 * s).stroke(frameColor, lineWidth: 1.5 * s))
                .frame(width: 26 * s, height: 17 * s)
                .offset(x: -20 * s)

            // Right lens — centered over the smaller right eye
            RoundedRectangle(cornerRadius: 5 * s)
                .fill(lensColor)
                .overlay(RoundedRectangle(cornerRadius: 5 * s).stroke(frameColor, lineWidth: 1.5 * s))
                .frame(width: 24 * s, height: 17 * s)
                .offset(x: 22 * s)

            // Bridge — between the inner edges of both lenses
            Rectangle()
                .fill(frameColor)
                .frame(width: 5 * s, height: 1.5 * s)
                .offset(x: 1 * s)

            // Left temple arm
            Rectangle()
                .fill(frameColor)
                .frame(width: 12 * s, height: 1.5 * s)
                .offset(x: -39 * s)

            // Right temple arm
            Rectangle()
                .fill(frameColor)
                .frame(width: 12 * s, height: 1.5 * s)
                .offset(x: 41 * s)
        }
        .offset(y: -12 * s)   // CharacterGeometry.eyesOffsetY — sits exactly on the eyes
    }

    // MARK: - Heisenberg Hat

    @ViewBuilder
    private func heisenbergHatView() -> some View {
        let s = scale
        let hatColor = Color(red: 0.14, green: 0.12, blue: 0.10)
        let bandColor = Color(red: 0.35, green: 0.25, blue: 0.15)

        ZStack(alignment: .bottom) {
            // Crown
            RoundedRectangle(cornerRadius: 6 * s)
                .fill(hatColor)
                .frame(width: 42 * s, height: 30 * s)
                .offset(y: -10 * s)

            // Band
            Rectangle()
                .fill(bandColor)
                .frame(width: 42 * s, height: 5 * s)
                .offset(y: -10 * s)

            // Brim
            Capsule()
                .fill(hatColor)
                .frame(width: 62 * s, height: 8 * s)
        }
        .offset(y: -58 * s)
    }

    // MARK: - Cap Forward

    @ViewBuilder
    private func capView(backward: Bool) -> some View {
        let s = scale

        if !backward {
            // ── Cap Forward: classic blue cap, brim clearly extends to the right ──
            let capColor  = Color(red: 0.16, green: 0.38, blue: 0.72)
            let brimColor = Color(red: 0.11, green: 0.28, blue: 0.55)

            ZStack {
                // Dome
                Ellipse()
                    .fill(capColor)
                    .frame(width: 54 * s, height: 30 * s)
                    .offset(y: -15 * s)

                // Brim — extends forward (right side), slightly angled down
                Capsule()
                    .fill(brimColor)
                    .frame(width: 44 * s, height: 10 * s)
                    .offset(x: 28 * s, y: -8 * s)
                    .rotationEffect(.degrees(7))

                // Brim underside shadow
                Capsule()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: 42 * s, height: 5 * s)
                    .offset(x: 28 * s, y: -4 * s)
                    .rotationEffect(.degrees(7))

                // Top button
                Circle()
                    .fill(capColor.opacity(0.65))
                    .frame(width: 6 * s, height: 6 * s)
                    .offset(y: -30 * s)
            }
            .offset(y: -48 * s)

        } else {
            // ── Cap Backward: red/crimson cap, brim behind, sweatband + snap tab visible ──
            let capColor  = Color(red: 0.72, green: 0.18, blue: 0.14)
            let bandColor = Color.white.opacity(0.90)

            ZStack {
                // Brim peeking from the back (left side), behind the dome
                Capsule()
                    .fill(capColor.opacity(0.50))
                    .frame(width: 34 * s, height: 8 * s)
                    .offset(x: -24 * s, y: -10 * s)

                // Dome (renders on top of brim)
                Ellipse()
                    .fill(capColor)
                    .frame(width: 54 * s, height: 30 * s)
                    .offset(y: -15 * s)

                // White sweatband strip across the front bottom edge
                Capsule()
                    .fill(bandColor)
                    .frame(width: 46 * s, height: 5 * s)
                    .offset(y: -3 * s)

                // Snap-closure tab visible at upper right
                RoundedRectangle(cornerRadius: 2 * s)
                    .fill(capColor.opacity(0.55))
                    .frame(width: 10 * s, height: 4 * s)
                    .offset(x: 21 * s, y: -22 * s)

                // Top button
                Circle()
                    .fill(capColor.opacity(0.65))
                    .frame(width: 6 * s, height: 6 * s)
                    .offset(y: -30 * s)
            }
            .offset(y: -48 * s)
        }
    }
}
