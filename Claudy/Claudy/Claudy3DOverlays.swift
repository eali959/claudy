import SwiftUI
import Combine

// MARK: - Thinking dots overlay (V4 polish)
//
// Three bouncing terra-cotta dots shown above the 3D character when the
// chat is mid-stream / typing.  Mirrors the 2D character's `.thinkingDots`
// eye state — but instead of replacing the 3D pupils (which would require
// swapping USDZ materials at runtime), we float a SwiftUI overlay above
// the head.  Disappears smoothly when typing stops.
struct ThinkingDotsOverlay3D: View {
    @State private var phase: Int = 0
    private let pulse = Timer.publish(every: 0.18, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(
                        LinearGradient(colors: [
                            Color(red: 0.62, green: 0.26, blue: 0.14),
                            Color(red: 0.45, green: 0.16, blue: 0.08)
                        ], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 6, height: 6)
                    .offset(y: phase == i ? -3 : 0)
                    .scaleEffect(phase == i ? 1.25 : 1.0)
                    .animation(.easeInOut(duration: 0.18), value: phase)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.5))
        )
        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
        .onReceive(pulse) { _ in phase = (phase + 1) % 3 }
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Confetti burst (V4 polish, 3D)
//
// Lightweight SwiftUI confetti for celebrate / happy-bounce / love-eyes
// states in 3D mode.  2D already has a richer ConfettiView; this is a
// minimal port that doesn't require Metal — a handful of coloured shapes
// that fall from above the character with random rotations.
struct ConfettiBurst3D: View {
    @State private var pieces: [Piece] = (0..<28).map { _ in Piece.random() }
    @State private var t0: Date = .now
    private let timer = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

    private struct Piece: Identifiable {
        let id = UUID()
        let xStart: CGFloat
        let xEnd:   CGFloat
        let yEnd:   CGFloat
        let delay:  TimeInterval
        let dur:    TimeInterval
        let rotStart: Double
        let rotEnd:   Double
        let color:    Color
        let shape:    Int    // 0=rect 1=circle
        static func random() -> Piece {
            let palette: [Color] = [
                Color(red: 0.95, green: 0.50, blue: 0.20),
                Color(red: 1.0,  green: 0.78, blue: 0.30),
                Color(red: 0.62, green: 0.26, blue: 0.14),
                Color(red: 0.30, green: 0.78, blue: 0.92),
                Color(red: 0.55, green: 0.85, blue: 0.45)
            ]
            return Piece(
                xStart:   CGFloat.random(in: -8...8),
                xEnd:     CGFloat.random(in: -120...120),
                yEnd:     CGFloat.random(in: 140...260),
                delay:    TimeInterval.random(in: 0...0.25),
                dur:      TimeInterval.random(in: 0.9...1.6),
                rotStart: 0,
                rotEnd:   Double.random(in: -540...540),
                color:    palette.randomElement()!,
                shape:    Int.random(in: 0...1)
            )
        }
    }

    var body: some View {
        ZStack {
            ForEach(pieces) { p in
                let now = Date().timeIntervalSince(t0)
                let local = max(0, min(1, (now - p.delay) / p.dur))
                let eased = local < 0.5
                    ? 2 * local * local
                    : 1 - pow(-2 * local + 2, 2) / 2
                let x = p.xStart + (p.xEnd - p.xStart) * eased
                let y = p.yEnd * eased
                let rot = p.rotStart + (p.rotEnd - p.rotStart) * eased

                Group {
                    if p.shape == 0 {
                        Rectangle().fill(p.color).frame(width: 6, height: 10)
                    } else {
                        Circle().fill(p.color).frame(width: 7, height: 7)
                    }
                }
                .rotationEffect(.degrees(rot))
                .offset(x: x, y: y - 80)
                .opacity(local >= 1 ? 0 : 1.0 - eased * 0.3)
            }
        }
        .frame(width: 240, height: 320)
        .onReceive(timer) { _ in /* triggers re-render for time-based progress */ }
        .allowsHitTesting(false)
    }
}

// MARK: - Sleep ZZZ overlay

/// Floating "Z z z" bubbles above the character while sleeping.
/// Three Zs stagger: small (z), medium (Z), large (Z).  Each rises
/// independently on a repeating timer.  Works for both 2D and 3D mode.
struct SleepZZZOverlay: View {

    private struct ZBubble: Identifiable {
        let id: Int
        let size:  CGFloat   // font size
        let xOff:  CGFloat   // horizontal offset from anchor
        let delay: Double    // cycle start offset
        let dur:   Double    // one full rise cycle
    }

    private let bubbles: [ZBubble] = [
        ZBubble(id: 0, size: 10, xOff:  2, delay: 0.0, dur: 2.2),
        ZBubble(id: 1, size: 14, xOff:  9, delay: 0.7, dur: 2.4),
        ZBubble(id: 2, size: 18, xOff: 16, delay: 1.4, dur: 2.6),
    ]

    @State private var t0: Date = .now
    private let timer = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ForEach(bubbles) { b in
                let progress = cycleProgress(delay: b.delay, dur: b.dur)
                let rise = progress * 52          // total upward travel in pt
                let fade = progress < 0.6 ? min(1, progress * 3) : (1 - progress) * 2.5

                Text("z")
                    .font(.system(size: b.size, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [
                            Color(red: 0.55, green: 0.40, blue: 0.78),
                            Color(red: 0.42, green: 0.28, blue: 0.65)
                        ], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: Color(red: 0.55, green: 0.40, blue: 0.78).opacity(0.35),
                            radius: 3, y: 1)
                    .offset(x: b.xOff, y: -rise)
                    .opacity(fade)
            }
        }
        .frame(width: 44, height: 60, alignment: .bottomLeading)
        .allowsHitTesting(false)
        .onReceive(timer) { _ in }   // drives re-render for time-based progress
    }

    private func cycleProgress(delay: Double, dur: Double) -> CGFloat {
        let elapsed = Date().timeIntervalSince(t0)
        let local = ((elapsed - delay).truncatingRemainder(dividingBy: dur) + dur)
                        .truncatingRemainder(dividingBy: dur)
        return CGFloat(local / dur)
    }
}
