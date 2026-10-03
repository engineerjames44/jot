import SwiftData
import SwiftUI

/// One thing on Today, from either EventKit or Jot.
private struct TimelineEntry: Identifiable {
    enum Source {
        case calendar(CalendarEvent)
        case item(JotItem)
    }

    let id: String
    let time: Date?
    let isOverdue: Bool
    let source: Source

    var kind: ItemKind {
        switch source {
        case .calendar: .event
        case .item(let item): item.kind
        }
    }
}

/// A slot on the vertical timeline: an entry, or the glowing "now" line.
private enum TimelineSlot: Identifiable {
    case entry(TimelineEntry)
    case now(Date)

    var id: String {
        switch self {
        case .entry(let entry): entry.id
        case .now: "now"
        }
    }
}

private struct TodayContent {
    var timeline: [TimelineSlot] = []
    /// Open reminders and tasks whose time has passed, folded under "Still open from earlier".
    var earlier: [TimelineEntry] = []
    var anytime: [TimelineEntry] = []
    var notes: [JotItem] = []

    var isEmpty: Bool {
        !timeline.contains { if case .entry = $0 { true } else { false } }
            && earlier.isEmpty && anytime.isEmpty && notes.isEmpty
    }

    /// The first thing still to come today.
    var next: TimelineEntry? {
        for slot in timeline {
            if case .entry(let entry) = slot, let time = entry.time, time > .now { return entry }
        }
        return nil
    }
}

struct TodayView: View {
    @Environment(CalendarService.self) private var calendar
    @Environment(\.modelContext) private var modelContext
    @Environment(\.jotAnimation) private var animation
    @Environment(CaptureController.self) private var capture
    @Query(sort: \JotItem.createdAt, order: .reverse) private var items: [JotItem]

    /// Items mid-completion: their check fills in before they fade away.
    @State private var completing: Set<UUID> = []
    @State private var completedCount = 0
    @State private var openRow: UUID?
    @State private var path: [JotItem] = []
    @State private var showingEarlier = false

