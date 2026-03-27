import SwiftUI

/// Three bouncing orange dots shown while Claud-y is "thinking" before a response.
/// Matches the assistant bubble style (left-aligned, same corner radius + padding).
struct TypingIndicatorView: View {
    @State private var phase = false

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                dot(delay: 0.00)
                dot(delay: 0.15)
                dot(delay: 0.30)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
            )

            Spacer(minLength: 40)
        }
        .onAppear {
            // Tiny delay so the transition completes before the animation starts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                phase = true
            }
        }
        .onDisappear { phase = false }
    }

    private func dot(delay: Double) -> some View {
        Circle()
            .fill(Color.orange)
            .frame(width: 8, height: 8)
            .scaleEffect(phase ? 1.5 : 1.0)
            .animation(
                .easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: phase
            )
    }
}

#Preview {
    TypingIndicatorView()
        .padding()
        .frame(width: 280)
}
