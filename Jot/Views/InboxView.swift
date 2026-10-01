import SwiftData
import SwiftUI

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JotItem.createdAt, order: .reverse) private var items: [JotItem]

    @State private var searchText = ""
    @State private var kindFilter: ItemKind?

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { item in
                    NavigationLink(value: item) {
                        ItemRow(item: item, isOverdue: isOverdue(item))
                    }
                    .swipeActions(edge: .leading) {
                        if item.kind == .task || item.kind == .reminder {
                            Button(item.isCompleted ? "Reopen" : "Done", systemImage: "checkmark") {
                                item.toggleCompleted()
                                refillNotifications()
                            }
                            .tint(.green)
                        }
                    }
                }
                .onDelete(perform: delete)
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Inbox is empty",
                        systemImage: "tray",
                        description: Text("Everything you capture lands here.")
                    )
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.jotBackground.ignoresSafeArea())
            .navigationTitle("Inbox")
            .navigationDestination(for: JotItem.self) { ItemDetailView(item: $0) }
            .searchable(text: $searchText, prompt: "Search titles, details, transcripts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Show", selection: $kindFilter) {
                            Text("All").tag(ItemKind?.none)
                            ForEach(ItemKind.allCases) { kind in
                                Label(kind.label + "s", systemImage: kind.symbol).tag(Optional(kind))
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: kindFilter == nil
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { CaptureBar() }
        }
    }

    private var filtered: [JotItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return items.filter { item in
            if let kindFilter, item.kind != kindFilter { return false }
            guard !query.isEmpty else { return true }
            return item.title.localizedStandardContains(query)
                || item.details.localizedStandardContains(query)
                || item.transcript.localizedStandardContains(query)
        }
    }

    private func isOverdue(_ item: JotItem) -> Bool {
        guard item.kind == .task || item.kind == .reminder, !item.isCompleted, let due = item.dueDate else { return false }
        return due < .now
    }

    private func delete(at offsets: IndexSet) {
        let visible = filtered
        for index in offsets {
            modelContext.delete(visible[index])
        }
        try? modelContext.save()
        refillNotifications()
    }

    private func refillNotifications() {
        Task { await ReminderScheduler.refill(using: modelContext) }
    }
}
