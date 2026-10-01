import SwiftData
import SwiftUI

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.jotAnimation) private var animation
    @Query(sort: \JotItem.createdAt, order: .reverse) private var items: [JotItem]

    @State private var searchText = ""
    @State private var kindFilter: ItemKind?
    @State private var openRow: UUID?
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    searchField
                        .padding(.horizontal, JotMetrics.gutter)
                    ChipPicker(options: chipOptions, selection: $kindFilter)

                    results
                        .padding(.horizontal, JotMetrics.gutter)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .background(Color.jotBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: JotItem.self) { ItemDetailView(item: $0) }
            .safeAreaInset(edge: .bottom) {
                if !searchFocused {
                    CaptureDock()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(animation, value: searchFocused)
        }
    }

    // MARK: Header & search

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EVERYTHING YOU'VE CAPTURED")
                .font(.jotLabel)
                .tracking(1.2)
                .foregroundStyle(Color.jotAccent)
            HStack(alignment: .firstTextBaseline) {
                Text("Inbox")
                    .font(.jotDisplay)
                    .tracking(-0.8)
                    .foregroundStyle(Color.jotTextPrimary)
                Spacer()
                Text("\(items.count)")
                    .font(.system(.title2, design: .rounded, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color.jotTextSecondary)
                    .contentTransition(.numericText(value: Double(items.count)))
            }
        }
        .padding(.horizontal, JotMetrics.gutter)
        .padding(.top, 12)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(searchFocused ? Color.jotAccent : Color.jotTextSecondary)
            TextField("Search titles, details, what you said", text: $searchText)
                .font(.jotBody)
                .foregroundStyle(Color.jotTextPrimary)
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    withAnimation(animation) { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.jotTextSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color.jotSurface, in: .capsule)
        .overlay(
            Capsule().strokeBorder(searchFocused ? Color.jotAccent.opacity(0.6) : Color.jotBorder, lineWidth: 1)
        )
        .animation(animation, value: searchFocused)
        .animation(animation, value: searchText.isEmpty)
    }

    private var chipOptions: [ChipPicker<ItemKind?>.Option] {
        var options: [ChipPicker<ItemKind?>.Option] = [.init(value: nil, label: "All", count: items.count)]
        for kind in [ItemKind.reminder, .task, .note, .event] {
            options.append(.init(
                value: kind,
                label: kind.label + "s",
                color: kind.color,
                count: items.count { $0.kind == kind }
            ))
        }
        return options
    }

    // MARK: Results

    @ViewBuilder
    private var results: some View {
        let groups = groupedResults
        if items.isEmpty {
            EmptyStateView(
                symbol: "tray.full.fill",
                color: .jotNote,
                title: "Nothing here yet",
                message: "Everything you capture lands here."
            )
        } else if groups.isEmpty {
            EmptyStateView(
                symbol: "magnifyingglass",
                color: .jotEvent,
                orbitSymbols: ["questionmark", "text.magnifyingglass"],
                title: "No matches",
                message: searchText.isEmpty
                    ? "Nothing of this type yet."
                    : "Nothing mentions “\(searchText)”."
            )
        } else {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(Array(groups.enumerated()), id: \.element.title) { groupIndex, group in
                    SectionHeader(title: group.title, trailing: "\(group.items.count)")
                        .padding(.top, groupIndex == 0 ? 4 : 14)
                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                        row(for: item)
                            .staggeredAppear(index)
                            .transition(.asymmetric(
                                insertion: .opacity,
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            ))
                    }
                }
            }
            .animation(animation, value: filtered.map(\.id))
        }
    }

    private func row(for item: JotItem) -> some View {
        SwipeableRow(
            item: item,
            openRow: $openRow,
            onComplete: { withAnimation(animation) { ItemActions.toggleComplete(item, in: modelContext) } },
            onSnooze: { option in withAnimation(animation) { ItemActions.snooze(item, option, in: modelContext) } },
            onDelete: { withAnimation(animation) { ItemActions.delete(item, in: modelContext) } }
        ) {
            NavigationLink(value: item) {
                InboxCard(item: item, query: searchText)
            }
            .buttonStyle(.pressable)
            .overlay(alignment: .topTrailing) {
                if ItemActions.canComplete(item) {
                    Button {
                        withAnimation(animation) { ItemActions.toggleComplete(item, in: modelContext) }
                    } label: {
                        CheckCircle(isChecked: item.isCompleted, color: item.kind.color)
                            .padding(JotMetrics.cardPadding)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.isCompleted ? "Reopen \(item.title)" : "Complete \(item.title)")
                }
            }
        }
        .sensoryFeedback(.success, trigger: item.isCompleted) { _, done in done }
    }

    // MARK: Data

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

    private struct Group {
        let title: String
        var items: [JotItem]
    }

    /// Items grouped by the day they were captured.
    private var groupedResults: [Group] {
        let calendar = Calendar.current
        var groups: [Group] = []
        for item in filtered {
            let title: String
            if calendar.isDateInToday(item.createdAt) {
                title = "Today"
            } else if calendar.isDateInYesterday(item.createdAt) {
                title = "Yesterday"
            } else {
                title = item.createdAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            }
            if groups.last?.title == title {
                groups[groups.count - 1].items.append(item)
            } else {
                groups.append(Group(title: title, items: [item]))
            }
        }
        return groups
    }
}

