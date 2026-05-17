import SwiftUI

// MARK: - MatrixGlitchOverlay
//
// Matrix-rain style glitch effect used as the V4 demo's 2D→3D
// transition.  Pure SwiftUI — no Metal shaders, no PNG strips.
// Stacks three layers:
//   1. Vertical green character columns (Symbol-glyph rain)
//   2. Horizontal scan-lines (CRT vibe)
//   3. Chromatic aberration tint pulses
//
// Use as a `.overlay { MatrixGlitchOverlay(intensity: ...) }` modifier
// or via the VStack composition in DemoModeManager.
struct MatrixGlitchOverlay: View {
    /// 0 = invisible, 1 = full intensity.  Animate this with .animation
    /// for fade-in / fade-out at scene boundaries.
    var intensity: Double = 1.0

    @State private var scrollOffset: CGFloat = 0
    @State private var aberrationPhase: Double = 0
    @State private var columns: [Column] = (0..<28).map { _ in Column.random() }

    private struct Column: Identifiable {
        let id = UUID()
        var x: CGFloat
        var glyphs: [String]
        var startY: CGFloat
        var speed: CGFloat
        static func random() -> Column {
            Column(
                x: CGFloat.random(in: 0...1),
                glyphs: (0..<12).map { _ in String(Self.alphabet.randomElement()!) },
                startY: CGFloat.random(in: -1.2 ... -0.2),
                speed: CGFloat.random(in: 0.5...1.4)
            )
        }
        static let alphabet = Array("01アイウエオカキクケコサシスセソabcdef0123456789")
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Black backdrop (subtle so character still readable behind)
                Color.black.opacity(0.45 * intensity)

                // Matrix rain — green character columns
                ForEach(columns) { col in
                    let baseX = col.x * geo.size.width
                    VStack(spacing: 4) {
                        ForEach(0..<col.glyphs.count, id: \.self) { i in
                            Text(col.glyphs[i])
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.40, green: 1.0, blue: 0.40).opacity(1.0),
                                            Color(red: 0.10, green: 0.55, blue: 0.10).opacity(0.0)
                                        ],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .opacity(Double(i) / Double(col.glyphs.count))
                        }
                    }
                    .position(x: baseX,
                              y: (col.startY + scrollOffset * col.speed) * geo.size.height
                                  .truncatingRemainder(dividingBy: geo.size.height * 1.5)
                                + geo.size.height * 0.5)
                    .opacity(intensity)
                }

                // Horizontal scan lines
                VStack(spacing: 4) {
                    ForEach(0..<Int(geo.size.height / 4), id: \.self) { _ in
                        Color.white.opacity(0.04)
                            .frame(height: 1)
                    }
                }
                .opacity(intensity * 0.8)
                .blendMode(.overlay)

                // Chromatic aberration — soft red+cyan offsets (tinted pulses)
                Color.red.opacity(0.10 * intensity * (sin(aberrationPhase) * 0.5 + 0.5))
                    .blendMode(.screen)
                    .offset(x: 2 * sin(aberrationPhase * 1.7))
                Color.cyan.opacity(0.10 * intensity * (cos(aberrationPhase) * 0.5 + 0.5))
                    .blendMode(.screen)
                    .offset(x: -2 * cos(aberrationPhase * 1.3))
            }
            .compositingGroup()
            .allowsHitTesting(false)
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    scrollOffset = 1.0
                }
                Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { t in
                    // Capture only the Sendable Bool before crossing the actor boundary.
                    // Passing `t` (Timer) directly into a @MainActor Task is a Swift 6 error.
                    let shouldStop = intensity == 0
                    if shouldStop { t.invalidate(); return }
                    Task { @MainActor in
                        aberrationPhase += 0.18
                    }
                }
            }
        }
    }
}
