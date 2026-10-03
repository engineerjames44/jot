import Foundation
import SwiftData
import Testing
@testable import Jot

/// Serialized: both tests use the shared `RecentlyDeleted`.
@MainActor
@Suite(.serialized)
struct UndoDeleteTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(versionedSchema: JotSchemaV2.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func undoRestoresTheSameItem() throws {
        let context = try makeContext()
        let parent = UUID()
        let item = JotItem(kind: .reminder, title: "Renew passport", details: "before December",
                           dueDate: .now.addingTimeInterval(3600), recurrence: .yearly, transcript: "renew my passport")
        item.parentID = parent
        item.audioFileName = "renew.m4a"
        context.insert(item)
        try context.save()
        let id = item.id

        ItemActions.delete(item, in: context)
        #expect(try context.fetchCount(FetchDescriptor<JotItem>()) == 0)
        #expect(RecentlyDeleted.shared.last?.title == "Renew passport")

        RecentlyDeleted.shared.undo()
        let restored = try #require(try context.fetch(FetchDescriptor<JotItem>()).first)
        #expect(restored.id == id)
        #expect(restored.kind == .reminder)
        #expect(restored.details == "before December")
        #expect(restored.recurrence == .yearly)
        #expect(restored.parentID == parent)
        #expect(restored.audioFileName == "renew.m4a")
        #expect(RecentlyDeleted.shared.last == nil)
    }

    @Test func aSecondDeleteReplacesTheFirstUndo() throws {
        let context = try makeContext()
        let first = JotItem(kind: .note, title: "First")
        let second = JotItem(kind: .note, title: "Second")
        context.insert(first)
        context.insert(second)
        try context.save()

        ItemActions.delete(first, in: context)
        ItemActions.delete(second, in: context)
        RecentlyDeleted.shared.undo()

        let titles = try context.fetch(FetchDescriptor<JotItem>()).map(\.title)
        #expect(titles == ["Second"])
    }
}
