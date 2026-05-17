import Foundation
import Observation
import OSLog

// MARK: - SpotifyBPMReactor (Section 9)
//
// Reads audio features (BPM, energy) from Spotify and adjusts Claud-y's
// animation multiplier and triggers dance bursts on high-energy tracks.
//
// Requires an active Spotify token (via existing SpotifyMonitor).
// Settings > Behaviour > "React to music energy" (on by default when Spotify connected).

@MainActor
@Observable
final class SpotifyBPMReactor {

    // MARK: - State

    /// Multiplier applied to animation timing. 1.0 = normal, 0.5 = slow, 1.5 = fast.
    private(set) var animationMultiplier: Double = 1.0

    /// Genre-based tint hint (cosmetic only, applied externally).
    private(set) var genreTint: GenreTint = .none

    var isEnabled: Bool = {
        guard UserDefaults.standard.object(forKey: DefaultsKeys.reactToMusicEnergy) != nil else { return true }
        return UserDefaults.standard.bool(forKey: DefaultsKeys.reactToMusicEnergy)
    }() {
        didSet { UserDefaults.standard.set(isEnabled, forKey: DefaultsKeys.reactToMusicEnergy) }
    }

    enum GenreTint: Sendable { case none, calm, energetic, chill }

    // MARK: - Dance burst scheduling

    @ObservationIgnored private nonisolated(unsafe) var danceBurstTask: Task<Void, Never>?
    private weak var viewModel: CharacterViewModel?

    private let logger = Logger(subsystem: "com.claudy", category: "BPMReactor")

    // MARK: - Init

    init(viewModel: CharacterViewModel) {
        self.viewModel = viewModel
    }

    deinit {
        danceBurstTask?.cancel()
    }

    // MARK: - Track change handler

    /// Call this when Spotify reports a new track with its Spotify track ID.
    func trackDidChange(trackID: String, spotifyToken: String) {
        guard isEnabled else { return }
        Task {
            await fetchAudioFeatures(trackID: trackID, token: spotifyToken)
        }
    }

    // MARK: - Audio features fetch

    private func fetchAudioFeatures(trackID: String, token: String) async {
        let urlStr = "https://api.spotify.com/v1/audio-features/\(trackID)"
        guard let url = URL(string: urlStr) else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            struct Features: Decodable {
                let tempo: Double
                let energy: Double
            }
            let features = try JSONDecoder().decode(Features.self, from: data)
            applyFeatures(bpm: features.tempo, energy: features.energy)
        } catch {
            logger.error("Audio features fetch failed: \(error)")
        }
    }

    // MARK: - Apply features

    private func applyFeatures(bpm: Double, energy: Double) {
        // Animation multiplier from BPM
        switch bpm {
        case ..<80:          animationMultiplier = 0.5
        case 80..<120:       animationMultiplier = 1.0
        default:             animationMultiplier = 1.5
        }

        // Dance bursts on high-energy, high-BPM tracks (~every 30s)
        danceBurstTask?.cancel()
        if energy > 0.8 && bpm > 120 {
            scheduleDanceBursts()
        }

        logger.debug("BPM \(bpm, format: .fixed(precision: 0)) energy \(energy, format: .fixed(precision: 2)) → ×\(self.animationMultiplier)")
    }

    // MARK: - Genre tint (call with artist genres array from Spotify)

    func applyGenres(_ genres: [String]) {
        guard isEnabled else { return }
        let joined = genres.joined(separator: " ").lowercased()

        if joined.contains("classical") || joined.contains("ambient") || joined.contains("jazz") {
            genreTint = .calm
        } else if joined.contains("metal") || joined.contains("punk") || joined.contains("hardcore") {
            genreTint = .energetic
        } else if joined.contains("lo-fi") || joined.contains("chillhop") || joined.contains("chill") {
            genreTint = .chill
        } else {
            genreTint = .none
        }
    }

    // MARK: - Dance burst scheduler

    private func scheduleDanceBursts() {
        danceBurstTask = Task { [weak self, weak viewModel] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                viewModel?.setState(.dancing, duration: 3.0)
                self?.logger.debug("Dance burst fired")
            }
        }
    }

    func stopDanceBursts() {
        danceBurstTask?.cancel()
        danceBurstTask = nil
        animationMultiplier = 1.0
    }
}
