import Foundation
import SwiftData
import AppKit
import OSLog
import Observation

private let log = Logger(subsystem: "com.claudy", category: "Tamagotchi")

// MARK: - TamagotchiManager

/// Manages Claud-y's wellbeing stats (hunger, happiness, energy).
///
/// Stats persist across launches via SwiftData (`TamagotchiState`).
/// On init, elapsed-time catch-up decay is applied (capped at 24 h).
/// A 5-minute timer loop applies ongoing decay while the app is open.
/// Stats drive character animation state and speech-bubble nudges.
///
/// **Decay rates (per minute, mode-multiplied):**
/// - Hunger:    +2.0   (increases → Claud-y gets hungrier)
/// - Happiness: −1.5   (decreases)
/// - Energy:    −1.0   (decreases)
///
/// **Stat floor:** 15% — Claud-y is grumpy but never "dead".
/// **Stat ceiling:** 100%.
@MainActor
@Observable
final class TamagotchiManager {

    // MARK: - Observed stats (mirrored from SwiftData for SwiftUI)

    /// 0–100. Higher = hungrier. Display as "fullness" (100 − hunger) for the UI.
    var hunger: Float    = 40
    var happiness: Float = 80
    var energy: Float    = 75

    /// Convenience for display: how "full" Claud-y is (inverse of hunger).
    var fullness: Float { max(0, 100 - hunger) }

    // MARK: - Private

    private weak var viewModel: CharacterViewModel?
    @ObservationIgnored private var decayTask: Task<Void, Never>?
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var state: TamagotchiState?
    @ObservationIgnored private var lastNudgeTime: Date = .distantPast
    private let nudgeCooldown: TimeInterval = 600   // 10 minutes between tamagotchi nudges

    // MARK: - Init / deinit

    init(viewModel: CharacterViewModel) {
        self.viewModel = viewModel
        loadAndApplyCatchUpDecay()
        startDecayLoop()
    }

    deinit {
        decayTask?.cancel()
    }

    // MARK: - Actions

    /// Feed Claud-y: reduces hunger, costs a little energy.
    func feed() {
        hunger    = max(15, hunger - 35)
        energy    = max(15, energy - 5)
        saveState()
        playReaction(.happyBounce, bubble: feedBubble(), duration: 2.5)
        log.info("Fed — hunger=\(self.hunger) energy=\(self.energy)")
    }

    /// Play with Claud-y: boosts happiness, costs energy.
    func play() {
        happiness = min(100, happiness + 25)
        energy    = max(15, energy - 15)
        saveState()
        playReaction(.happyBounce, bubble: playBubble(), duration: 2.5)
        log.info("Played — happiness=\(self.happiness) energy=\(self.energy)")
    }

    /// Rest/pet Claud-y: restores energy, slight happiness boost.
    func rest() {
        energy    = min(100, energy + 30)
        happiness = min(100, happiness + 5)
        saveState()
        playReaction(.vibing, bubble: restBubble(), duration: 2.0)
        log.info("Rested — energy=\(self.energy)")
    }

    // MARK: - Animation bridge

    /// Updates the character's base animation state based on worst stat.
    /// hungryWobble > sleepyDroop > idle (hunger takes priority).
    func syncAnimation() {
        guard let vm = viewModel else { return }
        if hunger > 78 {
            vm.setState(.hungryWobble)
        } else if energy < 22 {
            vm.setState(.sleepyDroop)
        } else if vm.animationState == .hungryWobble || vm.animationState == .sleepyDroop {
            vm.setState(.idle)
        }
    }

    // MARK: - Private helpers

    private func loadAndApplyCatchUpDecay() {
        guard let container = (NSApp.delegate as? AppDelegate)?.modelContainer else {
            log.warning("No ModelContainer — Tamagotchi running with in-memory defaults")
            return
        }
        let ctx = ModelContext(container)
        context = ctx
        do {
            let all = try ctx.fetch(FetchDescriptor<TamagotchiState>())
            let s: TamagotchiState
            if let existing = all.first {
                s = existing
                applyCatchUpDecay(to: s)
            } else {
                s = TamagotchiState()
                ctx.insert(s)
                try? ctx.save()
                log.info("TamagotchiState created (first launch via manager)")
            }
            state = s
            syncFromState(s)
        } catch {
            log.error("Failed to load TamagotchiState: \(error.localizedDescription)")
        }
    }

