import Foundation
import SwiftData

// The store's schema history. See ADR-001 (versioning) and ADR-004 (V2).
//
// Never edit a shipped version. To change a model: copy the live models into
// the latest version below as nested types, edit the live models, add a new
// version that lists them, and add a stage to `JotMigrationPlan`.

/// 1.0, as first shipped. Frozen copies of the models at that point.
enum JotSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [JotItem.self, DevNote.self] }

    @Model
    final class JotItem {
        @Attribute(.unique) var id: UUID
        var kindRaw: String
        var title: String
        var details: String
        var dueDate: Date?
        var recurrenceRaw: String?
        var transcript: String
        var createdAt: Date
        var isCompleted: Bool
        var audioFileName: String?

        init(id: UUID = UUID(), kindRaw: String, title: String, details: String = "", dueDate: Date? = nil,
             recurrenceRaw: String? = nil, transcript: String = "", createdAt: Date = .now,
             isCompleted: Bool = false, audioFileName: String? = nil) {
            self.id = id
            self.kindRaw = kindRaw
            self.title = title
            self.details = details
            self.dueDate = dueDate
            self.recurrenceRaw = recurrenceRaw
            self.transcript = transcript
            self.createdAt = createdAt
            self.isCompleted = isCompleted
            self.audioFileName = audioFileName
        }
    }

    @Model
    final class DevNote {
        @Attribute(.unique) var id: UUID
        var text: String
        var categoryRaw: String
        var screen: String?
        var appVersion: String
        var createdAt: Date
        var isDone: Bool
        var audioFileName: String?
        var duration: Double

        init(id: UUID = UUID(), text: String, categoryRaw: String, screen: String? = nil, appVersion: String,
             createdAt: Date = .now, isDone: Bool = false, audioFileName: String? = nil, duration: Double = 0) {
            self.id = id
            self.text = text
            self.categoryRaw = categoryRaw
            self.screen = screen
            self.appVersion = appVersion
            self.createdAt = createdAt
            self.isDone = isDone
            self.audioFileName = audioFileName
            self.duration = duration
        }
    }
}

/// Follow-ups (`parentID`) and the sort-later flag (`needsSorting`).
enum JotSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [JotItem.self, DevNote.self] }
}

enum JotMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [JotSchemaV1.self, JotSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: JotSchemaV1.self, toVersion: JotSchemaV2.self)]
    }
}
