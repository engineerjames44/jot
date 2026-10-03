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

        // Follow-ups to dinner, so the detail screen shows them.
        if let dinner = items.first(where: { $0.title == "Dinner with Sam" }) {
            items.first { $0.title.hasPrefix("Sam recommended") }?.parentID = dinner.id
            let photos = JotItem(kind: .reminder, title: "Send Sam the trip photos", dueDate: at(10, dayOffset: 1),
                                 transcript: "remind me to send Sam the trip photos tomorrow morning")
            photos.parentID = dinner.id
            context.insert(photos)
        }
        try? context.save()
    }

    /// Sample change notes for the Develop tab, enough to span two PDF pages.
    @MainActor
    static func seedDevNotesIfEmpty(_ context: ModelContext) {
        guard isRequested, (try? context.fetchCount(FetchDescriptor<DevNote>())) == 0 else { return }
        let version = Bundle.main.jotVersion
        let samples: [(String, DevNote.Category, String, Bool)] = [
            ("The orb covers the last card in Inbox when I scroll to the bottom. Needs more bottom padding.", .bug, "Inbox", false),
            ("Overdue items from yesterday show only a time, so 2 PM yesterday looks like it's after 8 AM today. Show the day.", .bug, "Today", false),
            ("Swiping to snooze feels slow, maybe snooze straight to tomorrow on a long swipe.", .change, "Inbox", false),
            ("Make the confirmation card stay a bit longer when it's a reminder with a time, I want to check the time it picked.", .change, "Today", false),
            ("Search should also find things by date, like typing Thursday.", .idea, "Inbox", false),
            ("Let me record a note to someone else and have it drafted as a message.", .idea, "Today", false),
            ("The thinking shimmer is too subtle in light mode.", .bug, "Today", false),
            ("Add a weekly review on Sunday evening with everything done this week.", .idea, "Settings", false),
            ("Group tasks by project when I say a project name.", .idea, "Inbox", false),
            ("Haptic on completing a task could be a bit stronger.", .change, "Today", false),
            ("Calendar events should open in the Calendar app when tapped.", .change, "Today", false),
            ("Transcription sometimes splits names, like Dish oom instead of Dishoom. Maybe let me add custom words.", .bug, "Today", false),
            ("Onboarding page 2 words wrap awkwardly.", .bug, "Onboarding", true),
            ("Rename the Develop tab to something friendlier if I ever ship it.", .idea, "Develop", true),
        ]
        for (index, sample) in samples.enumerated() {
            let note = DevNote(
                text: sample.0,
                category: sample.1,
                screen: sample.2,
                appVersion: version,
                createdAt: .now.addingTimeInterval(Double(index - samples.count) * 3600)
            )
            note.isDone = sample.3
            context.insert(note)
        }
        try? context.save()
    }
}
#endif
