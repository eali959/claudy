import Foundation
import OSLog

// MARK: - AppleIntelligenceService (Section 4)
//
// Placeholder for Apple's on-device Foundation Models (macOS 26+).
// The FoundationModels framework API is not yet finalised in the public SDK.
// This stub compiles cleanly on macOS 15 and returns a graceful message.
//
// To activate when the final SDK ships:
//   1. Import FoundationModels (macOS 26+)
//   2. Add com.apple.developer.foundation-models entitlement
//   3. Replace the stub body with the real LanguageModelSession streaming code

@MainActor
final class AppleIntelligenceService {

    private let logger = Logger(subsystem: "com.claudy", category: "AppleIntelligence")

    /// True when Apple Intelligence can be used on this device/OS.
    /// Currently always false until the macOS 26 SDK is finalised.
    static var isAvailable: Bool { false }

    /// Stub implementation — streams a single explanatory message.
    /// Replace with real LanguageModelSession streaming on macOS 26+.
    func streamChat(
        systemPrompt: String,
        messages: [ChatMessage]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield("Apple Intelligence requires macOS 26 — not yet available.")
            continuation.finish()
        }
    }
}
