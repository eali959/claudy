import Foundation
import SwiftData

// MARK: - VersionedSchema

/// Version 1 schema for Claud-y's Tamagotchi persistence layer.
///
/// Wrapping models in `VersionedSchema` + `SchemaMigrationPlan` lets us safely
/// add columns, rename, or split tables in future versions without touching
/// existing user data. No migrations exist yet — the plan is forward-ready only.
///
/// Storage: local Application Support only (`cloudKitDatabase: .none`).
/// No iCloud sync. No telemetry. The file lives at:
///   ~/Library/Application Support/Claudy/claudy.store
enum TamagotchiSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [TamagotchiState.self] }
}

// MARK: - TamagotchiState

/// The single persisted record that tracks Claud-y's wellbeing.
///
/// Exactly one `TamagotchiState` record exists — created on first launch, never deleted.
/// Stats are floating-point percentages (0–100) and decay over time while the app is open.
/// On relaunch, `TamagotchiManager` computes elapsed-time decay from `lastUpdated`
/// (capped at 24 h to avoid punishing users who close the app for a weekend).
///
/// Stat semantics:
/// - `hunger`    — higher = hungrier; decays upward over time; reduced by Feed action
/// - `happiness` — higher = happier; decays downward; boosted by Play action
/// - `energy`    — higher = more energetic; decays downward; restored by Rest/Pet action
@Model
final class TamagotchiState {
    var hunger: Float       // 0–100; increases over time (Claud-y gets hungrier)
    var happiness: Float    // 0–100; decreases over time
    var energy: Float       // 0–100; decreases over time

    /// Timestamp of the last stat update — used by TamagotchiManager to compute
    /// elapsed-time decay on relaunch. Updated every decay tick and after every action.
    var lastUpdated: Date

    init(hunger: Float = 40, happiness: Float = 80, energy: Float = 75) {
        self.hunger    = hunger
        self.happiness = happiness
        self.energy    = energy
        self.lastUpdated = .now
    }
}

// MARK: - Migration plan (no stages yet — forward-ready)

/// Add a new `LightweightMigrationStage` or `CustomMigrationStage` here when
/// `TamagotchiSchemaV2` is defined. Never delete old schemas from `schemas` —
/// SwiftData needs the full chain to migrate from any previous version.
enum TamagotchiMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [TamagotchiSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