// MARK: - Card

private struct InboxCard: View {
    let item: JotItem
    let query: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                KindLabel(kind: item.kind)
                if let due = item.dueDate, item.kind != .note {
                    Text("·").foregroundStyle(Color.jotTextSecondary)
                    Text(JotDate.short(due))
                        .font(.jotTimeSmall)
                        .foregroundStyle(isOverdue ? Color.jotAccent : Color.jotTextSecondary)
                        .lineLimit(1)
                }
                if item.recurrence != nil {
                    Image(systemName: "arrow.trianglehead.2.clockwise")
                        .font(.jotLabel)
                        .foregroundStyle(Color.jotTextSecondary)
                }
                if item.audioFileName != nil {
                    Image(systemName: "waveform")
                        .font(.jotLabel)
                        .foregroundStyle(Color.jotTextSecondary)
                        .accessibilityLabel("Has recording")
                }
            }

            Text(SearchHighlight.attributed(item.title, query: query))
                .font(.jotBodyEmphasis)
                .foregroundStyle(item.isCompleted ? Color.jotTextSecondary : Color.jotTextPrimary)
                .strikethrough(item.isCompleted, color: Color.jotTextSecondary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)

            if !item.details.isEmpty {
                Text(SearchHighlight.attributed(item.details, query: query))
                    .font(.jotCaption)
                    .foregroundStyle(Color.jotTextSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }

            if let snippet = transcriptSnippet {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color.jotNote)
                        .padding(.top, 3)
                    Text(SearchHighlight.attributed(snippet, query: query))
                        .font(.jotCaption)
                        .italic()
                        .foregroundStyle(Color.jotTextSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                .padding(.top, 2)
            }
        }
        .padding(.trailing, ItemActions.canComplete(item) ? 36 : 0)
        .jotCard()
        .overlay(alignment: .leading) {
            Capsule().fill(item.kind.color).frame(width: 3).padding(.vertical, 18)
        }
        .opacity(item.isCompleted ? 0.7 : 1)
    }

    private var isOverdue: Bool {
        ItemActions.canComplete(item) && !item.isCompleted && (item.dueDate ?? .distantFuture) < .now
    }

    /// Shown only when the match is in what was said, not the title or details.
    private var transcriptSnippet: String? {
        guard !query.isEmpty,
              !item.title.localizedStandardContains(query),
              !item.details.localizedStandardContains(query)
        else { return nil }
        return SearchHighlight.snippet(item.transcript, query: query)
    }
}
