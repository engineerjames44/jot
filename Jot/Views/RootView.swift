import SwiftData
import SwiftUI

struct RootView: View {
    enum Screen: Hashable {
        case today, inbox, develop, settings

        var name: String {
            switch self {
            case .today: "Today"
            case .inbox: "Inbox"
            case .develop: "Develop"
            case .settings: "Settings"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(CalendarService.self) private var calendar
    @Environment(CaptureController.self) private var capture
    @Namespace private var captureNamespace
    @State private var screen: Screen = .today
    @AppStorage("JotHasOnboarded") private var hasOnboarded = false
    @AppStorage(DevMode.enabledKey) private var devModeEnabled = DevMode.defaultEnabled
    @State private var quickNoteScreen: String?
    @State private var orbLocator = OrbLocator()
    @State private var showingLaunch = true

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
            if devModeEnabled {
                Tab("Develop", systemImage: "hammer.fill", value: .develop) {
                    DevelopView()
                        .environment(\.isActiveTab, screen == .develop)
                }
            }
            Tab("Settings", systemImage: "gearshape.fill", value: .settings) {
                SettingsView()
                    .environment(\.isActiveTab, screen == .settings)
            }
        }
        .environment(\.captureNamespace, captureNamespace)
        .environment(orbLocator)
        .overlay {
            if showingLaunch {
                LaunchHandoff(target: hasOnboarded ? orbLocator.frame : nil) {
                    showingLaunch = false
                }
            }
        }
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
        .onShake {
            guard devModeEnabled, quickNoteScreen == nil, !capture.phase.isBusy else { return }
            quickNoteScreen = screen.name
        }
        .sheet(item: Binding(
            get: { quickNoteScreen.map(QuickNoteTarget.init) },
            set: { quickNoteScreen = $0?.screen }
        )) { target in
            QuickDevNoteSheet(screen: target.screen)
        }
        .onChange(of: devModeEnabled) { _, enabled in
            if !enabled, screen == .develop { screen = .settings }
        }
        .fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { hasOnboarded = !$0 })) {
            OnboardingView { hasOnboarded = true }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            #if DEBUG
            SampleData.seedIfEmpty(modelContext)
            SampleData.seedDevNotesIfEmpty(modelContext)
            #endif
            // Launch and every return to the foreground: top the notification
            // queue back up to 64 and pick up calendar changes.
            calendar.reload()
            Task { await ReminderScheduler.refill(using: modelContext) }
        }
    }
}

private struct QuickNoteTarget: Identifiable {
    let screen: String
    var id: String { screen }
}

/// The Develop tab and shake-to-note: on by default in Debug builds,
/// off in Release (TestFlight/App Store) until turned on in Settings.
enum DevMode {
    static let enabledKey = "JotDevModeEnabled"
    #if DEBUG
    static let defaultEnabled = true
    #else
    static let defaultEnabled = false
    #endif
}
