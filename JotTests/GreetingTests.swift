import Foundation
import Testing
@testable import Jot

/// The Today header and the morning brief greet by first name when there is one.
struct GreetingTests {
    private func at(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now)!
    }

    @Test func greetsByFirstName() {
        #expect(UserProfile.greeting(at: at(hour: 8), name: "James") == "Good morning, James")
        #expect(UserProfile.greeting(at: at(hour: 14), name: "  James Cronin ") == "Good afternoon, James")
        #expect(UserProfile.greeting(at: at(hour: 19), name: "James") == "Good evening, James")
        #expect(UserProfile.greeting(at: at(hour: 1), name: "James") == "Still up, James?")
    }

    @Test func withoutANameItStillGreets() {
        #expect(UserProfile.greeting(at: at(hour: 8), name: "") == "Good morning")
        #expect(UserProfile.greeting(at: at(hour: 8), name: "   ") == "Good morning")
        #expect(UserProfile.greeting(at: at(hour: 23), name: "") == "Hello, night owl")
    }

    @MainActor @Test func briefTitleGreetsOrNamesTheDay() {
        let morning = at(hour: 8)
        let weekday = morning.formatted(.dateTime.weekday(.wide))
        #expect(MorningBrief.summary(for: morning, items: [], events: [], name: "James").title == "Good morning, James")
        #expect(MorningBrief.summary(for: morning, items: [], events: [], name: "").title == "Your \(weekday)")
    }
}
