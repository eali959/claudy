import AVFoundation
import OSLog

// MARK: - DemoMusicPlayer

/// Plays a synthesised glockenspiel melody during Demo Mode.
///
/// Loops a C-major-pentatonic phrase (16 notes, 8.5 s at 120 BPM) using additive synthesis.
/// Fades in over 1 s on `play()` and fades out over 1.4 s on `fadeOutAndStop()`.
/// Silent when "SoundEffectsEnabled" is false.
@MainActor
final class DemoMusicPlayer {
    static let shared = DemoMusicPlayer()

    private let engine     = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let mixerNode  = AVAudioMixerNode()
    private let sampleRate: Double = 44100
    private let format: AVAudioFormat
    private var playTask:  Task<Void, Never>?
    private var fadeTask:  Task<Void, Never>?
    private let logger = Logger(subsystem: "com.claudy", category: "DemoMusic")

    private init() {
        // Safe: 44100 Hz mono PCM is a universally valid format on all shipping macOS versions.
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(playerNode)
        engine.attach(mixerNode)
        engine.connect(playerNode, to: mixerNode, format: format)
        engine.connect(mixerNode, to: engine.mainMixerNode, format: format)
        mixerNode.outputVolume = 0
        do {
            try engine.start()
        } catch {
            logger.error("DemoMusicPlayer engine failed to start: \(error.localizedDescription)")
        }
    }

    func play() {
        guard UserDefaults.standard.bool(forKey: DefaultsKeys.soundEffectsEnabled) else { return }
        stopAll()
        mixerNode.outputVolume = 0
        playTask = Task { [weak self] in
            guard let self else { return }
            await self.fadeVolume(to: targetVolume, duration: 1.0)
            while !Task.isCancelled {
                await self.playMelodyLoop()
            }
        }
    }

    func fadeOutAndStop() {
        playTask?.cancel()
        playTask = nil
        fadeTask = Task { [weak self] in
            guard let self else { return }
            await self.fadeVolume(to: 0.0, duration: 1.4)
            self.playerNode.stop()
        }
    }

    // MARK: - Private

    /// Target playback volume - quiet enough not to overpower speech bubbles.
    private var targetVolume: Float {
        let stored = UserDefaults.standard.double(forKey: DefaultsKeys.soundVolume)
        let base = stored > 0 ? Float(min(1.0, stored)) : 0.7
        return base * 0.22
    }

    // C-major-pentatonic melody - two 4-bar phrases (8.5 s loop at 120 BPM).
    // Format: (Hz, duration in seconds)
    private let melody: [(Double, Double)] = [
        // Phrase 1 - ascending/bouncy
        (523.25, 0.50),  // C5
        (659.25, 0.50),  // E5
        (783.99, 0.50),  // G5
        (880.00, 0.50),  // A5
        (783.99, 0.50),  // G5
        (659.25, 0.50),  // E5
        (587.33, 0.50),  // D5
        (523.25, 1.00),  // C5 (held)
        // Phrase 2 - returns to root via lower notes
        (392.00, 0.50),  // G4
        (523.25, 0.25),  // C5
        (587.33, 0.25),  // D5
        (659.25, 0.50),  // E5
        (523.25, 0.50),  // C5
        (440.00, 0.50),  // A4
        (523.25, 0.50),  // C5
        (392.00, 1.00),  // G4 (held)
    ]

    private func playMelodyLoop() async {
        for (freq, dur) in melody {
            guard !Task.isCancelled else { return }
            scheduleNote(frequency: freq, noteDuration: dur * 0.82)
            try? await Task.sleep(for: .seconds(dur))
        }
    }

    /// Synthesise a single glockenspiel-style note and schedule it on the player.
    private func scheduleNote(frequency: Double, noteDuration: Double) {
        let frameCount = AVAudioFrameCount(sampleRate * max(noteDuration, 0.05))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channelData = buffer.floatChannelData else { return }

        buffer.frameLength = frameCount
        let samples = channelData[0]

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            // Quick-decay bell envelope
            let envelope = Float(exp(-5.5 * t / noteDuration) * exp(-0.5))
            // Additive synthesis: fundamental + 2nd + 3rd partial (glockenspiel character)
            let f1 = Float(sin(2.0 * .pi * frequency       * t))
            let f2 = Float(sin(2.0 * .pi * frequency * 2.0 * t)) * 0.30
            let f3 = Float(sin(2.0 * .pi * frequency * 3.0 * t)) * 0.10
            samples[frame] = (f1 + f2 + f3) * envelope * 0.55
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
    }

    private func fadeVolume(to target: Float, duration: Double) async {
        let steps = 30
        let stepDuration = duration / Double(steps)
        let start = mixerNode.outputVolume
        for i in 0...steps {
            guard !Task.isCancelled else { return }
            let progress = Float(i) / Float(steps)
            mixerNode.outputVolume = start + (target - start) * progress
            try? await Task.sleep(for: .seconds(stepDuration))
        }
    }

    private func stopAll() {
        playTask?.cancel()
        playTask = nil
        fadeTask?.cancel()
        fadeTask = nil
        playerNode.stop()
        mixerNode.outputVolume = 0
    }
}
