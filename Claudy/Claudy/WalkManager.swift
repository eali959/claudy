import AppKit
import Observation

/// Manages Claud-y's occasional walk-across-screen behaviour (ANIM-09).
///
/// Every 10 minutes (±90 s jitter) Claud-y picks a new random destination within the
/// visible screen area, sets `.walking` animation state, slides to the destination over
/// ~2–3 seconds with a smooth easeInOut curve, then returns to idle.
///
/// Rules:
/// - Max 1 walk per 10 minutes
/// - Never covers the macOS menu bar (top ~24 pt) or dock (varies)
/// - Respects `NSScreen.main.visibleFrame` so it stays out of dock / menu bar
/// - Skips the walk if: user is dragging, character is sleeping, or walk is disabled
/// - Can be toggled at runtime via `isEnabled` (persisted to UserDefaults)
@MainActor
@Observable
final class WalkManager {

    // MARK: - State

    private(set) var isWalking = false
    /// True while walking toward a destination whose x-coordinate is to the left of the current position.
    private(set) var isWalkingLeft = false

    var isEnabled: Bool = {
        // Default on; key absent → true
        guard UserDefaults.standard.object(forKey: DefaultsKeys.walkEnabled) != nil else { return true }
        return UserDefaults.standard.bool(forKey: DefaultsKeys.walkEnabled)
    }() {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: DefaultsKeys.walkEnabled)
            if !isEnabled { cancelWalk() }
        }
    }

    // MARK: - Dependencies

    private weak var viewModel: CharacterViewModel?
    private weak var windowManager: WindowManager?

    // MARK: - Timers / tasks

    @ObservationIgnored private nonisolated(unsafe) var scheduleTask: Task<Void, Never>?
    @ObservationIgnored private nonisolated(unsafe) var walkTask: Task<Void, Never>?

    // MARK: - Constants

    /// Minimum interval between walks (seconds).
    private static let minInterval: Double = 420   // 7 min
    /// Random jitter added to the base interval (±half this value).
    private static let jitter: Double = 60
    /// Duration of the sliding walk animation (seconds).
    private static let slideDuration: Double = 2.4
    /// Panel size used for boundary math.
    private static let panelSize = WindowManager.characterSize   // 150 pt

    // MARK: - Init

    init(viewModel: CharacterViewModel, windowManager: WindowManager) {
        self.viewModel = viewModel
        self.windowManager = windowManager
        scheduleNextWalk()
    }

    deinit {
        scheduleTask?.cancel()
        walkTask?.cancel()
    }

    // MARK: - Scheduling

    private func scheduleNextWalk() {
        scheduleTask?.cancel()
        scheduleTask = Task { [weak self] in
            let delay = Self.minInterval + Double.random(in: -Self.jitter...Self.jitter)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.attemptWalk()
            self?.scheduleNextWalk()
        }
    }

    // MARK: - Walk execution

    private func attemptWalk() async {
        guard let vm = viewModel, let wm = windowManager, let window = wm.window else { return }
        guard isEnabled else { return }
        guard !wm.isDragging else { return }

        // Don't interrupt sleeping, talking, celebrating, or active Tamagotchi states
        let blockedStates: Set<CharacterAnimationState> = [
            .sleeping, .talking, .celebrating, .dancing, .headbanging, .hungryWobble
        ]
        guard !blockedStates.contains(vm.animationState) else { return }

        // Compute destination along the dock edge
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let vis  = screen.visibleFrame
        let full = screen.frame
        let margin: CGFloat = 6
        let panel = Self.panelSize

        // Detect dock position by seeing which side of the full frame is excluded from visibleFrame
        let dockAtLeft  = vis.minX > full.minX + 10
        let dockAtRight = vis.maxX < full.maxX - 10
        // If neither left nor right, dock is at the bottom (most common) or auto-hidden

        let dest: CGPoint
        if dockAtLeft {
            // Walk vertically along the right edge of the left dock
            let minY = vis.minY + margin
            let maxY = vis.maxY - panel - margin
            guard maxY > minY else { return }
            dest = CGPoint(x: vis.minX, y: CGFloat.random(in: minY...maxY))
        } else if dockAtRight {
            // Walk vertically along the left edge of the right dock
            let minY = vis.minY + margin
            let maxY = vis.maxY - panel - margin
            guard maxY > minY else { return }
            dest = CGPoint(x: vis.maxX - panel - margin, y: CGFloat.random(in: minY...maxY))
        } else {
            // Dock at bottom (or auto-hidden) — walk horizontally along the dock's top edge
            let minX = vis.minX + margin
            let maxX = vis.maxX - panel - margin
            guard maxX > minX else { return }
            dest = CGPoint(x: CGFloat.random(in: minX...maxX), y: vis.minY)
        }

        isWalking = true
        isWalkingLeft = dest.x < window.frame.origin.x
        vm.setState(.walking)

        // Slide the window to the destination — 144 steps at ~16 ms each ≈ 60 fps
        let origin = window.frame.origin
        let steps = 144
        let stepDelay: UInt64 = UInt64((Self.slideDuration / Double(steps)) * 1_000_000_000)
        walkTask = Task { @MainActor [weak window] in
            for i in 1...steps {
                guard !Task.isCancelled else { break }
                let t = Double(i) / Double(steps)
                // Smooth easeInOut
                let ease = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
                let x = origin.x + (dest.x - origin.x) * ease
                let y = origin.y + (dest.y - origin.y) * ease
                window?.setFrameOrigin(CGPoint(x: x, y: y))
                try? await Task.sleep(nanoseconds: stepDelay)
            }
            // Persist final position
            let finalOrigin = [dest.x, dest.y]
            UserDefaults.standard.set(finalOrigin, forKey: DefaultsKeys.characterWindowOrigin)
        }
        await walkTask?.value

        isWalking = false
        isWalkingLeft = false
        vm.setState(.idle)
    }

    // MARK: - Manual trigger / cancel

    /// Cancels an in-progress walk immediately — called when user starts dragging.
    func cancelWalk() {
        walkTask?.cancel()
        walkTask = nil
        isWalking = false
        viewModel?.setState(.idle)
    }

    /// Trigger a walk immediately (e.g. from context menu).
    func walkNow() {
        Task { await attemptWalk() }
    }
}
