import Foundation
import SwiftData
import UserNotifications

/// Keeps local notifications in sync with Jot's reminders.
///
/// iOS keeps at most 64 pending notifications per app, so this schedules only
/// the 64 soonest and is re-run on launch, on returning to the foreground, and
/// whenever reminders change.
@MainActor
enum ReminderScheduler {
    static let pendingLimit = 64

    static func refill(using context: ModelContext, now: Date = .now) async {
        let center = UNUserNotificationCenter.current()

        let reminderKind = ItemKind.reminder.rawValue
        let descriptor = FetchDescriptor<JotItem>(
            predicate: #Predicate { $0.kindRaw == reminderKind && !$0.isCompleted && $0.dueDate != nil }
        )
        let reminders = (try? context.fetch(descriptor)) ?? []

        let upcoming = reminders
            .compactMap { item -> (JotItem, Date)? in
                guard let next = item.nextOccurrence(onOrAfter: now), next > now else { return nil }
                return (item, next)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(pendingLimit)

        center.removeAllPendingNotificationRequests()
        // Don't ask before onboarding has explained why.
        let mayPrompt = UserDefaults.standard.bool(forKey: "JotHasOnboarded")
        guard !upcoming.isEmpty, await ensureAuthorized(center, mayPrompt: mayPrompt) else { return }

        for (item, fireDate) in upcoming {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.details
            content.sound = .default
            content.userInfo = ["itemID": item.id.uuidString]

            let request = UNNotificationRequest(
                identifier: item.id.uuidString,
                content: content,
                trigger: trigger(for: fireDate, recurrence: item.recurrence)
            )
            try? await center.add(request)
        }
    }

    /// Asks for permission the first time there's something to schedule.
    static func ensureAuthorized(
        _ center: UNUserNotificationCenter = .current(),
        mayPrompt: Bool = true
    ) async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            guard mayPrompt else { return false }
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    private static func trigger(for date: Date, recurrence: Recurrence?) -> UNCalendarNotificationTrigger {
        let calendar = Calendar.current
        let components: Set<Calendar.Component> = switch recurrence {
        case nil: [.year, .month, .day, .hour, .minute]
        case .daily: [.hour, .minute]
        case .weekly: [.weekday, .hour, .minute]
        case .monthly: [.day, .hour, .minute]
        case .yearly: [.month, .day, .hour, .minute]
        }
        return UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents(components, from: date),
            repeats: recurrence != nil
        )
    }
}

/// Shows reminder banners even while Jot is open.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
