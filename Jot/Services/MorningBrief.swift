import BackgroundTasks
import Foundation
import SwiftData
import UserNotifications

/// A notification each morning summarizing the day's events, reminders, and open tasks.
///
/// Local notifications carry fixed text, so briefs for the next few mornings are
/// scheduled with precomputed summaries. `ReminderScheduler.refill` rebuilds them
/// whenever items change and on every launch, and a background refresh shortly
/// before delivery keeps the next one current even if Jot isn't opened.
@MainActor
enum MorningBrief {
    static let taskIdentifier = "com.jamescronin.Jot.brief"
    static let daysAhead = 3
    private static let identifierPrefix = "brief-"
    /// The one-off "send me a preview" brief; reminder refills leave it alone.
    static let previewIdentifier = "brief-preview"

    // MARK: Settings

    enum Keys {
        static let enabled = "JotBriefEnabled"
        static let minutes = "JotBriefMinutes"   // minutes after midnight
    }

    static let defaultMinutes = 8 * 60

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: Keys.enabled) }

    static var deliveryMinutes: Int {
        UserDefaults.standard.object(forKey: Keys.minutes) as? Int ?? defaultMinutes
    }

    // MARK: Content

    struct Summary: Equatable {
        var title: String
        var subtitle: String
        var body: String
    }

    /// What the brief for `day` says, given everything Jot and the calendar know.
    static func summary(for day: Date, items: [JotItem], events: [CalendarEvent], name: String = UserProfile.name) -> Summary {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? day

        func occurrence(_ item: JotItem) -> Date? { item.occurrence(onDayOf: day) }
        func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }

        // Events: the calendar's plus Jot's own, in time order.
        var eventLines: [(Date, String)] = events.map {
            ($0.isAllDay ? start : $0.start, $0.isAllDay ? $0.title : "\($0.title) \(time($0.start))")
        }
        for item in items where item.kind == .event {
            if let at = occurrence(item) { eventLines.append((at, "\(item.title) \(time(at))")) }
        }
        eventLines.sort { $0.0 < $1.0 }

        let reminders = items
            .filter { $0.kind == .reminder && !$0.isCompleted }
            .compactMap { item in occurrence(item).map { ($0, "\(item.title) \(time($0))") } }
            .sorted { $0.0 < $1.0 }

        // Open tasks due by the end of the day (including overdue), then undated ones.
        let tasks = items.filter { $0.kind == .task && !$0.isCompleted }
        let dueTasks = tasks.filter { ($0.dueDate ?? .distantFuture) < end }
            .sorted { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }
        let undatedTasks = tasks.filter { $0.dueDate == nil }
        let taskTitles = (dueTasks + undatedTasks).map(\.title)

        func list(_ names: [String], limit: Int = 3) -> String {
            let shown = names.prefix(limit).joined(separator: ", ")
            return names.count > limit ? "\(shown), +\(names.count - limit) more" : shown
        }
        func count(_ n: Int, _ noun: String) -> String { "\(n) \(noun)\(n == 1 ? "" : "s")" }

        var lines: [String] = []
        if !eventLines.isEmpty { lines.append("Events · " + list(eventLines.map(\.1))) }
        if !reminders.isEmpty { lines.append("Reminders · " + list(reminders.map(\.1))) }
        if !taskTitles.isEmpty { lines.append("Tasks · " + list(taskTitles)) }

        let weekday = day.formatted(.dateTime.weekday(.wide))
        // With a name it greets ("Good morning, James"); without, it names the day.
        let title = UserProfile.firstName(name).isEmpty ? "Your \(weekday)" : UserProfile.greeting(at: day, name: name)
        if lines.isEmpty {
            return Summary(
                title: title,
                subtitle: "A clear day",
                body: "Nothing scheduled. Hold the orb when something comes up."
            )
        }
        return Summary(
            title: title,
            subtitle: [count(eventLines.count, "event"), count(reminders.count, "reminder"), count(taskTitles.count, "task")]
                .joined(separator: " · "),
            body: lines.joined(separator: "\n")
        )
    }

    // MARK: Scheduling

    /// Delivery times for the next `daysAhead` briefs, soonest first.
    static func upcomingDeliveries(after now: Date = .now) -> [Date] {
        let calendar = Calendar.current
        let minutes = deliveryMinutes
        return (0...daysAhead).compactMap { offset -> Date? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else { return nil }
            return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day)
        }
        .filter { $0 > now }
        .prefix(daysAhead)
        .map { $0 }
    }

    /// Notification requests for the upcoming briefs, or none when turned off.
    static func requests(using context: ModelContext, now: Date = .now) -> [UNNotificationRequest] {
        guard isEnabled else { return [] }
        let items = (try? context.fetch(FetchDescriptor<JotItem>())) ?? []

        return upcomingDeliveries(after: now).map { delivery in
            let summary = summary(for: delivery, items: items, events: CalendarService.events(on: delivery))
            let content = UNMutableNotificationContent()
            content.title = summary.title
            content.subtitle = summary.subtitle
            content.body = summary.body
            content.sound = .default
            content.threadIdentifier = "morning-brief"
            content.relevanceScore = 1

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: delivery)
            return UNNotificationRequest(
                identifier: identifierPrefix + delivery.formatted(.iso8601.year().month().day()),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
        }
    }

    /// Delivers today's brief in a few seconds, so the format can be checked.
    static func sendPreview(using context: ModelContext) async -> Bool {
        guard await ReminderScheduler.ensureAuthorized() else { return false }
        let items = (try? context.fetch(FetchDescriptor<JotItem>())) ?? []
        let summary = summary(for: .now, items: items, events: CalendarService.events(on: .now))
        let content = UNMutableNotificationContent()
        content.title = summary.title
        content.subtitle = summary.subtitle
        content.body = summary.body
        content.sound = .default
        content.threadIdentifier = "morning-brief"
        let request = UNNotificationRequest(
            identifier: previewIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        )
        return (try? await UNUserNotificationCenter.current().add(request)) != nil
    }

    // MARK: Background refresh

    /// Asks iOS to wake Jot about an hour before the next brief to rebuild it.
    static func scheduleBackgroundRefresh(now: Date = .now) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
        guard isEnabled, let next = upcomingDeliveries(after: now).first else { return }
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = max(next.addingTimeInterval(-60 * 60), now.addingTimeInterval(15 * 60))
        try? BGTaskScheduler.shared.submit(request)
    }

    static func handleBackgroundRefresh() async {
        await ReminderScheduler.refill(using: SharedStore.container.mainContext)
    }
}
