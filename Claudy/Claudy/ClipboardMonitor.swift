import AppKit

// MARK: - ClipboardMonitor

/// Monitors the system clipboard and triggers contextual reactions on paste events.
///
/// Polls NSPasteboard every 2 s, detects text, code snippets, and URLs,
/// and notices repeated pastes of the same content. Rate-limited to one reaction per 30 s.
/// Reactions sourced from ReactionLibraryService.
@MainActor
final class ClipboardMonitor {
    private weak var viewModel: CharacterViewModel?
    private var pollTask: Task<Void, Never>?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var lastTriggeredTime: Date = .distantPast
    private var lastSeenContent: String? = nil

    init(viewModel: CharacterViewModel) {
        self.viewModel = viewModel
        startPolling()
    }

    func stop() { pollTask?.cancel() }

    // MARK: - Private

    private func startPolling() {
        pollTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                self.check()
            }
        }
    }

    private func check() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        guard Date().timeIntervalSince(lastTriggeredTime) >= 30 else { return }
        guard let str = pb.string(forType: .string), str.count > 50 else { return }

        lastTriggeredTime = Date()
        let trigger = classify(str)
        let msg = ReactionLibraryService.shared.reaction(for: trigger)
        guard !msg.isEmpty else { return }
        viewModel?.showSpeechBubble(msg)
        lastSeenContent = str
    }

    // MARK: - Content classification

    private func classify(_ text: String) -> ReactionTrigger {
        if let last = lastSeenContent, text == last { return .clipboardRepeat }
        if isURL(text)        { return .clipboardUrl }
        if looksLikeCode(text) { return .clipboardCode }
        return .clipboardText
    }

    private func isURL(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.hasPrefix("http://") || t.hasPrefix("https://")
    }

    private func looksLikeCode(_ text: String) -> Bool {
        let indicators = ["{", "}", ";", "def ", "func ", "import ",
                          "class ", "const ", "var ", "let ", "->", "=>"]
        return indicators.filter { text.contains($0) }.count >= 2
    }
}
