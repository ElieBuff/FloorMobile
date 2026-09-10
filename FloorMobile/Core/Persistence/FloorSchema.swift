//
//  FloorSchema.swift
//  FloorMobile
//

import SwiftData

/// The app's data schema, versioned from day one so the first real
/// migration is an entry in `FloorMigrationPlan.stages` instead of a
/// store reset.
nonisolated enum FloorSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [AIAction.self]
    }
}

nonisolated enum FloorMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [FloorSchemaV1.self]
    }

    static var stages: [MigrationStage] { [] }
}
