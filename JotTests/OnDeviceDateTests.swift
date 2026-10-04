import Foundation
import Testing
@testable import Jot

/// The on-device model only extracts what was said; these check the date maths
/// that turns it into a time. "Now" is Saturday 3 October 2026, 3:49 PM in Boston.
struct OnDeviceDateTests {
    typealias When = OnDeviceClassifier.Sorted.When

    private let boston = TimeZone(identifier: "America/New_York")!
    private var now: Date { date(2026, 10, 3, 15, 49) }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = boston
        return calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    private func when(_ reference: When.Reference, minutes: Int = 0, weekday: When.Day = .monday,
                      month: Int = 0, day: Int = 0, hour: Int = -1, minute: Int = 0) -> When {
        When(reference: reference, minutesFromNow: minutes, weekday: weekday,
             month: month, day: day, hour: hour, minute: minute)
    }

    private func resolve(_ w: When, _ said: String = "") -> Date? {
        OnDeviceClassifier.resolve(w, transcript: said, now: now, timeZone: boston)
    }

    @Test func weekdayMeansTheNextOne() {
        #expect(resolve(when(.weekday, weekday: .thursday, hour: 2), "call the dentist on Thursday at two") == date(2026, 10, 8, 14, 0))
    }

    @Test func sameWeekdayMeansNextWeek() {
        #expect(resolve(when(.weekday, weekday: .saturday, hour: 10), "Saturday at 10 am") == date(2026, 10, 10, 10, 0))
    }

    @Test func minutesFromNow() {
        #expect(resolve(when(.inMinutes, minutes: 20)) == now.addingTimeInterval(20 * 60))
    }

    @Test func dayWithoutATimeIsNineAM() {
        #expect(resolve(when(.tomorrow)) == date(2026, 10, 4, 9, 0))
    }

    @Test func morningKeepsTheMorningHour() {
        #expect(resolve(when(.tomorrow, hour: 7, minute: 30), "tomorrow at 7:30 in the morning") == date(2026, 10, 4, 7, 30))
    }

    @Test func aPassedTimeTodayMeansTomorrow() {
        #expect(resolve(when(.today, hour: 9), "at nine") == date(2026, 10, 4, 9, 0))
    }

    @Test func calendarDateThisYearOrNext() {
        #expect(resolve(when(.date, month: 10, day: 14, hour: 15)) == date(2026, 10, 14, 15, 0))
        #expect(resolve(when(.date, month: 2, day: 1)) == date(2027, 2, 1, 9, 0))
    }

    @Test func noTimeMeansNoDate() {
        #expect(resolve(when(.none)) == nil)
    }
}