    var body: some View {
        NavigationStack(path: $path) {
            TimelineView(.everyMinute) { context in
                let content = buildContent(now: context.date)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 32) {
                            TodayHeader(now: context.date, content: content)

                            if !calendar.hasAccess {
                                CalendarAccessCard()
                            }

                            if content.isEmpty {
                                EmptyStateView(
                                    symbol: "sun.horizon.fill",
                                    color: .jotReminder,
                                    title: "A clear day",
                                    message: "Hold the orb and say what's on your mind."
                                )
                            } else {
                                timelineSection(content)
                                earlierSection(content)
                                anytimeSection(content)
                                notesSection(content)
                            }
                        }
                        .padding(.horizontal, JotMetrics.gutter)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                        .animation(animation, value: content.signature)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: capture.landingItemID) { _, id in
                        // Bring a just-captured item's slot on screen so it can fly into it.
                        guard let id else { return }
                        withAnimation(animation) { proxy.scrollTo(id.uuidString, anchor: .center) }
                    }
                }
            }
            .background(Color.jotBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: JotItem.self) { ItemDetailView(item: $0) }
            .refreshable { calendar.reload() }
            .sensoryFeedback(.success, trigger: completedCount)
        }
        .overlay { CaptureStage() }
        // Only at the root: on a detail screen the orb would cover its controls.
        // It comes back while a capture is underway (e.g. from the Action Button).
        .safeAreaInset(edge: .bottom) {
            if path.isEmpty || capture.phase != .idle {
                CaptureDock()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(animation, value: path.isEmpty)
    }

    // MARK: Sections

    @ViewBuilder
    private func timelineSection(_ content: TodayContent) -> some View {
        let hasEntries = content.timeline.contains { if case .entry = $0 { true } else { false } }
        if hasEntries {
            VStack(spacing: 0) {
                ForEach(Array(content.timeline.enumerated()), id: \.element.id) { index, slot in
                    Group {
                        switch slot {
                        case .now(let date):
                            NowLine(now: date)
                        case .entry(let entry):
                            row(for: entry, railAbove: index > 0, railBelow: index < content.timeline.count - 1)
                        }
                    }
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 0.97))))
                }
            }
        }
    }

    @ViewBuilder
    private func earlierSection(_ content: TodayContent) -> some View {
        if !content.earlier.isEmpty {
            let movable = content.earlier.compactMap { entry -> JotItem? in
                if case .item(let item) = entry.source, ItemActions.canSnooze(item) { item } else { nil }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(animation) { showingEarlier.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Still open from earlier")
                                .font(.jotSection)
                                .foregroundStyle(Color.jotTextPrimary)
                            Text("\(content.earlier.count)")
                                .font(.jotTimeSmall)
                                .foregroundStyle(Color.jotTextSecondary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.jotTextSecondary)
                                .rotationEffect(.degrees(showingEarlier ? 0 : -90))
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(showingEarlier ? "Hides them" : "Shows them")

                    Spacer(minLength: 0)

                    if !movable.isEmpty {
                        Button("Move to tomorrow") {
                            withAnimation(animation) { ItemActions.moveToTomorrow(movable, in: modelContext) }
                        }
                        .buttonStyle(.jotSecondary)
                        .controlSize(.small)
                        .fixedSize()
                    }
                }
                .padding(.horizontal, 4)

                if showingEarlier {
                    VStack(spacing: 0) {
                        ForEach(content.earlier) { entry in
                            row(for: entry, railAbove: false, railBelow: false, showsDay: true)
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    @ViewBuilder
    private func anytimeSection(_ content: TodayContent) -> some View {
        if !content.anytime.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                SectionHeader(title: "Anytime", trailing: "\(content.anytime.count)")
                VStack(spacing: 0) {
                    ForEach(content.anytime) { entry in
                        row(for: entry, railAbove: false, railBelow: false)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func notesSection(_ content: TodayContent) -> some View {
        if !content.notes.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                SectionHeader(title: "Recent notes", trailing: "\(content.notes.count)")
                VStack(spacing: 0) {
                    ForEach(content.notes, id: \.id.uuidString) { note in
                        NavigationLink(value: note) {
                            RailRow(kind: .note, time: nil, railAbove: false, railBelow: false) {
                                NoteLines(note: note)
                            }
                        }
                        .buttonStyle(.pressable)
                        .landingTarget(note.id)
                    }
                }
            }
        }
    }

    // MARK: Rows

    @ViewBuilder
    private func row(for entry: TimelineEntry, railAbove: Bool, railBelow: Bool, showsDay: Bool = false) -> some View {
        switch entry.source {
        case .calendar(let event):
            RailRow(kind: .event, time: entry.time, railAbove: railAbove, railBelow: railBelow) {
                CalendarEventLines(event: event)
            }
            .accessibilityElement(children: .combine)
        case .item(let item):
            let checkable = ItemActions.canComplete(item)
            SwipeableRow(
                item: item,
                openRow: $openRow,
                onComplete: { complete(item) },
                onSnooze: { option in withAnimation(animation) { ItemActions.snooze(item, option, in: modelContext) } },
                onDelete: { withAnimation(animation) { ItemActions.delete(item, in: modelContext) } }
            ) {
                NavigationLink(value: item) {
                    RailRow(kind: item.kind, time: entry.time, showsDay: showsDay, railAbove: railAbove, railBelow: railBelow) {
                        ItemLines(item: item)
                            .padding(.trailing, checkable ? 40 : 0)
                    }
                }
                .buttonStyle(.pressable)
                .overlay(alignment: .trailing) {
                    if checkable {
                        Button {
                            complete(item)
                        } label: {
                            CheckCircle(isChecked: completing.contains(item.id), color: item.kind.color)
                                .padding(.vertical, 12)
                                .padding(.leading, 12)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Complete \(item.title)")
                    }
                }
                .background(Color.jotBackground)
            }
            .landingTarget(item.id)
        }
    }

    private func complete(_ item: JotItem) {
        guard !completing.contains(item.id) else { return }
        withAnimation(animation) { _ = completing.insert(item.id) }
        completedCount += 1

        Task {
            // Let the check land before the row leaves.
            try? await Task.sleep(for: .milliseconds(550))
            withAnimation(animation) {
                ItemActions.toggleComplete(item, in: modelContext)
                completing.remove(item.id)
            }
        }
    }

    // MARK: Data

    private func buildContent(now: Date) -> TodayContent {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: now)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) ?? now
        let recentNotesCutoff = now.addingTimeInterval(-24 * 60 * 60)

        var content = TodayContent()
        var timed: [TimelineEntry] = []

        for event in calendar.todaysEvents {
            let entry = TimelineEntry(id: "cal-\(event.id)", time: event.isAllDay ? nil : event.start, isOverdue: false, source: .calendar(event))
            event.isAllDay ? content.anytime.append(entry) : timed.append(entry)
        }

        for item in items {
            let id = item.id.uuidString
            switch item.kind {
            case .event:
                guard let start = item.occurrence(onDayOf: now) else { continue }
                timed.append(TimelineEntry(id: id, time: start, isOverdue: false, source: .item(item)))

            case .reminder, .task:
                guard !item.isCompleted else { continue }
                if let due = item.dueDate {
                    let next = item.recurrence == nil ? due : (item.nextOccurrence(onOrAfter: startOfDay) ?? due)
                    guard next < endOfDay else { continue }
                    let entry = TimelineEntry(id: id, time: next, isOverdue: next < now, source: .item(item))
                    if entry.isOverdue { content.earlier.append(entry) } else { timed.append(entry) }
                } else if item.kind == .task {
                    content.anytime.append(TimelineEntry(id: id, time: nil, isOverdue: false, source: .item(item)))
                }

            case .note:
                if item.createdAt >= recentNotesCutoff { content.notes.append(item) }
            }
        }

        timed.sort { ($0.time ?? .distantPast) < ($1.time ?? .distantPast) }
        content.earlier.sort { ($0.time ?? .distantPast) < ($1.time ?? .distantPast) }

        var slots = timed.map(TimelineSlot.entry)
        let nowIndex = timed.firstIndex { ($0.time ?? .distantPast) > now } ?? timed.count
        if !timed.isEmpty {
            slots.insert(.now(now), at: nowIndex)
        }
        content.timeline = slots
        return content
    }
}

private extension TodayContent {
    /// Changes whenever entries are added or removed, to drive list animations.
    var signature: [String] {
        timeline.map(\.id) + earlier.map(\.id) + anytime.map(\.id) + notes.map(\.id.uuidString)
    }
}

// MARK: - Header

private struct TodayHeader: View {
    let now: Date
    let content: TodayContent
    @AppStorage(UserProfile.nameKey, store: UserProfile.defaults) private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.jotSection)
                    .foregroundStyle(Color.jotTextSecondary)
                Spacer()
                ProfileBadge()
            }

            Text(UserProfile.greeting(at: now, name: name))
                .font(.jotDisplay)
                .tracking(-0.8)
                .foregroundStyle(Color.jotTextPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)

            nextLine
                .font(.body)
                .padding(.top, 2)
        }
        .padding(.top, 4)
    }

    /// What's coming up, so the header answers "what now?" rather than counting.
    @ViewBuilder
    private var nextLine: some View {
        if let next = content.next, let time = next.time {
            (Text("Next: ").foregroundStyle(Color.jotTextSecondary)
                + Text(next.title).foregroundStyle(Color.jotTextPrimary).fontWeight(.semibold)
                + Text(" at \(time.formatted(date: .omitted, time: .shortened))").foregroundStyle(Color.jotTextSecondary))
                .lineLimit(2)
        } else if !content.earlier.isEmpty {
            Text("Nothing else scheduled. \(content.earlier.count) still open from earlier.")
                .foregroundStyle(Color.jotTextSecondary)
        } else if !content.isEmpty {
            Text("Nothing else scheduled today.")
                .foregroundStyle(Color.jotTextSecondary)
        }
    }
}

private extension TimelineEntry {
    var title: String {
        switch source {
        case .calendar(let event): event.title
        case .item(let item): item.title
        }
    }
}

// MARK: - Timeline pieces

private enum TimelineLayout {
    static let timeColumn: CGFloat = 64
    static let railWidth: CGFloat = 18
}

/// One line on the day's rail: time readout, the kind's node, then the words.
private struct RailRow<Lines: View>: View {
    let kind: ItemKind
    let time: Date?
    var showsDay = false
    let railAbove: Bool
    let railBelow: Bool
    @ViewBuilder let lines: Lines

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(timeLabel)
                .font(.jotReadout)
                .foregroundStyle(Color.jotTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: TimelineLayout.timeColumn, alignment: .trailing)
                .padding(.top, 2)

            ZStack(alignment: .top) {
                // The rail runs through the row and joins its neighbours.
                VStack(spacing: 0) {
                    Rectangle().fill(railAbove ? Color.jotTextSecondary.opacity(0.3) : .clear).frame(width: 1.5, height: 9)
                    Rectangle().fill(railBelow ? Color.jotTextSecondary.opacity(0.3) : .clear).frame(width: 1.5)
                }
                KindNode(kind: kind)
                    .padding(.top, 3)
            }
            .frame(width: TimelineLayout.railWidth)
            .frame(maxHeight: .infinity, alignment: .top)

            lines
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 18)
        }
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(.rect)
    }

    private var timeLabel: String {
        guard let time else { return "" }
        if showsDay, !Calendar.current.isDateInToday(time) {
            return Calendar.current.isDateInYesterday(time) ? "Yesterday" : time.formatted(.dateTime.weekday(.abbreviated))
        }
        return time.formatted(date: .omitted, time: .shortened)
    }
}

