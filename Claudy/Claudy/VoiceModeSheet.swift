import SwiftUI
import AppKit

/// Voice Mode — full-screen-ish sheet that lets the user talk to Claud-y.
///
/// Flow:
///   1. User taps the big mic → VoiceManager.startListening()
///   2. Live partial transcript shown
///   3. User taps stop (or press-and-hold release) → transcript sent through ChatViewModel
///   4. ChatViewModel streams response → tokens accumulate
///   5. On stream finish, VoiceManager.speak(reply) — character animates while TTS plays
///   6. Loop back to (1)
struct VoiceModeSheet: View {
    @Binding var isPresented: Bool
    let chatViewModel: ChatViewModel
    let characterViewModel: CharacterViewModel

    @State private var voice = VoiceManager.shared
    @AppStorage(DefaultsKeys.voiceAutoSpeak) private var autoSpeak: Bool = true

    @State private var lastSpokenMessageID: UUID?
    @State private var pulseScale: CGFloat = 1.0
    @State private var permissionDenied = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 24) {
                    personaPicker
                    transcriptView
                    micButton
                    autoSpeakToggle
                    voicesHint
                }
                .padding(24)
            }
            Divider()
            footer
        }
        .frame(width: 520, height: 620)
        .task { await voice.requestPermissionsIfNeeded() }
        .onReceive(NotificationCenter.default.publisher(for: .claudyVoiceMouthPulse)) { _ in
            withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) {
                pulseScale = 1.18
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) {
                    pulseScale = 1.0
                }
            }
        }
        .onChange(of: chatViewModel.isStreaming) { _, streaming in
            if !streaming, autoSpeak {
                speakLatestAssistantMessageIfNew()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(red: 0.784, green: 0.361, blue: 0.220))
            VStack(alignment: .leading, spacing: 2) {
                Text("Voice Mode")
                    .font(.system(size: 16, weight: .bold))
                Text("Talk to Claud-y. He'll talk back.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { closeAndCleanup() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Persona picker

    private var personaPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Voice")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(VoicePersona.allCases) { p in
                    personaCard(p)
                }
            }
        }
    }

    private func personaCard(_ p: VoicePersona) -> some View {
        let active = voice.persona == p
        return Button {
            voice.persona = p
            // Sample line so the user can hear it.
            voice.speak(samplePhrase(for: p))
        } label: {
            VStack(spacing: 6) {
                Image(systemName: p.icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(p.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(p.blurb)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(active ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(active ? Color.accentColor : Color.clear, lineWidth: 1.5)
                    )
            )
            .foregroundStyle(active ? Color.primary : Color.secondary)
        }
        .buttonStyle(.plain)
        .help("Tap to preview \(p.displayName)")
    }

    private func samplePhrase(for p: VoicePersona) -> String {
        switch p {
        case .systemDefault: return "Hi, I'm Claud-y. Ready when you are."
        case .cute:          return "Hiii! I'm Cute Claudy and I am SO excited to help!"
        case .yo:            return "Yo. Claudy in the building. What we workin' on?"
        case .q:             return "Claud-y, at your service. Shall we begin?"
        }
    }

    // MARK: - Transcript

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(voice.isListening ? "Listening…" : "Tap the mic to talk")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.08))
                Text(voice.partialTranscript.isEmpty
                     ? (voice.lastTranscript.isEmpty ? "Your words will appear here…" : voice.lastTranscript)
                     : voice.partialTranscript)
                    .font(.system(size: 14))
                    .foregroundStyle(voice.partialTranscript.isEmpty && voice.lastTranscript.isEmpty
                                     ? Color.secondary : Color.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(minHeight: 80, maxHeight: 120)
        }
    }

    // MARK: - Mic button

    private var micButton: some View {
        VStack(spacing: 12) {
            ZStack {
                // Pulse ring while speaking
                if voice.isSpeaking {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 2)
                        .frame(width: 130, height: 130)
                        .scaleEffect(pulseScale)
                }
                // Listening ring
                if voice.isListening {
                    Circle()
                        .stroke(Color.red.opacity(0.7), lineWidth: 3)
                        .frame(width: 120, height: 120)
                }
                Button {
                    toggleMic()
                } label: {
                    Circle()
                        .fill(voice.isListening ? Color.red : Color.accentColor)
                        .frame(width: 96, height: 96)
                        .overlay(
                            Image(systemName: voice.isListening ? "stop.fill" : "mic.fill")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(chatViewModel.isStreaming)
            }
            Text(micHint)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var micHint: String {
        if chatViewModel.isStreaming { return "Claud-y is replying…" }
        if voice.isSpeaking          { return "Tap mic to interrupt." }
        if voice.isListening         { return "Tap to send." }
        if permissionDenied          { return "Microphone or speech permission denied." }
        return "Tap to start talking."
    }

    private var autoSpeakToggle: some View {
        Toggle(isOn: $autoSpeak) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Auto-speak replies")
                    .font(.system(size: 12, weight: .semibold))
                Text("Claud-y reads each response out loud as it finishes streaming.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
    }

    @ViewBuilder
    private var voicesHint: some View {
        if !voice.persona.hasInstalledPremiumVoice && voice.persona != .systemDefault {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Better voice available")
                        .font(.system(size: 11, weight: .semibold))
                    Text("System Settings → Accessibility → Spoken Content → System Voice → Manage Voices, then download the **Enhanced** version of \(voice.persona.displayName)'s voice for noticeably higher fidelity.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text(voice.micAuthorized && voice.speechAuthorized
                 ? "🔒 Speech recognition runs on-device. Voice playback uses macOS TTS."
                 : "Permissions needed for mic + speech recognition.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Done") { closeAndCleanup() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(12)
    }

    // MARK: - Actions

    private func toggleMic() {
        if voice.isSpeaking {
            voice.stopSpeaking()
            return
        }
        if voice.isListening {
            voice.stopListening(commit: true)
            commitTranscript()
            return
        }
        Task {
            await voice.requestPermissionsIfNeeded()
            do {
                try voice.startListening()
                permissionDenied = false
            } catch {
                permissionDenied = true
            }
        }
    }

    private func commitTranscript() {
        let text = voice.lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        chatViewModel.inputText = text
        chatViewModel.isOpen = true
        chatViewModel.send()
    }

    private func speakLatestAssistantMessageIfNew() {
        guard let last = chatViewModel.messages.last,
              last.role == .assistant,
              last.id != lastSpokenMessageID else { return }
        lastSpokenMessageID = last.id
        voice.speak(last.content)
    }

    private func closeAndCleanup() {
        voice.stopListening(commit: false)
        voice.stopSpeaking()
        isPresented = false
    }
}
