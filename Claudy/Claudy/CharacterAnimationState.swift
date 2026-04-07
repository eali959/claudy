import SwiftUI

// MARK: - AnimationConfig (ANIM-01)

/// Data-driven animation descriptor. Each `CharacterAnimationState` returns one of these,
/// which `ClaudyCharacterView` reads to drive all animation parameters without needing
/// a per-state switch inside every rendering sub-function. (ANIM-02)
struct AnimationConfig: Sendable {

    // Eye and mouth shape tokens — ClaudyCharacterView maps these to @ViewBuilders.
    enum EyeShape: Sendable {
        case pixar           // standard Pixar-style large iris + catchlights
        case arcUp           // happy arch ^^
        case arcDown         // embarrassed / tickled reverse arch
        case squint          // tight horizontal squint
        case angrySquint     // squint with angled inner brow
        case drowsy          // heavy half-lid
        case halfClosed      // bored, slightly less heavy than drowsy
        case vibe            // relaxed half-lid, content gaze
        case sleep           // thin crescent / closed
        case peacefulClosed  // thin line, eyes fully shut in peace
        case thinkingDots    // three bouncing dots (replaces eyes)
        case wideAlert       // pixar × 1.2
        case wideSurprised   // pixar × 1.4
        case hungryPleading  // pixar × 1.12, soft pleading gaze
        case nervousWide     // pixar slightly larger, uncertainty
        case loveHeart       // ♥ eyes
        case wink            // one squint + one pixar
    }

    enum MouthShape: Sendable {
        case `default`       // gentle upward curve
        case bigSmile        // wider happy curve
        case hugeSmile       // maximum grin, celebrating
        case sadCurve        // downward arc
        case flatLine        // neutral / stoic / angry flat
        case tinyOpen        // small oval (hungry / hiccup)
        case mediumOpen      // medium O (confused / surprised)
        case wideOpen        // large O (yawn / sneeze)
        case sleepLine       // tiny flat sleep line
        case vibeSmile       // small relaxed curve
        case rockMouth       // wide grin + teeth (headbang)
        case talkingSync     // lip-sync ellipse (driven by mouthOpenAmount)
        case smirk           // one-sided upward curve
        case effortGrin      // slightly parted effort grin (exercise)
        case chewing         // animated chewing (eating)
    }

    // Bob animation
    var bobDuration: Double   = 1.9
    var bobAmplitude: CGFloat = -6

    // Side-to-side wiggle
    var wiggleEnabled: Bool   = false
    var wiggleAmount: CGFloat = 5
    var wiggleDuration: Double = 0.55

    // Visual properties
    var eyeShape: EyeShape    = .pixar
    var mouthShape: MouthShape = .default
    var armFlair: Bool         = false
    var celebrateScale: Bool   = false
    var hasGlow: Bool          = false

    // Blush / colour tint overlay (e.g. embarrassed)
    var blushOpacity: Double   = 0.0
}

// MARK: - CharacterAnimationState (ANIM-02 / ANIM-03 / ANIM-04 / ANIM-05 / ANIM-06)

/// All visual states Claud-y can occupy.
/// Each case returns a fully-specified `AnimationConfig` — ClaudyCharacterView reads
/// the config rather than switching on the state directly inside each rendering function.
enum CharacterAnimationState: String, Sendable {

    // ── Existing states ────────────────────────────────────────────────────────
    case idle
    case thinking
    case talking
    case celebrating
    case confused
    case sleeping
    case surprised
    case alert
    case tickled
    case drowsy
    case waving
    case facepalm
    case dancing
    case headbanging
    case vibing

    // ── Tamagotchi states (ANIM-06) ────────────────────────────────────────────
    case hungryWobble   // hunger > 75%: side-to-side tummy wobble, pleading eyes
    case sleepyDroop    // energy < 25%: heavy half-lid, slow sag
    case happyBounce    // post-Feed/Play boost: cheerful bounce, sparkle eyes
    case fullBellyPat   // well-fed contentment: gentle satisfied sway
    case evolutionShimmer // brief sparkle during stat milestone

