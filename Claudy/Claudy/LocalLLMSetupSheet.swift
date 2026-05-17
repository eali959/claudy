import SwiftUI
import AppKit

/// Setup wizard for local LLM providers — Ollama + LM Studio.
///
/// Two tabs (LM Studio default — easier UX). Each tab walks through:
///   1. Install
///   2. Load a model
///   3. Start the local server
/// then surfaces a live "Detected ✓" badge driven by `LocalLLMStatus`,
/// with a "Use this provider" CTA that flips `APIProvider.selected`.
struct LocalLLMSetupSheet: View {
    @Binding var isPresented: Bool
    @State private var selectedTab: LocalProvider = .lmStudio
    @State private var status = LocalLLMStatus.shared

    enum LocalProvider: String, CaseIterable, Identifiable {
        case lmStudio, ollama
        var id: String { rawValue }
        var title: String { self == .lmStudio ? "LM Studio" : "Ollama" }
        var icon: String  { self == .lmStudio ? "server.rack" : "cpu" }
        var blurb: String {
            self == .lmStudio
                ? "Easier — graphical, point-and-click."
                : "Power-user — terminal-driven, scriptable."
        }
        var apiProvider: APIProvider { self == .lmStudio ? .lmStudio : .ollama }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabPicker
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if selectedTab == .lmStudio {
                        lmStudioBody
                    } else {
                        ollamaBody
                    }
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(width: 540, height: 560)
        .task { await status.pingAll() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(red: 0.784, green: 0.361, blue: 0.220))
            VStack(alignment: .leading, spacing: 2) {
                Text("Set up local LLM")
                    .font(.system(size: 16, weight: .bold))
                Text("Run Claud-y entirely on your Mac. Nothing leaves your device.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { isPresented = false } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Tab picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(LocalProvider.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func tabButton(_ tab: LocalProvider) -> some View {
        let active = selectedTab == tab
        let up = tab == .lmStudio ? status.lmStudioUp : status.ollamaUp
        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 13, weight: .semibold))
                Circle()
                    .fill(up ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 7, height: 7)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(active ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .foregroundStyle(active ? Color.primary : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - LM Studio body

    @ViewBuilder
    private var lmStudioBody: some View {
        statusBanner(up: status.lmStudioUp, provider: .lmStudio)

        Text("LM Studio gives you a friendly UI for downloading and running open models. Recommended for most people.")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)

        step(number: 1, title: "Download LM Studio") {
            HStack(spacing: 10) {
                Button("Open lmstudio.ai") {
                    NSWorkspace.shared.open(URL(string: "https://lmstudio.ai")!)
                }
                .buttonStyle(.borderedProminent)
                Text("Free for personal use.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }

        step(number: 2, title: "Load a model") {
            VStack(alignment: .leading, spacing: 6) {
                Text("In LM Studio, open the **Discover** tab and download a small model — recommended:")
                    .font(.system(size: 12))
                bullet("Llama 3.2 3B Instruct  — fast, ~2 GB")
                bullet("Qwen 2.5 7B Instruct   — smarter, ~4.5 GB")
                bullet("Phi-3 Mini             — tiny + speedy, ~2 GB")
            }
        }

        step(number: 3, title: "Start the local server") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Click the **Developer** tab (left sidebar) → toggle **Start Server**. Default port is `1234` — Claud-y looks here automatically.")
                    .font(.system(size: 12))
                Text("Tip: enable **Just-in-Time Model Loading** so it warms up on first request.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Ollama body

    @ViewBuilder
    private var ollamaBody: some View {
        statusBanner(up: status.ollamaUp, provider: .ollama)

        Text("Ollama is a lean, terminal-driven runtime. Best if you're comfortable in the command line.")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)

        step(number: 1, title: "Install Ollama") {
            VStack(alignment: .leading, spacing: 8) {
                copyableCommand("brew install ollama")
                Text("Or download from ollama.com.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button("Open ollama.com") {
                    NSWorkspace.shared.open(URL(string: "https://ollama.com")!)
                }
                .buttonStyle(.bordered)
            }
        }

        step(number: 2, title: "Pull a model") {
            VStack(alignment: .leading, spacing: 6) {
                copyableCommand("ollama pull llama3.2:3b")
                Text("Other good picks: `qwen2.5:7b`, `phi3:mini`, `mistral:7b`.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }

        step(number: 3, title: "Start the server") {
            VStack(alignment: .leading, spacing: 6) {
                copyableCommand("ollama serve")
                Text("Or just run any `ollama run …` — it'll start the server on port `11434` automatically.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Status banner + CTA

    private func statusBanner(up: Bool, provider: LocalProvider) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(up ? Color.green : Color.orange)
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(up ? "\(provider.title) detected" : "\(provider.title) not detected")
                    .font(.system(size: 12, weight: .semibold))
                Text(up
                     ? "Ready to use. Tap below to switch Claud-y to this provider."
                     : "Follow the steps below, then tap Refresh.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Refresh") {
                Task { await status.pingAll() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((up ? Color.green : Color.orange).opacity(0.10))
        )
    }

    // MARK: - Footer

    private var footer: some View {
        let up = selectedTab == .lmStudio ? status.lmStudioUp : status.ollamaUp
        return HStack {
            Text("Privacy: nothing leaves your Mac when a local provider is selected.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Use this provider") {
                APIProvider.selected = selectedTab.apiProvider
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .disabled(!up)
        }
        .padding(12)
    }

    // MARK: - Reusable bits

    private func step<Content: View>(number: Int, title: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.18))
                    .frame(width: 26, height: 26)
                Text("\(number)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                content()
            }
            Spacer(minLength: 0)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").foregroundStyle(.secondary)
            Text(text).font(.system(size: 12, design: .monospaced))
        }
    }

    private func copyableCommand(_ cmd: String) -> some View {
        HStack(spacing: 8) {
            Text(cmd)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                .textSelection(.enabled)
            Button {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(cmd, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Copy")
        }
    }
}
