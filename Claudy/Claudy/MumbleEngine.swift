import AVFoundation
import OSLog

// MARK: - MumbleEngine

/// Synthesises short pip tones that give Claud-y a cute, warm chipmunk voice.
///
/// Pips are in the 300–520 Hz register (down an octave from the original) so they
/// feel round and soothing rather than piercing. Gentle vibrato, soft envelopes,
/// and relaxed spacing make the mumble feel like a friendly murmur, not a beep burst.
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
        let pipCount = min(12, max(1, text.count / 5))
        mumbleTask = Task { [weak self] in
            guard let self else { return }
            for _ in 0..<pipCount {
                guard !Task.isCancelled else { return }
                self.schedulePip()
                let spacing = Double.random(in: 0.085...0.130)
                try? await Task.sleep(for: .seconds(spacing))
            }
        }
    }

    /// Play the two-syllable name melody: "Claud-y".
    /// A4 → E5 — warm and musical without being shrill.
    func speakName() {
        guard isEnabled else { return }
        stop()
        mumbleTask = Task { [weak self] in
            guard let self else { return }
            // "Claud": A4 clean bell tone, 145ms
            self.scheduleNameNote(frequency: 440.0, duration: 0.145, vibratoDepth: 0)
            try? await Task.sleep(for: .seconds(0.175))
            guard !Task.isCancelled else { return }
            // "-y": E5 gentle vibrato chirp, 110ms
            self.scheduleNameNote(frequency: 659.25, duration: 0.110, vibratoDepth: 8)
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
        UserDefaults.standard.bool(forKey: DefaultsKeys.soundEffectsEnabled) &&
        UserDefaults.standard.bool(forKey: DefaultsKeys.characterVoiceEnabled) &&
        !UserDefaults.standard.bool(forKey: DefaultsKeys.isMuted)
    }

    private var outputVolume: Float {
        let stored = UserDefaults.standard.double(forKey: DefaultsKeys.soundVolume)
        let base = stored > 0 ? Float(min(1.0, stored)) : 0.7
        return base * 0.25   // keep mumble quiet relative to other sounds
    }

    /// A single warm pip: lower frequency range (300–520 Hz) for a round, non-piercing tone.
    /// Gentle vibrato on ~55% of pips. 2nd + 3rd harmonics for bell warmth.
    private func schedulePip() {
        let sampleRate: Double = 44100
        let frequency  = Double.random(in: 300...520)
        let duration   = 0.055
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let addVibrato = Double.random(in: 0...1) < 0.55

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount),
              let channelData = buffer.floatChannelData else { return }

        buffer.frameLength = frameCount
        let samples = channelData[0]
        let vol = outputVolume

        for frame in 0..<Int(frameCount) {
            let t        = Double(frame) / sampleRate
            let progress = t / duration

            // 10% soft attack, 55% sustain, 35% gentle decay
            let envelope: Float
            if progress < 0.10 {
                envelope = Float(progress / 0.10)
            } else if progress > 0.65 {
                envelope = Float((1.0 - progress) / 0.35)
            } else {
                envelope = 1.0
            }

            // Subtle vibrato: 6 Hz depth at 5 Hz rate — dreamy shimmer, not wobble
            let vibratoOffset = addVibrato ? 6.0 * sin(2.0 * .pi * 5.0 * t) : 0.0
            let f = frequency + vibratoOffset
            let fundamental = sin(2.0 * .pi * f * t)
            let harmonic2   = 0.12 * sin(2.0 * .pi * f * 2.0 * t)  // bell warmth
            let harmonic3   = 0.04 * sin(2.0 * .pi * f * 3.0 * t)  // subtle depth

            samples[frame] = Float(fundamental + harmonic2 + harmonic3) * vol * envelope
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
    }

    /// A sustained name-melody note with optional gentle vibrato.
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

            // 8% soft attack, exponential tail decay
            let envelope: Float
            if progress < 0.08 {
                envelope = Float(progress / 0.08)
            } else {
                envelope = Float(exp(-3.5 * (progress - 0.08)))
            }

            let vibratoOffset = vibratoDepth * sin(2.0 * .pi * 5.0 * t)
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
