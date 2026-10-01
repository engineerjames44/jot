#if DEBUG
import Foundation
import SwiftData

/// Fills an empty store with a realistic day, for designing and testing UI.
/// Enable with the launch argument `-JotSampleData YES` (Debug builds only).
enum SampleData {
    static var isRequested: Bool {
        UserDefaults.standard.bool(forKey: "JotSampleData")
    }

    @MainActor
    static func seedIfEmpty(_ context: ModelContext) {
        guard isRequested, (try? context.fetchCount(FetchDescriptor<JotItem>())) == 0 else { return }

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        func at(_ hour: Int, _ minute: Int = 0, dayOffset: Int = 0) -> Date {
            let day = cal.date(byAdding: .day, value: dayOffset, to: today) ?? today
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        let items = [
            JotItem(kind: .event, title: "Standup with design", details: "Bring the new timeline mocks",
                    dueDate: at(9, 30), transcript: "standup with design at nine thirty, bring the new timeline mocks"),
            JotItem(kind: .reminder, title: "Take vitamins", dueDate: at(8), recurrence: .daily,
                    transcript: "remind me to take my vitamins every morning at eight"),
            JotItem(kind: .task, title: "Send invoice to Northwind", details: "October retainer",
                    dueDate: at(12), transcript: "I need to send the invoice to Northwind by noon, it's the October retainer"),
            JotItem(kind: .reminder, title: "Call the dentist", dueDate: at(14),
                    transcript: "remind me to call the dentist at two"),
            JotItem(kind: .event, title: "Dinner with Sam", details: "Dishoom, Shoreditch",
                    dueDate: at(19, 30), transcript: "dinner with Sam at Dishoom Shoreditch at seven thirty"),
            JotItem(kind: .task, title: "Book flights for December",
                    transcript: "book flights for December"),
            JotItem(kind: .task, title: "Return the library books",
                    transcript: "return the library books"),
            JotItem(kind: .note, title: "App idea: voice-first grocery list",
                    details: "Group items by aisle automatically.",
                    transcript: "app idea, a voice first grocery list that groups items by aisle automatically",
                    createdAt: .now.addingTimeInterval(-40 * 60)),
            JotItem(kind: .note, title: "Sam recommended 'Piranesi'",
                    transcript: "Sam recommended the book Piranesi",
                    createdAt: .now.addingTimeInterval(-5 * 3600)),
            JotItem(kind: .reminder, title: "Renew passport", dueDate: at(10, dayOffset: 3),
                    transcript: "remind me on Saturday at ten to renew my passport"),
        ]
        items.forEach(context.insert)
        try? context.save()
    }
}
#endif
