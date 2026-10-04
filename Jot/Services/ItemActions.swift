import Foundation
import SwiftData
import SwiftUI
import WidgetKit

/// Quick snooze choices offered from swipe actions.
enum SnoozeOption: CaseIterable, Identifiable {
    case oneHour, tonight, tomorrow

    var id: Self { self }

    var label: String {
        switch self {
        case .oneHour: "In 1 hour"
        case .tonight: "Tonight, 8 PM"
        case .tomorrow: "Tomorrow, 9 AM"
        }
    }

    var symbol: String {
        switch self {
        case .oneHour: "clock.arrow.circlepath"
        case .tonight: "moon.stars.fill"
        case .tomorrow: "sunrise.fill"
        }
    }

    func date(from now: Date = .now, calendar: Calendar = .current) -> Date {
        switch self {
        case .oneHour:
            return now.addingTimeInterval(3600)
        case .tonight:
            return calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now
        case .tomorrow:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        }
    }

    /// "Tonight" only makes sense while there's still evening left.
    static func available(at now: Date = .now) -> [SnoozeOption] {
        let hour = Calendar.current.component(.hour, from: now)
        return allCases.filter { $0 != .tonight || hour < 19 }
    }
}

/// The actions an item supports, shared by swipe actions, menus, and the detail screen.
@MainActor
enum ItemActions {
    static func canComplete(_ item: JotItem) -> Bool {
        item.kind == .task || item.kind == .reminder
    }

    static func canSnooze(_ item: JotItem) -> Bool {
        item.kind != .note && item.recurrence == nil && !item.isCompleted
    }

    static func toggleComplete(_ item: JotItem, in context: ModelContext) {
        item.toggleCompleted()
        commit(context)
    }

    static func snooze(_ item: JotItem, _ option: SnoozeOption, in context: ModelContext) {
        item.dueDate = option.date()
        item.isCompleted = false
        commit(context)
    }

    /// Moves open items that are past due to the same time tomorrow. Repeating
    /// items are left alone: their next occurrence already comes round.
    static func moveToTomorrow(_ items: [JotItem], in context: ModelContext, now: Date = .now) {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        for item in items where canSnooze(item) {
            guard let due = item.dueDate, due < now else { continue }
            let time = calendar.dateComponents([.hour, .minute], from: due)
            item.dueDate = calendar.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: 0, of: tomorrow)
        }
        commit(context)
    }

    /// Deletes now; the item can be brought back from the Undo toast for a few
    /// seconds, after which its recording is removed too.
    static func delete(_ item: JotItem, in context: ModelContext) {
        withAnimation(.jot) { RecentlyDeleted.shared.record(item, in: context) }
        context.delete(item)
        commit(context)
    }

    /// Saves and re-syncs reminder notifications.
    static func commit(_ context: ModelContext) {
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        Task { await ReminderScheduler.refill(using: context) }
    }
}
