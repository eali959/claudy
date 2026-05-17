import SwiftUI
import Observation

// MARK: - SeasonalThemeEngine (Section 7)
//
// Determines the current season (hemisphere-aware) and time-of-day.
// Publishes overlay colours and particle effects for the character scene.
//
// Enabled via Settings > Behaviour > "Seasonal themes" (on by default).

enum Season: String, Sendable {
    case spring, summer, autumn, winter
}

enum TimeOfDayTintType: Sendable {
    case morning    // 05:00–10:00 — warm golden
    case day        // 10:00–17:00 — none
    case evening    // 17:00–21:00 — cool blue
    case night      // 21:00–05:00 — dark overlay
}

@MainActor
@Observable
final class SeasonalThemeEngine {

    static let shared = SeasonalThemeEngine()

    var isEnabled: Bool = {
        let key = DefaultsKeys.seasonalThemesEnabled
        guard UserDefaults.standard.object(forKey: key) != nil else { return true }
        return UserDefaults.standard.bool(forKey: key)
    }() {
        didSet { UserDefaults.standard.set(isEnabled, forKey: DefaultsKeys.seasonalThemesEnabled) }
    }

    private(set) var currentSeason: Season = .spring
    private(set) var timeOfDayTint: TimeOfDayTintType = .day

    // Session-only accessories (reset on next launch)
    private(set) var sessionAccessoryHint: CharacterAccessory = .none

    @ObservationIgnored private nonisolated(unsafe) var updateTask: Task<Void, Never>?

    private init() { refresh() }

    // MARK: - Refresh

    func refresh() {
        currentSeason    = detectSeason()
        timeOfDayTint    = detectTimeOfDay()
        sessionAccessoryHint = seasonAccessory(for: currentSeason)
    }

    func startUpdating() {
        updateTask?.cancel()
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15 * 60))
                self?.refresh()
            }
        }
    }

    func stopUpdating() {
        updateTask?.cancel()
    }

    // MARK: - Overlay colour

    /// Translucent SwiftUI Color to layer above the character background.
    var overlayColor: Color? {
        guard isEnabled else { return nil }
        switch timeOfDayTint {
        case .morning: return Color(red: 1.0,  green: 0.85, blue: 0.4).opacity(0.12)
        case .day:     return nil
        case .evening: return Color(red: 0.35, green: 0.55, blue: 1.0).opacity(0.10)
        case .night:   return Color.black.opacity(0.18)
        }
    }

    // MARK: - Particle effect hint

    enum ParticleEffect: String, Sendable { case petals, leaves, snow, rain, none }

    var particleEffect: ParticleEffect {
        guard isEnabled else { return .none }
        switch currentSeason {
        case .spring:  return .petals
        case .autumn:  return .leaves
        case .winter:  return .snow
        case .summer:  return .none
        }
    }

    // MARK: - Detection helpers

    private func detectSeason() -> Season {
        let month = Calendar.current.component(.month, from: Date())
        let region = Locale.current.region?.identifier ?? ""
        let southernHemisphere: Set<String> = [
            "AU", "NZ", "ZA", "AR", "BR", "CL", "PE", "BO", "PY", "UY"
        ]
        let isSouthern = southernHemisphere.contains(region)

        // Northern hemisphere seasons (flip for Southern)
        let northernSeason: Season
        switch month {
        case 3...5:  northernSeason = .spring
        case 6...8:  northernSeason = .summer
        case 9...11: northernSeason = .autumn
        default:     northernSeason = .winter
        }

        if isSouthern {
            switch northernSeason {
            case .spring: return .autumn
            case .summer: return .winter
            case .autumn: return .spring
            case .winter: return .summer
            }
        }
        return northernSeason
    }

    private func detectTimeOfDay() -> TimeOfDayTintType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<10:  return .morning
        case 10..<17: return .day
        case 17..<21: return .evening
        default:      return .night
        }
    }

    private func seasonAccessory(for season: Season) -> CharacterAccessory {
        switch season {
        case .summer: return .tintedSunnies  // sunglasses for summer
        default:      return .none           // .scarf not yet in CharacterAccessory enum
        }
    }
}
