import SwiftUI

// MARK: - SpeechBubbleView
// Floating speech bubble that appears above Claud-y's head.
// Tap anywhere on the bubble or the X button to dismiss it early.

struct SpeechBubbleView: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .padding(.trailing, 18)   // room for X button

                // X dismiss button
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(5)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .padding(.trailing, 2)
            }
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture { onDismiss() }

            // Downward-pointing triangle tail
            BubbleTail()
                .fill(.ultraThinMaterial)
                .frame(width: 14, height: 8)
        }
        .frame(maxWidth: 210)
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    ZStack {
        Color(white: 0.15)
        SpeechBubbleView(text: "Ooh, that's a lot of text. Want me to summarise?") {}
    }
    .frame(width: 300, height: 200)
}
