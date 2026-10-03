import SwiftData

/// The store's schema as shipped in 1.0. See ADR-001.
///
/// Never edit a shipped version. To change a model, add `JotSchemaV2` with
/// copies of the models as they were, then a stage in `JotMigrationPlan`.
enum JotSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [JotItem.self, DevNote.self] }
}

enum JotMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [JotSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
