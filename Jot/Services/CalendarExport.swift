import EventKit
import EventKitUI
import SwiftUI

/// Sends a Jot item to Apple's Calendar or Reminders.
///
/// Events go through the system's own add-event screen, so the person picks the
/// calendar and confirms, and Jot needs no calendar permission to write. Reminders
/// have no such screen, so adding one asks for Reminders access once.
@MainActor
enum CalendarExport {
    static func canAddToCalendar(_ item: JotItem) -> Bool {
        item.kind == .event && item.dueDate != nil
    }

    static func canAddToReminders(_ item: JotItem) -> Bool {
        (item.kind == .reminder || item.kind == .task) && !item.isCompleted
    }

    /// A one-hour event at the item's time, repeating like the item.
    static func eventDraft(for item: JotItem, in store: EKEventStore) -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = item.title
        event.notes = item.details.isEmpty ? nil : item.details
        if let start = item.dueDate {
            event.startDate = start
            event.endDate = start.addingTimeInterval(60 * 60)
        }
        if let rule = recurrenceRule(item.recurrence) { event.recurrenceRules = [rule] }
        return event
    }

    enum ReminderError: LocalizedError {
        case notAllowed, noList

        var errorDescription: String? {
            switch self {
            case .notAllowed: "Jot needs access to Reminders to add this. You can turn it on in the Settings app."
            case .noList: "There's no Reminders list to add this to. Make one in the Reminders app, then try again."
            }
        }
    }

    /// Adds the item to the default Reminders list, with an alert at its time.
    static func addToReminders(_ item: JotItem) async throws {
        let store = EKEventStore()
        guard (try? await store.requestFullAccessToReminders()) == true else { throw ReminderError.notAllowed }
        guard let list = store.defaultCalendarForNewReminders() else { throw ReminderError.noList }

        let reminder = EKReminder(eventStore: store)
        reminder.calendar = list
        reminder.title = item.title
        reminder.notes = item.details.isEmpty ? nil : item.details
        if let due = item.dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: due
            )
            reminder.addAlarm(EKAlarm(absoluteDate: due))
        }
        if let rule = recurrenceRule(item.recurrence) { reminder.recurrenceRules = [rule] }
        try store.save(reminder, commit: true)
    }

    private static func recurrenceRule(_ recurrence: Recurrence?) -> EKRecurrenceRule? {
        let frequency: EKRecurrenceFrequency? = switch recurrence {
        case nil: nil
        case .daily: .daily
        case .weekly: .weekly
        case .monthly: .monthly
        case .yearly: .yearly
        }
        return frequency.map { EKRecurrenceRule(recurrenceWith: $0, interval: 1, end: nil) }
    }
}

/// The system's add-event screen, prefilled from an item.
struct EventEditor: UIViewControllerRepresentable {
    let item: JotItem
    /// True when the event was saved, false when cancelled.
    var onFinish: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = CalendarExport.eventDraft(for: item, in: store)
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onFinish: (Bool) -> Void
        init(onFinish: @escaping (Bool) -> Void) { self.onFinish = onFinish }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onFinish(action == .saved)
        }
    }
}
