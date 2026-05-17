import SwiftUI
import AppKit
import Observation

// MARK: - VoiceOverlayPanel
//
// Floating voice overlay shown directly BELOW the Claud-y character window.
// Replaces the full-sheet voice UI with a compact, non-intrusive panel:
//
//   ┌──────────────────────────────────┐
//   │   ●●●●●●  (waveform)             │
//   │      [ 🎤 ]                       │   ← big mic button (tap to talk)
//   │   "live transcript appears here"  │
//   └──────────────────────────────────┘
//
// The character itself does the listening / thinking / speaking animation
// (driven by VoiceModeManager.voiceCharacterState).  This panel just shows
// the mic + transcript + waveform.
@MainActor
final class VoiceOverlayController {
    static let shared = VoiceOverlayController()

    private var panel: NSPanel?
    private weak var characterPanelRef: NSPanel?

    private init() {}

    /// Set the Claud-y character panel so we can position our overlay just
    /// below it.  Called from CharacterPanelController on setup.
    func bindCharacterPanel(_ panel: NSPanel) {
        self.characterPanelRef = panel
    }

    func show() {
        if panel == nil { build() }
        repositionBelowCharacter()
        panel?.orderFrontRegardless()
        VoiceModeManager.shared.enterVoiceMode()
    }

    func hide() {
        panel?.orderOut(nil)
        VoiceModeManager.shared.exitVoiceMode()
    }

    func toggle() {
        if panel?.isVisible == true { hide() } else { show() }
    }

    private func build() {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 180),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.hidesOnDeactivate = false
        p.isMovableByWindowBackground = false

        let host = NSHostingController(rootView: VoiceOverlayView(onClose: { [weak self] in
            self?.hide()
        }))
        p.contentView = host.view
        self.panel = p
    }

    private func repositionBelowCharacter() {
        guard let panel = panel else { return }
        guard let char = characterPanelRef else { return }
        let f = char.frame
        let w = panel.frame.width
        let h = panel.frame.height
        // Center horizontally below the character; 12pt gap
        let x = f.midX - w / 2
        let y = f.minY - h - 12
        panel.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
    }
}

// MARK: - VoiceOverlayView (SwiftUI content)

struct VoiceOverlayView: View {
    let onClose: () -> Void

    @State private var pulse: Float = 0
    // V5.10 — wave bars start FLAT (zero) instead of 0.2.  Idle = no wiggle.
    @State private var waveBars: [Float] = Array(repeating: 0.0, count: 18)
    @State private var pollTimer: Timer?

    var body: some View {
        let vm = VoiceModeManager.shared
        ZStack {
            // Background — dark glass with subtle terra-cotta border
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color(red: 0.78, green: 0.36, blue: 0.22).opacity(0.55), lineWidth: 1.2)
                )
                .shadow(color: .black.opacity(0.35), radius: 14, y: 4)

            VStack(spacing: 10) {
                // Waveform bars
                HStack(spacing: 3) {
                    ForEach(0..<waveBars.count, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(barColor(for: vm.voiceCharacterState))
                            .frame(width: 4, height: CGFloat(8 + waveBars[i] * 26))
                            .animation(.easeInOut(duration: 0.18), value: waveBars[i])
                    }
                }
                .frame(height: 36)

                // Big mic button — full voice loop
                Button {
                    let m = VoiceModeManager.shared
                    let voice = VoiceManager.shared
                    if voice.isListening {
                        // Currently listening → user has finished speaking
                        m.stopListeningAndSubmit()
                    } else if voice.isSpeaking {
                        // TTS is playing → tap to interrupt
                        // (no-op for now — let speech finish)
                    } else {
                        // Idle in voice mode → start a new listening session
                        m.startListeningSession()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [
                                Color(red: 0.78, green: 0.36, blue: 0.22),
                                Color(red: 0.62, green: 0.26, blue: 0.14)
                            ], startPoint: .top, endPoint: .bottom))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                            // V5.10 — mic button only pulses while ACTIVELY listening.
                            // Idle / thinking / speaking → static button.
                            .scaleEffect(1.0 + (VoiceManager.shared.isListening ? CGFloat(pulse) * 0.15 : 0))
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                                       value: pulse)
                        Image(systemName: micIcon(for: vm.voiceCharacterState))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)

                // Status / transcript / error line — V4 polish
                if let err = vm.errorMessage {
                    Text(err)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.45))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                } else if VoiceManager.shared.isListening,
                          !VoiceManager.shared.partialTranscript.isEmpty {
                    // Live transcript — shows the user what's being heard
                    Text("\u{201C}\(VoiceManager.shared.partialTranscript)\u{201D}")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .italic()
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .truncationMode(.head)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(statusText(for: vm.voiceCharacterState))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            // Close button (top-right)
            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(Color.black.opacity(0.35)))
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
                Spacer()
            }
        }
        .frame(width: 320, height: 180)
        .onAppear {
            pulse = 1
            startWavePolling()
        }
        .onDisappear {
            pollTimer?.invalidate()
            pollTimer = nil
        }
    }

    private func barColor(for state: VoiceModeManager.VoiceCharacterState) -> Color {
        switch state {
        case .listening: return Color(red: 0.85, green: 0.42, blue: 0.25)
        case .thinking:  return Color(white: 0.55)
        case .speaking:  return Color(red: 1.0,  green: 0.62, blue: 0.30)
        case .off:       return Color(white: 0.25)
        }
    }

    private func micIcon(for state: VoiceModeManager.VoiceCharacterState) -> String {
        switch state {
        case .listening: return "mic.fill"
        case .thinking:  return "ellipsis"
        case .speaking:  return "speaker.wave.2.fill"
        case .off:       return "mic.slash.fill"
        }
    }

    private func statusText(for state: VoiceModeManager.VoiceCharacterState) -> String {
        // Distinguish ACTUAL listening (mic open) from idle-in-voice-mode
        // ("ready to talk again").  VoiceManager.isListening is the truth.
        switch state {
        case .listening:
            return VoiceManager.shared.isListening ? "Listening…" : "Tap to talk"
        case .thinking:  return "Thinking…"
        case .speaking:  return "Speaking…"
        case .off:       return "Tap to talk"
        }
    }

    /// V5.10 — Bars only animate when voice mode is ACTIVELY listening or
    /// speaking.  Previously the random jitter made them wiggle constantly
    /// even when voice mode was off, suggesting always-on audio capture
    /// (which we don't do).  Now:
    ///   • voiceModeActive AND (listening OR speaking) → live amplitude + jitter
    ///   • otherwise (off, thinking, idle in mode) → bars decay to flat (zero)
    /// Visually unmistakable when audio is being captured vs. not.
    private func startWavePolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { _ in
            Task { @MainActor in
                let vm = VoiceModeManager.shared
                let voice = VoiceManager.shared
                waveBars.removeFirst()

                let isLiveAudio = vm.isVoiceModeActive
                                 && (voice.isListening || voice.isSpeaking)
                if isLiveAudio {
                    // Bars react to amplitude (mic pulses or TTS word boundaries)
                    let amp = vm.mouthPulse
                    let jitter = Float.random(in: -0.10...0.10)
                    let nextVal = max(0, min(1, amp * 0.85 + 0.15 + jitter))
                    waveBars.append(nextVal)
                } else {
                    // Decay smoothly toward zero; no jitter while idle
                    let last = waveBars.last ?? 0
                    waveBars.append(max(0, last * 0.85 - 0.02))
                }
            }
        }
    }
}
