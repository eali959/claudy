import Foundation

/// Scans assistant text for emotional cue tokens and posts a notification
/// that the 3D coordinator listens to. Cheap, deterministic — no LLM call.
/// Used to make Claud-y emote in sync with what he just "said".
///
/// When the active provider is Ollama or LM Studio (i.e. local + free),
/// the same notification could in future be driven by a small classifier
/// LLM call — see `LLMCapabilityProfile` in the v4 plan. This regex
/// fallback always runs.
enum ExpressionTagger {

    /// Notification posted with one of the cue raw values in `userInfo["cue"]`.
    static let cueChanged = Notification.Name("ExpressionTagger.cueChanged")

    enum Cue: String {
        case wow         // → whoaTwirl + wide eyes
        case hmm         // → hmm fidget
        case happy       // → small nod + smile flash
        case sad         // → head droop + small shrug
        case curious     // → head tilt
        case focused     // → analysing squint
        case neutral     // → no extra animation
    }

    /// Inspects `text` and posts the most salient cue. Uses simple
    /// case-insensitive substring scans so cost is O(text length) and
    /// runs safely on the main actor in <1ms.
    static func tag(text: String) {
        let lower = text.lowercased()
        let cue: Cue = {
            // Order matters — first match wins. Strong cues first.
            if hasAny(lower, of: ["wow", "whoa", "amazing", "incredible", "mind-blowing"]) {
                return .wow
            }
            if hasAny(lower, of: ["hmm", "let me think", "i'm not sure", "good question"]) {
                return .hmm
            }
            if hasAny(lower, of: ["sorry", "my bad", "oops", "i made a mistake", "i was wrong"]) {
                return .sad
            }
            if hasAny(lower, of: ["nice", "great", "perfect", "love it", "well done", "excellent"]) {
                return .happy
            }
            if text.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?") {
                return .curious
            }
            if lower.contains("```") || hasAny(lower, of: ["analysing", "let's review", "looking at"]) {
                return .focused
            }
            return .neutral
        }()

        NotificationCenter.default.post(
            name: cueChanged,
            object: nil,
            userInfo: ["cue": cue.rawValue]
        )
    }

    private static func hasAny(_ haystack: String, of needles: [String]) -> Bool {
        for n in needles where haystack.contains(n) { return true }
        return false
    }
}
