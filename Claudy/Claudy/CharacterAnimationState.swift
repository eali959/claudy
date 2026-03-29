import Foundation

/// All visual states the character can occupy.
///
/// Each case maps to a distinct eye shape, mouth shape, arm position, and body animation
/// in ClaudyCharacterView. The `accessibilityDescription` property surfaces the current
/// state to VoiceOver.
enum CharacterAnimationState: String, Sendable {
    case idle
    case thinking
    case talking
    case celebrating
    case confused
    case sleeping
    case surprised
    case alert      // hover: eyes wide (scale 1.2), body scale 1.05
    case tickled    // light/full tickle: arcs-down eyes, laugh mouth
    case drowsy     // 5-min idle: half-closed eyes, slow bob
    case waving     // greeting: right arm raised and waving, happy ^^ eyes, big smile
    case facepalm   // exasperation: squinty eyes, flat mouth, left arm raised
    case dancing      // dance mode: big glow, pulsing bob, choreographed arm moves
    case headbanging  // metal mode: ultra-fast bob, intense squint, rock grin
    case vibing       // lo-fi mode: slow gentle sway, half-closed content eyes

    var accessibilityDescription: String {
        switch self {
        case .idle:        return "Idle"
        case .thinking:    return "Thinking"
        case .talking:     return "Talking"
        case .celebrating: return "Celebrating"
        case .confused:    return "Confused"
        case .sleeping:    return "Sleeping"
        case .surprised:   return "Surprised"
        case .alert:       return "Alert"
        case .tickled:     return "Tickled"
        case .drowsy:      return "Drowsy"
        case .waving:      return "Waving"
        case .facepalm:    return "Facepalm"
        case .dancing:     return "Dancing"
        case .headbanging: return "Headbanging"
        case .vibing:      return "Vibing"
        }
    }
}

/// Intensity level of a tickle interaction, used to drive wiggle amplitude and arm flair.
enum TickleIntensity: Equatable, Sendable {
    case none, light, full
}
