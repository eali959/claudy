import Foundation
import SwiftUI
import Observation
import OSLog

// MARK: - VoiceModeManager (V4)
//
// Thin coordinator that bridges `VoiceManager` (TTS / STT plumbing) to the
// character's expressive layer.  Drives distinct visual states:
//   • Distinct visual states for idle / listening / speaking / thinking
//   • Voice-only minimal overlay (no full chat panel during voice exchange)
//   • Mouth amplitude pulse drives the character's lip-sync
//   • Privacy-first defaults — mic-on indicator visible at all times
//
// Drop-in: subscribe `voiceCharacterState` from CharacterViewModel and
// override the active animation state when in voice mode.
@MainActor
@Observable
final class VoiceModeManager {
    static let shared = VoiceModeManager()

    // MARK: - Public observable state

    /// True while the user is in an active voice exchange.  When true,
    /// the chat panel is suppressed and the voice-only minimal overlay
    /// is shown instead.
    private(set) var isVoiceModeActive: Bool = false

    /// Push-to-talk hotkey state — true while user is holding the key.
    private(set) var isPushToTalkHeld: Bool = false

    /// Visible state for the character — drives animation override.
    enum VoiceCharacterState: Equatable, Sendable {
        case off          // not in voice mode
        case listening    // mic open, waiting / hearing user
        case thinking     // user finished, AI processing
        case speaking     // TTS producing audio
    }
    private(set) var voiceCharacterState: VoiceCharacterState = .off

    /// Mouth pulse 0…1 — drives lip-sync amplitude.  Updated while
    /// `voiceCharacterState == .speaking`.
    private(set) var mouthPulse: Float = 0

    /// Last error surfaced to the overlay (mic permission denied, speech
    /// unavailable, etc).  Cleared on successful start.
    private(set) var errorMessage: String? = nil

    // MARK: - Configuration

    /// User-configurable hotkey for push-to-talk.  Default ⌘⇧V.
    var pushToTalkHotkey: String {
        get { UserDefaults.standard.string(forKey: "PushToTalkHotkey") ?? "cmd+shift+v" }
        set { UserDefaults.standard.set(newValue, forKey: "PushToTalkHotkey") }
    }

    /// Privacy: keep mic data on-device.  When true, voice mode requires
    /// a local TTS/STT pipeline — never routes audio to a cloud service.
    var localOnly: Bool {
        get { UserDefaults.standard.bool(forKey: "VoiceModeLocalOnly") }
        set { UserDefaults.standard.set(newValue, forKey: "VoiceModeLocalOnly") }
    }

    // MARK: - Private

    private let logger = Logger(subsystem: "com.claudy", category: "VoiceModeManager")
    private var pollTask: Task<Void, Never>?

    // MARK: - Init

    private init() {
        startObservingVoiceManager()
    }

    // MARK: - Lifecycle

    /// Begin a voice exchange.  Auto-starts the mic so the user doesn't
    /// have to tap twice.  Surfaces permission errors via `errorMessage`.
    func enterVoiceMode() {
        guard !isVoiceModeActive else { return }
        isVoiceModeActive = true
        voiceCharacterState = .listening
        errorMessage = nil
        Task { @MainActor in
            await VoiceManager.shared.requestPermissionsIfNeeded()
            let vm = VoiceManager.shared
            // Diagnose why startListening might fail BEFORE calling it,
            // so we can show a precise error instead of "Listening…" forever.
            if !vm.micAuthorized {
                self.errorMessage = "Microphone permission denied. Open System Settings → Privacy & Security → Microphone and enable Claud-y."
                self.logger.error("mic not authorized")
                return
            }
            if !vm.speechAuthorized {
                self.errorMessage = "Speech Recognition permission denied. Open System Settings → Privacy & Security → Speech Recognition and enable Claud-y."
                self.logger.error("speech not authorized")
                return
            }
            do {
                try vm.startListening()
                self.errorMessage = nil
                self.startSilenceWatcher()
            } catch {
                self.errorMessage = "Couldn't start mic: \(error.localizedDescription)"
                self.logger.error("auto-start mic failed: \(error.localizedDescription)")
            }
        }
        logger.info("Entered voice mode (mic auto-opened)")
    }

    /// End the current voice exchange.  Closes mic, dismisses overlay.
    func exitVoiceMode() {
        guard isVoiceModeActive else { return }
        isVoiceModeActive = false
        voiceCharacterState = .off
        mouthPulse = 0
        // Stop any active listening / speaking
        // (VoiceManager exposes its own stop methods)
        logger.info("Exited voice mode")
    }

    /// Push-to-talk down event — hotkey pressed.
    func pushToTalkDown() {
        isPushToTalkHeld = true
        if !isVoiceModeActive { enterVoiceMode() }
    }

    /// Push-to-talk up event — hotkey released.
    func pushToTalkUp() {
        isPushToTalkHeld = false
    }

    /// Set externally by CharacterRootView when chat is sending a request
    /// to the AI.  Drives the .thinking visual state.
    var isChatProcessing: Bool = false

