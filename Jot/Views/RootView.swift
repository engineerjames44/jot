import SwiftData
import SwiftUI

struct RootView: View {
    enum Screen: Hashable { case today, inbox, settings }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(CalendarService.self) private var calendar
    @Environment(CaptureController.self) private var capture
    @Namespace private var captureNamespace
    @State private var screen: Screen = .today

    var body: some View {
        @Bindable var capture = capture

        TabView(selection: $screen) {
            Tab("Today", systemImage: "sun.max.fill", value: .today) {
                TodayView()
                    .environment(\.isActiveTab, screen == .today)
            }
            Tab("Inbox", systemImage: "tray.full.fill", value: .inbox) {
                InboxView()
                    .environment(\.isActiveTab, screen == .inbox)
            }
            Tab("Settings", systemImage: "gearshape.fill", value: .settings) {
                SettingsView()
                    .environment(\.isActiveTab, screen == .settings)
            }
        }
        .environment(\.captureNamespace, captureNamespace)
        .tint(Color.jotAccent)
        .sensoryFeedback(trigger: capture.feedbackTick) { _, _ in capture.feedback.sensory }
        .sheet(item: $capture.editingItem) { item in
            NavigationStack {
                ItemDetailView(item: item)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { capture.editingItem = nil }
                        }
                    }
            }
        }
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
