import AVFoundation
import OSLog

// MARK: - SoundManager
// Synthesises soft bell and glide tones for UI feedback using AVAudioEngine.
// All sounds are warm, soothing, and in the lower-mid frequency register
// (D4–A4 range) so they never feel harsh or intrusive.
// Zero overhead when disabled.

@MainActor
final class SoundManager {
    static let shared = SoundManager()
    private let logger = Logger(subsystem: "com.claudy", category: "Sound")

    enum SoundEffect {
        case bubblePop    // soft descending boop when a speech bubble appears
        case cleanBuild   // two-note ascending chime on successful Xcode build
        case celebrate    // three-note sparkle for confetti / wins
        case timerDone    // warm resonant bell for Pomodoro session complete
        case chatOpen     // soft rising blip as chat tray slides open
    }

    private let engine      = AVAudioEngine()
    private let playerNode  = AVAudioPlayerNode()
    private let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

    private init() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: audioFormat)
        do {
            try engine.start()
        } catch {
            logger.error("SoundManager engine failed to start: \(error.localizedDescription)")
        }
    }

    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKeys.soundEffectsEnabled)
    }

    private var outputVolume: Float {
        let stored = UserDefaults.standard.double(forKey: DefaultsKeys.soundVolume)
        return stored > 0 ? Float(min(1.0, stored)) : 0.7
    }

    func play(_ effect: SoundEffect) {
        guard isEnabled else { return }
        switch effect {
        case .bubblePop:  playBoop()
        case .cleanBuild: playChime()
        case .celebrate:  playSparkle()
        case .timerDone:  playBell()
        case .chatOpen:   playBlip()
        }
    }

    // MARK: - Effects

    /// Soft descending frequency glide — gentle "doop" when a bubble appears.
    private func playBoop() {
        scheduleGlide(startFreq: 480, endFreq: 340, duration: 0.082, volume: outputVolume * 0.38)
    }

    /// Two-note ascending chime E4 → A4 — satisfying but quiet build-success cue.
    private func playChime() {
        let vol = outputVolume * 0.36
        scheduleBell(frequency: 329.63, duration: 0.11, volume: vol)
        let capturedVol = vol
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(140))
            self?.scheduleBell(frequency: 440.0, duration: 0.11, volume: capturedVol)
        }
    }

    /// Three-note sparkle C4 → E4 → G4 — airy and celebratory.
    private func playSparkle() {
        let freqs: [Double] = [261.63, 329.63, 392.0]
        let vol = outputVolume * 0.34
        for (i, freq) in freqs.enumerated() {
            let delayMs = i * 90
            let capturedFreq = freq
            Task { [weak self] in
                if delayMs > 0 { try? await Task.sleep(for: .milliseconds(delayMs)) }
                self?.scheduleBell(frequency: capturedFreq, duration: 0.085, volume: vol)
            }
        }
    }

    /// Warm single bell D4 with long decay — soothing Pomodoro-done tone.
    private func playBell() {
        scheduleBell(frequency: 293.66, duration: 0.28, volume: outputVolume * 0.40)
    }

    /// Rising frequency blip — a soft "tink" as the chat panel opens.
    private func playBlip() {
        scheduleGlide(startFreq: 350, endFreq: 460, duration: 0.065, volume: outputVolume * 0.32)
    }

    // MARK: - Primitive synthesisers

    /// Sine wave that glides linearly from `startFreq` to `endFreq`.
    /// 10% soft attack, 65% sustain, 25% gentle decay.
    private func scheduleGlide(startFreq: Double, endFreq: Double, duration: Double, volume: Float) {
        let sampleRate: Double = 44100
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount),
              let channelData = buffer.floatChannelData else { return }
        buffer.frameLength = frameCount
        let samples = channelData[0]

        for frame in 0..<Int(frameCount) {
            let t        = Double(frame) / sampleRate
            let progress = t / duration

            let envelope: Float
            if progress < 0.10 {
                envelope = Float(progress / 0.10)
            } else if progress > 0.75 {
                envelope = Float((1.0 - progress) / 0.25)
            } else {
                envelope = 1.0
            }

            let freq        = startFreq + (endFreq - startFreq) * progress
            let fundamental = sin(2.0 * .pi * freq * t)
            let harmonic2   = 0.10 * sin(2.0 * .pi * freq * 2.0 * t)
            samples[frame]  = Float(fundamental + harmonic2) * volume * envelope
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
    }

    /// Bell-like tone: 8% soft attack then smooth exponential decay.
    /// 2nd and 3rd harmonics give warmth without harshness.
    private func scheduleBell(frequency: Double, duration: Double, volume: Float) {
        let sampleRate: Double = 44100
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount),
              let channelData = buffer.floatChannelData else { return }
        buffer.frameLength = frameCount
        let samples = channelData[0]

        for frame in 0..<Int(frameCount) {
            let t        = Double(frame) / sampleRate
            let progress = t / duration

            let envelope: Float
            if progress < 0.08 {
                envelope = Float(progress / 0.08)
            } else {
                envelope = Float(exp(-4.5 * (progress - 0.08)))
            }

            let fundamental = sin(2.0 * .pi * frequency * t)
            let harmonic2   = 0.18 * sin(2.0 * .pi * frequency * 2.0 * t)
            let harmonic3   = 0.06 * sin(2.0 * .pi * frequency * 3.0 * t)
            samples[frame]  = Float(fundamental + harmonic2 + harmonic3) * volume * envelope
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
    }
}
