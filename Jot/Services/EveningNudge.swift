import Foundation
import SwiftData
import UserNotifications

/// At the end of the day, a nudge about what's still open, with a button that
/// moves it all to tomorrow without opening the app. Built like the morning
/// brief: worked out ahead of time and rebuilt on every refill.
@MainActor
enum EveningNudge {
    enum Keys {
        static let enabled = "JotNudgeEnabled"
    }

    /// 8 PM: late enough that the day's done, early enough to act on it.
    static let hour = 20
    static let daysAhead = 2
    nonisolated static let categoryID = "jot.evening"
    nonisolated static let moveAction = "jot.moveToTomorrow"
    private static let identifierPrefix = "evening-"

    /// On unless turned off in Settings.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Keys.enabled) as? Bool ?? true
    }

    /// Built on demand: `UNNotificationCategory` isn't Sendable.
    nonisolated static var category: UNNotificationCategory {
        UNNotificationCategory(
            identifier: categoryID,
            actions: [
                UNNotificationAction(identifier: moveAction, title: "Move to tomorrow", options: [],
                                     icon: UNNotificationActionIcon(systemImageName: "arrow.right.circle")),
            ],
            intentIdentifiers: []
        )
    }

    /// Open reminders and tasks that will be past due at `moment`, oldest first.
    static func stillOpen(at moment: Date, items: [JotItem]) -> [JotItem] {
        let startOfDay = Calendar.current.startOfDay(for: moment)
        return items
            .compactMap { item -> (JotItem, Date)? in
                guard item.kind == .reminder || item.kind == .task, !item.isCompleted, let due = item.dueDate else { return nil }
                let next = item.recurrence == nil ? due : (item.nextOccurrence(onOrAfter: startOfDay) ?? due)
                return next < moment ? (item, next) : nil
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    /// "3 things still open" and the first few titles, or nil when nothing is.
    static func content(at moment: Date, items: [JotItem]) -> (title: String, body: String)? {
        let open = stillOpen(at: moment, items: items)
        guard !open.isEmpty else { return nil }
        let titles = open.map(\.title)
        let shown = titles.prefix(3).joined(separator: ", ")
        let body = titles.count > 3 ? "\(shown), +\(titles.count - 3) more" : shown
        let title = open.count == 1 ? "1 thing still open" : "\(open.count) things still open"
        return (title, body)
    }

    /// Delivery times for the next few evenings, soonest first.
    static func upcomingDeliveries(after now: Date = .now) -> [Date] {
        let calendar = Calendar.current
        return (0...daysAhead).compactMap { offset -> Date? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else { return nil }
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)
        }
        .filter { $0 > now }
    }

    /// Notification requests for the evenings that will have something open.
    static func requests(using context: ModelContext, now: Date = .now) -> [UNNotificationRequest] {
        guard isEnabled else { return [] }
        let items = (try? context.fetch(FetchDescriptor<JotItem>())) ?? []

        return upcomingDeliveries(after: now).compactMap { delivery in
            guard let text = content(at: delivery, items: items) else { return nil }
            let content = UNMutableNotificationContent()
            content.title = text.title
            content.body = text.body
            content.sound = .default
            content.categoryIdentifier = categoryID
            content.threadIdentifier = "evening"

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: delivery)
            return UNNotificationRequest(
                identifier: identifierPrefix + delivery.formatted(.iso8601.year().month().day()),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
        }
    }

    /// The notification's button: move everything still open to tomorrow.
    static func moveStillOpenToTomorrow(in context: ModelContext, now: Date = .now) {
        let items = (try? context.fetch(FetchDescriptor<JotItem>())) ?? []
        ItemActions.moveToTomorrow(stillOpen(at: now, items: items), in: context, now: now)
    }
}
