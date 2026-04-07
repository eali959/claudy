import SwiftUI

/// Input bar component for ChatView.
/// The full implementation is composed inline in ChatView.swift because
/// it depends on viewModel state (@Bindable ChatViewModel) directly.
/// This file marks the component boundary for Phase 5 refactoring.
///
/// When refactoring for full extraction, pass:
///   - inputText: Binding<String>
///   - isAPIMode: Bool
///   - isStreaming: Bool
///   - chatFontSize: Double
///   - onSend: () -> Void
///   - onCancel: () -> Void
struct ChatInputBarPreview: View {
    var body: some View {
        Text("ChatInputBar — see ChatView.swift inputBar section")
            .foregroundStyle(.secondary)
    }
}
