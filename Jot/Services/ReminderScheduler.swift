import Foundation
import SwiftData
import UserNotifications

/// Keeps local notifications in sync with Jot's reminders.
///
/// iOS keeps at most 64 pending notifications per app. Morning briefs get the
/// slots they need, and reminders fill the rest, soonest first. Re-run on launch,
/// on returning to the foreground, whenever items change, and before each brief.
@MainActor
enum ReminderScheduler {
    static let pendingLimit = 64

    /// The refill in flight, if any. Refills are called from many places at once
    /// (launch, foreground, every edit); running two together could re-add a
    /// notification for an item that was just completed or deleted.
    private static var running: Task<Void, Never>?
    private static var needsRerun = false

    /// Re-syncs notifications. Calls made while a refill is running wait for it
    /// and trigger one more pass, so the last call always sees the latest data.
    static func refill(using context: ModelContext, now: Date = .now) async {
        if let running {
            needsRerun = true
            await running.value
            return
        }
        let task = Task { @MainActor in
            var date = now
            repeat {
                needsRerun = false
                await performRefill(using: context, now: date)
                date = .now
            } while needsRerun
        }
        running = task
        await task.value
        running = nil
    }

    /// What a reminder notification needs, copied out before any `await` so a
    /// deleted item is never read afterwards.
    private struct Pending {
        let id: String
        let title: String
        let body: String
        let fireDate: Date
        let recurrence: Recurrence?
        let isEvent: Bool
    }

    private static func performRefill(using context: ModelContext, now: Date) async {
        let center = UNUserNotificationCenter.current()

        // Events alert at their start time too; before, they never alerted at all.
        let reminderKind = ItemKind.reminder.rawValue
        let eventKind = ItemKind.event.rawValue
        let descriptor = FetchDescriptor<JotItem>(
            predicate: #Predicate {
                ($0.kindRaw == reminderKind || $0.kindRaw == eventKind) && !$0.isCompleted && $0.dueDate != nil
            }
        )
        let open = (try? context.fetch(descriptor)) ?? []

        let reminders = open
            .compactMap { item -> (JotItem, Date)? in
                guard let next = item.nextOccurrence(onOrAfter: now), next > now else { return nil }
                return (item, next)
            }
            .sorted { $0.1 < $1.1 }

        let briefs = MorningBrief.requests(using: context, now: now)
        let upcoming = reminders.prefix(pendingLimit - briefs.count).map { item, fireDate in
            Pending(
                id: item.id.uuidString,
                title: item.title,
                body: item.details,
                fireDate: fireDate,
                recurrence: item.recurrence,
                isEvent: item.kind == .event
            )
        }

        // Everything except a brief preview the user just asked for.
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0 != MorningBrief.previewIdentifier }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        // Don't ask before onboarding has explained why.
        let mayPrompt = UserDefaults.standard.bool(forKey: "JotHasOnboarded")
        MorningBrief.scheduleBackgroundRefresh(now: now)
        guard !(upcoming.isEmpty && briefs.isEmpty), await ensureAuthorized(center, mayPrompt: mayPrompt) else { return }

        for brief in briefs {
            try? await center.add(brief)
        }

        for reminder in upcoming {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.userInfo = ["itemID": reminder.id]
            // Done and Snooze make sense for reminders; an event just opens.
            if !reminder.isEvent {
                content.categoryIdentifier = NotificationPresenter.reminderCategoryID
            }

            let request = UNNotificationRequest(
                identifier: reminder.id,
                content: content,
                trigger: trigger(for: reminder.fireDate, recurrence: reminder.recurrence, now: now)
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

    static func trigger(for date: Date, recurrence: Recurrence?, now: Date = .now) -> UNCalendarNotificationTrigger {
        let calendar = Calendar.current
        let once: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute]
        let repeating: Set<Calendar.Component>? = switch recurrence {
        case nil: nil
        case .daily: [.hour, .minute]
        case .weekly: [.weekday, .hour, .minute]
        case .monthly: [.day, .hour, .minute]
        case .yearly: [.month, .day, .hour, .minute]
        }
        guard let repeating else {
            return UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents(once, from: date), repeats: false)
        }
        // A repeating trigger fires at the next match after now, which can be
        // before the first occurrence ("every Monday, starting the 20th"). Until
        // then, schedule the first one alone; a later refill switches to repeating.
        let matching = calendar.dateComponents(repeating, from: date)
        if let nextMatch = calendar.nextDate(after: now, matching: matching, matchingPolicy: .nextTime),
           nextMatch < date.addingTimeInterval(-60) {
            return UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents(once, from: date), repeats: false)
        }
        return UNCalendarNotificationTrigger(dateMatching: matching, repeats: true)
    }
}

/// Shows reminder banners even while Jot is open, and handles taps and the
/// Done and Snooze buttons on them.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let doneAction = "jot.done"
    static let snoozeAction = "jot.snooze"
    static let reminderCategoryID = "jot.reminder"

    /// Built on demand: `UNNotificationCategory` isn't Sendable, so it can't be a stored static.
    static var reminderCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: reminderCategoryID,
            actions: [
                UNNotificationAction(identifier: doneAction, title: "Done", options: [],
                                     icon: UNNotificationActionIcon(systemImageName: "checkmark")),
                UNNotificationAction(identifier: snoozeAction, title: "Snooze 1 hour", options: [],
                                     icon: UNNotificationActionIcon(systemImageName: "clock")),
            ],
            intentIdentifiers: []
        )
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let raw = response.notification.request.content.userInfo["itemID"] as? String,
              let id = UUID(uuidString: raw)
        else { return }
        let action = response.actionIdentifier
        await MainActor.run {
            let context = SharedStore.container.mainContext
            guard SharedStore.canWrite,
                  let item = try? context.fetch(FetchDescriptor<JotItem>(predicate: #Predicate { $0.id == id })).first
            else { return }
            switch action {
            case Self.doneAction:
                if !item.isCompleted { ItemActions.toggleComplete(item, in: context) }
            case Self.snoozeAction:
                ItemActions.snooze(item, .oneHour, in: context)
            default:
                AppRouter.shared.itemToOpen = id
            }
        }
    }
}
