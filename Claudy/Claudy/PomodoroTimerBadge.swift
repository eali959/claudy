import SwiftUI

/// Floating badge above Claud-y showing Pomodoro state.
/// Only shown when the timer is running, paused, or complete - hidden while idle.
/// Start the timer via right-click → Focus Timer. Tap to pause/resume. Double-tap to reset.
struct PomodoroTimerBadge: View {
    let manager: PomodoroManager
    @State private var pulsing = false

    private var arcColor: Color {
        switch manager.state {
        case .idle:
            return Color.orange.opacity(0.35)
        case .running:
            return manager.remainingSeconds <= 300
                ? Color(red: 1, green: 0.35, blue: 0.1)   // urgent: last 5 min
                : Color.orange
        case .paused:
            return Color.yellow.opacity(0.75)
        case .complete:
            return Color.green
        }
    }

    private var arcTrim: Double {
        switch manager.state {
        case .idle, .complete: return 1.0   // full ring
        default:               return manager.progressFraction
        }
    }

    var body: some View {
        animatedBadge
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint)
    }

    private var animatedBadge: some View {
        badgeStack
            .frame(width: 42, height: 42)
            .scaleEffect(pulsing ? 1.04 : 1.0)
            .animation(pulseAnimation, value: pulsing)
            .onChange(of: manager.state) { _, newState in
                pulsing = (newState == .running || newState == .complete)
            }
            .onAppear { pulsing = (manager.state == .running) }
    }

    /// V5.10 — Extracted from `body` to keep each closure under the
    /// type-checker's complexity budget.
    private var badgeStack: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 3)
                .frame(width: 42, height: 42)
            // Progress arc — full when idle/complete, partial when active
            Circle()
                .trim(from: 0, to: arcTrim)
                .stroke(arcColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 42, height: 42)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: manager.progressFraction)
                .animation(.easeInOut(duration: 0.4), value: manager.state)
            // Dark pill background
            Circle()
                .fill(Color.black.opacity(0.58))
                .frame(width: 34, height: 34)
            // Centre content per state
            centreContent
        }
    }

    @ViewBuilder
    private var centreContent: some View {
        switch manager.state {
        case .idle:
            Image(systemName: "play.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.orange.opacity(0.85))

        case .running:
            Text(manager.displayTime)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()

        case .paused:
            VStack(spacing: 1) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(Color.yellow.opacity(0.9))
                Text(manager.displayTime)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }

        case .complete:
            // V5.10 — sealed checkmark, slightly larger than the old checkmark
            // for a clear "you did it" moment.  Pulse comes from the body-level
            // scaleEffect (which runs for both .running and .complete states).
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.green)
        }
    }

    /// V5.10 — extracted to keep `body` under the type-checker's complexity budget.
    private var pulseAnimation: Animation {
        if pulsing {
            return .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
        } else {
            return .spring(response: 0.3, dampingFraction: 0.7)
        }
    }

    /// V5.10 — extracted to a property so the SwiftUI type-checker doesn't
    /// time out on the inline ternary it had before.
    private var accessibilityLabel: String {
        let state = manager.state == .complete ? "complete" : manager.displayTime
        return "Focus timer: \(state)"
    }

    private var accessibilityHint: String {
        switch manager.state {
        case .idle:     return "Tap to start."
        case .running:  return "Tap to pause. Double-tap to reset."
        case .paused:   return "Tap to resume. Double-tap to reset."
        case .complete: return "Tap to restart. Double-tap to reset."
        }
    }
}
