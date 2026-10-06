import SwiftData
import SwiftUI

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.jotAnimation) private var animation
    @Environment(CaptureController.self) private var capture
    @Query(sort: \JotItem.createdAt, order: .reverse) private var items: [JotItem]

    @State private var searchText = ""
    @State private var kindFilter: ItemKind?
    @State private var openRow: UUID?
    @FocusState private var searchFocused: Bool
    @State private var path: [JotItem] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        searchField
                            .padding(.horizontal, JotMetrics.gutter)
                        ChipPicker(options: chipOptions, selection: $kindFilter)

                        if !items.isEmpty {
                            WeekStrip(days: stripDays) { day in
                                withAnimation(animation) { proxy.scrollTo(Self.sectionID(for: day), anchor: .top) }
                            }
                        }

                        results
                            .padding(.horizontal, JotMetrics.gutter)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .background(Color.jotBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: JotItem.self) { ItemDetailView(item: $0) }
        }
        .overlay { CaptureStage() }
        // Only at the root: on a detail screen the orb would cover its controls.
        // It comes back while a capture is underway (e.g. from the Action Button).
        .safeAreaInset(edge: .bottom) {
            if !searchFocused && (path.isEmpty || capture.phase != .idle) {
                CaptureDock()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(animation, value: searchFocused)
        .animation(animation, value: path.isEmpty)
        .onChange(of: AppRouter.shared.itemToOpen, initial: true) { _, id in
            guard let id else { return }
            AppRouter.shared.itemToOpen = nil
            if let item = items.first(where: { $0.id == id }) {
                searchFocused = false
                path = [item]
            }
        }
    }

    // MARK: Header & search

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                JotStatusBadge()
                Text("Everything you've said")
                    .font(.jotSection)
                    .foregroundStyle(Color.jotTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                ProfileBadge()
            }
            Text("Inbox")
                .font(.jotDisplay)
                .tracking(-0.8)
                .foregroundStyle(Color.jotTextPrimary)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, JotMetrics.gutter)
        .padding(.top, 4)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(searchFocused ? Color.jotAccentText : Color.jotTextSecondary)
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
        let groups = agenda
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
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(groups.enumerated()), id: \.element.id) { groupIndex, group in
                    SectionHeader(title: group.title, trailing: "\(group.entries.count)")
                        .padding(.top, groupIndex == 0 ? 4 : 24)
                        .padding(.bottom, 4)
                        .id(group.id)
                    ForEach(group.entries, id: \.item.id) { entry in
                        row(for: entry.item, at: entry.date, dated: group.isDated)
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

    private func row(for item: JotItem, at date: Date?, dated: Bool) -> some View {
        SwipeableRow(
            item: item,
            openRow: $openRow,
            onComplete: { withAnimation(animation) { ItemActions.toggleComplete(item, in: modelContext) } },
            onSnooze: { option in withAnimation(animation) { ItemActions.snooze(item, option, in: modelContext) } },
            onDelete: { withAnimation(animation) { ItemActions.delete(item, in: modelContext) } }
        ) {
            NavigationLink(value: item) {
                InboxCard(item: item, query: searchText, date: date, showsTime: dated)
            }
            .buttonStyle(.pressable)
            .overlay(alignment: .trailing) {
                if ItemActions.canComplete(item) {
                    Button {
                        withAnimation(animation) { ItemActions.toggleComplete(item, in: modelContext) }
                    } label: {
                        CheckCircle(isChecked: item.isCompleted, color: item.kind.color)
                            .padding(.vertical, 12)
                            .padding(.leading, 12)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.isCompleted ? "Reopen \(item.title)" : "Complete \(item.title)")
                }
            }
            .background(Color.jotBackground)
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

    // MARK: Agenda

    /// A section of the agenda: overdue, one day, no date, or done.
    private struct Section {
        let id: String
        let title: String
        /// Day sections show a time column; the others don't.
        let isDated: Bool
        var entries: [(item: JotItem, date: Date?)]
    }

    static func sectionID(for day: Date) -> String {
        "day-" + day.formatted(.iso8601.year().month().day())
    }

    /// When an item next happens: its due date, or a repeating item's next occurrence.
    private func when(_ item: JotItem, today: Date) -> Date? {
        guard item.kind != .note else { return nil }
        return item.recurrence == nil ? item.dueDate : item.nextOccurrence(onOrAfter: today)
    }

    /// Everything in calendar order: what's overdue, then each day with something
    /// on it, then things with no date, then what's done.
    private var agenda: [Section] {
        let calendar = Calendar.current
        let now = Date.now
        let today = calendar.startOfDay(for: now)

        var overdue: [(JotItem, Date?)] = []
        var days: [Date: [(JotItem, Date?)]] = [:]
        var undated: [(JotItem, Date?)] = []
        var done: [(JotItem, Date?)] = []

        for item in filtered {
            let date = when(item, today: today)
            if item.isCompleted {
                done.append((item, date))
            } else if let date {
                if date < now, ItemActions.canComplete(item) {
                    overdue.append((item, date))
                } else {
                    // Events stay on their day, even once they've passed.
                    days[calendar.startOfDay(for: date), default: []].append((item, date))
                }
            } else {
                undated.append((item, nil))
            }
        }

        var sections: [Section] = []
        if !overdue.isEmpty {
            sections.append(Section(id: "overdue", title: "Overdue", isDated: true,
                                    entries: overdue.sorted { ($0.1 ?? now) < ($1.1 ?? now) }))
        }
        for (day, dayEntries) in days.sorted(by: { $0.key < $1.key }) {
            let entries = dayEntries.sorted { ($0.1 ?? day) < ($1.1 ?? day) }
            sections.append(Section(id: Self.sectionID(for: day), title: Self.dayTitle(day), isDated: true, entries: entries))
        }
        if !undated.isEmpty {
            sections.append(Section(id: "undated", title: "No date", isDated: false, entries: undated))
        }
        if !done.isEmpty {
            sections.append(Section(id: "done", title: "Done", isDated: false, entries: done))
        }
        return sections
    }

    /// "Today", "Tomorrow", "Monday 5 October".
    static func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    /// The next two weeks, each with the kinds of what's on it.
    private var stripDays: [WeekStrip.Day] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var kinds: [Date: [ItemKind]] = [:]
        for item in filtered where !item.isCompleted {
            guard let date = when(item, today: today), date >= today else { continue }
            kinds[calendar.startOfDay(for: date), default: []].append(item.kind)
        }
        return (0..<14).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today).map { WeekStrip.Day(date: $0, kinds: kinds[$0] ?? []) }
        }
    }
}