    // ── Emotional batch (ANIM-03) ─────────────────────────────────────────────
    case sad            // downcast eyes, small sad curve
    case angry          // squint with angled brow, tight flat mouth, slight shake
    case nervous        // wide uncertain eyes, open mouth, fast-ish bob
    case excited        // huge eyes, maximum grin, scale pulse
    case bored          // half-closed eyes, flat mouth, slow heavy bob
    case loveEyes       // heart eyes, big smile
    case embarrassed    // reversed arch, red blush overlay
    case mischievous    // one-eye wink, smirk

    // ── Activity batch (ANIM-04) ──────────────────────────────────────────────
    case typing         // focused squint, neutral mouth, moderate bob
    case reading        // standard eyes (side-look handled by irisOffset), relaxed
    case coding         // intense squint, flat focus mouth
    case meditating     // eyes fully closed, gentle vibe smile, very slow bob
    case exercising     // wide determined eyes, effort grin, fast bob
    case eating         // happy arc eyes, chewing mouth
    case studying       // squint focus, slightly slower than coding

    // ── Fun / viral batch (ANIM-05) ───────────────────────────────────────────
    case dab            // squint + arm dab pose, smirk
    case moonwalk       // relaxed cool eyes, smirk, lateral glide
    case backflip       // huge surprised eyes, O-mouth, very fast bob
    case breakdance     // vibe eyes, big grin, fast bob + glow
    case sneeze         // squint before sneeze, wide open mouth, fast bob
    case yawn           // half-closed heavy eyes, wide open mouth, slow bob
    case hiccup         // sudden surprised eyes, small O, snappy fast bob
    case walking        // gentle side-sway walk cycle, standard eyes

    // MARK: - AnimationConfig (ANIM-01 / ANIM-02)

