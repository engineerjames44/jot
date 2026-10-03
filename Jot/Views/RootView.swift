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
    #if DEBUG
    @AppStorage(DevMode.enabledKey) private var devModeEnabled = DevMode.defaultEnabled
    @State private var quickNoteScreen: String?
    #endif
    @State private var orbLocator = OrbLocator()
    @AppStorage(SmartSorting.key) private var smartSortingAllowed = false
    @State private var showingLaunch = true
    @State private var showingSettings = false

    var body: some View {
        @Bindable var capture = capture

        // The system tab bar is hidden: each screen draws the bottom bar, with
        // the record orb between Today and Inbox. Settings opens from your initial.
        TabView(selection: $screen) {
            Tab("Today", systemImage: "sun.max.fill", value: .today) {
                TodayView()
                    .environment(\.isActiveTab, screen == .today)
                    .toolbar(.hidden, for: .tabBar)
            }
            Tab("Inbox", systemImage: "tray.full.fill", value: .inbox) {
                InboxView()
                    .environment(\.isActiveTab, screen == .inbox)
                    .toolbar(.hidden, for: .tabBar)
            }
        }
        .environment(\.currentScreen, screen)
        .environment(\.selectScreen) { selected in screen = selected }
        .environment(\.openSettings) { showingSettings = true }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .overlay(alignment: .bottom) {
            // Above the tab bar and the record orb.
            UndoToast()
                .padding(.bottom, 150)
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
        #if DEBUG
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
        #endif
        .fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { hasOnboarded = !$0 })) {
            OnboardingView { hasOnboarded = true }
        }
        .onChange(of: AppRouter.shared.itemToOpen) { _, id in
            if id != nil { screen = .inbox }
        }
        .onChange(of: smartSortingAllowed) { _, allowed in
            // Turning sorting on sorts what was kept as notes while it was off.
            if allowed { Task { await SortLater.retryPending(in: modelContext) } }
        }
        #if DEBUG
        .onAppear {
            // -JotStartTab inbox|settings|develop: open a tab directly, for screenshots.
            switch UserDefaults.standard.string(forKey: "JotStartTab") {
            case "inbox": screen = .inbox
            case "settings": showingSettings = true
            default: break
            }
        }
        #endif
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            #if DEBUG
            SampleData.seedIfEmpty(modelContext)
            SampleData.seedDevNotesIfEmpty(modelContext)
            #endif
            // Launch and every return to the foreground: top the notification
            // queue back up to 64 and pick up calendar changes.
            calendar.reload()
            Task {
                await ReminderScheduler.refill(using: modelContext)
                await SortLater.retryPending(in: modelContext)
            }
        }
    }
}

#if DEBUG
private struct QuickNoteTarget: Identifiable {
    let screen: String
    var id: String { screen }
}

/// The Develop tab and shake-to-note. Debug builds only: they're tools for
/// building Jot, not features, and shake-to-note would take over Shake to Undo.
enum DevMode {
    static let enabledKey = "JotDevModeEnabled"
    static let defaultEnabled = true
}
#endif
