import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(CalendarService.self) private var calendar

    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max") {
                TodayView()
            }
            Tab("Inbox", systemImage: "tray") {
                InboxView()
            }
            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
        }
        .tint(Color.jotAccent)
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            #if DEBUG
            SampleData.seedIfEmpty(modelContext)
            #endif
            // Launch and every return to the foreground: top the notification
            // queue back up to 64 and pick up calendar changes.
            calendar.reload()
            Task { await ReminderScheduler.refill(using: modelContext) }
        }
    }
}