/// The glowing orange "now" marker: the only orange on Today besides the orb.
private struct NowLine: View {
    let now: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 10) {
            Text(now.formatted(date: .omitted, time: .shortened))
                .font(.jotReadout)
                .fontWeight(.semibold)
                .foregroundStyle(Color.jotAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: TimelineLayout.timeColumn, alignment: .trailing)

            ZStack {
                Circle()
                    .fill(Color.jotAccent.opacity(0.35))
                    .frame(width: 20, height: 20)
                    .scaleEffect(pulsing ? 1.25 : 0.7)
                    .opacity(pulsing ? 0 : 1)
                Circle()
                    .fill(Color.jotAccent)
                    .frame(width: 9, height: 9)
                    .shadow(color: Color.jotAccent.opacity(0.9), radius: 5)
            }
            .frame(width: TimelineLayout.railWidth)

            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.jotAccent, Color.jotAccent.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(height: 1.5)
        }
        .frame(height: 24)
        .padding(.bottom, 14)
        .accessibilityElement()
        .accessibilityLabel("Now, \(now.formatted(date: .omitted, time: .shortened))")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
    }
}

// MARK: - Row contents

private struct ItemLines: View {
    let item: JotItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title)
                .font(.jotBodyEmphasis)
                .foregroundStyle(Color.jotTextPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            if let meta {
                Text(meta)
                    .font(.jotCaption)
                    .foregroundStyle(Color.jotTextSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
            }
        }
    }

    private var meta: String? {
        var parts: [String] = []
        if !item.details.isEmpty { parts.append(item.details) }
        if let recurrence = item.recurrence { parts.append("Repeats \(recurrence.label.lowercased())") }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

private struct CalendarEventLines: View {
    let event: CalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(event.title)
                .font(.jotBodyEmphasis)
                .foregroundStyle(Color.jotTextPrimary)
                .lineLimit(2)
            Text(meta)
                .font(.jotCaption)
                .foregroundStyle(Color.jotTextSecondary)
                .lineLimit(1)
        }
    }

    private var meta: String {
        var parts = [event.isAllDay ? "All day" : "Until \(event.end.formatted(date: .omitted, time: .shortened))"]
        if let location = event.location, !location.isEmpty { parts.append(location) }
        parts.append(event.calendarTitle)
        return parts.joined(separator: ", ")
    }
}

private struct NoteLines: View {
    let note: JotItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(note.title)
                .font(.jotBodyEmphasis)
                .foregroundStyle(Color.jotTextPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            Text(note.createdAt.formatted(.relative(presentation: .named)).capitalizedFirst)
                .font(.jotCaption)
                .foregroundStyle(Color.jotTextSecondary)
        }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

private struct CalendarAccessCard: View {
    @Environment(CalendarService.self) private var calendar

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.jotEvent)
                .frame(width: 40, height: 40)
                .background(Color.jotRaised, in: .rect(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Bring in your calendar")
                    .font(.jotHeadline)
                    .foregroundStyle(Color.jotTextPrimary)
                Text(calendar.authorization == .notDetermined
                     ? "See your events on the timeline. Jot never changes them."
                     : "Calendar access is off. Turn it on in the Settings app.")
                    .font(.jotCaption)
                    .foregroundStyle(Color.jotTextSecondary)
            }

            Spacer(minLength: 0)

            if calendar.authorization == .notDetermined {
                Button("Allow") {
                    Task { await calendar.requestAccess() }
                }
                .buttonStyle(.jotSecondary)
                .controlSize(.small)
                .fixedSize()
            }
        }
        .jotCard()
    }
}
