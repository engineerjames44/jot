import Foundation
import Testing
@testable import Jot

@MainActor
struct RecurrenceTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string)!
    }

    @Test func oneOffReturnsItsDueDate() {
        let item = JotItem(kind: .reminder, title: "x", dueDate: date("2026-10-01T09:00:00Z"))
        #expect(item.nextOccurrence(onOrAfter: date("2026-10-03T00:00:00Z"), calendar: calendar) == date("2026-10-01T09:00:00Z"))
    }

    @Test func dailyRollsForwardPastNow() {
        let item = JotItem(kind: .reminder, title: "x", dueDate: date("2026-10-01T09:00:00Z"), recurrence: .daily)
        #expect(item.nextOccurrence(onOrAfter: date("2026-10-03T12:00:00Z"), calendar: calendar) == date("2026-10-04T09:00:00Z"))
    }

    @Test func futureAnchorIsUnchanged() {
        let item = JotItem(kind: .reminder, title: "x", dueDate: date("2026-10-20T09:00:00Z"), recurrence: .weekly)
        #expect(item.nextOccurrence(onOrAfter: date("2026-10-03T12:00:00Z"), calendar: calendar) == date("2026-10-20T09:00:00Z"))
    }

    @Test func completingRecurringRollsForwardInsteadOfCompleting() {
        let item = JotItem(kind: .reminder, title: "x", dueDate: date("2026-10-01T09:00:00Z"), recurrence: .daily)
        item.toggleCompleted(now: date("2026-10-03T12:00:00Z"))
        #expect(!item.isCompleted)
        #expect(item.dueDate.map { $0 > date("2026-10-03T12:00:00Z") } == true)
    }

    @Test func completingOneOffMarksDone() {
        let item = JotItem(kind: .task, title: "x", dueDate: date("2026-10-01T09:00:00Z"))
        item.toggleCompleted()
        #expect(item.isCompleted)
    }
}
