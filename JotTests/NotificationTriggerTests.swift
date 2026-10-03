import Foundation
import Testing
import UserNotifications
@testable import Jot

/// Repeating triggers fire at the next calendar match after now, which can be
/// earlier than an item's first occurrence. The scheduler must not fire early.
@MainActor
struct NotificationTriggerTests {
    private let calendar = Calendar.current

    private func at(daysFromNow days: Int, hour: Int, from now: Date) -> Date {
        let day = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now))!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    @Test func oneOffDoesNotRepeat() {
        let now = Date.now
        let trigger = ReminderScheduler.trigger(for: at(daysFromNow: 1, hour: 9, from: now), recurrence: nil, now: now)
        #expect(!trigger.repeats)
    }

    @Test func dailyStartingTomorrowRepeats() {
        // At noon, the next 9:00 match is tomorrow: the first occurrence itself.
        let noon = at(daysFromNow: 0, hour: 12, from: .now)
        let trigger = ReminderScheduler.trigger(for: at(daysFromNow: 1, hour: 9, from: noon), recurrence: .daily, now: noon)
        #expect(trigger.repeats)
    }

    @Test func dailyStartingInThreeDaysWaitsForFirstOccurrence() {
        let noon = at(daysFromNow: 0, hour: 12, from: .now)
        let trigger = ReminderScheduler.trigger(for: at(daysFromNow: 3, hour: 9, from: noon), recurrence: .daily, now: noon)
        #expect(!trigger.repeats)
    }

    @Test func weeklyStartingInTwoWeeksSchedulesFirstOccurrenceOnly() throws {
        let now = Date.now
        let first = at(daysFromNow: 14, hour: 9, from: now)
        let trigger = ReminderScheduler.trigger(for: first, recurrence: .weekly, now: now)
        #expect(!trigger.repeats)
        let next = try #require(trigger.nextTriggerDate())
        #expect(abs(next.timeIntervalSince(first)) < 60)
    }

    @Test func weeklyAlreadyStartedRepeats() {
        let now = Date.now
        let past = at(daysFromNow: -7, hour: 9, from: now)
        let nextOccurrence = calendar.date(byAdding: .day, value: 7, to: past)!
        let trigger = ReminderScheduler.trigger(for: nextOccurrence, recurrence: .weekly, now: now)
        #expect(trigger.repeats)
    }
}
