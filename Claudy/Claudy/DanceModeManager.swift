import Foundation
import OSLog
import Observation

private let logger = Logger(subsystem: "com.claudy", category: "DanceModeManager")

// MARK: - DanceMove

/// Choreography moves that drive ClaudyCharacterView during dance mode.
enum DanceMove: Equatable, Sendable {
    case groove         // base bounce, arms alternating to the beat
    case leftArmUp      // left arm raised high
    case rightArmUp     // right arm raised high
    case bothArmsUp     // Y-shape, maximum energy
    case shimmy         // rapid side-to-side sway
    case spin           // full 360° rotation
    case freeze         // dramatic pose hold — sudden stop
    case bigJump        // large vertical leap with both arms up
    case pointUp        // right arm pointing straight up, left at hip
    case lowRide        // crouch with arms wide — body scales down
    case throwHands     // both arms thrown forward/up — quick energy burst
    case chestPop       // sharp body pop with scale pulse
}

// MARK: - DanceModeManager

/// Timed choreography engine for Dance Mode.
///
/// Sequences DanceMove values across five repeating phrases at ~130 BPM.
/// CharacterViewModel owns this object and calls start() / stop().
/// ClaudyCharacterView reads currentMove to render each pose.
@MainActor
@Observable
final class DanceModeManager {

    private(set) var currentMove: DanceMove = .groove
    private(set) var isActive: Bool = false

    @ObservationIgnored private var choreographyTask: Task<Void, Never>?

    // MARK: - Control

    func start() {
        guard !isActive else { return }
        isActive = true
        currentMove = .groove
        choreographyTask = Task { @MainActor in
            await runChoreography()
        }
        logger.info("Dance mode started")
    }

    func stop() {
        choreographyTask?.cancel()
        choreographyTask = nil
        isActive = false
        currentMove = .groove
        logger.info("Dance mode stopped")
    }

    // MARK: - Choreography
    //
    // At 130 BPM: 1 beat = 0.462s
    //   1 beat  = 0.462s   2 beats = 0.924s
    //   4 beats = 1.846s   8 beats = 3.692s

    private let beat: Double = 0.462

    /// Full choreography loop — runs until dance mode is stopped.
    ///
    /// Five phrases total. Phrase C uses 1-beat micro-moves to build
    /// urgency before the drop in Phrase D.
    private func runChoreography() async {
        while !Task.isCancelled {

            // ── Phrase A: Settle in ─────────────────────────────────────
            await step(.groove,      beats: 4)
            await step(.rightArmUp,  beats: 2)
            await step(.leftArmUp,   beats: 2)
            await step(.pointUp,     beats: 2)
            await step(.groove,      beats: 2)

            // ── Phrase B: Build ─────────────────────────────────────────
            await step(.shimmy,      beats: 4)
            await step(.rightArmUp,  beats: 2)
            await step(.throwHands,  beats: 1)
            await step(.leftArmUp,   beats: 2)
            await step(.throwHands,  beats: 1)
            await step(.bothArmsUp,  beats: 2)

            // ── Phrase C: Tension — rapid 1-beat cuts ───────────────────
            await step(.chestPop,    beats: 1)
            await step(.rightArmUp,  beats: 1)
            await step(.chestPop,    beats: 1)
            await step(.leftArmUp,   beats: 1)
            await step(.chestPop,    beats: 1)
            await step(.pointUp,     beats: 1)
            await step(.spin,        beats: 2)
            await step(.freeze,      beats: 2)

            // ── Phrase D: Drop / chorus — maximum energy ────────────────
            await step(.bothArmsUp,  beats: 2)
            await step(.bigJump,     beats: 2)
            await step(.lowRide,     beats: 2)
            await step(.bothArmsUp,  beats: 2)
            await step(.chestPop,    beats: 1)
            await step(.throwHands,  beats: 1)
            await step(.bigJump,     beats: 2)

            // ── Phrase E: Cool down → loop ───────────────────────────────
            await step(.shimmy,      beats: 4)
            await step(.spin,        beats: 2)
            await step(.freeze,      beats: 2)
            await step(.bothArmsUp,  beats: 2)
            await step(.groove,      beats: 2)
        }
    }

    private func step(_ move: DanceMove, beats: Double) async {
        guard !Task.isCancelled else { return }
        currentMove = move
        try? await Task.sleep(for: .seconds(beat * beats))
    }
}