// MARK: - Week strip

/// Two weeks across the top, each day dotted with what's on it. Tapping a day
/// jumps the agenda to it.
private struct WeekStrip: View {
    struct Day: Identifiable {
        let date: Date
        let kinds: [ItemKind]
        var id: Date { date }
    }

    let days: [Day]
    var onSelect: (Date) -> Void
    @ScaledMetric(relativeTo: .title3) private var cellWidth: CGFloat = 38

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(days) { day in
                    cell(day)
                }
            }
            .padding(.horizontal, JotMetrics.gutter)
        }
        .scrollIndicators(.hidden)
    }

    private func cell(_ day: Day) -> some View {
        let isToday = Calendar.current.isDateInToday(day.date)
        let hasItems = !day.kinds.isEmpty
        return Button {
            onSelect(day.date)
        } label: {
            VStack(spacing: 6) {
                Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(isToday ? Color.jotBackground.opacity(0.75) : Color.jotTextSecondary)
                Text(day.date.formatted(.dateTime.day()))
                    .font(.system(.title3, design: .rounded, weight: .bold).monospacedDigit())
                    .foregroundStyle(isToday ? Color.jotBackground : Color.jotTextPrimary)
                HStack(spacing: 3) {
                    // One dot per kind on the day, in a fixed order.
                    ForEach([ItemKind.event, .reminder, .task].filter(day.kinds.contains), id: \.self) { kind in
                        Circle().fill(kind.color).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(minWidth: cellWidth)
            .padding(.horizontal, 4)
            .padding(.vertical, 10)
            .background(isToday ? Color.jotTextPrimary : Color.jotSurface, in: .rect(cornerRadius: 14, style: .continuous))
            .opacity(hasItems || isToday ? 1 : 0.55)
        }
        .buttonStyle(.pressable)
        .disabled(!hasItems)
        .accessibilityLabel("\(day.date.formatted(.dateTime.weekday(.wide).day().month(.wide))), \(day.kinds.count) items")
    }
}

// MARK: - Row

/// One captured item as a line: the kind's node, the words, and when it's due.
private struct InboxCard: View {
    let item: JotItem
    let query: String
    /// When it happens; shown in the time column in day sections.
    var date: Date?
    var showsTime = false

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .footnote) private var timeColumn: CGFloat = 64

    /// At accessibility text sizes the time goes above the title instead.
    private var stacksTime: Bool { showsTime && typeSize.isAccessibilitySize }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if stacksTime {
                Text(timeLabel)
                    .font(.jotReadout)
                    .foregroundStyle(Color.jotTextSecondary)
            }
            row
        }
        .accessibilityElement(children: .combine)
    }

    private var row: some View {
        HStack(alignment: .top, spacing: 12) {
            if showsTime, !stacksTime {
                Text(timeLabel)
                    .font(.jotReadout)
                    .foregroundStyle(Color.jotTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: timeColumn, alignment: .trailing)
                    .padding(.top, 3)
            }
            KindNode(kind: item.kind)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(SearchHighlight.attributed(item.title, query: query))
                    .font(.jotBodyEmphasis)
                    .foregroundStyle(item.isCompleted ? Color.jotTextSecondary : Color.jotTextPrimary)
                    .strikethrough(item.isCompleted, color: Color.jotTextSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                HStack(spacing: 5) {
                    Text(meta)
                        .lineLimit(1)
                    if item.recurrence != nil {
                        Image(systemName: "arrow.trianglehead.2.clockwise")
                            .accessibilityLabel("Repeats")
                    }
                    if item.audioFileName != nil {
                        Image(systemName: "waveform")
                            .accessibilityLabel("Has recording")
                    }
                }
                .font(.jotCaption)
                .foregroundStyle(Color.jotTextSecondary)

                if !item.details.isEmpty, !query.isEmpty {
                    Text(SearchHighlight.attributed(item.details, query: query))
                        .font(.jotCaption)
                        .foregroundStyle(Color.jotTextSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                if let snippet = transcriptSnippet {
                    Text(SearchHighlight.attributed("“\(snippet)”", query: query))
                        .font(.jotCaption)
                        .italic()
                        .foregroundStyle(Color.jotTextSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.leading, 4)
        .padding(.trailing, ItemActions.canComplete(item) ? 44 : 0)
        .accessibilityElement(children: .combine)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.jotTextSecondary.opacity(0.15)).frame(height: 0.5).padding(.leading, 32)
        }
        .contentShape(.rect)
        .opacity(item.isCompleted ? 0.7 : 1)
    }

    /// In day sections the time column says when; elsewhere it's "Thu" or "Oct 14".
    private var timeLabel: String {
        guard let date else { return "" }
        if Calendar.current.isDateInToday(date) || !isOverdue {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return Calendar.current.isDateInYesterday(date) ? "Yesterday" : date.formatted(.dateTime.weekday(.abbreviated).day())
    }

    /// "Reminder, tomorrow 10:00 AM" or "Task, overdue since Thu 2:00 PM". In day
    /// sections the date is already in the header and time column.
    private var meta: String {
        var text = item.kind.label
        if showsTime {
            // The node already shows the kind; details say more when there are any.
            return !item.details.isEmpty && query.isEmpty ? item.details : text
        }
        if let due = item.dueDate, item.kind != .note {
            // Mid-sentence: "tomorrow 10:00 AM", but weekdays and months keep their capital.
            let short = JotDate.short(due)
            let relative = ["Today", "Tomorrow", "Yesterday"].contains { short.hasPrefix($0) }
            let when = relative ? short.prefix(1).lowercased() + short.dropFirst() : short
            text += isOverdue ? ", overdue since \(when)" : ", \(when)"
        } else if !item.details.isEmpty, query.isEmpty {
            text += ", \(item.details)"
        }
        return text
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