    var animationConfig: AnimationConfig {
        switch self {

        // Existing states
        case .idle:
            return AnimationConfig()
        case .thinking:
            return AnimationConfig(bobDuration: 1.9, bobAmplitude: -5, eyeShape: .thinkingDots, mouthShape: .default)
        case .talking:
            return AnimationConfig(bobDuration: 1.6, bobAmplitude: -6, eyeShape: .pixar, mouthShape: .talkingSync)
        case .celebrating:
            return AnimationConfig(bobDuration: 0.5, bobAmplitude: -10, eyeShape: .arcUp, mouthShape: .hugeSmile, celebrateScale: true)
        case .confused:
            return AnimationConfig(bobDuration: 1.2, bobAmplitude: -7, eyeShape: .wideSurprised, mouthShape: .mediumOpen)
        case .sleeping:
            return AnimationConfig(bobDuration: 3.2, bobAmplitude: -2, eyeShape: .sleep, mouthShape: .sleepLine)
        case .surprised:
            return AnimationConfig(bobDuration: 1.9, bobAmplitude: -6, eyeShape: .wideSurprised, mouthShape: .mediumOpen)
        case .alert:
            return AnimationConfig(bobDuration: 1.9, bobAmplitude: -6, eyeShape: .wideAlert, mouthShape: .default)
        case .tickled:
            return AnimationConfig(bobDuration: 1.6, bobAmplitude: -7, eyeShape: .arcDown, mouthShape: .bigSmile)
        case .drowsy:
            return AnimationConfig(bobDuration: 2.5, bobAmplitude: -4, eyeShape: .drowsy, mouthShape: .sleepLine)
        case .waving:
            return AnimationConfig(bobDuration: 1.4, bobAmplitude: -8, eyeShape: .arcUp, mouthShape: .bigSmile, armFlair: true)
        case .facepalm:
            return AnimationConfig(bobDuration: 1.9, bobAmplitude: -5, eyeShape: .squint, mouthShape: .flatLine)
        case .dancing:
            return AnimationConfig(bobDuration: 0.36, bobAmplitude: -16, eyeShape: .arcUp, mouthShape: .hugeSmile, armFlair: true, hasGlow: true)
        case .headbanging:
            return AnimationConfig(bobDuration: 0.13, bobAmplitude: -26, eyeShape: .squint, mouthShape: .rockMouth, armFlair: true)
        case .vibing:
            return AnimationConfig(bobDuration: 1.10, bobAmplitude: -8, eyeShape: .vibe, mouthShape: .vibeSmile)

        // Tamagotchi
        case .hungryWobble:
            return AnimationConfig(bobDuration: 1.8, bobAmplitude: -5, wiggleEnabled: true, wiggleAmount: 5, wiggleDuration: 0.55, eyeShape: .hungryPleading, mouthShape: .tinyOpen)
        case .sleepyDroop:
            return AnimationConfig(bobDuration: 2.8, bobAmplitude: -3, eyeShape: .drowsy, mouthShape: .sleepLine)
        case .happyBounce:
            return AnimationConfig(bobDuration: 0.45, bobAmplitude: -14, eyeShape: .arcUp, mouthShape: .hugeSmile)
        case .fullBellyPat:
            return AnimationConfig(bobDuration: 1.2, bobAmplitude: -6, eyeShape: .arcUp, mouthShape: .vibeSmile)
        case .evolutionShimmer:
            return AnimationConfig(bobDuration: 0.4, bobAmplitude: -10, eyeShape: .arcUp, mouthShape: .hugeSmile, celebrateScale: true, hasGlow: true)

        // Emotional
        case .sad:
            return AnimationConfig(bobDuration: 2.5, bobAmplitude: -3, eyeShape: .arcDown, mouthShape: .sadCurve)
        case .angry:
            return AnimationConfig(bobDuration: 0.8, bobAmplitude: -8, wiggleEnabled: true, wiggleAmount: 3, wiggleDuration: 0.3, eyeShape: .angrySquint, mouthShape: .flatLine)
        case .nervous:
            return AnimationConfig(bobDuration: 1.1, bobAmplitude: -8, eyeShape: .nervousWide, mouthShape: .mediumOpen)
        case .excited:
            return AnimationConfig(bobDuration: 0.55, bobAmplitude: -12, eyeShape: .wideSurprised, mouthShape: .hugeSmile, celebrateScale: true)
        case .bored:
            return AnimationConfig(bobDuration: 3.0, bobAmplitude: -3, eyeShape: .halfClosed, mouthShape: .flatLine)
        case .loveEyes:
            return AnimationConfig(bobDuration: 1.2, bobAmplitude: -8, eyeShape: .loveHeart, mouthShape: .bigSmile)
        case .embarrassed:
            return AnimationConfig(bobDuration: 1.5, bobAmplitude: -5, eyeShape: .arcDown, mouthShape: .default, blushOpacity: 0.18)
        case .mischievous:
            return AnimationConfig(bobDuration: 1.4, bobAmplitude: -7, eyeShape: .wink, mouthShape: .smirk)

        // Activity
        case .typing:
            return AnimationConfig(bobDuration: 1.6, bobAmplitude: -6, eyeShape: .squint, mouthShape: .default)
        case .reading:
            return AnimationConfig(bobDuration: 2.0, bobAmplitude: -4, eyeShape: .pixar, mouthShape: .default)
        case .coding:
            return AnimationConfig(bobDuration: 1.4, bobAmplitude: -6, eyeShape: .squint, mouthShape: .flatLine)
        case .meditating:
            return AnimationConfig(bobDuration: 2.5, bobAmplitude: -4, eyeShape: .peacefulClosed, mouthShape: .vibeSmile)
        case .exercising:
            return AnimationConfig(bobDuration: 0.4, bobAmplitude: -12, eyeShape: .nervousWide, mouthShape: .effortGrin)
        case .eating:
            return AnimationConfig(bobDuration: 1.0, bobAmplitude: -5, eyeShape: .arcUp, mouthShape: .chewing)
        case .studying:
            return AnimationConfig(bobDuration: 1.8, bobAmplitude: -5, eyeShape: .squint, mouthShape: .default)

        // Fun / viral
        case .dab:
            return AnimationConfig(bobDuration: 1.0, bobAmplitude: -8, eyeShape: .squint, mouthShape: .smirk)
        case .moonwalk:
            return AnimationConfig(bobDuration: 0.7, bobAmplitude: -8, eyeShape: .vibe, mouthShape: .smirk)
        case .backflip:
            return AnimationConfig(bobDuration: 0.5, bobAmplitude: -14, eyeShape: .wideSurprised, mouthShape: .mediumOpen)
        case .breakdance:
            return AnimationConfig(bobDuration: 0.4, bobAmplitude: -16, eyeShape: .vibe, mouthShape: .bigSmile, hasGlow: true)
        case .sneeze:
            return AnimationConfig(bobDuration: 0.6, bobAmplitude: -12, eyeShape: .squint, mouthShape: .wideOpen)
        case .yawn:
            return AnimationConfig(bobDuration: 2.0, bobAmplitude: -4, eyeShape: .halfClosed, mouthShape: .wideOpen)
        case .hiccup:
            return AnimationConfig(bobDuration: 0.3, bobAmplitude: -18, eyeShape: .wideSurprised, mouthShape: .tinyOpen)
        case .walking:
            return AnimationConfig(bobDuration: 0.4, bobAmplitude: -8, wiggleEnabled: true, wiggleAmount: 4, wiggleDuration: 0.4, eyeShape: .pixar, mouthShape: .default)
        }
    }

