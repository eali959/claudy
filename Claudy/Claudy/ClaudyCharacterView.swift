import SwiftUI

// MARK: - ClaudyCharacterView
// NOTE: Do not refactor the structure of this view without consulting CLAUDE.md.

struct ClaudyCharacterView: View {
    let animationState: CharacterAnimationState
    var isBlinking: Bool = false
    var irisOffset: CGPoint = .zero
    var tickleIntensity: TickleIntensity = .none
    var danceMove: DanceMove = .groove
    var onTap: () -> Void = {}
    var onDoubleTap: () -> Void = {}
    var onDragBegan: () -> Void = {}
    var onDragChanged: (CGSize) -> Void = { _ in }
    var onDragEnded: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var bobOffset: CGFloat = 0
    @State private var celebrateScale: CGFloat = 1
    @State private var dotPhase: Int = 0
    /// 0 = closed, 1 = wide open - drives lip-sync shape interpolation
    @State private var mouthOpenAmount: CGFloat = 0
    @State private var isDragging = false
    @State private var lastDragTranslation: CGSize = .zero
    @State private var wiggleOffset: CGFloat = 0
    @State private var jumpOffset: CGFloat = 0
    @State private var dragTilt: Double = 0
    @State private var armFlair: Bool = false
    @State private var armFlairTask: Task<Void, Never>? = nil
    // Stored so we can invalidate on disappear - avoids timer accumulation if the
    // view is ever removed and re-added to the hierarchy.
    @State private var talkingTimer: Timer? = nil
    @State private var dotTimer: Timer? = nil

    // Dance mode state
    @State private var danceSpinAngle: Double = 0
    @State private var danceJumpOffset: CGFloat = 0
    @State private var danceGlowPulse: Bool = false
    @State private var danceSpinTask: Task<Void, Never>? = nil
    @State private var danceScalePulse: CGFloat = 1.0

    // Palette - spec: #C85C38 body, #E07048 highlight, #9A3520 shadow, #A84020 limbs
    private let bodyColor  = Color(red: 0.784, green: 0.361, blue: 0.220) // #C85C38
    private let highlight  = Color(red: 0.878, green: 0.439, blue: 0.282) // #E07048
    private let shadowClr  = Color(red: 0.604, green: 0.208, blue: 0.125) // #9A3520
    private let limbColor  = Color(red: 0.659, green: 0.251, blue: 0.125) // #A84020
    private let darkBrown  = Color(red: 0.102, green: 0.039, blue: 0.020) // #1a0a05