    private func applyCatchUpDecay(to s: TamagotchiState) {
        let elapsed = min(-s.lastUpdated.timeIntervalSinceNow, 24 * 3600)
        guard elapsed > 60 else { return }  // skip if less than 1 min
        let minutes = Float(elapsed / 60.0)
        s.hunger    = min(100, s.hunger    + minutes * 2.0)
        s.happiness = max(15,  s.happiness - minutes * 1.5)
        s.energy    = max(15,  s.energy    - minutes * 1.0)
        s.lastUpdated = .now
        try? context?.save()
        log.info("Catch-up decay applied — \(Int(elapsed / 60)) minutes elapsed")
    }

    private func syncFromState(_ s: TamagotchiState) {
        hunger    = s.hunger
        happiness = s.happiness
        energy    = s.energy
    }

    private func saveState() {
        guard let state, let context else { return }
        state.hunger    = hunger
        state.happiness = happiness
        state.energy    = energy
        state.lastUpdated = .now
        try? context.save()
    }

    private func startDecayLoop() {
        decayTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                guard let self, !Task.isCancelled else { return }
                self.applyDecayTick()
            }
        }
    }

    private func applyDecayTick() {
        let m = decayMultiplier
        hunger    = min(100, hunger    + 10.0 * m)
        happiness = max(15,  happiness -  7.5 * m)
        energy    = max(15,  energy    -  5.0 * m)
        saveState()
        syncAnimation()
        maybeNudge()
        log.debug("Decay tick — hunger=\(self.hunger) happiness=\(self.happiness) energy=\(self.energy)")
    }

    /// Behavior-mode-aware decay multiplier.
    private var decayMultiplier: Float {
        switch PersonalityManager.shared.activeBehaviorMode {
        case .study, .work: return 1.5
        case .dev:          return 1.2
        case .dance, .brainRot: return 0.5
        default:            return 1.0
        }
    }

    private func maybeNudge() {
        guard -lastNudgeTime.timeIntervalSinceNow > nudgeCooldown else { return }
        let intensity = UserDefaults.standard.string(forKey: DefaultsKeys.tamagotchiNudgeIntensity) ?? "normal"
        guard intensity != "silent" else { return }

        let bubble: String?
        if hunger > 78 {
            bubble = hungerNudge()
        } else if energy < 22 {
            bubble = energyNudge()
        } else if happiness < 30 {
            bubble = happinessNudge()
        } else {
            return
        }

        guard let text = bubble else { return }
        lastNudgeTime = .now
        viewModel?.showBubbleDirect(text, duration: 4)
    }

    private func playReaction(_ state: CharacterAnimationState, bubble: String, duration: TimeInterval) {
        viewModel?.setState(state, duration: duration)
        viewModel?.showBubbleDirect(bubble, duration: 3)
    }

    // MARK: - Response strings

    private func feedBubble() -> String {
        let options = [
            "*munch munch* Mmm. Thank you.",
            "Oh! Food! My favourite! *happy chomp*",
            "*nom nom nom* You're the best.",
            "Finally. I was starting to worry.",
            "*eats with alarming enthusiasm*",
        ]
        return options.randomElement()!
    }

    private func playBubble() -> String {
        let options = [
            "*bounces around excitedly* Yes! Let's go!",
            "Playtime! This is the best.",
            "*zooms in a tiny circle* Wheeee!",
            "You played with me. My happiness is at maximum.",
            "*wriggles with joy*",
        ]
        return options.randomElement()!
    }

    private func restBubble() -> String {
        let options = [
            "*settles in and sighs contentedly*",
            "Ahh. Rest. Exactly what I needed.",
            "*goes soft and warm* Thank you.",
            "A little rest goes a long way.",
            "*slow blink* This is nice.",
        ]
        return options.randomElement()!
    }

    private func hungerNudge() -> String {
        let options = [
            "Psst. I'm a bit hungry over here.",
            "*stomach makes a small sad noise*",
            "Just so you know. Hungry. Very.",
            "I'm not complaining. I'm just... hungry.",
            "*stares at you with large hungry eyes*",
        ]
        return options.randomElement()!
    }

    private func energyNudge() -> String {
        let options = [
            "*yawn* Getting a bit tired...",
            "Not complaining, just... running low.",
            "*droops slightly* Could use a rest.",
            "Energy levels: minimal. Send help.",
            "*blink, blink* So... sleepy...",
        ]
        return options.randomElement()!
    }

    private func happinessNudge() -> String {
        let options = [
            "Could use a bit of a play...",
            "*stares out the window wistfully*",
            "Not sad. Just... a little bored.",
            "Play with me? Just for a second?",
            "*quiet sigh*",
        ]
        return options.randomElement()!
    }
}
