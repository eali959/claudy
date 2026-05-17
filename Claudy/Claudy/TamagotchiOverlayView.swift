import SwiftUI

// MARK: - TamagotchiOverlayIfEnabled

/// Thin wrapper that reads the overlay-enabled preference and shows/hides the overlay.
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

/// Compact care stats shown below Claud-y when Tamagotchi mode is on.
/// Minimal: thin progress bars + three action buttons.
struct TamagotchiOverlayView: View {
    let manager: TamagotchiManager

    var body: some View {
        VStack(spacing: 8) {
            statBars
            actionButtons
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(width: 150)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
    }

    // MARK: - Stat bars

    private var statBars: some View {
        VStack(spacing: 5) {
            statRow(icon: "fork.knife",    value: manager.fullness,  color: Color(red: 0.80, green: 0.40, blue: 0.20), label: "Fed")
            statRow(icon: "face.smiling",  value: manager.happiness, color: Color(red: 0.95, green: 0.75, blue: 0.20), label: "Happy")
            statRow(icon: "bolt.fill",     value: manager.energy,    color: Color(red: 0.30, green: 0.80, blue: 0.90), label: "Energy")
        }
    }

    private func statRow(icon: String, value: Float, color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 13)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(barGradient(for: value, color: color))
                        .frame(width: max(4, geo.size.width * CGFloat(value / 100)))
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: value)
                }
            }
            .frame(height: 5)

            Text(String(format: "%2.0f%%", value))
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private func barGradient(for value: Float, color: Color) -> LinearGradient {
        let base = value < 25 ? color.opacity(0.55) : color
        return LinearGradient(
            colors: [base, base.opacity(0.65)],
            startPoint: .leading, endPoint: .trailing
        )
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        HStack(spacing: 5) {
            actionButton(icon: "fork.knife",     label: "Feed", color: Color(red: 0.80, green: 0.40, blue: 0.20)) {
                withAnimation(.spring(response: 0.3)) { manager.feed() }
            }
            actionButton(icon: "gamecontroller", label: "Play", color: Color(red: 0.95, green: 0.75, blue: 0.20)) {
                withAnimation(.spring(response: 0.3)) { manager.play() }
            }
            actionButton(icon: "hand.raised.fill", label: "Rest", color: Color(red: 0.30, green: 0.80, blue: 0.90)) {
                withAnimation(.spring(response: 0.3)) { manager.rest() }
            }
        }
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
