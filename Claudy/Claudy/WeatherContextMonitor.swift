import CoreLocation
import Foundation
import OSLog

private let log = Logger(subsystem: "Claudy", category: "WeatherContextMonitor")

// MARK: - WeatherCondition

enum WeatherCondition: String {
    case sunny, cloudy, rainy, stormy, snowy, hot, cold, windy, unknown
}

// MARK: - WeatherContextMonitor (WTHR-01)

/// Reads device location (with permission) and fetches current weather via Open-Meteo
/// (free, no API key required, privacy-respecting). Falls back to seasonal/timezone
/// approximation if permission is denied or network is unavailable. (WTHR-03)
///
/// Fires a weather-tinted ambient comment at most once per session (WTHR-02).
/// Actual comment text is tinted by active personality and behaviour mode.
@MainActor
final class WeatherContextMonitor: NSObject {

    // MARK: - State

    private(set) var condition: WeatherCondition = .unknown
    private var hasCommented = false

    // MARK: - Dependencies

    private weak var viewModel: CharacterViewModel?
    private let locationManager = CLLocationManager()
    private var locationTask: CheckedContinuation<CLLocation?, Never>?
    private var commentTask: Task<Void, Never>?

    // MARK: - Init

    init(viewModel: CharacterViewModel) {
        self.viewModel = viewModel
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        scheduleComment()
    }

    deinit {
        commentTask?.cancel()
    }

    // MARK: - Scheduling

