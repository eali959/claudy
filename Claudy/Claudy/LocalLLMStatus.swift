import Foundation
import Observation
import OSLog

/// Lightweight status pinger for local LLM endpoints (Ollama + LM Studio).
/// Polls every 30s in the background. UI reads `.ollamaUp` / `.lmStudioUp`
/// directly via @Observable for live status dots in the menu.
///
/// Cost: 2 HEAD-equivalent GETs every 30s — negligible.
@MainActor
@Observable
final class LocalLLMStatus {
    static let shared = LocalLLMStatus()

    private(set) var ollamaUp:   Bool = false
    private(set) var lmStudioUp: Bool = false
    private(set) var lastChecked: Date?

    private let logger = Logger(subsystem: "com.claudy", category: "LocalLLMStatus")
    private var pollTask: Task<Void, Never>?

    private init() {
        startPolling()
    }

    func startPolling(intervalSeconds: TimeInterval = 30) {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await self?.pingAll()
                try? await Task.sleep(for: .seconds(intervalSeconds))
            }
        }
    }

    func pingAll() async {
        async let o = ping(URL(string: "http://localhost:11434/api/tags")!)
        async let l = ping(URL(string: "http://localhost:1234/v1/models")!)
        let (ollama, lmStudio) = await (o, l)
        ollamaUp   = ollama
        lmStudioUp = lmStudio
        lastChecked = Date()
    }

    /// True if at least one local provider is reachable.
    var anyLocalUp: Bool { ollamaUp || lmStudioUp }

    private func ping(_ url: URL) async -> Bool {
        var req = URLRequest(url: url)
        req.timeoutInterval = 1.5
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
