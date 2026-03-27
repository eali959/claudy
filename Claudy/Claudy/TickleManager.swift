import Foundation

// MARK: - TickleState

enum TickleState: Equatable, Sendable {
    case none
    case hover        // 0 – 0.8s: eyes wide, body scale 1.05
    case lightTickle  // 0.8 – 2.0s: side-to-side wiggle ±4pt
    case fullTickle   // 2.0s+: rapid shake, arms flailing
    case startled     // fast swipe: body jump, massive eyes
}

// MARK: - TickleManager

/// Converts hover and drag gesture events into a progressive tickle state machine.
///
/// States escalate from `.hover` (cursor over character) to `.lightTickle` (prolonged hover)
/// to `.fullTickle` (sustained), or jump to `.startled` on a fast swipe. Results are pushed
/// to CharacterViewModel via `syncTickleState(_:)`.
@MainActor
final class TickleManager {
    private weak var viewModel: CharacterViewModel?
    private var hoverTask: Task<Void, Never>?
    private var startledTask: Task<Void, Never>?
    private(set) var tickleState: TickleState = .none

    init(viewModel: CharacterViewModel) {
        self.viewModel = viewModel
    }

    func startHoverTimer() {
        hoverTask?.cancel()
        apply(.hover)

        hoverTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            self.apply(.lightTickle)

            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled else { return }
            self.apply(.fullTickle)
        }
    }

    func resetTickle() {
        hoverTask?.cancel()
        hoverTask = nil
        apply(.none)
    }

    func triggerStartled() {
        hoverTask?.cancel()
        hoverTask = nil
        startledTask?.cancel()

        apply(.startled)

        startledTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            if self.tickleState == .startled {
                self.apply(.none)
            }
        }
    }

    // MARK: - Private

    private func apply(_ state: TickleState) {
        tickleState = state
        viewModel?.syncTickleState(state)
    }
}
