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
    var anytime: [TimelineEntry] = []
    var notes: [JotItem] = []
    var eventCount = 0
    var reminderCount = 0
    var taskCount = 0

    var isEmpty: Bool {
        !timeline.contains { if case .entry = $0 { true } else { false } } && anytime.isEmpty && notes.isEmpty
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

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                let content = buildContent(now: context.date)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            TodayHeader(now: context.date, content: content)
                                .staggeredAppear(0)

                            if !calendar.hasAccess {
                                CalendarAccessCard()
                                    .staggeredAppear(1)
                            }

                            if content.isEmpty {
                                EmptyStateView(
                                    symbol: "sun.horizon.fill",
                                    color: .jotReminder,
                                    title: "A clear day",
                                    message: "Hold the orb and say what's on your mind."
                                )
                                .staggeredAppear(2)
                            } else {
                                timelineSection(content, now: context.date)
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
        // On the stack, so the orb stays reachable on pushed screens too.
        .safeAreaInset(edge: .bottom) { CaptureDock() }
    }

    // MARK: Sections

    @ViewBuilder
    private func timelineSection(_ content: TodayContent, now: Date) -> some View {
        let hasEntries = content.timeline.contains { if case .entry = $0 { true } else { false } }
        if hasEntries {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Timeline")
                VStack(spacing: 0) {
                    ForEach(Array(content.timeline.enumerated()), id: \.element.id) { index, slot in
                        Group {
                            switch slot {
                            case .now(let date):
                                NowLine(now: date)
                            case .entry(let entry):
                                TimelineRow(
                                    entry: entry,
                                    isFirst: index == 0,
                                    isLast: index == content.timeline.count - 1
                                ) {
                                    card(for: entry)
                                }
                            }
                        }
                        .staggeredAppear(index + 2)
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 0.95))))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func anytimeSection(_ content: TodayContent) -> some View {
        if !content.anytime.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Anytime", trailing: "\(content.anytime.count)")
                ForEach(Array(content.anytime.enumerated()), id: \.element.id) { index, entry in
                    card(for: entry)
                        .staggeredAppear(index + 4)
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 0.95))))
                }
            }
        }
    }

    @ViewBuilder
    private func notesSection(_ content: TodayContent) -> some View {
        if !content.notes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Recent notes", trailing: "\(content.notes.count)")
                ForEach(Array(content.notes.enumerated()), id: \.element.id.uuidString) { index, note in
                    NavigationLink(value: note) {
                        NoteCard(note: note)
                    }
                    .buttonStyle(.pressable)
                    .landingTarget(note.id)
                    .staggeredAppear(index + 6)
                }
            }
        }
    }

    // MARK: Cards

    @ViewBuilder
    private func card(for entry: TimelineEntry) -> some View {
        switch entry.source {
        case .calendar(let event):
            CalendarEventCard(event: event)
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
                    ItemCard(
                        item: item,
                        time: entry.time,
                        isOverdue: entry.isOverdue,
                        reservesCheckSpace: checkable
                    )
                }
                .buttonStyle(.pressable)
                .overlay(alignment: .trailing) {
                    if checkable {
                        Button {
                            complete(item)
                        } label: {
                            CheckCircle(isChecked: completing.contains(item.id), color: item.kind.color)
                                .padding(JotMetrics.cardPadding)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Complete \(item.title)")
                    }
                }
            }
            .landingTarget(item.id)
        }
    }

    private func complete(_ item: JotItem) {
        guard !completing.contains(item.id) else { return }
        withAnimation(animation) { _ = completing.insert(item.id) }
        completedCount += 1

        Task {
            // Let the check land before the card leaves.
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
            content.eventCount += 1
        }

        for item in items {
            let id = item.id.uuidString
            switch item.kind {
            case .event:
                guard let start = item.occurrence(onDayOf: now) else { continue }
                timed.append(TimelineEntry(id: id, time: start, isOverdue: false, source: .item(item)))
                content.eventCount += 1

            case .reminder, .task:
                guard !item.isCompleted else { continue }
                if let due = item.dueDate {
                    let next = item.recurrence == nil ? due : (item.nextOccurrence(onOrAfter: startOfDay) ?? due)
                    guard next < endOfDay else { continue }
                    timed.append(TimelineEntry(id: id, time: next, isOverdue: next < now, source: .item(item)))
                } else if item.kind == .task {
                    content.anytime.append(TimelineEntry(id: id, time: nil, isOverdue: false, source: .item(item)))
                } else {
                    continue
                }
                if item.kind == .task { content.taskCount += 1 } else { content.reminderCount += 1 }

            case .note:
                if item.createdAt >= recentNotesCutoff { content.notes.append(item) }
            }
        }

        timed.sort { ($0.time ?? .distantPast) < ($1.time ?? .distantPast) }

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
        timeline.map(\.id) + anytime.map(\.id) + notes.map(\.id.uuidString)
    }
}

// MARK: - Header

private struct TodayHeader: View {
    let now: Date
    let content: TodayContent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                .font(.jotLabel)
                .tracking(1.2)
                .foregroundStyle(Color.jotAccent)

            Text(greeting)
                .font(.jotDisplay)
                .tracking(-0.8)
                .foregroundStyle(Color.jotTextPrimary)

            HStack(spacing: 14) {
                SummaryCount(value: content.eventCount, noun: "event", color: .jotEvent)
                SummaryCount(value: content.reminderCount, noun: "reminder", color: .jotReminder)
                SummaryCount(value: content.taskCount, noun: "task", color: .jotTask)
            }
            .padding(.top, 2)
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "Hello, night owl"
        }
    }
}

