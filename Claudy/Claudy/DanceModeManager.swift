import Foundation
import OSLog
import Observation

private let logger = Logger(subsystem: "com.claudy", category: "DanceModeManager")

// MARK: - DanceMove

/// Choreography moves that drive ClaudyCharacterView during dance mode.
///
/// Each case maps to a distinct arm position, wiggle, and energy level in the character view.
/// The sequence is timed at ~130 BPM — the approximate tempo of No Broke Boys.
enum DanceMove: Equatable, Sendable {
    case groove       // base bounce, arms alternating to the beat
    case leftArmUp    // left arm raised high, body energy right
    case rightArmUp   // right arm raised high, body energy left
    case bothArmsUp   // Y-shape, maximum energy
    case shimmy       // rapid side-to-side sway
    case spin         // full 360° rotation
    case freeze       // dramatic pose hold — sudden stop
    case bigJump      // large vertical leap with both arms up
}

// MARK: - DanceModeManager

/// Timed choreography engine for Dance Mode.
///
/// Sequences DanceMove values across four repeating phrases at ~130 BPM.
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
    //   2 beats = 0.924s   4 beats = 1.846s   8 beats = 3.692s

    private let beat: Double = 0.462

    /// Full choreography loop — runs until dance mode is stopped.
    private func runChoreography() async {
        while !Task.isCancelled {

            // ── Phrase A: Intro groove ──────────────────────────────────
            await step(.groove,      beats: 4)
            await step(.rightArmUp,  beats: 4)
            await step(.leftArmUp,   beats: 4)
            await step(.groove,      beats: 4)

            // ── Phrase B: Build energy ──────────────────────────────────
            await step(.rightArmUp,  beats: 2)
            await step(.leftArmUp,   beats: 2)
            await step(.bothArmsUp,  beats: 4)
            await step(.shimmy,      beats: 4)

            // ── Phrase C: Drop ──────────────────────────────────────────
            await step(.spin,        beats: 2)
            await step(.freeze,      beats: 2)
            await step(.bothArmsUp,  beats: 4)
            await step(.bigJump,     beats: 4)

            // ── Phrase D: Peak / chorus ─────────────────────────────────
            await step(.shimmy,      beats: 4)
            await step(.rightArmUp,  beats: 2)
            await step(.leftArmUp,   beats: 2)
            await step(.spin,        beats: 2)
            await step(.bothArmsUp,  beats: 4)
            await step(.freeze,      beats: 2)
            await step(.groove,      beats: 4)
        }
    }

    private func step(_ move: DanceMove, beats: Double) async {
        guard !Task.isCancelled else { return }
        currentMove = move
        try? await Task.sleep(for: .seconds(beat * beats))
    }
}
