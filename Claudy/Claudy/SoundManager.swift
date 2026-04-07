import AppKit
import OSLog

// MARK: - SoundManager
// Plays optional audio feedback using built-in macOS system sounds.
// All playback is guarded by the "SoundEffectsEnabled" UserDefaults flag.
// Zero overhead when disabled.

@MainActor
final class SoundManager {
    static let shared = SoundManager()
    private let logger = Logger(subsystem: "com.claudy", category: "Sound")

    enum SoundEffect {
        case bubblePop    // tiny pop when a speech bubble appears
        case cleanBuild   // soft chime on successful Xcode build
        case celebrate    // bright note for confetti / wins
        case timerDone    // Pomodoro session complete
        case chatOpen     // chat tray slides open
    }

    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKeys.soundEffectsEnabled)
    }

    /// Current volume, 0.0–1.0. Default 0.7 when no value has been set.
    /// Reads as Double to match the @AppStorage("SoundVolume") type in SettingsView,
    /// then casts to Float for NSSound.volume.
    private var volume: Float {
        let stored = UserDefaults.standard.double(forKey: DefaultsKeys.soundVolume)
        // double(forKey:) returns 0.0 when the key is missing - treat as unset
        return stored > 0 ? Float(min(1.0, stored)) : 0.7
    }

    func play(_ effect: SoundEffect) {
        guard isEnabled else { return }
        let name: NSSound.Name
        switch effect {
        case .bubblePop:  name = NSSound.Name("Pop")
        case .cleanBuild: name = NSSound.Name("Glass")
        case .celebrate:  name = NSSound.Name("Hero")
        case .timerDone:  name = NSSound.Name("Glass")
        case .chatOpen:   name = NSSound.Name("Tink")
        }
        guard let sound = NSSound(named: name) else {
            logger.debug("System sound '\(name)' not found - skipping")
            return
        }
        sound.volume = volume
        sound.play()
    }
}