private struct SummaryCount: View {
    let value: Int
    let noun: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            KindDot(color: color, size: 6)
            Text("\(value)")
                .font(.jotTime)
                .foregroundStyle(Color.jotTextPrimary)
                .contentTransition(.numericText(value: Double(value)))
            Text(value == 1 ? noun : noun + "s")
                .font(.jotCaption)
                .foregroundStyle(Color.jotTextSecondary)
        }
    }
}

// MARK: - Timeline pieces

private enum TimelineLayout {
    static let timeColumn: CGFloat = 58
    static let railWidth: CGFloat = 20
}

/// Time label, rail with a colored node, and the card.
private struct TimelineRow<Card: View>: View {
    let entry: TimelineEntry
    let isFirst: Bool
    let isLast: Bool
    @ViewBuilder let card: Card

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(entry.time.map { $0.formatted(date: .omitted, time: .shortened) } ?? "")
                .font(.jotTimeSmall)
                .foregroundStyle(Color.jotTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: TimelineLayout.timeColumn, alignment: .trailing)
                .padding(.top, 19)

            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Color.jotBorder)
                    .frame(width: 2)
                    .padding(.top, isFirst ? 22 : 0)
                    .padding(.bottom, isLast ? 0 : 0)
                Circle()
                    .fill(Color.jotBackground)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(entry.kind.color, lineWidth: 3))
                    .padding(.top, 20)
            }
            .frame(width: TimelineLayout.railWidth)
            .frame(maxHeight: .infinity, alignment: .top)

            card
                .padding(.bottom, 10)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The glowing orange "now" marker.
private struct NowLine: View {
    let now: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 10) {
            Text(now.formatted(date: .omitted, time: .shortened))
                .font(.jotTimeSmall)
                .foregroundStyle(Color.jotAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: TimelineLayout.timeColumn, alignment: .trailing)

            ZStack {
                Circle()
                    .fill(Color.jotAccent.opacity(0.35))
                    .frame(width: 22, height: 22)
                    .scaleEffect(pulsing ? 1.25 : 0.7)
                    .opacity(pulsing ? 0 : 1)
                Circle()
                    .fill(Color.jotAccent)
                    .frame(width: 10, height: 10)
                    .shadow(color: Color.jotAccent.opacity(0.9), radius: 6)
            }
            .frame(width: TimelineLayout.railWidth)

            Capsule()
                .fill(LinearGradient(
                    colors: [Color.jotAccent, Color.jotAccent.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(height: 2)
                .shadow(color: Color.jotAccent.opacity(0.8), radius: 4)
        }
        .frame(height: 30)
        .padding(.bottom, 10)
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

// MARK: - Cards

private struct ItemCard: View {
    let item: JotItem
    let time: Date?
    let isOverdue: Bool
    let reservesCheckSpace: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                KindLabel(kind: item.kind)
                if isOverdue {
                    Text("OVERDUE")
                        .font(.jotLabel)
                        .tracking(0.6)
                        .foregroundStyle(Color.jotAccent)
                }
            }

            Text(item.title)
                .font(.jotBodyEmphasis)
                .foregroundStyle(Color.jotTextPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)

            if !item.details.isEmpty {
                Text(item.details)
                    .font(.jotCaption)
                    .foregroundStyle(Color.jotTextSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }

            if let recurrence = item.recurrence {
                Label("Repeats \(recurrence.label.lowercased())", systemImage: "arrow.trianglehead.2.clockwise")
                    .font(.jotCaption)
                    .foregroundStyle(Color.jotTextSecondary)
            }
        }
        .padding(.trailing, reservesCheckSpace ? 36 : 0)
        .jotCard()
        .overlay(alignment: .leading) { KindEdge(color: item.kind.color) }
    }
}

private struct CalendarEventCard: View {
    let event: CalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                KindLabel(kind: .event)
                Text(event.calendarTitle)
                    .font(.jotLabel)
                    .foregroundStyle(Color.jotTextSecondary)
                    .lineLimit(1)
            }
            Text(event.title)
                .font(.jotBodyEmphasis)
                .foregroundStyle(Color.jotTextPrimary)
                .lineLimit(2)

            HStack(spacing: 10) {
                if event.isAllDay {
                    Text("All day")
                } else {
                    Text("\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))")
                        .monospacedDigit()
                }
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .lineLimit(1)
                }
            }
            .font(.jotCaption)
            .foregroundStyle(Color.jotTextSecondary)
        }
        .jotCard()
        .overlay(alignment: .leading) { KindEdge(color: .jotEvent) }
        .accessibilityElement(children: .combine)
    }
}

private struct NoteCard: View {
    let note: JotItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "quote.opening")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Color.jotNote)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.jotBodyEmphasis)
                    .foregroundStyle(Color.jotTextPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                if !note.details.isEmpty {
                    Text(note.details)
                        .font(.jotCaption)
                        .foregroundStyle(Color.jotTextSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                Text(note.createdAt.formatted(.relative(presentation: .named)))
                    .font(.jotTimeSmall)
                    .foregroundStyle(Color.jotTextSecondary)
            }
        }
        .jotCard()
        .overlay(alignment: .leading) { KindEdge(color: .jotNote) }
    }
}

/// The thin colored edge on the leading side of a card.
private struct KindEdge: View {
    let color: Color

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: 3)
            .padding(.vertical, 18)
    }
}

private struct CalendarAccessCard: View {
    @Environment(CalendarService.self) private var calendar

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.jotEvent)
                .frame(width: 44, height: 44)
                .background(Color.jotRaised, in: .rect(cornerRadius: 14, style: .continuous))

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
