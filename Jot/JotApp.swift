import SwiftData
import SwiftUI
import UserNotifications

@main
struct JotApp: App {
    @State private var capture: CaptureController
    @State private var calendar = CalendarService()
    @State private var device: JotDevice
    private let notificationPresenter = NotificationPresenter()

    init() {
        let capture: CaptureController = {
            #if DEBUG
            if DemoCapture.isRequested { return DemoCapture.makeController() }
            #endif
            return CaptureController()
        }()
        _capture = State(initialValue: capture)
        _device = State(initialValue: JotDevice(capture: capture))

        UNUserNotificationCenter.current().delegate = notificationPresenter
        UNUserNotificationCenter.current().setNotificationCategories([NotificationPresenter.reminderCategory, EveningNudge.category])

        // The Action Button, Control Center, and Siri reach the pipeline through here.
        CaptureCommands.toggleRecording = {
            capture.toggleHandsFree(into: SharedStore.container.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if SharedStore.canWrite {
                    RootView()
                } else {
                    StoreUnavailableView()
                }
            }
            .environment(capture)
            .environment(calendar)
            .environment(device)
            .onOpenURL { url in
                switch JotLink(url: url) {
                case .record:
                    capture.toggleHandsFree(into: SharedStore.container.mainContext)
                case .item(let id):
                    AppRouter.shared.itemToOpen = id
                case nil:
                    break
                }
            }
        }
        .modelContainer(SharedStore.container)
        .backgroundTask(.appRefresh(MorningBrief.taskIdentifier)) {
            await MorningBrief.handleBackgroundRefresh()
        }
    }
}
