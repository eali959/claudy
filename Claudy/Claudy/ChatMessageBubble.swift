import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Message Bubble

struct ChatMessageBubble: View {
    let message: ChatMessage
    @State private var showCopied = false
    @AppStorage(DefaultsKeys.chatFontSize) private var chatFontSize: Double = 14
    @AppStorage(DefaultsKeys.userBubbleColor) private var userBubbleColor: String = "orange"
    private var isUser: Bool { message.role == .user }

    private var bubbleColor: Color {
        switch userBubbleColor {
        case "blue":   return .blue.opacity(0.85)
        case "green":  return .green.opacity(0.75)
        case "purple": return .purple.opacity(0.75)
        default:       return Color(red: 0.784, green: 0.361, blue: 0.220)
        }
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 50) }

            bubbleContent
                .accessibilityLabel(isUser ? "You: \(message.content)" : "Claud-y: \(message.content)")
                .accessibilityHint("Long press to copy")
                .onLongPressGesture(minimumDuration: 0.4) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message.content, forType: .string)
                    withAnimation { showCopied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation { showCopied = false }
                    }
                }
                .overlay(alignment: .top) {
                    if showCopied {
                        Text("Copied")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.75), in: Capsule())
                            .offset(y: -26)
                            .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    }
                }

            if !isUser { Spacer(minLength: 50) }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if isUser {
            Text(message.content.isEmpty ? "…" : message.content)
                .font(.system(size: chatFontSize))
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(bubbleColor)
                )
                .textSelection(.enabled)
        } else {
            MarkdownBubble(text: message.content.isEmpty ? "…" : message.content)
        }
    }
}

// MARK: - Markdown Bubble

struct MarkdownBubble: View {
    let text: String
    @AppStorage(DefaultsKeys.chatFontSize) private var chatFontSize: Double = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(parseBlocks(text), id: \.id) { block in
                switch block.kind {
                case .codeBlock(let lang, let code):
                    CodeBlockView(language: lang, code: code)
                case .text(let content):
                    inlineText(content)
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.1))
        )
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func inlineText(_ content: String) -> some View {
        if let attributed = try? AttributedString(
            markdown: content,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            Text(attributed)
                .font(.system(size: chatFontSize))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(content)
                .font(.system(size: chatFontSize))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Block parser

    private struct Block: Identifiable {
        let id = UUID()
        enum Kind { case text(String); case codeBlock(lang: String, code: String) }
        let kind: Kind
    }

    private func parseBlocks(_ input: String) -> [Block] {
        var blocks: [Block] = []
        var remaining = input
        let fence = "```"

        while let fenceRange = remaining.range(of: fence) {
            let before = String(remaining[..<fenceRange.lowerBound])
            if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(Block(kind: .text(before)))
            }
            remaining = String(remaining[fenceRange.upperBound...])

            var lang = ""
            if let newline = remaining.firstIndex(of: "\n") {
                lang = String(remaining[..<newline]).trimmingCharacters(in: .whitespaces)
                remaining = String(remaining[remaining.index(after: newline)...])
            }

            if let closeFence = remaining.range(of: fence) {
                let code = String(remaining[..<closeFence.lowerBound])
                blocks.append(Block(kind: .codeBlock(lang: lang, code: code)))
                remaining = String(remaining[closeFence.upperBound...])
            } else {
                blocks.append(Block(kind: .codeBlock(lang: lang, code: remaining)))
                remaining = ""
            }
        }

        if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks.append(Block(kind: .text(remaining)))
        }

        return blocks.isEmpty ? [Block(kind: .text(input))] : blocks
    }
}

// MARK: - Code Block View

struct CodeBlockView: View {
    let language: String
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if !language.isEmpty {
                    Text(language.lowercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.6))
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.08))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code.trimmingCharacters(in: .newlines))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Export Sheet

struct ExportSheet: View {
    let transcript: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Export Conversation")
                    .font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                Text(transcript.isEmpty ? "No messages yet." : transcript)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    .textSelection(.enabled)
            }
            .frame(height: 200)

            HStack(spacing: 12) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(transcript, forType: .string)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied!" : "Copy All",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.784, green: 0.361, blue: 0.220))

                Button {
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = "claud-y-chat.txt"
                    panel.allowedContentTypes = [UTType.plainText]
                    panel.begin { response in
                        guard response == .OK, let url = panel.url else { return }
                        try? transcript.write(to: url, atomically: true, encoding: .utf8)
                    }
                } label: {
                    Label("Save .txt", systemImage: "arrow.down.doc")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 13))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.8))
        }
        .padding(10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ChatView(viewModel: {
        let vm = ChatViewModel()
        vm.messages = [
            ChatMessage(role: .assistant, content: "Oh good, you're up. What are we doing today?"),
            ChatMessage(role: .user, content: "Help me write a function"),
            ChatMessage(role: .assistant, content: "Here's a simple example:\n\n```swift\nfunc greet(name: String) -> String {\n    return \"Hello, \\(name)!\"\n}\n```\n\nWhat does it need to do?")
        ]
        return vm
    }())
    .frame(width: 300, height: 450)
    .environment(WindowManager())
    .environment(PersonalityManager.shared)
}