    // MARK: - Accessibility

    var accessibilityDescription: String {
        switch self {
        case .idle:            return "Idle"
        case .thinking:        return "Thinking"
        case .talking:         return "Talking"
        case .celebrating:     return "Celebrating"
        case .confused:        return "Confused"
        case .sleeping:        return "Sleeping"
        case .surprised:       return "Surprised"
        case .alert:           return "Alert"
        case .tickled:         return "Tickled"
        case .drowsy:          return "Drowsy"
        case .waving:          return "Waving"
        case .facepalm:        return "Facepalm"
        case .dancing:         return "Dancing"
        case .headbanging:     return "Headbanging"
        case .vibing:          return "Vibing"
        case .hungryWobble:    return "Hungry"
        case .sleepyDroop:     return "Sleepy"
        case .happyBounce:     return "Happy"
        case .fullBellyPat:    return "Full and content"
        case .evolutionShimmer:return "Glowing"
        case .sad:             return "Sad"
        case .angry:           return "Angry"
        case .nervous:         return "Nervous"
        case .excited:         return "Excited"
        case .bored:           return "Bored"
        case .loveEyes:        return "Loving"
        case .embarrassed:     return "Embarrassed"
        case .mischievous:     return "Mischievous"
        case .typing:          return "Typing"
        case .reading:         return "Reading"
        case .coding:          return "Coding"
        case .meditating:      return "Meditating"
        case .exercising:      return "Exercising"
        case .eating:          return "Eating"
        case .studying:        return "Studying"
        case .dab:             return "Dabbing"
        case .moonwalk:        return "Moonwalking"
        case .backflip:        return "Backflipping"
        case .breakdance:      return "Breakdancing"
        case .sneeze:          return "Sneezing"
        case .yawn:            return "Yawning"
        case .hiccup:          return "Hiccuping"
        case .walking:         return "Walking"
        }
    }
}

/// Intensity level of a tickle interaction, used to drive wiggle amplitude and arm flair.
enum TickleIntensity: Equatable, Sendable {
    case none, light, full
}
