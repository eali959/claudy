import AVFoundation
import OSLog

// MARK: - MumbleEngine

/// Synthesises short pip tones that give Claud-y a cute chipmunk voice.
///
/// Each speech bubble triggers a burst of sine-wave pip tones scaled to text length,
/// with bell-like harmonics and optional vibrato for variety.
/// The two-tone name melody ("Claud-y") is available via `speakName()`.
///
/// Controlled by UserDefaults keys: "CharacterVoiceEnabled", "SoundEffectsEnabled", "IsMuted".
@MainActor
final class MumbleEngine {
    static let shared = MumbleEngine()

    private let engine      = AVAudioEngine()
    private let playerNode  = AVAudioPlayerNode()
    // Safe: 44100 Hz mono PCM is a universally valid format on all shipping macOS versions.
    private let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private var mumbleTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.claudy", category: "Mumble")

    private init() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: audioFormat)
        do {
            try engine.start()
        } catch {
            logger.error("MumbleEngine failed to start: \(error.localizedDescription)")
        }
    }

    /// Play a sequence of cute pip tones scaled to the length of `text`.
    func speak(_ text: String) {
        guard isEnabled else { return }
        stop()
        let pipCount = min(20, max(1, text.count / 3))
        mumbleTask = Task { [weak self] in
            guard let self else { return }
            for _ in 0..<pipCount {
                guard !Task.isCancelled else { return }
                self.schedulePip()
                let spacing = Double.random(in: 0.055...0.095)
                try? await Task.sleep(for: .seconds(spacing))
            }
        }
    }

    /// Play the two-syllable name melody: "Claud-y".
    /// C5 -> G5, gives Claud-y a recognisable musical signature.
    func speakName() {
        guard isEnabled else { return }
        stop()
        mumbleTask = Task { [weak self] in
            guard let self else { return }
            // "Claud": C5, clean bell tone, 130ms
            self.scheduleNameNote(frequency: 523.25, duration: 0.13, vibratoDepth: 0)
            try? await Task.sleep(for: .seconds(0.16))
            guard !Task.isCancelled else { return }
            // "-y": G5, cute vibrato chirp, 95ms
            self.scheduleNameNote(frequency: 783.99, duration: 0.095, vibratoDepth: 22)
        }
    }

    /// Stop any in-progress mumble immediately.
    func stop() {
        mumbleTask?.cancel()
        mumbleTask = nil
        playerNode.stop()
        // Restart the node so it's ready for the next speak() call.
        playerNode.play()
    }

    // MARK: - Private

    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "SoundEffectsEnabled") &&
        UserDefaults.standard.bool(forKey: "CharacterVoiceEnabled") &&
        !UserDefaults.standard.bool(forKey: "IsMuted")
    }

    private var outputVolume: Float {
        let stored = UserDefaults.standard.double(forKey: "SoundVolume")
        let base = stored > 0 ? Float(min(1.0, stored)) : 0.7
        return base * 0.25   // keep mumble quiet relative to other sounds
    }

    /// A single cute pip: higher range, gentle vibrato on ~40% of pips,
    /// 2nd harmonic at 15% for a soft bell/chime quality.
    private func schedulePip() {
        let sampleRate: Double = 44100
        let frequency  = Double.random(in: 520...840)   // higher = cuter
        let duration   = 0.040                           // snappier than before
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let addVibrato = Double.random(in: 0...1) < 0.4

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount),
              let channelData = buffer.floatChannelData else { return }

        buffer.frameLength = frameCount
        let samples = channelData[0]
        let vol = outputVolume

        for frame in 0..<Int(frameCount) {
            let t        = Double(frame) / sampleRate
            let progress = t / duration

            // Snappier envelope: 5% attack, 70% sustain, 25% decay
            let envelope: Float
            if progress < 0.05 {
                envelope = Float(progress / 0.05)
            } else if progress > 0.75 {
                envelope = Float((1.0 - progress) / 0.25)
            } else {
                envelope = 1.0
            }

            let vibratoOffset = addVibrato ? 20.0 * sin(2.0 * .pi * 7.0 * t) : 0.0
            let f = frequency + vibratoOffset
            let fundamental = sin(2.0 * .pi * f * t)
            let harmonic    = 0.15 * sin(2.0 * .pi * f * 2.0 * t)  // bell shimmer

            samples[frame] = Float(fundamental + harmonic) * vol * envelope
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
    }

    /// A sustained name-melody note with optional vibrato.
    private func scheduleNameNote(frequency: Double, duration: Double, vibratoDepth: Double) {
        let sampleRate: Double = 44100
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount),
              let channelData = buffer.floatChannelData else { return }

        buffer.frameLength = frameCount
        let samples = channelData[0]
        let vol = outputVolume * 1.5   // name tones a touch louder for clarity

        for frame in 0..<Int(frameCount) {
            let t        = Double(frame) / sampleRate
            let progress = t / duration

            // Soft attack (5%), long sustain, gentle tail (25%)
            let envelope: Float
            if progress < 0.05 {
                envelope = Float(progress / 0.05)
            } else if progress > 0.75 {
                envelope = Float((1.0 - progress) / 0.25)
            } else {
                envelope = 1.0
            }

            let vibratoOffset = vibratoDepth * sin(2.0 * .pi * 6.5 * t)
            let f           = frequency + vibratoOffset
            let fundamental = sin(2.0 * .pi * f * t)
            let harmonic2   = 0.20 * sin(2.0 * .pi * f * 2.0 * t)  // bell quality
            let harmonic3   = 0.06 * sin(2.0 * .pi * f * 3.0 * t)

            samples[frame] = Float(fundamental + harmonic2 + harmonic3) * vol * envelope
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
    }
}
