import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Data

struct UpcomingReminder: Identifiable, Hashable {
    let id: UUID
    let title: String
    let date: Date
    let kind: ItemKind
    let repeats: Bool
}

struct UpcomingEntry: TimelineEntry {
    let date: Date
    let reminders: [UpcomingReminder]

    static let placeholder = UpcomingEntry(date: .now, reminders: [
        UpcomingReminder(id: UUID(), title: "Call the dentist", date: .now.addingTimeInterval(3600), kind: .reminder, repeats: false),
        UpcomingReminder(id: UUID(), title: "Take vitamins", date: .now.addingTimeInterval(5 * 3600), kind: .reminder, repeats: true),
        UpcomingReminder(id: UUID(), title: "Renew passport", date: .now.addingTimeInterval(26 * 3600), kind: .reminder, repeats: false),
    ])
}

struct UpcomingProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpcomingEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingEntry) -> Void) {
        completion(context.isPreview ? .placeholder : Self.entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingEntry>) -> Void) {
        let now = Date.now
        let entry = Self.entry(at: now)
        // Refresh when the first reminder passes, or in 30 minutes at most.
        let refresh = min(entry.reminders.first?.date ?? .distantFuture, now.addingTimeInterval(30 * 60))
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    /// The next few reminders that haven't been done, soonest first.
    static func entry(at now: Date) -> UpcomingEntry {
        let context = ModelContext(SharedStore.container)
        let reminderKind = ItemKind.reminder.rawValue
        let descriptor = FetchDescriptor<JotItem>(
            predicate: #Predicate { $0.kindRaw == reminderKind && !$0.isCompleted && $0.dueDate != nil }
        )
        let items = (try? context.fetch(descriptor)) ?? []
        let reminders = items
            .compactMap { item -> UpcomingReminder? in
                guard let next = item.nextOccurrence(onOrAfter: now), next >= now else { return nil }
                return UpcomingReminder(id: item.id, title: item.title, date: next, kind: item.kind, repeats: item.recurrence != nil)
            }
            .sorted { $0.date < $1.date }
            .prefix(4)
        return UpcomingEntry(date: now, reminders: Array(reminders))
    }
}

// MARK: - Widget

struct UpcomingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.jamescronin.Jot.Upcoming", provider: UpcomingProvider()) { entry in
            UpcomingView(entry: entry)
        }
        .configurationDisplayName("Up Next")
        .description("Your next reminders, with a button to jot something down.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct UpcomingView: View {
    let entry: UpcomingEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall: SmallUpcoming(entry: entry)
        case .systemMedium: MediumUpcoming(entry: entry)
        case .accessoryRectangular: RectangularUpcoming(entry: entry)
        default: InlineUpcoming(entry: entry)
        }
    }
}

// MARK: Home Screen

/// The whole small widget is a record button, with the next reminder above it.
private struct SmallUpcoming: View {
    let entry: UpcomingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("UP NEXT")
                .font(.jotLabel)
                .tracking(1)
                .foregroundStyle(Color.jotAccent)
            if let next = entry.reminders.first {
                Text(next.title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.jotTextPrimary)
                    .lineLimit(2)
                    .padding(.top, 4)
                Text(JotDate.short(next.date))
                    .font(.jotTimeSmall)
                    .foregroundStyle(Color.jotTextSecondary)
                    .padding(.top, 2)
            } else {
                Text("All clear")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.jotTextPrimary)
                    .padding(.top, 4)
            }
            Spacer(minLength: 6)
            HStack {
                Spacer()
                RecordOrb(size: 46)
            }
        }
        .widgetURL(recordURL)
        .containerBackground(for: .widget) { Color.jotBackground }
    }
}

private struct MediumUpcoming: View {
    let entry: UpcomingEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("UP NEXT")
                    .font(.jotLabel)
                    .tracking(1)
                    .foregroundStyle(Color.jotAccent)
                if entry.reminders.isEmpty {
                    Spacer()
                    Text("No reminders coming up.")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.jotTextSecondary)
                    Spacer()
                } else {
                    ForEach(entry.reminders.prefix(3)) { reminder in
                        ReminderLine(reminder: reminder)
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Link(destination: recordURL) {
                VStack(spacing: 6) {
                    RecordOrb(size: 58)
                    Text("Jot")
                        .font(.jotLabel)
                        .foregroundStyle(Color.jotTextSecondary)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .containerBackground(for: .widget) { Color.jotBackground }
    }
}

private struct ReminderLine: View {
    let reminder: UpcomingReminder

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            KindDot(color: reminder.kind.color, size: 6)
            Text(reminder.title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.jotTextPrimary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(reminder.date, format: .dateTime.hour().minute())
                .font(.jotTimeSmall)
                .foregroundStyle(Color.jotTextSecondary)
        }
    }
}

// MARK: Lock Screen

private struct RectangularUpcoming: View {
    let entry: UpcomingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let next = entry.reminders.first {
                Label {
                    Text(JotDate.short(next.date))
                } icon: {
                    Image(systemName: next.repeats ? "bell.badge" : "bell.fill")
                }
                .font(.system(.caption, design: .rounded, weight: .bold).monospacedDigit())
                .widgetAccentable()
                Text(next.title)
                    .font(.system(.headline, design: .rounded))
                    .lineLimit(2)
            } else {
                Label("Jot", systemImage: "mic.fill")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .widgetAccentable()
                Text("Nothing coming up")
                    .font(.system(.headline, design: .rounded))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }
}

private struct InlineUpcoming: View {
    let entry: UpcomingEntry

    var body: some View {
        if let next = entry.reminders.first {
            Label("\(next.date.formatted(date: .omitted, time: .shortened)) \(next.title)", systemImage: "bell.fill")
        } else {
            Label("No reminders", systemImage: "checkmark")
        }
    }
}

// MARK: - Record button (Lock Screen and Home Screen)

struct RecordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.jamescronin.Jot.Record", provider: RecordProvider()) { _ in
            RecordWidgetView()
        }
        .configurationDisplayName("Record")
        .description("One tap to start jotting.")
        .supportedFamilies([.accessoryCircular, .systemSmall])
    }
}

struct RecordProvider: TimelineProvider {
    struct Entry: TimelineEntry { let date: Date }
    func placeholder(in context: Context) -> Entry { Entry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(Entry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now)], policy: .never))
    }
}

private struct RecordWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .accessoryCircular {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "mic.fill")
                        .font(.system(size: 22, weight: .bold))
                        .widgetAccentable()
                }
                .containerBackground(for: .widget) { Color.clear }
            } else {
                VStack(spacing: 10) {
                    RecordOrb(size: 74)
                    Wordmark(size: 22)
                }
                .containerBackground(for: .widget) { Color.jotBackground }
            }
        }
        .widgetURL(recordURL)
        .accessibilityLabel("Record with Jot")
    }
}

/// The orb with a mic, as drawn in widgets. Tints sensibly in accented modes.
struct RecordOrb: View {
    let size: CGFloat
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        if renderingMode == .fullColor {
            BrandOrb(size: size, glow: 0.4)
                .overlay {
                    Image(systemName: "mic.fill")
                        .font(.system(size: size * 0.36, weight: .bold))
                        .foregroundStyle(.white)
                }
        } else {
            Circle()
                .frame(width: size, height: size)
                .widgetAccentable()
                .overlay {
                    Image(systemName: "mic.fill")
                        .font(.system(size: size * 0.36, weight: .bold))
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
        }
    }
}
