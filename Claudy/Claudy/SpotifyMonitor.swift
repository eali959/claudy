@preconcurrency import Foundation
import OSLog

private let logger = Logger(subsystem: "com.claudy", category: "SpotifyMonitor")

// MARK: - SpotifyGenre

/// Broad genre buckets used to drive character reactions.
enum SpotifyGenre {
    case metal        // headbang
    case electronic   // dance mode trigger
    case hiphop       // dance mode / groove
    case lofi         // vibing state
    case classical    // thoughtful / thinking
    case country      // wave, friendly reaction
    case rnb          // groove / celebrating
    case pop          // celebrating
    case unknown      // generic reaction
}

// MARK: - SpotifyMonitor

/// Listens to Spotify's distributed playback notifications and drives character reactions.
///
/// Spotify broadcasts `com.spotify.client.PlaybackStateChanged` on every track change,
/// play, and pause. This monitor reads the track name and artist, infers a genre via
/// keyword matching, and calls the relevant CharacterViewModel reaction method.
///
/// No Spotify API credentials are required — this is entirely local IPC.
@MainActor
final class SpotifyMonitor {

    @ObservationIgnored private weak var viewModel: CharacterViewModel?
    @ObservationIgnored private nonisolated(unsafe) var observer: NSObjectProtocol?
    @ObservationIgnored private var lastTrack: String = ""

    // MARK: - Init / deinit

    init(viewModel: CharacterViewModel) {
        self.viewModel = viewModel
        startListening()
        logger.info("SpotifyMonitor active")
    }

    deinit {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    // MARK: - Listening

    private func startListening() {
        observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Extract Sendable String values on the calling thread before hopping to
            // MainActor — avoids capturing non-Sendable Notification / [AnyHashable:Any]
            // across the concurrency boundary.
            let info   = notification.userInfo
            let state  = info?["Player State"] as? String ?? ""
            let track  = info?["Name"]         as? String ?? ""
            let artist = info?["Artist"]       as? String ?? ""
            Task { @MainActor [weak self] in
                self?.handlePlaybackChange(state: state, track: track, artist: artist)
            }
        }
    }

    private func handlePlaybackChange(state: String, track: String, artist: String) {

        guard state == "Playing" else {
            viewModel?.onSpotifyPaused()
            return
        }

        // Only react on track change, not position/volume updates on the same track
        guard track != lastTrack else { return }
        lastTrack = track

        let genre = detectGenre(track: track, artist: artist)
        logger.info("Spotify: \(track) - \(artist) → \(String(describing: genre))")
        viewModel?.onSpotifyTrackChanged(track: track, artist: artist, genre: genre)
    }

    // MARK: - Genre detection

    /// Heuristic genre classification from track name + artist keywords.
    private func detectGenre(track: String, artist: String) -> SpotifyGenre {
        let text = "\(track) \(artist)".lowercased()

        let metalWords      = ["metal", "heavy", "death", "thrash", "hardcore", "punk", "iron maiden",
                               "metallica", "slayer", "pantera", "tool", "rage against", "nirvana",
                               "acdc", "ac/dc", "led zeppelin", "black sabbath", "system of a down",
                               "linkin park", "green day", "blink-182"]
        let electronicWords = ["edm", "electronic", "house", "techno", "dance", "dubstep", "bass drop",
                               "rave", "trance", "deadmau5", "skrillex", "calvin harris", "avicii",
                               "martin garrix", "tiesto", "afrojack", "dj snake", "marshmello",
                               "illenium", "flume", "kygo"]
        let hiphopWords     = ["hip hop", "hip-hop", "rap", "trap", "drill", "kendrick", "drake",
                               "kanye", "travis scott", "jay-z", "jay z", "eminem", "nas", "j. cole",
                               "lil uzi", "lil baby", "young thug", "21 savage", "future", "gunna",
                               "polo g", "roddy ricch", "asap", "a$ap", "tyler the creator"]
        let lofiWords       = ["lo-fi", "lofi", "lo fi", "chill beats", "study", "study music",
                               "rain sounds", "coffee shop", "ambient", "nujabes", "jinsang",
                               "tomppabeats", "j dilla", "relaxing"]
        let classicalWords  = ["classical", "orchestra", "symphony", "concerto", "sonata", "quartet",
                               "mozart", "beethoven", "bach", "chopin", "brahms", "debussy",
                               "tchaikovsky", "vivaldi", "handel", "schubert"]
        let countryWords    = ["country", "western", "bluegrass", "nashville", "johnny cash",
                               "dolly parton", "willie nelson", "luke bryan", "blake shelton",
                               "morgan wallen", "zac brown", "kenny chesney"]
        let rnbWords        = ["r&b", "rnb", "soul", "funk", "gospel", "motown", "neo soul",
                               "frank ocean", "sza", "h.e.r.", "anderson paak", "silk sonic",
                               "usher", "alicia keys", "john legend", "the weeknd", "bryson tiller"]

        if metalWords.contains(where:      { text.contains($0) }) { return .metal }
        if electronicWords.contains(where: { text.contains($0) }) { return .electronic }
        if hiphopWords.contains(where:     { text.contains($0) }) { return .hiphop }
        if lofiWords.contains(where:       { text.contains($0) }) { return .lofi }
        if classicalWords.contains(where:  { text.contains($0) }) { return .classical }
        if countryWords.contains(where:    { text.contains($0) }) { return .country }
        if rnbWords.contains(where:        { text.contains($0) }) { return .rnb }
        return .unknown
    }
}
