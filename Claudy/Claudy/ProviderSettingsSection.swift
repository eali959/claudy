import SwiftUI

struct ProviderSettingsSection: View {
    @Binding var selectedProviderRaw: String
    @Binding var claudeKeyInput: String
    @Binding var openAIKeyInput: String
    @Binding var geminiKeyInput: String
    @Binding var isSaved: Bool
    @Binding var saveError: String?
    @Binding var showKey: Bool
    @Binding var testStatus: SettingsView.TestStatus
    @Binding var showRemoveConfirm: Bool

    private var activeProvider: APIProvider {
        APIProvider(rawValue: selectedProviderRaw) ?? .claude
    }

    private var activeKeyBinding: Binding<String> {
        switch activeProvider {
        case .claude: return $claudeKeyInput
        case .openai: return $openAIKeyInput
        case .gemini: return $geminiKeyInput
        }
    }

    var body: some View {
        Section {
            Picker("AI Provider", selection: $selectedProviderRaw) {
                ForEach(APIProvider.allCases, id: \.self) { p in
                    Label(p.displayName, systemImage: p.icon).tag(p.rawValue)
                }
            }
            .frame(minHeight: 44)

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

                    Button { showKey.toggle() } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minHeight: 44)

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
                Text("No Claud-y server exists. There is no middleman. We cannot see your key, your prompts, or your responses — ever. No telemetry, no analytics, no logging of any kind.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.green.opacity(0.18), lineWidth: 0.5))
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text("What API mode is for")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text("API mode powers Claud-y's live reactions, quick-chat, ambient commentary, and in-the-moment responses — the things that make a desktop companion actually feel alive. It is not designed to replace a dedicated AI assistant for long, complex tasks. For deep work, use Claude.ai, ChatGPT, or Gemini directly. Claud-y stays in its lane: present, reactive, and genuinely useful on the fly.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.orange.opacity(0.18), lineWidth: 0.5))
            .padding(.top, 2)

            HStack {
                Button("Save Key") { saveAPIKey() }
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
        } header: {
            Label("API Provider", systemImage: "key.fill").font(.headline)
        }
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
                    guard let endpoint = URL(string: "https://api.anthropic.com/v1/models") else {
                        testStatus = .fail("Invalid endpoint"); return
                    }
                    var req = URLRequest(url: endpoint)
                    req.setValue(key, forHTTPHeaderField: "x-api-key")
                    req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    let (_, res) = try await URLSession.shared.data(for: req)
                    let code = (res as? HTTPURLResponse)?.statusCode ?? 0
                    testStatus = code == 200 ? .ok("Key valid") : .fail("HTTP \(code)")

                case .openai:
                    guard let endpoint = URL(string: "https://api.openai.com/v1/models") else {
                        testStatus = .fail("Invalid endpoint"); return
                    }
                    var req = URLRequest(url: endpoint)
                    req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                    let (_, res) = try await URLSession.shared.data(for: req)
                    let code = (res as? HTTPURLResponse)?.statusCode ?? 0
                    testStatus = code == 200 ? .ok("Key valid") : .fail("HTTP \(code)")

                case .gemini:
                    let urlStr = "https://generativelanguage.googleapis.com/v1beta/models?key=\(key)"
                    guard let endpoint = URL(string: urlStr) else {
                        testStatus = .fail("Invalid endpoint"); return
                    }
                    let (_, res) = try await URLSession.shared.data(from: endpoint)
                    let code = (res as? HTTPURLResponse)?.statusCode ?? 0
                    testStatus = code == 200 ? .ok("Key valid") : .fail("HTTP \(code)")
                }
            } catch {
                testStatus = .fail(error.localizedDescription)
            }
        }
    }
}
