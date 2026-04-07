import SwiftUI

/// Header bar component for ChatView (mode pill + personality pill + action buttons).
/// The full implementation is composed inline in ChatView.swift because
/// it depends on multiple @State properties and @Environment(PersonalityManager) directly.
/// This file marks the component boundary for Phase 5 refactoring.
///
/// When refactoring for full extraction, pass:
///   - isAPIMode: Bool
///   - hasAPIKey: Bool
///   - personalityManager: PersonalityManager
///   - onExport: () -> Void
///   - onClearHistory: () -> Void
///   - onClose: () -> Void
struct ChatHeaderBarPreview: View {
    var body: some View {
        Text("ChatHeaderBar — see ChatView.swift header section")
            .foregroundStyle(.secondary)
    }
}
