import Foundation
import AVFoundation
import Speech
import Observation
import OSLog

/// Owns voice I/O for Claud-y:
///   • TTS via AVSpeechSynthesizer (default, on-device, free) or OpenAI TTS (opt-in)
///   • STT via Apple Speech framework (on-device when available)
///   • Persona routing + word-level "mouth pulse" events for the character
///
/// `@MainActor` everywhere — UI subscribes to `isSpeaking`, `isListening`, `partialTranscript`.
@MainActor
@Observable
final class VoiceManager: NSObject {
    static let shared = VoiceManager()

    // MARK: - Public observable state

    /// Currently selected persona. Persisted in UserDefaults.
    var persona: VoicePersona {
        didSet { UserDefaults.standard.set(persona.rawValue, forKey: DefaultsKeys.voicePersona) }
    }

    /// True while AVSpeechSynthesizer is producing audio.
    private(set) var isSpeaking: Bool = false

    /// True while the mic is actively transcribing.
    private(set) var isListening: Bool = false

    /// Live partial transcript while listening. Cleared on commit.
    private(set) var partialTranscript: String = ""

    /// Last finalised transcript (for caller to consume).
    private(set) var lastTranscript: String = ""

    /// Permission state for the mic + speech recognition.
    private(set) var micAuthorized: Bool = false
    private(set) var speechAuthorized: Bool = false

    // MARK: - Private

    private let synth = AVSpeechSynthesizer()
    private let logger = Logger(subsystem: "com.claudy", category: "VoiceManager")

    // Speech recognition
    private let recognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    // MARK: - Init

    override private init() {
        let raw = UserDefaults.standard.string(forKey: DefaultsKeys.voicePersona) ?? VoicePersona.systemDefault.rawValue
        self.persona = VoicePersona(rawValue: raw) ?? .systemDefault
        super.init()
        synth.delegate = self
        refreshAuthorizationState()
    }

    // MARK: - Permissions

    func requestPermissionsIfNeeded() async {
        // Microphone (AVCaptureDevice on macOS).
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
        // Speech recognition.
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                SFSpeechRecognizer.requestAuthorization { _ in cont.resume() }
            }
        }
        refreshAuthorizationState()
    }

    private func refreshAuthorizationState() {
        micAuthorized    = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        speechAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    // MARK: - TTS

    /// Speak a string in the current persona's voice. Replaces any in-flight utterance.
    /// Posts `.claudyVoiceMouthPulse` per word so the character can animate its mouth.
    func speak(_ raw: String) {
        guard !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let text = persona.transform(raw)

        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }

        let utt = AVSpeechUtterance(string: text)
        utt.voice = persona.resolveVoice()
        utt.pitchMultiplier = persona.pitch
        utt.rate            = persona.rate
        utt.volume          = persona.volume
        utt.preUtteranceDelay = 0.05
        utt.postUtteranceDelay = 0.05

        synth.speak(utt)
    }

    /// Hard-stop any active utterance.
    func stopSpeaking() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        isSpeaking = false
        NotificationCenter.default.post(name: .claudyVoiceDidFinishSpeaking, object: nil)
    }

    // MARK: - STT

    /// Begin listening. Updates `partialTranscript` live.
    /// Caller invokes `stopListening()` to commit and read `lastTranscript`.
    func startListening() throws {
        // Tear down anything in flight.
        stopListening(commit: false)

        guard let recognizer, recognizer.isAvailable else {
            throw VoiceError.recognizerUnavailable
        }
        guard speechAuthorized else { throw VoiceError.notAuthorized("speech") }
        guard micAuthorized    else { throw VoiceError.notAuthorized("microphone") }

        let engine = AVAudioEngine()
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak req] buffer, _ in
            req?.append(buffer)
        }

        engine.prepare()
        try engine.start()

        self.audioEngine = engine
        self.request = req
        self.partialTranscript = ""
        self.isListening = true

        self.task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.partialTranscript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.lastTranscript = self.partialTranscript
                    }
                }
                if error != nil {
                    self.stopListening(commit: true)
                }
            }
        }
    }

    /// Stop listening. If `commit` is true, copies `partialTranscript` into `lastTranscript`.
    func stopListening(commit: Bool = true) {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        request?.endAudio()
        task?.cancel()
        audioEngine = nil
        request = nil
        task = nil
        if commit && !partialTranscript.isEmpty {
            lastTranscript = partialTranscript
        }
        isListening = false
    }

    enum VoiceError: LocalizedError {
        case recognizerUnavailable
        case notAuthorized(String)
        var errorDescription: String? {
            switch self {
            case .recognizerUnavailable: return "Speech recognition is not available on this Mac."
            case .notAuthorized(let what): return "\(what.capitalized) permission was denied. Enable it in System Settings → Privacy & Security."
            }
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
            NotificationCenter.default.post(name: .claudyVoiceDidStartSpeaking, object: nil)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            NotificationCenter.default.post(name: .claudyVoiceDidFinishSpeaking, object: nil)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            NotificationCenter.default.post(name: .claudyVoiceDidFinishSpeaking, object: nil)
        }
    }

    /// Per-word callback — used to drive the character's mouth pulse.
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       willSpeakRangeOfSpeechString characterRange: NSRange,
                                       utterance: AVSpeechUtterance) {
        Task { @MainActor in
            NotificationCenter.default.post(name: .claudyVoiceMouthPulse, object: nil)
            // V4: also feed the VoiceModeManager so the overlay waveform
            // and the character mouth-pulse get a real per-word signal
            // instead of a sine approximation.
            VoiceModeManager.shared.noteSpokenWord()
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    /// Posted when TTS begins. Character can switch to .talking.
    static let claudyVoiceDidStartSpeaking  = Notification.Name("claudyVoiceDidStartSpeaking")
    /// Posted when TTS ends or is cancelled. Character returns to .idle.
    static let claudyVoiceDidFinishSpeaking = Notification.Name("claudyVoiceDidFinishSpeaking")
    /// Posted on each word boundary while speaking — drives mouth scale pulse.
    static let claudyVoiceMouthPulse        = Notification.Name("claudyVoiceMouthPulse")
}
