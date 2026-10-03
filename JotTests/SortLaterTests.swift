import Foundation
import Testing
@testable import Jot

@MainActor
struct SortLaterTests {
    @Test func applyingAResultSortsTheItemInPlace() {
        let item = JotItem(kind: .note, title: "Remind me to call the dentist on Thursday at two",
                           transcript: "Remind me to call the dentist on Thursday at two")
        item.needsSorting = true
        let result = ClassifiedItem(type: .reminder, title: "Call the dentist", details: "",
                                    dueDatetime: "2026-10-08T14:00:00-04:00", recurrence: nil)
        SortLater.apply(result, to: item)
        #expect(item.kind == .reminder)
        #expect(item.title == "Call the dentist")
        #expect(item.dueDate == ISO8601DateFormatter().date(from: "2026-10-08T18:00:00Z"))
        #expect(!item.needsSorting)
    }

    @Test func emptyFieldsKeepWhatWasThere() {
        let item = JotItem(kind: .note, title: "Gift idea", details: "record player")
        SortLater.apply(ClassifiedItem(type: .note, title: "", details: "", dueDatetime: nil, recurrence: nil), to: item)
        #expect(item.title == "Gift idea")
        #expect(item.details == "record player")
    }

    @Test func claudeSortingNeedsPermission() async {
        let previous = UserDefaults.standard.object(forKey: SmartSorting.key)
        let previousEngine = UserDefaults.standard.object(forKey: SmartSorting.engineKey)
        UserDefaults.standard.set(false, forKey: SmartSorting.key)
        UserDefaults.standard.set(SmartSorting.Engine.claude.rawValue, forKey: SmartSorting.engineKey)
        defer {
            UserDefaults.standard.set(previous, forKey: SmartSorting.key)
            UserDefaults.standard.set(previousEngine, forKey: SmartSorting.engineKey)
        }
        await #expect(throws: SortingError.notAllowed) {
            try await Classifier.classify("buy milk")
        }
    }
}