    var body: some View {
        ZStack {
            // Sleeping Zs
            if animationState == .sleeping {
                sleepingZs.offset(x: 40, y: -50)
            }

            // Startled "!"
            if animationState == .surprised {
                Text("!")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(bodyColor)
                    .offset(x: 22, y: -58)
                    .transition(.opacity.combined(with: .scale))
            }

            // Dance glow — pulsing orange aura, sits behind everything
            if animationState == .dancing {
                RoundedRectangle(cornerRadius: 22)
                    .fill(bodyColor.opacity(danceGlowPulse ? 0.5 : 0.08))
                    .frame(width: 122, height: 100)
                    .blur(radius: danceGlowPulse ? 20 : 8)
                    .animation(
                        .easeInOut(duration: 0.38).repeatForever(autoreverses: true),
                        value: danceGlowPulse
                    )
                    .allowsHitTesting(false)
            }

            // Character group
            ZStack {
                // Drop shadow
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.25))
                    .frame(width: 90, height: 72)
                    .blur(radius: 6)
                    .offset(x: 3, y: 46)

                // Body
                RoundedRectangle(cornerRadius: 16)
                    .fill(bodyColor)
                    .frame(width: 90, height: 72)

                // Upper highlight overlay
                RoundedRectangle(cornerRadius: 16)
                    .fill(highlight.opacity(0.50))
                    .frame(width: 90, height: 72)
                    .mask(alignment: .top) {
                        Rectangle().frame(width: 90, height: 36)
                    }

                // Lower shadow overlay
                RoundedRectangle(cornerRadius: 16)
                    .fill(shadowClr.opacity(0.28))
                    .frame(width: 90, height: 72)
                    .mask(alignment: .bottom) {
                        Rectangle().frame(width: 90, height: 36)
                    }

                // Soft top-left catchlight
                RoundedRectangle(cornerRadius: 16)
                    .fill(RadialGradient(
                        colors: [Color.white.opacity(0.20), Color.clear],
                        center: UnitPoint(x: 0.22, y: 0.18),
                        startRadius: 0, endRadius: 38
                    ))
                    .frame(width: 90, height: 72)

                leftArm
                rightArm
                feet.offset(y: 44)
                face
            }
            .offset(x: wiggleOffset, y: bobOffset + jumpOffset + danceJumpOffset - 10)
            .rotationEffect(.degrees(dragTilt + (animationState == .dancing ? danceSpinAngle : 0)))
            .scaleEffect(
                animationState == .celebrating  ? celebrateScale :
                animationState == .dancing      ? danceScalePulse :
                animationState == .headbanging  ? 1.0 :
                animationState == .alert        ? 1.05 : 1.0
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: animationState)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: dragTilt)
            .animation(.easeInOut(duration: 0.924), value: danceSpinAngle)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: danceMove)
            .animation(.spring(response: 0.12, dampingFraction: 0.45), value: danceScalePulse)
        }
        .frame(width: 130, height: 150)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        lastDragTranslation = .zero
                        onDragBegan()
                    }
                    // Pass only the delta since the last event, not cumulative translation.
                    // Cumulative translation is unreliable for window dragging because the
                    // window (and its coordinate system) moves with each update.
                    let delta = CGSize(
                        width:  value.translation.width  - lastDragTranslation.width,
                        height: value.translation.height - lastDragTranslation.height
                    )
                    lastDragTranslation = value.translation
                    let tilt = max(-8.0, min(8.0, Double(value.translation.width) * 0.12))
                    dragTilt = tilt
                    onDragChanged(delta)
                }
                .onEnded { _ in
                    isDragging = false
                    lastDragTranslation = .zero
                    dragTilt = 0
                    onDragEnded()
                }
        )
        .onTapGesture(count: 2) { onDoubleTap() }
        .onTapGesture { onTap() }
        .onAppear {
            startBobAnimation()
            startTalkingAnimation()
            startCelebrationAnimation()
            startDotAnimation()
        }
        .onDisappear {
            talkingTimer?.invalidate()
            talkingTimer = nil
            dotTimer?.invalidate()
            dotTimer = nil
        }
        // Single merged onChange for animationState
        .onChange(of: animationState) { _, newState in
            startBobAnimation()
            startCelebrationAnimation()
            if newState == .surprised { applyStartledJump() }

            // Arm flair: waving, dancing, and headbanging use it
            if newState == .waving || newState == .dancing || newState == .headbanging {
                startArmFlair()
            } else if newState != .tickled || tickleIntensity != .full {
                stopArmFlair()
            }

            // Dance glow: start when entering, clear when leaving
            if newState == .dancing {
                startDanceGlow()
            } else {
                danceGlowPulse = false
                danceScalePulse = 1.0
                // Unwind any active shimmy / jump / spin cleanly
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    wiggleOffset    = 0
                    danceJumpOffset = 0
                }
                danceSpinTask?.cancel()
                danceSpinTask = nil
                danceSpinAngle = danceSpinAngle.truncatingRemainder(dividingBy: 360)
            }

            if newState != .talking { mouthOpenAmount = 0 }
        }
        .onChange(of: danceMove) { _, move in
            guard animationState == .dancing else { return }
            handleDanceMove(move)
        }
        .onChange(of: tickleIntensity) { _, intensity in
            applyWiggle(intensity)
        }
    }

    // MARK: - Feet

    private var feet: some View {
        ZStack {
            footShape(at: -28)
            footShape(at:  -8)
            footShape(at:   8)
            footShape(at:  28)
        }
        .frame(width: 90, height: 17)
    }

    private func footShape(at x: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(limbColor)
            .frame(width: 18, height: 17)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 12, height: 4)
                    .offset(y: 3)
            }
            .offset(x: x)
    }

    // MARK: - Arms

    // MARK: - Dance arm helpers

    private var danceLeftArmAngle: Double {
        switch danceMove {
        case .bothArmsUp, .bigJump, .throwHands: return -72
        case .leftArmUp:                          return -84
        case .spin:                               return -62
        case .shimmy:                             return armFlair ? -56 : 16
        case .freeze:                             return 24
        case .groove, .chestPop:                  return armFlair ? -52 : 22
        case .rightArmUp:                         return 34
        case .pointUp:                            return 20       // left at hip
        case .lowRide:                            return armFlair ? -44 : 44  // arms wide
        }
    }

    private var danceRightArmAngle: Double {
        switch danceMove {
        case .bothArmsUp, .bigJump, .throwHands: return 72
        case .rightArmUp:                         return 84
        case .spin:                               return 62
        case .shimmy:                             return armFlair ? 56 : -16
        case .freeze:                             return -24
        case .groove, .chestPop:                  return armFlair ? 52 : -22
        case .leftArmUp:                          return -34
        case .pointUp:                            return 86       // right arm pointing up
        case .lowRide:                            return armFlair ? 44 : -44  // arms wide
        }
    }

    private var danceLeftArmRaised: Bool {
        switch danceMove {
        case .bothArmsUp, .bigJump, .leftArmUp, .spin, .throwHands: return true
        case .groove, .shimmy, .chestPop: return armFlair
        case .lowRide: return false
        default: return false
        }
    }

    private var danceRightArmRaised: Bool {
        switch danceMove {
        case .bothArmsUp, .bigJump, .rightArmUp, .spin, .throwHands, .pointUp: return true
        case .groove, .shimmy, .chestPop: return armFlair
        case .lowRide: return false
        default: return false
        }
    }

    private var leftArm: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(limbColor)
            .frame(width: 14, height: 16)
            .rotationEffect(.degrees(
                animationState == .dancing                  ? danceLeftArmAngle :
                animationState == .celebrating              ? -60 :
                animationState == .thinking                 ? -18 :
                animationState == .facepalm                 ? -48 :
                (animationState == .tickled && armFlair)    ? -55 : 28
            ))
            .offset(x: -52, y: (animationState == .dancing && danceLeftArmRaised) ? -12 :
                                (animationState == .celebrating ||
                                 animationState == .facepalm ||
                                 (animationState == .tickled && armFlair)) ? -8 : 8)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: animationState)
            .animation(.spring(response: 0.15, dampingFraction: 0.4), value: armFlair)
            .animation(.spring(response: 0.2, dampingFraction: 0.45), value: danceMove)
    }

    private var rightArm: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(limbColor)
            .frame(width: 14, height: 16)
            .rotationEffect(.degrees(
                animationState == .dancing                  ?  danceRightArmAngle :
                animationState == .celebrating              ?  60 :
                (animationState == .waving && armFlair)     ? -80 :
                animationState == .waving                   ? -65 :
                (animationState == .tickled && armFlair)    ?  55 : -28
            ))
            .offset(x: 52, y: (animationState == .dancing && danceRightArmRaised) ? -12 :
                               (animationState == .celebrating ||
                                animationState == .waving ||
                                (animationState == .tickled && armFlair)) ? -8 : 8)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: animationState)
            .animation(.spring(response: 0.15, dampingFraction: 0.4), value: armFlair)
            .animation(.spring(response: 0.2, dampingFraction: 0.45), value: danceMove)
    }

    // MARK: - Face

    private var face: some View {
        ZStack {
            eyes.offset(y: -12)
            mouth.offset(y: 14)
        }
    }

    // MARK: - Eyes

    @ViewBuilder
    private var eyes: some View {
        switch animationState {
        case .celebrating, .waving, .dancing:
            HStack(spacing: 20) { arcEyeUp; arcEyeUp }
        case .headbanging:
            // Intense squint — rock face
            HStack(spacing: 17) { squintyEye; squintyEye }
        case .vibing:
            // Half-closed content eyes — in the zone
            HStack(spacing: 17) { vibeEye(size: 27); vibeEye(size: 23) }
        case .sleeping:
            HStack(spacing: 22) { sleepEye; sleepEye }
        case .drowsy:
            HStack(spacing: 17) { drowsyEye(size: 27); drowsyEye(size: 23) }
        case .thinking:
            thinkingDots
        case .tickled:
            HStack(spacing: 20) { arcEyeDown; arcEyeDown }
        case .alert:
            HStack(spacing: 17) {
                pixarEye(size: 27).scaleEffect(1.2)
                pixarEye(size: 23).scaleEffect(1.2)
            }
        case .surprised:
            HStack(spacing: 17) {
                pixarEye(size: 27).scaleEffect(1.4)
                pixarEye(size: 23).scaleEffect(1.4)
            }
        case .facepalm:
            HStack(spacing: 20) { squintyEye; squintyEye }
        default:
            HStack(spacing: 17) {
                pixarEye(size: 27)
                pixarEye(size: 23)
            }
        }
    }

    /// Facepalm - tight frustrated squint, thinner than drowsy
    private var squintyEye: some View {
        ZStack {
            Capsule()
                .fill(Color.white)
                .frame(width: 18, height: 7)
            Capsule()
                .fill(darkBrown)
                .frame(width: 18, height: 7)
                .mask(alignment: .bottom) {
                    Rectangle().frame(width: 18, height: 4)
                }
        }
    }

    /// Pixar-style eye with iris tracking
    private func pixarEye(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: size, height: isBlinking ? 2.5 : size)
                .animation(.easeInOut(duration: 0.08), value: isBlinking)

            if !isBlinking {
                Circle()
                    .fill(darkBrown)
                    .frame(width: size * 0.55, height: size * 0.55)
                    .offset(x: irisOffset.x, y: irisOffset.y)

                Circle()
                    .fill(Color.white.opacity(0.88))
                    .frame(width: size * 0.22, height: size * 0.22)
                    .offset(x: irisOffset.x + size * 0.12, y: irisOffset.y - size * 0.14)
            }
        }
        .animation(.easeOut(duration: 0.12), value: irisOffset.x)
        .animation(.easeOut(duration: 0.12), value: irisOffset.y)
    }

    /// Drowsy - heavy drooping eyelid over squinted eye
    private func drowsyEye(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: size, height: size * 0.42)
            // Dark iris peeking under lid
            Circle()
                .fill(darkBrown)
                .frame(width: size * 0.32, height: size * 0.18)
                .offset(y: size * 0.04)
        }
    }

    /// Vibe - half-closed but relaxed and content, slightly more open than drowsy
    private func vibeEye(size: CGFloat) -> some View {
        ZStack {
            // Sclera — taller than drowsy, shorter than normal
            Capsule()
                .fill(Color.white)
                .frame(width: size, height: size * 0.58)
            // Iris — centred, visible
            Circle()
                .fill(darkBrown)
                .frame(width: size * 0.38, height: size * 0.38)
                .offset(y: size * 0.04)
            // Catchlight
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: size * 0.14, height: size * 0.14)
                .offset(x: size * 0.1, y: size * 0.0)
        }
    }

    /// Celebrating ^ arc
    private var arcEyeUp: some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 9))
            p.addQuadCurve(to: CGPoint(x: 16, y: 9), control: CGPoint(x: 8, y: -1))
        }
        .stroke(darkBrown, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        .frame(width: 16, height: 11)
    }

    /// Tickled - arc curving downward (happy scrunch)
    private var arcEyeDown: some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 0))
            p.addQuadCurve(to: CGPoint(x: 16, y: 0), control: CGPoint(x: 8, y: 9))
        }
        .stroke(darkBrown, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        .frame(width: 16, height: 10)
    }

    /// Sleeping - closed flat line
    private var sleepEye: some View {
        Capsule().fill(darkBrown).frame(width: 14, height: 3)
    }

    /// Thinking - three pulsing dots
    private var thinkingDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(darkBrown)
                    .frame(width: 7, height: 7)
                    .scaleEffect(dotPhase == i ? 1.35 : 0.75)
                    .opacity(dotPhase == i ? 1.0 : 0.45)
                    .animation(.easeInOut(duration: 0.3), value: dotPhase)
            }
        }
    }

    // MARK: - Mouth

    @ViewBuilder
    private var mouth: some View {
        switch animationState {
        case .talking:
            // Lip-sync: interpolate width (11-17) and height (2-12) from mouthOpenAmount
            Ellipse()
                .fill(Color(red: 0.22, green: 0.07, blue: 0.04))
                .frame(
                    width:  11 + mouthOpenAmount * 6,
                    height:  2 + mouthOpenAmount * 10
                )
                .animation(.easeInOut(duration: 0.07), value: mouthOpenAmount)

        case .sleeping, .drowsy:
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addQuadCurve(to: CGPoint(x: 10, y: 0), control: CGPoint(x: 5, y: 2))
            }
            .stroke(darkBrown, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .frame(width: 10, height: 4)

        case .tickled:
            VStack(spacing: 1) {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addQuadCurve(to: CGPoint(x: 18, y: 0), control: CGPoint(x: 9, y: 9))
                }
                .stroke(darkBrown, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 18, height: 10)

                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white)
                            .frame(width: 4, height: 3)
                    }
                }
            }

        case .surprised, .confused:
            Circle()
                .strokeBorder(Color(red: 0.22, green: 0.07, blue: 0.04), lineWidth: 2)
                .frame(width: 9, height: 9)

        case .dancing:
            // Wider, more open grin than celebrating
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addQuadCurve(to: CGPoint(x: 22, y: 0), control: CGPoint(x: 11, y: 14))
            }
            .stroke(darkBrown, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: 22, height: 15)

        case .headbanging:
            // Wide open rock mouth — teeth showing
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addQuadCurve(to: CGPoint(x: 20, y: 0), control: CGPoint(x: 10, y: 14))
                }
                .stroke(darkBrown, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 20, height: 14)
                // Teeth
                HStack(spacing: 2) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white)
                            .frame(width: 3.5, height: 4)
                    }
                }
                .offset(y: 2)
            }

        case .vibing:
            // Small relaxed smile — content, not ecstatic
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addQuadCurve(to: CGPoint(x: 12, y: 0), control: CGPoint(x: 6, y: 6))
            }
            .stroke(darkBrown, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 12, height: 7)

        case .celebrating, .waving:
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addQuadCurve(to: CGPoint(x: 18, y: 0), control: CGPoint(x: 9, y: 11))
            }
            .stroke(darkBrown, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: 18, height: 12)

        case .facepalm:
            Capsule()
                .fill(darkBrown)
                .frame(width: 14, height: 2.5)

        default:
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addQuadCurve(to: CGPoint(x: 13, y: 0), control: CGPoint(x: 6.5, y: 5))
            }
            .stroke(darkBrown, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 13, height: 6)
        }
    }

    // MARK: - Sleeping Zs

    private var sleepingZs: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach([("z", 9.0), ("z", 12.0), ("Z", 16.0)], id: \.1) { letter, size in
                Text(letter)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(bodyColor.opacity(0.55))
            }
        }
    }

    // MARK: - Animations

    private func startBobAnimation() {
        guard !reduceMotion else { bobOffset = 0; return }
        let duration: Double = animationState == .dancing      ? 0.36 :  // fast groove bounce
                               animationState == .headbanging  ? 0.13 :  // ultra-fast headbang
                               animationState == .vibing       ? 1.10 :  // slow chill sway
                               animationState == .sleeping     ? 3.2  :
                               animationState == .drowsy       ? 2.5  : 1.9
        let target: CGFloat  = animationState == .dancing      ? -16  :  // big energetic bounce
                               animationState == .headbanging  ? -26  :  // massive headbang
                               animationState == .vibing       ? -8   :  // gentle vibe
                               animationState == .sleeping     ? -2   :
                               animationState == .drowsy       ? -4   : -6
        // Reset to 0 without animation first - this cleanly cancels any existing
        // repeatForever transaction on bobOffset so the new one starts fresh
        // rather than stacking on top and causing interference.
        bobOffset = 0
        withAnimation(Animation.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            bobOffset = target
        }
    }

    private func startTalkingAnimation() {
        talkingTimer?.invalidate()
        // Lip-sync: cycle through phoneme-shaped mouth openings at speech rhythm.
        // Weights approximate real speech - more mid-open than fully open or closed.
        let shapes: [CGFloat] = [
            0.05, 0.15, 0.45, 0.65, 0.85, 0.55, 0.30, 0.70,
            0.10, 0.50, 0.90, 0.40, 0.20, 0.75, 0.35, 0.60,
        ]
        var shapeIndex = 0
        // Note: animationState is a `let` prop captured by value at timer creation, so we
        // cannot guard on it here; the guard would always check the creation-time value.
        // Instead, always update mouthOpenAmount; the mouth switch only renders the
        // animated ellipse when animationState == .talking, so non-talking states are
        // unaffected. onChange resets mouthOpenAmount to 0 when leaving .talking.
        talkingTimer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { _ in
            mouthOpenAmount = shapes[shapeIndex % shapes.count]
            shapeIndex += 1
        }
    }

    private func startCelebrationAnimation() {
        guard !reduceMotion else { celebrateScale = 1.0; return }
        // Reset without animation to cleanly replace any existing repeatForever.
        celebrateScale = 1.0
        withAnimation(Animation.easeInOut(duration: 0.28).repeatForever(autoreverses: true)) {
            celebrateScale = animationState == .celebrating ? 1.07 : 1.0
        }
    }

    private func startDotAnimation() {
        dotTimer?.invalidate()
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.38, repeats: true) { _ in
            guard animationState == .thinking else { return }
            dotPhase = (dotPhase + 1) % 3
        }
    }

    private func applyWiggle(_ intensity: TickleIntensity) {
        switch intensity {
        case .none:
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { wiggleOffset = 0 }
            stopArmFlair()
        case .light:
            guard !reduceMotion else { return }
            stopArmFlair()
            withAnimation(.easeInOut(duration: 0.20).repeatForever(autoreverses: true)) { wiggleOffset = 4 }
        case .full:
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.07).repeatForever(autoreverses: true)) { wiggleOffset = 4 }
            startArmFlair()
        }
    }

    private func startArmFlair() {
        armFlairTask?.cancel()
        armFlairTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { break }
                armFlair.toggle()
            }
        }
    }

    private func stopArmFlair() {
        armFlairTask?.cancel()
        armFlairTask = nil
        armFlair = false
    }

    private func startDanceGlow() {
        guard !reduceMotion else { return }
        danceGlowPulse = false
        // Small delay lets the entrance animation settle before the pulse starts
        Task {
            try? await Task.sleep(for: .milliseconds(60))
            danceGlowPulse = true
        }
    }

    /// Drives character-level effects for each incoming DanceMove.
    ///
    /// Arm angles and y-offsets are handled declaratively via danceLeftArmAngle /
    /// danceRightArmAngle / danceLeftArmRaised / danceRightArmRaised. This method
    /// handles the imperative side: shimmy wiggle, spin rotation, freeze snap, big jump.
    private func handleDanceMove(_ move: DanceMove) {
        switch move {

        case .spin:
            stopArmFlair()
            danceSpinTask?.cancel()
            withAnimation(.easeInOut(duration: 0.924)) { danceSpinAngle += 360 }
            // Normalize angle after spin completes — 360° mod 360 = 0, same visual
            danceSpinTask = Task {
                try? await Task.sleep(for: .milliseconds(950))
                guard !Task.isCancelled else { return }
                danceSpinAngle = danceSpinAngle.truncatingRemainder(dividingBy: 360)
                startArmFlair()
            }

        case .freeze:
            stopArmFlair()
            danceScalePulse = 1.0
            withAnimation(.spring(response: 0.12, dampingFraction: 0.55)) { wiggleOffset = 0 }
            withAnimation(.spring(response: 0.12, dampingFraction: 0.55)) { danceJumpOffset = 0 }

        case .bigJump:
            stopArmFlair()
            withAnimation(.spring(response: 0.16, dampingFraction: 0.38)) {
                danceJumpOffset = -28
                danceScalePulse = 1.08
            }
            Task {
                try? await Task.sleep(for: .milliseconds(240))
                withAnimation(.spring(response: 0.36, dampingFraction: 0.60)) {
                    danceJumpOffset = 0
                    danceScalePulse = 1.0
                }
                try? await Task.sleep(for: .milliseconds(150))
                startArmFlair()
            }

        case .shimmy:
            startArmFlair()
            danceJumpOffset = 0
            danceScalePulse = 1.0
            withAnimation(.easeInOut(duration: 0.09).repeatForever(autoreverses: true)) {
                wiggleOffset = 14
            }

        case .throwHands:
            stopArmFlair()
            withAnimation(.spring(response: 0.14, dampingFraction: 0.38)) {
                danceScalePulse = 1.10
                danceJumpOffset = -12
            }
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation(.spring(response: 0.32, dampingFraction: 0.60)) {
                    danceScalePulse = 1.0
                    danceJumpOffset = 0
                }
                try? await Task.sleep(for: .milliseconds(100))
                startArmFlair()
            }

        case .chestPop:
            stopArmFlair()
            withAnimation(.spring(response: 0.10, dampingFraction: 0.40)) { danceScalePulse = 1.13 }
            Task {
                try? await Task.sleep(for: .milliseconds(160))
                withAnimation(.spring(response: 0.28, dampingFraction: 0.58)) { danceScalePulse = 1.0 }
                try? await Task.sleep(for: .milliseconds(120))
                startArmFlair()
            }

        case .lowRide:
            startArmFlair()
            danceJumpOffset = 0
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                danceScalePulse = 0.90
                wiggleOffset = 0
            }

        case .pointUp:
            stopArmFlair()
            danceScalePulse = 1.0
            danceJumpOffset = 0
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { wiggleOffset = 0 }

        case .groove, .leftArmUp, .rightArmUp, .bothArmsUp:
            startArmFlair()
            danceJumpOffset = 0
            withAnimation(.spring(response: 0.28, dampingFraction: 0.58)) {
                wiggleOffset = 0
                danceScalePulse = (move == .bothArmsUp) ? 1.05 : 1.0
            }
        }
    }

    private func applyStartledJump() {
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) { jumpOffset = -8 }
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { jumpOffset = 0 }
        }
    }
}

#Preview {
    HStack(spacing: 6) {
        ForEach([
            CharacterAnimationState.idle, .thinking, .celebrating,
            .sleeping, .drowsy, .tickled, .alert, .waving, .facepalm
        ], id: \.rawValue) { state in
            VStack {
                ClaudyCharacterView(animationState: state)
                    .frame(width: 130, height: 130)
                Text(state.rawValue).font(.caption2)
            }
        }
    }
    .padding()
    .background(Color(white: 0.15))
}
