import Foundation
import Observation
import OSLog

// MARK: - QuickAction

/// A contextual one-tap prompt surfaced when a specific app is frontmost.
struct QuickAction: Sendable {
    let label: String          // displayed on the floating button
    let icon: String           // SF Symbol name
    let promptText: String     // pre-filled into chat on tap
}

// MARK: - QuickActionManager

/// Provides a contextual quick-action button near Claud-y when the user switches to
/// an app that has a natural first question.
///
/// Example: switching to Zoom → "Prep talking points?"
/// Tapping fires a Notification that CharacterRootView observes to open chat
/// with the prompt pre-filled.
@MainActor
@Observable
final class QuickActionManager {
    static let shared = QuickActionManager()

    private(set) var currentAction: QuickAction? = nil
    private var hideTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.claudy", category: "QuickAction")

    private init() {}

    // MARK: - Called by AppContextMonitor on app switch

    func appDidActivate(bundleID: String) {
        let lower = bundleID.lowercased()
        guard let action = action(for: lower) else {
            dismiss()
            return
        }
        show(action)
    }

    // MARK: - Show / dismiss

    func show(_ action: QuickAction) {
        hideTask?.cancel()
        currentAction = action
        // Auto-hide after 8 seconds if not tapped
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        hideTask?.cancel()
        hideTask = nil
        currentAction = nil
    }

    // MARK: - Tap handler

    func actionTapped() {
        guard let action = currentAction else { return }
        logger.info("Quick action tapped: \(action.label)")
        NotificationCenter.default.post(
            name: .claudyQuickActionFired,
            object: nil,
            userInfo: ["prompt": action.promptText]
        )
        dismiss()
    }

    // MARK: - App → action mapping

    private func action(for bundleID: String) -> QuickAction? {
        // Video calls
        if bundleID.contains("zoom") {
            return QuickAction(label: "Prep talking points?",
                               icon: "video",
                               promptText: "I'm about to jump on a Zoom call. Help me quickly prep three talking points or key questions to raise.")
        }
        if bundleID.contains("slack") {
            return QuickAction(label: "Draft a message?",
                               icon: "message",
                               promptText: "I need to write a Slack message. Help me draft something clear and concise — I'll tell you what it's about.")
        }
        if bundleID.contains("teams") || bundleID.contains("microsoft.teams") {
            return QuickAction(label: "Prep for meeting?",
                               icon: "person.3",
                               promptText: "I'm about to join a Teams meeting. Help me quickly think through what I should cover or ask.")
        }
        // Writing
        if bundleID.contains("notion") {
            return QuickAction(label: "Help me write?",
                               icon: "doc.text",
                               promptText: "I'm working in Notion. Help me write or structure something — I'll describe what I need.")
        }
        if bundleID.contains("obsidian") {
            return QuickAction(label: "Summarise or expand?",
                               icon: "note.text",
                               promptText: "I'm in Obsidian. I need help with a note — either summarising, expanding, or structuring ideas.")
        }
        if bundleID.contains("pages") || bundleID.contains("word") {
            return QuickAction(label: "Polish this writing?",
                               icon: "pencil",
                               promptText: "I'm writing a document. Paste in what you have and I'll help you improve clarity, tone, or structure.")
        }
        // Presentations
        if bundleID.contains("keynote") || bundleID.contains("powerpoint") {
            return QuickAction(label: "Slide structure help?",
                               icon: "rectangle.on.rectangle",
                               promptText: "I'm building a presentation. Help me structure the slides or write punchy slide titles for what I'm covering.")
        }
        // Spreadsheets
        if bundleID.contains("numbers") || bundleID.contains("excel") {
            return QuickAction(label: "Write a formula?",
                               icon: "function",
                               promptText: "I'm working in a spreadsheet. Help me write or fix a formula — describe what you're trying to calculate.")
        }
        // Email
        if bundleID.contains("outlook") || bundleID.contains("mail") {
            return QuickAction(label: "Draft an email?",
                               icon: "envelope",
                               promptText: "I need to write an email. Tell me who it's to and what you need to say, and I'll draft it for you.")
        }
        // Code review
        if bundleID.contains("github") || bundleID.contains("linear") {
            return QuickAction(label: "Summarise changes?",
                               icon: "arrow.triangle.branch",
                               promptText: "I'm reviewing a PR or issue. Paste in the diff or description and I'll summarise what's changing and flag anything to consider.")
        }
        // API testing
        if bundleID.contains("postman") || bundleID.contains("insomnia") {
            return QuickAction(label: "Debug this request?",
                               icon: "network",
                               promptText: "I'm testing an API request and something isn't working. Describe the endpoint, payload, and what's happening.")
        }
        // Figma / design
        if bundleID.contains("figma") {
            return QuickAction(label: "Design feedback?",
                               icon: "paintpalette",
                               promptText: "I'm in Figma working on a design. Describe what you're working on and I'll give feedback on layout, hierarchy, or copy.")
        }
        return nil
    }
}
