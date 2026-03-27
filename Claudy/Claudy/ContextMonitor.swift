import AppKit

// MARK: - ContextMonitor

/// Tracks global mouse position for iris following and velocity-based startled reactions.
///
/// The iris offset is updated whenever the cursor moves relative to the character window.
/// A fast swipe (high velocity) triggers a `.startled` animation via `CharacterViewModel.syncTickleState`.
/// Owned by CharacterViewModel. Call `stop()` before deallocation.
@MainActor
final class ContextMonitor {
    private weak var viewModel: CharacterViewModel?
    private weak var windowManager: WindowManager?

    // nonisolated(unsafe): only ever written on MainActor, but deinit is uncontrolled
    nonisolated(unsafe) private var mouseMonitor: Any?

    private var lastMousePos: CGPoint = .zero
    private var lastMouseTime: Date = .distantPast

    init(viewModel: CharacterViewModel, windowManager: WindowManager) {
        self.viewModel = viewModel
        self.windowManager = windowManager
        start()
    }

    func stop() {
        if let m = mouseMonitor {
            NSEvent.removeMonitor(m)
            mouseMonitor = nil
        }
    }

    deinit {
        // mouseMonitor is nonisolated(unsafe) so accessible here.
        // NSEvent.removeMonitor is safe to call off-actor - it just unregisters the token.
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
    }

    // MARK: - Private

    private func start() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleMouseMoved()
            }
        }
    }

    private func handleMouseMoved() {
        guard let vm = viewModel,
              vm.animationState != .sleeping else { return }

        let cursor = NSEvent.mouseLocation

        // --- Iris tracking ---
        if let window = windowManager?.window {
            let origin = window.frame.origin
            let size   = window.frame.size
            // Character sits at the bottom of the panel; approximate its center in screen coords
            let charCenter = CGPoint(
                x: origin.x + size.width / 2,
                y: origin.y + WindowManager.characterSize / 2
            )
            let dx = cursor.x - charCenter.x
            let dy = cursor.y - charCenter.y
            let dist = hypot(dx, dy)

            if dist > 1 {
                let maxTravel: CGFloat = 3
                // AppKit Y increases upward; SwiftUI Y increases downward → negate Y
                vm.irisOffset = CGPoint(
                    x:  (dx / dist) * maxTravel,
                    y: -(dy / dist) * maxTravel
                )
            }
        }

        // --- Velocity → startled ---
        let now = Date()
        let dt  = now.timeIntervalSince(lastMouseTime)
        if dt > 0 && dt < 0.1 {
            let vx = abs(cursor.x - lastMousePos.x) / dt
            let vy = abs(cursor.y - lastMousePos.y) / dt
            if hypot(vx, vy) > 800 && vm.isHovered {
                vm.tickleManager.triggerStartled()
            }
        }
        lastMousePos  = cursor
        lastMouseTime = now
    }
}
