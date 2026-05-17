import CoreGraphics

/// All hard-coded drawing constants for ClaudyCharacterView.
/// Phase 4 AnimationConfig will reference these for data-driven animation.
/// All values are static let — no mutable state.
struct CharacterGeometry {
    // MARK: - Body
    static let bodyWidth:           CGFloat = 90
    static let bodyHeight:          CGFloat = 72
    static let bodyCorner:          CGFloat = 16

    // MARK: - Drop shadow (body-sized, blurred)
    static let shadowWidth:         CGFloat = 90
    static let shadowHeight:        CGFloat = 72
    static let shadowCorner:        CGFloat = 16
    static let shadowBlur:          CGFloat = 6
    static let shadowOffsetX:       CGFloat = 3
    static let shadowOffsetY:       CGFloat = 46

    // MARK: - Dance glow ellipse
    static let glowWidth:           CGFloat = 122
    static let glowHeight:          CGFloat = 100
    static let glowCorner:          CGFloat = 22

    // MARK: - Overall character frame
    static let characterFrameWidth:  CGFloat = 130
    static let characterFrameHeight: CGFloat = 150

    // MARK: - Feet (v4.0: two-leg biped — was four legs)
    static let feetGroupOffsetY:    CGFloat = 44
    static let feetFrameWidth:      CGFloat = 90
    static let feetFrameHeight:     CGFloat = 20
    static let footWidth:           CGFloat = 22   // slightly wider for biped stance
    static let footHeight:          CGFloat = 20
    static let footCorner:          CGFloat = 7
    static let footPositions:       [CGFloat] = [-16, 16]   // two legs: left, right

    // MARK: - Arms
    static let armWidth:            CGFloat = 14
    static let armHeight:           CGFloat = 16
    static let armCorner:           CGFloat = 7
    static let armOffsetX:          CGFloat = 52    // left arm: -52, right arm: +52

    // MARK: - Eyes (default size, used in pixarEye calls)
    static let eyeSizeLarge:        CGFloat = 27
    static let eyeSizeSmall:        CGFloat = 23
    static let irisRatio:           CGFloat = 0.57
    static let catchlightPrimaryRatio:   CGFloat = 0.22
    static let catchlightSecondaryRatio: CGFloat = 0.10

    // MARK: - Drowsy eye ratios
    static let drowsyHeightRatio:   CGFloat = 0.42
    static let drowsyIrisHeightRatio: CGFloat = 0.18
    static let drowsyIrisWidthRatio:  CGFloat = 0.32

    // MARK: - Vibe eye ratios
    static let vibeHeightRatio:     CGFloat = 0.58
    static let vibeIrisRatio:       CGFloat = 0.38

    // MARK: - Face offsets
    static let eyesOffsetY:         CGFloat = -12
    static let mouthOffsetY:        CGFloat = 14

    // MARK: - Sleeping Zs label offset
    static let sleepingZsOffsetX:   CGFloat = 40
    static let sleepingZsOffsetY:   CGFloat = -50

    // MARK: - Startled "!" offset
    static let startledOffsetX:     CGFloat = 22
    static let startledOffsetY:     CGFloat = -58
}
