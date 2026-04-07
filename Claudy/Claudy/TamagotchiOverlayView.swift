import SwiftUI

// MARK: - TamagotchiOverlayIfEnabled

/// Thin wrapper that reads the overlay-enabled preference and shows/hides the overlay.
/// Using a separate view keeps `@AppStorage` out of `CharacterSceneView`.
struct TamagotchiOverlayIfEnabled: View {
    let manager: TamagotchiManager
    @AppStorage(DefaultsKeys.tamagotchiOverlayEnabled) private var overlayEnabled = false

    var body: some View {
        if overlayEnabled {
            TamagotchiOverlayView(manager: manager)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
        }
    }
}

// MARK: - TamagotchiOverlayView

/// A compact stat display shown below Claud-y when Tamagotchi overlay is enabled.
/// Shows Fullness, Happiness, and Energy as small labelled bars with action buttons.
/// Designed to stay out of the way — narrow, translucent, non-intrusive.
struct TamagotchiOverlayView: View {
    let manager: TamagotchiManager

    var body: some View {
        VStack(spacing: 5) {
            statBars
            actionButtons
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(width: 150)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }

    // MARK: - Stat bars

    private var statBars: some View {
        VStack(spacing: 3) {
            statRow(icon: "fork.knife", value: manager.fullness, color: Color(red: 0.784, green: 0.361, blue: 0.220), label: "Fed")
            statRow(icon: "face.smiling", value: manager.happiness, color: .yellow, label: "Happy")
            statRow(icon: "bolt.fill", value: manager.energy, color: .cyan, label: "Energy")
        }
    }

    private func statRow(icon: String, value: Float, color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 12)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(barGradient(for: value, color: color))
                        .frame(width: max(4, geo.size.width * CGFloat(value / 100)))
                        .animation(.spring(response: 0.4), value: value)
                }
            }
            .frame(height: 5)

            Text(String(format: "%2.0f%%", value))
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .trailing)
        }
    }

    private func barGradient(for value: Float, color: Color) -> LinearGradient {
        let opacity = value < 25 ? 0.5 : 1.0
        return LinearGradient(
            colors: [color.opacity(opacity), color.opacity(opacity * 0.7)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        HStack(spacing: 6) {
            actionButton(icon: "fork.knife", label: "Feed", color: Color(red: 0.784, green: 0.361, blue: 0.220)) {
                withAnimation(.spring(response: 0.3)) { manager.feed() }
            }
            actionButton(icon: "gamecontroller", label: "Play", color: .yellow) {
                withAnimation(.spring(response: 0.3)) { manager.play() }
            }
            actionButton(icon: "hand.raised.fill", label: "Rest", color: .cyan) {
                withAnimation(.spring(response: 0.3)) { manager.rest() }
            }
        }
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 8, weight: .medium))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
