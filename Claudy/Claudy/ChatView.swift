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
                        ChatMessageBubble(message: message)
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

