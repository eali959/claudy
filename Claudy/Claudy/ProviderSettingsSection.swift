import SwiftUI

// MARK: - ProviderSettingsSection
// Section 1 fix: all Keychain reads are lazy — keys are NOT loaded on view appear.
// Keys load only when the user focuses a SecureField or taps "Load saved key".

struct ProviderSettingsSection: View {
    @Binding var selectedProviderRaw: String
    @Binding var claudeKeyInput: String
    @Binding var openAIKeyInput: String
    @Binding var geminiKeyInput: String
    @Binding var deepSeekKeyInput: String
    @Binding var isSaved: Bool
    @Binding var saveError: String?
    @Binding var showKey: Bool
    @Binding var testStatus: SettingsView.TestStatus
    @Binding var showRemoveConfirm: Bool

    @FocusState private var keyFieldFocused: Bool

    @State private var ollamaStatus: LocalProviderStatus = .unchecked
    @State private var ollamaModels: [String] = []
    @State private var ollamaChecking: Bool = false
    @State private var lmStudioStatus: LocalProviderStatus = .unchecked
    @State private var lmStudioModels: [String] = []
    @State private var lmStudioChecking: Bool = false
    @AppStorage(DefaultsKeys.ollamaModel) private var ollamaModel: String = "llama3.2:3b"
    @AppStorage(DefaultsKeys.lmStudioModel) private var lmStudioModel: String = ""

    enum LocalProviderStatus { case unchecked, running, notFound, noModels }

    // Curated Ollama models — small enough to run on 8–16 GB Macs.
    // Each entry: pull command, display name, approximate size, one-line hint.
    private struct RecommendedModel: Identifiable {
        let id = UUID()
        let pullCommand: String
        let displayName: String
        let size: String
        let hint: String
    }

    private static let recommendedOllamaModels: [RecommendedModel] = [
        .init(pullCommand: "llama3.2:3b",
              displayName: "Llama 3.2 (3B)",
              size: "~2 GB",
              hint: "Best balance for 8 GB Macs. Recommended."),
        .init(pullCommand: "llama3.2:1b",
              displayName: "Llama 3.2 (1B)",
              size: "~1.3 GB",
              hint: "Tiny + fast. Good for quick replies on 8 GB RAM."),
        .init(pullCommand: "qwen2.5:3b",
              displayName: "Qwen 2.5 (3B)",
              size: "~2 GB",
              hint: "Great reasoning for its size."),
        .init(pullCommand: "gemma3:4b",
              displayName: "Gemma 3 (4B)",
              size: "~3.3 GB",
              hint: "Google's small model. Good for 16 GB Macs."),
        .init(pullCommand: "phi3.5:3.8b",
              displayName: "Phi 3.5 (3.8B)",
              size: "~2.2 GB",
              hint: "Microsoft's compact model. Strong at code.")
    ]

    private var activeProvider: APIProvider {
        APIProvider(rawValue: selectedProviderRaw) ?? .claude
    }

    private var activeKeyBinding: Binding<String> {
        switch activeProvider {
        case .claude:   return $claudeKeyInput
        case .openai:   return $openAIKeyInput
        case .gemini:   return $geminiKeyInput
        case .deepseek: return $deepSeekKeyInput
        case .ollama, .lmStudio: return .constant("")
        }
    }

    // MARK: - Body

