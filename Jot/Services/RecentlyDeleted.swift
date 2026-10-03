import Foundation
import Observation
import SwiftData
import SwiftUI

/// Keeps the last deleted item for a few seconds so it can be undone. Its
/// recording is only removed once the undo window closes.
@MainActor
@Observable
final class RecentlyDeleted {
    static let shared = RecentlyDeleted()
    static let window: Duration = .seconds(6)

    /// Everything needed to put a deleted item back exactly as it was.
    struct Snapshot {
        let id: UUID
        let kind: ItemKind
        let title: String
        let details: String
        let dueDate: Date?
        let recurrence: Recurrence?
        let transcript: String
        let createdAt: Date
        let isCompleted: Bool
        let audioFileName: String?
        let parentID: UUID?
        let needsSorting: Bool

        init(_ item: JotItem) {
            id = item.id
            kind = item.kind
            title = item.title
            details = item.details
            dueDate = item.dueDate
            recurrence = item.recurrence
            transcript = item.transcript
            createdAt = item.createdAt
            isCompleted = item.isCompleted
            audioFileName = item.audioFileName
            parentID = item.parentID
            needsSorting = item.needsSorting
        }
    }

    private(set) var last: Snapshot?
    private var context: ModelContext?
    private var expiry: Task<Void, Never>?

    func record(_ item: JotItem, in context: ModelContext) {
        finalize()
        last = Snapshot(item)
        self.context = context
        expiry = Task { [weak self] in
            try? await Task.sleep(for: Self.window)
            guard !Task.isCancelled else { return }
            withAnimation(.jot) { self?.finalize() }
        }
    }

    func undo() {
        guard let snapshot = last, let context else { return }
        expiry?.cancel()
        let item = JotItem(
            kind: snapshot.kind,
            title: snapshot.title,
            details: snapshot.details,
            dueDate: snapshot.dueDate,
            recurrence: snapshot.recurrence,
            transcript: snapshot.transcript,
            createdAt: snapshot.createdAt
        )
        // Same id, so follow-ups and notifications still point at it.
        item.id = snapshot.id
        item.isCompleted = snapshot.isCompleted
        item.audioFileName = snapshot.audioFileName
        item.parentID = snapshot.parentID
        item.needsSorting = snapshot.needsSorting
        context.insert(item)
        last = nil
        ItemActions.commit(context)
    }

    /// Ends the undo window: the recording goes for good.
    private func finalize() {
        expiry?.cancel()
        AudioStore.remove(last?.audioFileName)
        last = nil
    }
}

/// "Deleted · Undo", above the tab bar while an undo is possible.
struct UndoToast: View {
    let deleted = RecentlyDeleted.shared

    var body: some View {
        if let snapshot = deleted.last {
            HStack(spacing: 12) {
                Image(systemName: "trash")
                    .foregroundStyle(Color.jotTextSecondary)
                Text("Deleted \u{201C}\(snapshot.title)\u{201D}")
                    .font(.jotBody)
                    .foregroundStyle(Color.jotTextPrimary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button("Undo") {
                    withAnimation(.jot) { deleted.undo() }
                }
                .font(.jotHeadline)
                .foregroundStyle(Color.jotAccentText)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .glassEffect(.regular.tint(Color.jotSurface.opacity(0.75)), in: .capsule)
            .padding(.horizontal, JotMetrics.gutter)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityAction(named: "Undo") { deleted.undo() }
        }
    }
}
