import SwiftUI

// MARK: - ConfettiView
// Pure SwiftUI particle burst - no library required.
// 22 coloured rectangles burst upward from centre, fade out over ~1s.
// Set allowsHitTesting(false) so it never blocks the character.

struct ConfettiView: View {

    private struct Particle: Identifiable {
        let id = UUID()
        let offsetX: CGFloat
        let offsetY: CGFloat
        let color: Color
        let width: CGFloat
        let height: CGFloat
        let delay: Double
        let finalRotation: Double
    }

    private static let palette: [Color] = [
        Color(red: 0.784, green: 0.361, blue: 0.220), // orange (Claud-y brand)
        .yellow,
        Color(red: 0.95, green: 0.65, blue: 0.25),
        .white,
        Color(red: 0.30, green: 0.82, blue: 0.90),
        Color(red: 0.95, green: 0.40, blue: 0.55),
    ]

    private let particles: [Particle] = (0..<24).map { _ in
        Particle(
            offsetX:       CGFloat.random(in: -90...90),
            offsetY:       CGFloat.random(in: -130...(-20)),
            color:         palette.randomElement() ?? .orange,
            width:         CGFloat.random(in: 5...9),
            height:        CGFloat.random(in: 8...14),
            delay:         Double.random(in: 0...0.25),
            finalRotation: Double.random(in: 180...540)
        )
    }

    @State private var launched = false

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.color)
                    .frame(width: p.width, height: p.height)
                    .rotationEffect(.degrees(launched ? p.finalRotation : 0))
                    .offset(x: launched ? p.offsetX : 0,
                            y: launched ? p.offsetY  : 0)
                    .opacity(launched ? 0 : 1)
                    .animation(
                        .easeOut(duration: 0.85).delay(p.delay),
                        value: launched
                    )
            }
        }
        .onAppear {
            withAnimation { launched = true }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        Color(white: 0.15)
        ConfettiView()
    }
    .frame(width: 200, height: 200)
}
