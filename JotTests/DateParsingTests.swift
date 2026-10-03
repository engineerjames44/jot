import Foundation
import Testing
@testable import Jot

/// Claude returns `due_datetime` in a few shapes; all of them must land on the right instant.
struct DateParsingTests {
    private let boston = TimeZone(identifier: "America/New_York")!

    private func item(_ raw: String?) -> ClassifiedItem {
        ClassifiedItem(type: .reminder, title: "x", details: "", dueDatetime: raw, recurrence: nil)
    }

    @Test func offsetIsRespected() throws {
        let date = try #require(item("2026-10-06T10:00:00-04:00").dueDate(in: boston))
        #expect(date == ISO8601DateFormatter().date(from: "2026-10-06T14:00:00Z"))
    }

    @Test func localTimeUsesTheGivenZone() throws {
        let date = try #require(item("2026-10-06T10:00").dueDate(in: boston))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = boston
        #expect(calendar.component(.hour, from: date) == 10)
        #expect(calendar.component(.day, from: date) == 6)
    }

    @Test func dateOnlyParses() {
        #expect(item("2026-10-06").dueDate(in: boston) != nil)
    }

    @Test(arguments: [nil, "", "  ", "next tuesday"])
    func missingOrUnparseableIsNil(raw: String?) {
        #expect(item(raw).dueDate(in: boston) == nil)
    }
}
