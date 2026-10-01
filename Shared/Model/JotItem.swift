import Foundation
import SwiftData

enum ItemKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case note, task, reminder, event

    var id: String { rawValue }

    var label: String {
        switch self {
        case .note: "Note"
        case .task: "Task"
        case .reminder: "Reminder"
        case .event: "Event"
        }
    }

    var symbol: String {
        switch self {
        case .note: "note.text"
        case .task: "checklist"
        case .reminder: "bell"
        case .event: "calendar"
        }
    }
}

enum Recurrence: String, Codable, CaseIterable, Identifiable, Sendable {
    case daily, weekly, monthly, yearly

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var calendarComponent: Calendar.Component {
        switch self {
        case .daily: .day
        case .weekly: .weekOfYear
        case .monthly: .month
        case .yearly: .year
        }
    }
}

@Model
final class JotItem {
    @Attribute(.unique) var id: UUID
    /// Stored as a raw string so it can be used in `#Predicate`.
    var kindRaw: String
    var title: String
    var details: String
    var dueDate: Date?
    var recurrenceRaw: String?
    /// The words the user actually spoke, kept for reference.
    var transcript: String
    var createdAt: Date
    var isCompleted: Bool
    /// The original recording in `AudioStore`, if one was kept.
    var audioFileName: String?

    init(
        kind: ItemKind,
        title: String,
        details: String = "",
        dueDate: Date? = nil,
        recurrence: Recurrence? = nil,
        transcript: String = "",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.title = title
        self.details = details
        self.dueDate = dueDate
        self.recurrenceRaw = recurrence?.rawValue
        self.transcript = transcript
        self.createdAt = createdAt
        self.isCompleted = false
    }

    var kind: ItemKind {
        get { ItemKind(rawValue: kindRaw) ?? .note }
        set { kindRaw = newValue.rawValue }
    }

    var recurrence: Recurrence? {
        get { recurrenceRaw.flatMap(Recurrence.init(rawValue:)) }
        set { recurrenceRaw = newValue?.rawValue }
    }

    /// The next time this item is due at or after `date`, accounting for recurrence.
    func nextOccurrence(onOrAfter date: Date = .now, calendar: Calendar = .current) -> Date? {
        guard let dueDate else { return nil }
        guard let recurrence, dueDate < date else { return dueDate }
        var next = dueDate
        // Step forward from the anchor; bounded so a bad anchor can't spin forever.
        for _ in 0..<10_000 where next < date {
            guard let stepped = calendar.date(byAdding: recurrence.calendarComponent, value: 1, to: next) else { break }
            next = stepped
        }
        return next
    }

    /// Completing a recurring item rolls it forward to its next occurrence instead.
    func toggleCompleted(now: Date = .now) {
        if !isCompleted, let recurrence, let dueDate {
            let base = max(dueDate, now)
            self.dueDate = nextOccurrence(onOrAfter: base.addingTimeInterval(1))
                ?? Calendar.current.date(byAdding: recurrence.calendarComponent, value: 1, to: dueDate)
        } else {
            isCompleted.toggle()
        }
    }
}
