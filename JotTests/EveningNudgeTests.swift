import EventKit
import Foundation
import SwiftData
import Testing
@testable import Jot

/// The 8 PM check-in counts what's still open, and the calendar export drafts
/// the right event.
@MainActor
struct EveningNudgeTests {
    private func at(_ hour: Int, daysFromToday: Int = 0) -> Date {
        let day = Calendar.current.date(byAdding: .day, value: daysFromToday, to: .now)!
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    @Test func countsOnlyOpenRemindersAndTasksPastDue() {
        let overdueTask = JotItem(kind: .task, title: "Send invoice", dueDate: at(12))
        let doneReminder = JotItem(kind: .reminder, title: "Call mum", dueDate: at(9))
        doneReminder.isCompleted = true
        let laterTonight = JotItem(kind: .reminder, title: "Take bins out", dueDate: at(21))
        let event = JotItem(kind: .event, title: "Standup", dueDate: at(9))
        let note = JotItem(kind: .note, title: "Gift idea")

        let open = EveningNudge.stillOpen(at: at(20), items: [overdueTask, doneReminder, laterTonight, event, note])
        #expect(open.map(\.title) == ["Send invoice"])
    }

    @Test func nothingOpenMeansNoNudge() {
        #expect(EveningNudge.content(at: at(20), items: []) == nil)
    }

    @Test func nudgeSaysHowManyAndListsThem() throws {
        let items = (1...4).map { JotItem(kind: .task, title: "Task \($0)", dueDate: at(8 + $0)) }
        let text = try #require(EveningNudge.content(at: at(20), items: items))
        #expect(text.title == "4 things still open")
        #expect(text.body == "Task 1, Task 2, Task 3, +1 more")
    }

    @Test func calendarDraftIsAnHourAtTheItemsTime() {
        let start = at(19, daysFromToday: 1)
        let item = JotItem(kind: .event, title: "Dinner with Sam", details: "Dishoom", dueDate: start, recurrence: .weekly)
        let event = CalendarExport.eventDraft(for: item, in: EKEventStore())
        #expect(event.title == "Dinner with Sam")
        #expect(event.notes == "Dishoom")
        #expect(event.startDate == start)
        #expect(event.endDate == start.addingTimeInterval(3600))
        #expect(event.recurrenceRules?.first?.frequency == .weekly)
    }

    @Test func exportOffersTheRightApp() {
        #expect(CalendarExport.canAddToCalendar(JotItem(kind: .event, title: "Dinner", dueDate: .now)))
        #expect(!CalendarExport.canAddToCalendar(JotItem(kind: .event, title: "Someday dinner")))
        #expect(CalendarExport.canAddToReminders(JotItem(kind: .task, title: "Return books")))
        #expect(!CalendarExport.canAddToReminders(JotItem(kind: .note, title: "Idea")))
    }

    /// What the notification's Move to tomorrow button runs: open items move to
    /// the same time tomorrow; done and future items stay put.
    @Test func moveButtonMovesWhatsStillOpen() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: JotSchemaV2.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let overdue = JotItem(kind: .task, title: "Send invoice", dueDate: at(12))
        let done = JotItem(kind: .reminder, title: "Call mum", dueDate: at(9))
        done.isCompleted = true
        let later = JotItem(kind: .reminder, title: "Take bins out", dueDate: at(22))
        [overdue, done, later].forEach(context.insert)

        EveningNudge.moveStillOpenToTomorrow(in: context, now: at(20))

        #expect(overdue.dueDate == at(12, daysFromToday: 1))
        #expect(done.dueDate == at(9))
        #expect(later.dueDate == at(22))
    }
}
