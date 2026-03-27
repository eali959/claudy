import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @Environment(WindowManager.self) private var windowManager
    @Environment(PersonalityManager.self) private var personalityManager
    @FocusState private var inputFocused: Bool?
    @AppStorage("ChatFontSize")      private var chatFontSize: Double = 14
    @AppStorage("ChatWindowOpacity") private var chatWindowOpacity: Double = 1.0

    @State private var resizeDragStartHeight: CGFloat? = nil
    @State private var showExportSheet = false
    @State private var showKeychainExplainer = false
    @State private var showHelp = false

    var body: some View {
        VStack(spacing: 0) {
            resizeHandle
            header
            Divider().opacity(0.35)
            if !viewModel.isAPIMode { companionBanner }
            messageList
            Divider().opacity(0.35)
            inputBar
            tokenFooter
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        .opacity(chatWindowOpacity)
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(transcript: viewModel.exportTranscript())
        }
        .alert("Before you switch to AI mode", isPresented: $showKeychainExplainer) {
            Button("Continue") { viewModel.toggleMode() }
            Button("Stay local", role: .cancel) {}
        } message: {
            Text("In AI mode, your messages are sent to Anthropic's Claude API using the key you saved in Settings. macOS may ask for your keychain password - that's your Mac protecting your key, not Claud-y.\n\nClaud-y stores nothing. No history, no analytics, no telemetry. Your key never leaves your device except to reach Anthropic directly.")
        }
    }

    // MARK: - Resize handle

    private var resizeHandle: some View {
        ZStack {
            Color.clear
            Capsule()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 36, height: 4)
        }
        .frame(height: 18)
        .frame(maxWidth: .infinity)
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    if resizeDragStartHeight == nil {
                        resizeDragStartHeight = windowManager.chatHeight
                    }
                    let proposed = (resizeDragStartHeight ?? windowManager.chatHeight) - value.translation.height
                    windowManager.adjustChatHeight(to: proposed)
                }
                .onEnded { _ in resizeDragStartHeight = nil }
        )
        .help("Drag to resize")
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            // Title + action buttons
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(red: 0.784, green: 0.361, blue: 0.220))
                    .frame(width: 10, height: 10)
                Text("Claud-y")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                headerButton(icon: "square.and.arrow.up", help: "Export conversation") {
                    showExportSheet = true
                }
                .disabled(viewModel.messages.isEmpty)

                headerButton(icon: "trash", help: "Clear conversation") {
                    viewModel.clearHistory()
                }

                // Help button
                Button {
                    showHelp.toggle()
                } label: {
                    Text("?")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("Help")
                .accessibilityLabel("Help")
                .popover(isPresented: $showHelp, arrowEdge: .top) {
                    HelpView()
                }

                headerButton(icon: "xmark", help: "Close") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.isOpen = false
                    }
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // Mode + personality pill row
            HStack(spacing: 6) {
                modePill
                personalityPill
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
    }

    // MARK: - Mode toggle

    private func handleModeToggle() {
        guard viewModel.hasAPIKey, !viewModel.isAPIMode else {
            viewModel.toggleMode()   // switching back to companion - no explainer needed
            return
        }
        let explained = UserDefaults.standard.bool(forKey: "keychainExplainerShown")
        if explained {
            viewModel.toggleMode()
        } else {
            UserDefaults.standard.set(true, forKey: "keychainExplainerShown")
            showKeychainExplainer = true   // alert's "Got it" button calls toggleMode
        }
    }

    // MARK: - Mode pill (Companion ↔ API toggle)

    private var modePill: some View {
        let isAPI = viewModel.isAPIMode
        let canSwitch = viewModel.hasAPIKey
        let dot: Color = isAPI ? .green : Color(red: 0.784, green: 0.361, blue: 0.220)
        let label = isAPI ? "API" : "Companion"

        return Button { handleModeToggle() } label: {
            HStack(spacing: 4) {
                Circle().fill(dot).frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(dot)
                if canSwitch {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(dot.opacity(0.8))
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(dot.opacity(0.15)))
            .overlay(Capsule().stroke(dot.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!canSwitch)
        .help(canSwitch
              ? (isAPI ? "Switch to Companion mode (local responses)" : "Switch to API mode (Claude AI)")
              : "Add an API key in Settings to enable AI mode")
        .accessibilityLabel(isAPI ? "API mode - tap to switch to Companion" : "Companion mode - tap to switch to API")
    }

    // MARK: - Personality pill (tap to cycle through all modes)

    private var personalityPill: some View {
        Menu {
            ForEach(PersonalityMode.allCases, id: \.self) { mode in
                Button {
                    guard mode != personalityManager.currentMode else { return }
                    personalityManager.currentMode = mode
                    viewModel.announcePersonalityChange(to: mode)
                } label: {
                    HStack {
                        Text(mode.displayName)
                        if mode == personalityManager.currentMode {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "theatermasks")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(personalityManager.currentMode.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.8))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.primary.opacity(0.1)))
            .overlay(Capsule().stroke(Color.primary.opacity(0.15), lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Switch personality")
        .accessibilityLabel("Personality: \(personalityManager.currentMode.displayName). Tap to change.")
    }

    // MARK: - Header button

    private func headerButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary.opacity(0.7))
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    // MARK: - Companion mode banner

    private var companionBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            if viewModel.hasAPIKey {
                Text("Responses are local - nothing is sent anywhere.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Use Claude AI") { handleModeToggle() }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.08), in: Capsule())
                    .accessibilityLabel("Switch to API mode")
            } else {
                Text("Responses are local - nothing is sent anywhere. Add an API key in Settings for Claude AI.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if viewModel.isTyping {
                        TypingIndicatorView()
                            .id("typing-indicator")
                            .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .bottomLeading)))
                    }

                    if let error = viewModel.errorMessage {
                        ErrorBanner(message: error)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.isTyping)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: viewModel.messages.last?.content) { _, _ in
                if let last = viewModel.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isTyping) { _, typing in
                if typing {
                    withAnimation { proxy.scrollTo("typing-indicator", anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField(
                viewModel.isAPIMode ? "Ask Claud-y anything…" : "Say something…",
                text: $viewModel.inputText,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.system(size: chatFontSize))
            .foregroundStyle(.primary)
            .lineLimit(1...4)
            .focused($inputFocused, equals: true)
            .accessibilityLabel("Message input")
            .accessibilityHint("Type a message and press Return to send")
            .onSubmit {
                if !viewModel.inputText.isEmpty { viewModel.send() }
            }
            .onAppear { inputFocused = true }

            if viewModel.isStreaming {
                Button(action: viewModel.cancel) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(red: 0.784, green: 0.361, blue: 0.220))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop response")
            } else {
                Button(action: viewModel.send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.primary.opacity(0.25)
                                : Color(red: 0.784, green: 0.361, blue: 0.220)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Send message")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - Footer (only shown when conversation is getting long)

    @State private var showClearAlert = false

    @ViewBuilder
    private var tokenFooter: some View {
        if viewModel.isNearContextLimit {
            // Urgent - conversation is very long
            Button { showClearAlert = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.system(size: 12))
                    Text("This chat is getting very long - start a new one for best results")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.08))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Chat is very long. Tap to start fresh.")
            .alert("Start a new chat?", isPresented: $showClearAlert) {
                Button("Clear and start fresh", role: .destructive) { viewModel.clearHistory() }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("Very long chats can affect response quality. Starting fresh usually helps.")
            }

        } else if viewModel.showContextWarning {
            // Soft warning - getting long but not urgent
            Button { showClearAlert = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.system(size: 12))
                    Text("Long chat - consider starting fresh")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(Color.primary.opacity(0.04))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Chat is getting long. Tap to start fresh.")
            .alert("Start a new chat?", isPresented: $showClearAlert) {
                Button("Clear and start fresh", role: .destructive) { viewModel.clearHistory() }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("Long conversations can affect response quality. Starting fresh may help.")
            }
        }
        // Nothing shown when conversation is short - no noise for the user
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage
    @State private var showCopied = false
    @AppStorage("ChatFontSize") private var chatFontSize: Double = 14
    @AppStorage("UserBubbleColor") private var userBubbleColor: String = "orange"
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

private struct MarkdownBubble: View {
    let text: String
    @AppStorage("ChatFontSize") private var chatFontSize: Double = 14

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

private struct CodeBlockView: View {
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

private struct ExportSheet: View {
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

private struct ErrorBanner: View {
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
