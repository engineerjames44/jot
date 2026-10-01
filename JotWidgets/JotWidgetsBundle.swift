import SwiftUI
import WidgetKit

@main
struct JotWidgetsBundle: WidgetBundle {
    var body: some Widget {
        UpcomingWidget()
        RecordWidget()
        RecordControl()
        CaptureLiveActivity()
    }
}

/// Opens Jot and starts a hands-free recording.
let recordURL = URL(string: "jot://record")!
