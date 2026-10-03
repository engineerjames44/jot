import SwiftData
import SwiftUI
import UserNotifications

@main
struct JotApp: App {
    @State private var capture: CaptureController
    @State private var calendar = CalendarService()
    private let notificationPresenter = NotificationPresenter()

    init() {
        let capture: CaptureController = {
            #if DEBUG
            if DemoCapture.isRequested { return DemoCapture.makeController() }
            #endif
            return CaptureController()
        }()
        _capture = State(initialValue: capture)

        UNUserNotificationCenter.current().delegate = notificationPresenter

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
            .onOpenURL { url in
                // jot://record, from the widgets' record buttons.
                if url.scheme == "jot", url.host() == "record" {
                    capture.toggleHandsFree(into: SharedStore.container.mainContext)
                }
            }
        }
        .modelContainer(SharedStore.container)
        .backgroundTask(.appRefresh(MorningBrief.taskIdentifier)) {
            await MorningBrief.handleBackgroundRefresh()
        }
    }
}