    private func scheduleComment() {
        // Fire once ~90 seconds after launch, then every 2 h if condition changes
        commentTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(90))
            guard !Task.isCancelled else { return }
            await self?.refreshAndComment()
        }
    }

    private func refreshAndComment() async {
        await updateCondition()
        guard !hasCommented else { return }
        guard let vm = viewModel else { return }
        guard condition != .unknown else { return }
        let text = comment(for: condition, vm: vm)
        hasCommented = true
        vm.showBubbleDirect(text, duration: 6)
    }

    // MARK: - Location + weather fetch (WTHR-01)

    private func updateCondition() async {
        // Try location-based weather first
        if let location = await requestLocation() {
            if let fetched = await fetchWeather(lat: location.coordinate.latitude,
                                                lon: location.coordinate.longitude) {
                condition = fetched
                return
            }
        }
        // Fallback: seasonal approximation from hemisphere + month (WTHR-03)
        condition = seasonalApproximation()
    }

    /// Requests a one-shot location. Returns nil if denied or unavailable.
    private func requestLocation() async -> CLLocation? {
        let status = locationManager.authorizationStatus
        guard status != .denied && status != .restricted else { return nil }

        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            // Wait briefly for the dialog to resolve
            try? await Task.sleep(for: .milliseconds(800))
            guard locationManager.authorizationStatus == .authorized else { return nil }
        }

        return await withCheckedContinuation { cont in
            locationTask = cont
            locationManager.requestLocation()
        }
    }

    /// Fetches WMO weather code from Open-Meteo (no API key, GDPR-friendly).
    private func fetchWeather(lat: Double, lon: Double) async -> WeatherCondition? {
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current_weather=true"
        guard let url = URL(string: urlStr) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let current = json["current_weather"] as? [String: Any],
               let code = current["weathercode"] as? Int,
               let temp = current["temperature"] as? Double,
               let windspeed = current["windspeed"] as? Double {
                return condition(fromWMO: code, temp: temp, windspeed: windspeed)
            }
        } catch {
            log.debug("Weather fetch failed: \(error.localizedDescription)")
        }
        return nil
    }

    /// Maps WMO weather interpretation codes to `WeatherCondition`.
    private func condition(fromWMO code: Int, temp: Double, windspeed: Double) -> WeatherCondition {
        switch code {
        case 0, 1:          // clear
            if temp > 30 { return .hot }
            return .sunny
        case 2, 3:          // partly/overcast
            return .cloudy
        case 51...67:       // drizzle / rain
            return .rainy
        case 71...77:       // snow
            return .snowy
        case 80...82:       // rain showers
            return .rainy
        case 85, 86:        // snow showers
            return .snowy
        case 95...99:       // thunderstorm
            return .stormy
        default:
            if temp < 0  { return .cold }
            if windspeed > 50 { return .windy }
            return .unknown
        }
    }

    /// Hemisphere + month fallback (no location needed). (WTHR-03)
    private func seasonalApproximation() -> WeatherCondition {
        let month = Calendar.current.component(.month, from: Date())
        // Assume northern hemisphere; good enough for a vibe comment
        switch month {
        case 12, 1, 2:  return .cold
        case 3, 4, 5:   return .cloudy
        case 6, 7, 8:   return .sunny
        case 9, 10, 11: return .cloudy
        default:        return .unknown
        }
    }

    // MARK: - Comment generation (WTHR-02)

    private func comment(for condition: WeatherCondition, vm: CharacterViewModel) -> String {
        let personality = PersonalityManager.shared.currentMode
        let mode = vm.behaviorModeManager?.currentMode ?? .normal

        switch condition {
        case .sunny:
            if mode == .brainRot {
                return ["sun said rizz fr", "slay weather fr no cap", "golden hour gang gang"].randomElement()!
            }
            if personality == .hypeCoach {
                return ["Beautiful day — beautiful energy. LET'S GO!", "Sun's out, grind's out!"].randomElement()!
            }
            return ["Lovely day out there ☀️", "It's nice and sunny today!", "Perfect weather for being productive ☀️"].randomElement()!

        case .cloudy:
            if personality == .listener {
                return ["Cloudy today. How are you feeling?", "A bit grey outside. I'm here either way."].randomElement()!
            }
            return ["A bit overcast today.", "Cloudy skies — good excuse to stay in and get things done.", "Nice cosy cloud cover today."].randomElement()!

        case .rainy:
            if mode == .study {
                return ["Rain outside — perfect study weather honestly.", "Rainy day. Best environment for deep focus."].randomElement()!
            }
            if personality == .hypeCoach {
                return ["Rain won't stop us. Indoors = unstoppable.", "Nothing like rain to keep you at your desk. Go time!"].randomElement()!
            }
            return ["It's raining! Cosy vibes in here though.", "Rainy day outside 🌧️", "Rain day — perfect excuse to stay productive."].randomElement()!

        case .stormy:
            if mode == .brainRot {
                return ["bestie the weather is NOT it rn", "storm szn lowkey bussin tho"].randomElement()!
            }
            return ["Storm outside! You're safe in here with me.", "Pretty wild weather out there. Stay in, stay cosy.", "Thunder outside… I'm staying close."].randomElement()!

        case .snowy:
            if personality == .chatty {
                return ["SNOW?! Ok I'm obsessed. Snow day energy!", "Oh my gosh it's snowing! I love it! Do you love it?!"].randomElement()!
            }
            return ["It's snowing! ❄️", "Snow day! Don't forget to look outside.", "Beautiful snow falling. Winter is here."].randomElement()!

        case .hot:
            if personality == .hypeCoach {
                return ["Scorching out there — hydrate and grind!", "Hot day! Water break, then back to it."].randomElement()!
            }
            return ["It's really hot out there 🥵 Stay hydrated!", "Phew, hot day. Good thing we're in here.", "Drink some water — it's warm out today!"].randomElement()!

        case .cold:
            if personality == .companion {
                return ["Brr, it's cold! I'm glad we're warm in here together.", "Wrap up if you're going out — it's chilly!"].randomElement()!
            }
            return ["Cold one today 🥶 Keep warm!", "It's pretty cold outside. Hot drink time?", "Brr! Chilly day. Good day to stay productive."].randomElement()!

        case .windy:
            return ["Windy out there today!", "Gusty conditions — I'd hold onto your hat.", "Wild winds outside. Nothing stopping us in here though."].randomElement()!

        case .unknown:
            return "Not sure about the weather today, but I hope it's nice out there!"
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherContextMonitor: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let loc = locations.first
        Task { @MainActor [weak self] in
            self?.locationTask?.resume(returning: loc)
            self?.locationTask = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Logger(subsystem: "Claudy", category: "WeatherContextMonitor").debug("Location failed: \(error.localizedDescription)")
        Task { @MainActor [weak self] in
            self?.locationTask?.resume(returning: nil)
            self?.locationTask = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Handled inline in requestLocation()
    }
}
