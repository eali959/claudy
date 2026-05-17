import SwiftUI
import AppKit

// MARK: - VoiceModeSettingsSection (V4.0)
//
// Settings panel for Voice Mode — exposes:
//   • Voice persona picker (Cute / Yo / Q / Classic)
//   • Auto-speak toggle (read assistant replies aloud)
//   • Silence-detection timeout (how long a pause counts as "user done")
//   • Permission status (mic + speech recognition) with a quick link
//     to System Settings
//   • Push-to-talk hotkey display
//   • A "Talk to Claud-y" button that opens the overlay
//
// The voice plumbing already exists (`VoiceManager`, `VoiceModeManager`,
// `VoiceOverlayController`) — this view is the GUI front-door so users can
// configure voice mode without right-clicking Claud-y.
struct VoiceModeSettingsSection: View {

    @AppStorage(DefaultsKeys.voicePersona)   private var personaRaw: String = VoicePersona.systemDefault.rawValue
    @AppStorage(DefaultsKeys.voiceAutoSpeak) private var autoSpeak: Bool = true

    @State private var silenceTimeout: Double = VoiceModeManager.shared.silenceTimeout
    @State private var localOnly:      Bool   = VoiceModeManager.shared.localOnly
    @State private var micAuthorized:      Bool = VoiceManager.shared.micAuthorized
    @State private var speechAuthorized:   Bool = VoiceManager.shared.speechAuthorized
    @State private var refreshTimer: Timer? = nil

    var body: some View {
        Section {
            // Persona picker
            HStack {
                Image(systemName: "person.wave.2.fill")
                    .foregroundStyle(.tint)
                    .frame(width: 18)
                Picker("Voice persona", selection: $personaRaw) {
                    ForEach(VoicePersona.allCases, id: \.self) { p in
                        Text(p.displayName).tag(p.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
            .frame(minHeight: 36)
            Text("Picks the voice + cadence Claud-y uses for spoken replies. Tap **Preview voice** below to hear it.")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Preview voice") {
                    VoiceManager.shared.speak("Hi, I'm Claud-y — this is what I sound like.")
                }
                .controlSize(.small)
            }

            Divider()

            // Auto-speak
            Toggle("Auto-speak assistant replies", isOn: $autoSpeak)
                .frame(minHeight: 36)
            Text("When on, Claud-y reads each AI reply out loud as it finishes streaming — works whether you sent the message via voice or by typing.")
                .font(.caption).foregroundStyle(.secondary)

            // Silence timeout
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Auto-submit pause")
                    Spacer()
                    Text("\(silenceTimeout, specifier: "%.1f")s")
                        .foregroundStyle(.secondary).font(.caption).monospacedDigit()
                }
                Slider(value: $silenceTimeout, in: 0.6...4.0, step: 0.1) { _ in
                    VoiceModeManager.shared.silenceTimeout = silenceTimeout
                }
            }
            .frame(minHeight: 36)
            Text("How long a silent pause counts as 'I'm done talking'. Voice Mode auto-submits your message after this much silence.")
                .font(.caption).foregroundStyle(.secondary)

            // Local-only privacy toggle
            Toggle("Local-only voice (no cloud)", isOn: $localOnly)
                .onChange(of: localOnly) { _, new in
                    VoiceModeManager.shared.localOnly = new
                }
                .frame(minHeight: 36)
            Text("When on, Voice Mode requires a local LLM (Ollama or LM Studio) and a local speech engine — your audio and transcript never leave your Mac.")
                .font(.caption).foregroundStyle(.secondary)

            Divider()

            // Permission status
            permissionRow(label: "Microphone",
                          authorized: micAuthorized,
                          systemPath: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
            permissionRow(label: "Speech Recognition",
                          authorized: speechAuthorized,
                          systemPath: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")

            Divider()

            // Hotkey + entry button
            HStack {
                Image(systemName: "keyboard")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text("Push-to-talk hotkey")
                Spacer()
                Text("⌘⇧V").font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
            }
            .frame(minHeight: 36)

            HStack {
                Spacer()
                Button {
                    NotificationCenter.default.post(name: .claudyShowVoiceMode, object: nil)
                } label: {
                    Label("Talk to Claud-y now", systemImage: "waveform.circle.fill")
                }
                .controlSize(.regular)
            }
        } header: {
            Label("Voice Mode", systemImage: "waveform.circle.fill")
                .font(.system(size: 13, weight: .semibold))
        }
        .onAppear  { startPermissionPolling() }
        .onDisappear { stopPermissionPolling() }
    }

    @ViewBuilder
    private func permissionRow(label: String, authorized: Bool, systemPath: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: authorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(authorized ? .green : .orange)
                .frame(width: 18)
            Text(label)
            Spacer()
            if authorized {
                Text("Granted").font(.caption).foregroundStyle(.secondary)
            } else {
                Button("Open System Settings") {
                    if let url = URL(string: systemPath) { NSWorkspace.shared.open(url) }
                }
                .controlSize(.small)
            }
        }
        .frame(minHeight: 30)
    }

    // MARK: - Auth polling

    private func startPermissionPolling() {
        stopPermissionPolling()
        refresh()
        // Poll every 2s while view is visible — the OS doesn't notify on
        // permission change, so polling is the simplest reliable refresh.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in refresh() }
        }
    }

    private func stopPermissionPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refresh() {
        micAuthorized    = VoiceManager.shared.micAuthorized
        speechAuthorized = VoiceManager.shared.speechAuthorized
    }
}
