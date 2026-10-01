import EventKit
import Foundation
import Observation

/// A calendar event copied out of EventKit so views don't hold `EKEvent`s.
struct CalendarEvent: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
    let calendarTitle: String
}

/// Reads the user's existing calendars. Jot never writes to them.
@MainActor
@Observable
final class CalendarService {
    private let store = EKEventStore()
    private(set) var todaysEvents: [CalendarEvent] = []
    private(set) var authorization = EKEventStore.authorizationStatus(for: .event)

    @ObservationIgnored private var changeObserver: (any NSObjectProtocol)?

    init() {
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    var hasAccess: Bool { authorization == .fullAccess }

    func requestAccess() async {
        _ = try? await store.requestFullAccessToEvents()
        authorization = EKEventStore.authorizationStatus(for: .event)
        reload()
    }

    func reload(for day: Date = .now) {
        authorization = EKEventStore.authorizationStatus(for: .event)
        guard hasAccess else {
            todaysEvents = []
            return
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        todaysEvents = store.events(matching: predicate)
            .map { event in
                CalendarEvent(
                    id: event.calendarItemIdentifier + "@" + event.startDate.timeIntervalSince1970.description,
                    title: event.title ?? "Untitled",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    location: event.location,
                    calendarTitle: event.calendar.title
                )
            }
            .sorted { $0.start < $1.start }
    }
}
