import SwiftData
import SwiftUI
import UserNotifications

@main
struct JotApp: App {
    @State private var capture: CaptureController = {
        #if DEBUG
        if DemoCapture.isRequested { return DemoCapture.makeController() }
        #endif
        return CaptureController()
    }()
    @State private var calendar = CalendarService()
    private let notificationPresenter = NotificationPresenter()

    init() {
        UNUserNotificationCenter.current().delegate = notificationPresenter
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(capture)
                .environment(calendar)
        }
        .modelContainer(for: JotItem.self)
    }
}
