import SwiftData
import Foundation
import OSLog

private let log = Logger(subsystem: "com.claudy", category: "SwiftData")

// MARK: - TamagotchiContainer

/// Factory that builds the app's SwiftData `ModelContainer`.
///
/// **Privacy guarantee:** `cloudKitDatabase: .none` — the store is local-only,
/// never synced to iCloud, never transmitted off-device.
///
/// **Store location:** `~/Library/Application Support/Claudy/claudy.store`
/// — the standard macOS per-app Application Support directory, sandboxed to this app.
///
/// **Schema versioning:** uses `TamagotchiMigrationPlan` so future schema changes
/// (new columns, renamed types) migrate safely without data loss.
enum TamagotchiContainer {

    /// Creates and returns a configured `ModelContainer`.
    ///
    /// - Throws: `CocoaError` if the Application Support directory is unavailable,
    ///   or `SwiftData.SwiftDataError` if the store is unreadable/corrupt.
    ///   Callers should treat a throw as non-fatal — Tamagotchi features degrade gracefully.
    static func make() throws -> ModelContainer {
        let storeURL = try resolvedStoreURL()
        let schema = Schema(TamagotchiSchemaV1.models)
        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: TamagotchiMigrationPlan.self,
            configurations: [config]
        )
    }

    // MARK: - Private

    /// Returns (and creates if needed) `~/Library/Application Support/Claudy/claudy.store`.
    private static func resolvedStoreURL() throws -> URL {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory,
                                       in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        let dir = appSupport.appendingPathComponent("Claudy", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        return dir.appendingPathComponent("claudy.store")
    }
}