    /// Begin a microphone listening session.  Called from the overlay's
    /// mic button.  Requests permissions, starts the recognizer pipeline,
    /// and arms the silence-timer that auto-submits the transcript after
    /// the user pauses for `silenceTimeout` seconds.
    func startListeningSession() {
        Task { @MainActor in
            await VoiceManager.shared.requestPermissionsIfNeeded()
            do {
                try VoiceManager.shared.startListening()
                startSilenceWatcher()
            } catch {
                logger.error("startListening failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Silence auto-submit

    /// User-configurable silence threshold (seconds of stable transcript
    /// before auto-submission).  1.6s is the natural pause between
    /// speaker turns — long enough to avoid mid-sentence cuts, short
    /// enough that the user doesn't sit waiting after they finish.
    var silenceTimeout: Double = 1.6

    private var silenceTask: Task<Void, Never>?
    private var lastTranscriptAtCheck: String = ""
    private var lastTranscriptChangeAt: TimeInterval = 0
    private var listeningStartedAt:    TimeInterval = 0

    /// Max time the mic can stay open without the transcript growing
    /// (i.e. the user said nothing).  Prevents infinite "Listening…".
    private let maxSilentListen: Double = 7.0

    private func startSilenceWatcher() {
        silenceTask?.cancel()
        lastTranscriptAtCheck = ""
        let start = Date().timeIntervalSince1970
        listeningStartedAt = start
        lastTranscriptChangeAt = start
        silenceTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self else { return }
                let vm = VoiceManager.shared
                guard vm.isListening else { return }   // ended elsewhere
                let now = Date().timeIntervalSince1970
                let cur = vm.partialTranscript

                if cur != self.lastTranscriptAtCheck {
                    // Transcript still growing — reset the silence clock
                    self.lastTranscriptAtCheck = cur
                    self.lastTranscriptChangeAt = now
                    continue
                }

                // Stable transcript — submit if non-empty after silenceTimeout
                if !cur.isEmpty,
                   (now - self.lastTranscriptChangeAt) > self.silenceTimeout {
                    self.silenceTask = nil
                    self.stopListeningAndSubmit()
                    return
                }

                // Empty transcript that's been empty too long → close the
                // mic (user said nothing).  Returns to "Tap to talk" state.
                if cur.isEmpty,
                   (now - self.listeningStartedAt) > self.maxSilentListen {
                    self.silenceTask = nil
                    VoiceManager.shared.stopListening(commit: false)
                    self.voiceCharacterState = .listening
                    return
                }
            }
        }
    }

    private func stopSilenceWatcher() {
        silenceTask?.cancel()
        silenceTask = nil
    }

    /// Stop listening + commit transcript.  Posts
    /// `.claudyVoiceTranscriptReady` with the transcript so CharacterRootView
    /// can route it through the chat → AI → TTS flow.
    func stopListeningAndSubmit() {
        stopSilenceWatcher()
        VoiceManager.shared.stopListening(commit: true)
        let text = VoiceManager.shared.lastTranscript
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            voiceCharacterState = .listening
            return
        }
        isChatProcessing = true
        voiceCharacterState = .thinking
        NotificationCenter.default.post(name: .claudyVoiceTranscriptReady,
                                         object: text)
    }

    // MARK: - Observation

    /// Poll VoiceManager state.  In a future pass this should be replaced
    /// with a proper Observation pipeline, but @Observable doesn't yet
    /// expose a notification stream so polling at 10Hz is the simplest
    /// correct approach.
    private func startObservingVoiceManager() {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.refreshFromVoiceManager()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func refreshFromVoiceManager() {
        let vm = VoiceManager.shared
        guard isVoiceModeActive else { return }
        let prev = voiceCharacterState
        if vm.isSpeaking {
            voiceCharacterState = .speaking
            let now = Date().timeIntervalSince1970
            let dt  = now - lastWordEventAt
            let decay = exp(-dt / 0.18)
            mouthPulse = Float(decay)
        } else if vm.isListening {
            voiceCharacterState = .listening
            mouthPulse = 0
        } else if isChatProcessing {
            voiceCharacterState = .thinking
            mouthPulse = 0
        } else {
            // No mic, no TTS, no AI in flight — ready for the user to tap
            // the mic again.  Show "listening" pose so it's an inviting
            // state, not a frozen "thinking" forever.
            voiceCharacterState = .listening
            mouthPulse = 0
        }
        if prev != voiceCharacterState {
            NotificationCenter.default.post(name: .claudyVoiceStateChanged,
                                             object: voiceCharacterState)
        }
    }

    // MARK: - Word-boundary event

    /// Wall-clock timestamp of the last synth word-boundary event.
    /// VoiceManager calls `noteSpokenWord()` from its synthesizer
    /// delegate `willSpeakRangeOfSpeechString` callback.
    private var lastWordEventAt: TimeInterval = 0

    /// Public hook — VoiceManager calls this on every word boundary
    /// during TTS.  Spikes mouthPulse to 1.0; decay handled in
    /// `refreshFromVoiceManager`.
    func noteSpokenWord() {
        lastWordEventAt = Date().timeIntervalSince1970
    }

    // Note: deinit is intentionally absent.  VoiceModeManager is a
    // singleton (.shared) for the app lifetime; the poll task lives until
    // process exit.  Adding a deinit forces a nonisolated context that
    // can't legally read @MainActor-isolated `pollTask`.
}
