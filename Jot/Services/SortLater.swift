import Foundation
import SwiftData
import WidgetKit

/// Sorts captures that were kept as notes without being sorted (ADR-004): on
/// request from an item, and in the background once sorting can happen again.
@MainActor
enum SortLater {
    /// One pass at a time; captures that keep failing wait for the next pass.
    private static var isRunning = false
    private static let passLimit = 10

    /// Sorts `item` from what was said, updating it in place.
    static func sort(_ item: JotItem, in context: ModelContext) async throws {
        let transcript = item.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { throw SortingError.unreadable }
        let result = try await Classifier.classify(transcript)
        apply(result, to: item)
        ItemActions.commit(context)
    }

    /// Sorts waiting captures, oldest first, stopping at the first problem that
    /// would fail the rest too (offline, sorting off, daily limit).
    static func retryPending(in context: ModelContext) async {
        guard !isRunning, Classifier.canSort else { return }
        isRunning = true
        defer { isRunning = false }

        let descriptor = FetchDescriptor<JotItem>(
            predicate: #Predicate { $0.needsSorting },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let pending = ((try? context.fetch(descriptor)) ?? []).prefix(passLimit)
        for item in pending {
            do {
                try await sort(item, in: context)
            } catch SortingError.unreadable {
                // Nothing more to learn from these words; keep it as a plain note.
                item.needsSorting = false
                try? context.save()
            } catch {
                return
            }
        }
    }

    static func apply(_ result: ClassifiedItem, to item: JotItem) {
        item.kind = result.type
        if !result.title.isEmpty { item.title = result.title }
        if !result.details.isEmpty { item.details = result.details }
        item.dueDate = result.dueDate()
        item.recurrence = result.recurrence
        item.needsSorting = false
    }
}
