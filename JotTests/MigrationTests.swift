import Foundation
import SwiftData
import Testing
@testable import Jot

/// A 1.0 store must open under the current schema with every item intact (ADR-001, ADR-004).
@MainActor
struct MigrationTests {
    @Test func v1StoreOpensAsV2() throws {
        let url = URL.temporaryDirectory.appending(path: "migration-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(filePath: url.path + suffix))
            }
        }
        let id = UUID()

        do {
            let v1 = try ModelContainer(
                for: Schema(versionedSchema: JotSchemaV1.self),
                configurations: ModelConfiguration(url: url)
            )
            let context = ModelContext(v1)
            context.insert(JotSchemaV1.JotItem(id: id, kindRaw: "reminder", title: "Call the dentist",
                                               transcript: "remind me to call the dentist", audioFileName: "a.m4a"))
            try context.save()
        }

        let v2 = try ModelContainer(
            for: Schema(versionedSchema: JotSchemaV2.self),
            migrationPlan: JotMigrationPlan.self,
            configurations: ModelConfiguration(url: url)
        )
        let items = try ModelContext(v2).fetch(FetchDescriptor<JotItem>())
        let item = try #require(items.first)
        #expect(items.count == 1)
        #expect(item.id == id)
        #expect(item.kind == .reminder)
        #expect(item.title == "Call the dentist")
        #expect(item.audioFileName == "a.m4a")
        #expect(item.parentID == nil)
        #expect(item.needsSorting == false)
    }
}