    var body: some View {
        Section {
            localProvidersGroup
            cloudProvidersGroup

            if activeProvider.isLocal {
                localProviderDetail
            } else {
                cloudProviderDetail
            }

        } header: {
            Label("AI Provider", systemImage: "key.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 0.784, green: 0.361, blue: 0.220))
        }
    }

    // MARK: - Local group

    private var localProvidersGroup: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LOCAL — Offline, no key required")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)

            ForEach([APIProvider.ollama, .lmStudio], id: \.self) { provider in
                HStack {
                    Image(systemName: selectedProviderRaw == provider.rawValue
                          ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(selectedProviderRaw == provider.rawValue
                                         ? Color(red: 0.784, green: 0.361, blue: 0.220) : .secondary)
                        .onTapGesture { selectProvider(provider) }

                    Label(provider.displayName, systemImage: provider.icon)
                        .onTapGesture { selectProvider(provider) }

                    Spacer()

                    localStatusBadge(for: provider)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func localStatusBadge(for provider: APIProvider) -> some View {
        let status = provider == .ollama ? ollamaStatus : lmStudioStatus
        switch status {
        case .unchecked: EmptyView()
        case .running:
            Label("Running", systemImage: "checkmark.circle.fill")
                .font(.caption).foregroundStyle(.green)
        case .notFound:
            Label("Not found", systemImage: "xmark.circle.fill")
                .font(.caption).foregroundStyle(.red)
        case .noModels:
            Label("No models", systemImage: "exclamationmark.circle.fill")
                .font(.caption).foregroundStyle(.orange)
        }
    }

    // MARK: - Cloud group

    private var cloudProvidersGroup: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CLOUD — API key required")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                .padding(.bottom, 2)

            let cloudProviders: [APIProvider] = [.claude, .openai, .gemini, .deepseek]
            ForEach(cloudProviders, id: \.self) { provider in
                HStack {
                    Image(systemName: selectedProviderRaw == provider.rawValue
                          ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(selectedProviderRaw == provider.rawValue
                                         ? Color(red: 0.784, green: 0.361, blue: 0.220) : .secondary)
                        .onTapGesture { selectProvider(provider) }

                    Label(provider.displayName, systemImage: provider.icon)
                        .onTapGesture { selectProvider(provider) }

                    Spacer()

                    if KeychainService.has(for: provider) {
                        Image(systemName: "key.fill")
                            .font(.caption)
                            .foregroundStyle(.green.opacity(0.8))
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Local provider detail

    @ViewBuilder
    private var localProviderDetail: some View {
        switch activeProvider {
        case .ollama:
            ollamaDetail
                .task(id: "ollama-init") {
                    if ollamaStatus == .unchecked { await checkOllama() }
                }
        case .lmStudio:
            lmStudioDetail
                .task(id: "lmstudio-init") {
                    if lmStudioStatus == .unchecked { await checkLMStudio() }
                }
        default:
            EmptyView()
        }
    }

    // MARK: - Ollama detail

    @ViewBuilder
    private var ollamaDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusHeader(
                title: "Ollama",
                status: ollamaStatus,
                checking: ollamaChecking,
                onRecheck: { Task { await checkOllama() } }
            )

            switch ollamaStatus {
            case .unchecked:
                ProgressView().controlSize(.small)

            case .notFound:
                ollamaNotFoundGuide

            case .noModels:
                ollamaNoModelsGuide

            case .running:
                ollamaRunningPanel
            }

            localPrivacyNote
        }
    }

    /// Step-by-step onboarding shown when Ollama is not running.
    private var ollamaNotFoundGuide: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Let's get Ollama set up — 2 minutes.")
                .font(.system(size: 12, weight: .semibold))

            setupStep(
                number: 1,
                title: "Install Ollama",
                body: "Download the macOS app from ollama.com. After installing, open it once — it runs quietly in the menu bar.",
                primaryLabel: "Open ollama.com",
                primaryAction: { openURL("https://ollama.com/download") }
            )

            setupStep(
                number: 2,
                title: "Pull a model",
                body: "Open Terminal and paste this command. Pick any model from the list below — llama3.2:3b is a great start.",
                mono: "ollama pull llama3.2:3b",
                primaryLabel: "Copy command",
                primaryAction: { copyToClipboard("ollama pull llama3.2:3b") },
                secondaryLabel: "Open Terminal",
                secondaryAction: { openTerminal() }
            )

            setupStep(
                number: 3,
                title: "Come back and recheck",
                body: "Once the pull finishes, click Recheck below. Ollama runs as a background service — you don't need to start it manually.",
                primaryLabel: ollamaChecking ? "Checking…" : "Recheck connection",
                primaryAction: { Task { await checkOllama() } },
                primaryDisabled: ollamaChecking
            )

            recommendedModelsCard
        }
    }

    /// Shown when Ollama is running but no model is pulled yet.
    private var ollamaNoModelsGuide: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ollama is running — you just need a model.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.green)

            Text("Open Terminal and paste one of the pull commands below. The model downloads once and is cached locally.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            recommendedModelsCard

            HStack {
                Button(ollamaChecking ? "Checking…" : "Recheck connection") {
                    Task { await checkOllama() }
                }
                .disabled(ollamaChecking)
                Button("Open Terminal") { openTerminal() }
            }
        }
    }

    /// Shown once a model is pulled and Ollama is live.
    private var ollamaRunningPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            if ollamaModels.isEmpty {
                Label("Connected to Ollama", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green)
            } else {
                Picker("Model", selection: $ollamaModel) {
                    ForEach(ollamaModels, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
                Text("\(ollamaModels.count) model\(ollamaModels.count == 1 ? "" : "s") detected locally.")
                    .font(.caption).foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button("Add another model…") {
                        openURL("https://ollama.com/library")
                    }
                    .font(.caption)
                    Button(ollamaChecking ? "Refreshing…" : "Refresh list") {
                        Task { await checkOllama() }
                    }
                    .font(.caption)
                    .disabled(ollamaChecking)
                }
            }
        }
    }

    /// Recommended-models card used by both .notFound and .noModels states.
    private var recommendedModelsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RECOMMENDED MODELS")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            ForEach(Self.recommendedOllamaModels) { model in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(model.displayName)
                            .font(.system(size: 12, weight: .semibold))
                        Text(model.size)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            copyToClipboard("ollama pull \(model.pullCommand)")
                        } label: {
                            Label("Copy pull", systemImage: "doc.on.doc")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(red: 0.784, green: 0.361, blue: 0.220))
                    }
                    Text(model.hint)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("ollama pull \(model.pullCommand)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.85))
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    // MARK: - LM Studio detail

    @ViewBuilder
    private var lmStudioDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusHeader(
                title: "LM Studio",
                status: lmStudioStatus,
                checking: lmStudioChecking,
                onRecheck: { Task { await checkLMStudio() } }
            )

            switch lmStudioStatus {
            case .unchecked:
                ProgressView().controlSize(.small)

            case .notFound:
                lmStudioNotFoundGuide

            case .noModels:
                lmStudioNoModelsGuide

            case .running:
                lmStudioRunningPanel
            }

            localPrivacyNote
        }
    }

    private var lmStudioNotFoundGuide: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Let's get LM Studio set up — 3 minutes.")
                .font(.system(size: 12, weight: .semibold))

            setupStep(
                number: 1,
                title: "Install LM Studio",
                body: "Download the app from lmstudio.ai. It's a full desktop app with a model browser, so no Terminal needed.",
                primaryLabel: "Open lmstudio.ai",
                primaryAction: { openURL("https://lmstudio.ai") }
            )

            setupStep(
                number: 2,
                title: "Download a model in-app",
                body: "Launch LM Studio → Discover tab → search for a model (e.g. \"Llama 3.2 3B\") → click Download. Pick the Q4_K_M quant for a good size/speed balance.",
                primaryLabel: "Model browsing guide",
                primaryAction: { openURL("https://lmstudio.ai/docs/basics/download-model") }
            )

            setupStep(
                number: 3,
                title: "Start the local server",
                body: "In LM Studio: go to the Developer tab (🔧 icon on the left), load your model, then toggle Status → Running. The server listens on port 1234.",
                primaryLabel: "Server docs",
                primaryAction: { openURL("https://lmstudio.ai/docs/local-server") }
            )

            setupStep(
                number: 4,
                title: "Come back and recheck",
                body: "Click Recheck once LM Studio's local server is Running.",
                primaryLabel: lmStudioChecking ? "Checking…" : "Recheck connection",
                primaryAction: { Task { await checkLMStudio() } },
                primaryDisabled: lmStudioChecking
            )
        }
    }

    private var lmStudioNoModelsGuide: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LM Studio is reachable, but no model is loaded.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)

            Text("Open LM Studio → Developer tab (🔧) → pick a model from the dropdown at the top → make sure Status is set to Running.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(lmStudioChecking ? "Checking…" : "Recheck connection") {
                    Task { await checkLMStudio() }
                }
                .disabled(lmStudioChecking)
                Button("Open LM Studio") { openApp(bundleID: "ai.lmstudio.app") }
            }
        }
    }

    private var lmStudioRunningPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            if lmStudioModels.isEmpty {
                Label("Connected to LM Studio", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green)
            } else {
                Picker("Model", selection: $lmStudioModel) {
                    ForEach(lmStudioModels, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
                Text("\(lmStudioModels.count) model\(lmStudioModels.count == 1 ? "" : "s") loaded.")
                    .font(.caption).foregroundStyle(.secondary)
                Button(lmStudioChecking ? "Refreshing…" : "Refresh list") {
                    Task { await checkLMStudio() }
                }
                .font(.caption)
                .disabled(lmStudioChecking)
            }
        }
    }

    // MARK: - Shared helpers

    @ViewBuilder
    private func statusHeader(
        title: String,
        status: LocalProviderStatus,
        checking: Bool,
        onRecheck: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title).font(.system(size: 12, weight: .semibold))
            Spacer()
            switch status {
            case .unchecked:
                Text("Checking…").font(.caption).foregroundStyle(.secondary)
            case .running:
                Label("Running", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green)
            case .notFound:
                Label("Not reachable", systemImage: "xmark.circle.fill")
                    .font(.caption).foregroundStyle(.red)
            case .noModels:
                Label("No model loaded", systemImage: "exclamationmark.circle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
            Button {
                onRecheck()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(checking)
            .help("Recheck connection")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    /// Small numbered setup card used by the onboarding guides.
    @ViewBuilder
    private func setupStep(
        number: Int,
        title: String,
        body: String,
        mono: String? = nil,
        primaryLabel: String,
        primaryAction: @escaping () -> Void,
        primaryDisabled: Bool = false,
        secondaryLabel: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.784, green: 0.361, blue: 0.220))
                    .frame(width: 22, height: 22)
                Text("\(number)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(body)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let mono {
                    Text(mono)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                        .textSelection(.enabled)
                }
                HStack(spacing: 8) {
                    Button(primaryLabel, action: primaryAction)
                        .disabled(primaryDisabled)
                        .font(.caption)
                    if let secondaryLabel, let secondaryAction {
                        Button(secondaryLabel, action: secondaryAction)
                            .font(.caption)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(10)
        .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.15), lineWidth: 0.5))
    }

    private var localPrivacyNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(.green)
            Text("Runs entirely on your Mac. Prompts, replies, and models never leave your device.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.green.opacity(0.18), lineWidth: 0.5))
    }

    // MARK: - Helper actions

    private func openURL(_ string: String) {
        if let url = URL(string: string) {
            NSWorkspace.shared.open(url)
        }
    }

    private func openTerminal() {
        if let url = URL(string: "file:///System/Applications/Utilities/Terminal.app") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openApp(bundleID: String) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.open(url)
        }
    }

    private func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    // MARK: - Cloud provider detail

    private var cloudProviderDetail: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text("API Key — \(activeProvider.displayName)")
                    .font(.caption).foregroundStyle(.secondary)

                HStack {
                    Group {
                        if showKey {
                            TextField(activeProvider.keyPlaceholder, text: activeKeyBinding)
                        } else {
                            SecureField(activeProvider.keyPlaceholder, text: activeKeyBinding)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .focused($keyFieldFocused)
                    .onChange(of: keyFieldFocused) { _, focused in
                        // Lazy Keychain load: only reads when field is focused and still empty
                        if focused && activeKeyBinding.wrappedValue.isEmpty {
                            activeKeyBinding.wrappedValue =
                                (try? KeychainService.load(for: activeProvider)) ?? ""
                        }
                    }

                    Button { showKey.toggle() } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minHeight: 44)

            // Privacy note
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                    Text("Your key is private — guaranteed")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(activeProvider.privacyNote)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("No Claud-y server exists. There is no middleman. We cannot see your key, your prompts, or your responses — ever.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.green.opacity(0.18), lineWidth: 0.5))

            // Action buttons
            HStack(spacing: 8) {
                Button("Load saved key") { loadKey() }

                Button("Save key") { saveAPIKey() }
                    .disabled(activeKeyBinding.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Test") { testConnection() }
                    .disabled(activeKeyBinding.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)

                switch testStatus {
                case .idle:     EmptyView()
                case .testing:  ProgressView().scaleEffect(0.7)
                case .ok(let msg):
                    Label(msg, systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                case .fail(let msg):
                    Label(msg, systemImage: "xmark.circle.fill").foregroundStyle(.red).font(.caption)
                }
                if isSaved {
                    Label("Saved", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                }
                if let err = saveError {
                    Label(err, systemImage: "xmark.circle.fill").foregroundStyle(.red).font(.caption)
                }
                Spacer()
                Button("Remove Key", role: .destructive) { showRemoveConfirm = true }
                    .foregroundStyle(.red)
            }
            .frame(minHeight: 44)

            if let url = URL(string: activeProvider.docsURL) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Get \(activeProvider.displayName) API key →", systemImage: "arrow.up.right.square")
                        .font(.caption)
                }
                .buttonStyle(.link)
            }

            Text("No key needed — Claud-y works in Companion mode without one. Local, private, and free forever.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func selectProvider(_ provider: APIProvider) {
        selectedProviderRaw = provider.rawValue
        if provider == .ollama && ollamaStatus == .unchecked {
            Task { await checkOllama() }
        } else if provider == .lmStudio && lmStudioStatus == .unchecked {
            Task { await checkLMStudio() }
        }
    }

    private func loadKey() {
        activeKeyBinding.wrappedValue =
            (try? KeychainService.load(for: activeProvider)) ?? ""
    }

    private func saveAPIKey() {
        isSaved = false
        saveError = nil
        let key = activeKeyBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try KeychainService.save(key, for: activeProvider)
            isSaved = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                isSaved = false
            }
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func testConnection() {
        testStatus = .testing
        let provider = activeProvider
        let key = activeKeyBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                switch provider {
                case .claude:
                    var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models")!)
                    req.setValue(key, forHTTPHeaderField: "x-api-key")
                    req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    let (_, res) = try await URLSession.shared.data(for: req)
                    let code = (res as? HTTPURLResponse)?.statusCode ?? 0
                    testStatus = code == 200 ? .ok("Key valid") : .fail("HTTP \(code)")

                case .openai:
                    var req = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
                    req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                    let (_, res) = try await URLSession.shared.data(for: req)
                    let code = (res as? HTTPURLResponse)?.statusCode ?? 0
                    testStatus = code == 200 ? .ok("Key valid") : .fail("HTTP \(code)")

                case .gemini:
                    let urlStr = "https://generativelanguage.googleapis.com/v1beta/models?key=\(key)"
                    let (_, res) = try await URLSession.shared.data(from: URL(string: urlStr)!)
                    let code = (res as? HTTPURLResponse)?.statusCode ?? 0
                    testStatus = code == 200 ? .ok("Key valid") : .fail("HTTP \(code)")

                case .deepseek:
                    var req = URLRequest(url: URL(string: "https://api.deepseek.com/v1/models")!)
                    req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                    let (_, res) = try await URLSession.shared.data(for: req)
                    let code = (res as? HTTPURLResponse)?.statusCode ?? 0
                    testStatus = code == 200 ? .ok("Key valid") : .fail("HTTP \(code)")

                case .ollama:
                    let (_, res) = try await URLSession.shared.data(from: URL(string: "http://localhost:11434/api/tags")!)
                    let code = (res as? HTTPURLResponse)?.statusCode ?? 0
                    testStatus = code == 200 ? .ok("Ollama running") : .fail("HTTP \(code)")

                case .lmStudio:
                    let (_, res) = try await URLSession.shared.data(from: URL(string: "http://localhost:1234/v1/models")!)
                    let code = (res as? HTTPURLResponse)?.statusCode ?? 0
                    testStatus = code == 200 ? .ok("LM Studio running") : .fail("HTTP \(code)")
                }
            } catch {
                testStatus = .fail(error.localizedDescription)
            }
        }
    }

    // MARK: - Local provider detection

    private func checkOllama() async {
        ollamaChecking = true
        defer { ollamaChecking = false }
        do {
            let (data, res) = try await URLSession.shared.data(from: URL(string: "http://localhost:11434/api/tags")!)
            guard (res as? HTTPURLResponse)?.statusCode == 200 else {
                ollamaStatus = .notFound; return
            }
            struct TagsResp: Decodable { struct Model: Decodable { let name: String }; let models: [Model] }
            let decoded = try JSONDecoder().decode(TagsResp.self, from: data)
            let names = decoded.models.map(\.name)
            ollamaModels = names
            ollamaStatus = names.isEmpty ? .noModels : .running
            if ollamaModel.isEmpty || !names.contains(ollamaModel), let first = names.first {
                ollamaModel = first
            }
        } catch {
            ollamaStatus = .notFound
        }
    }

    private func checkLMStudio() async {
        lmStudioChecking = true
        defer { lmStudioChecking = false }
        do {
            let (data, res) = try await URLSession.shared.data(from: URL(string: "http://localhost:1234/v1/models")!)
            guard (res as? HTTPURLResponse)?.statusCode == 200 else {
                lmStudioStatus = .notFound; return
            }
            struct ModelsResp: Decodable { struct Model: Decodable { let id: String }; let data: [Model] }
            let decoded = try JSONDecoder().decode(ModelsResp.self, from: data)
            let names = decoded.data.map(\.id)
            lmStudioModels = names
            lmStudioStatus = names.isEmpty ? .noModels : .running
            if lmStudioModel.isEmpty || !names.contains(lmStudioModel), let first = names.first {
                lmStudioModel = first
            }
        } catch {
            lmStudioStatus = .notFound
        }
    }
}
