import AppIntents
import SwiftUI
import WidgetKit

/// A Control Center control that starts a hands-free recording. The same
/// control can be assigned to the Action Button (Settings › Action Button ›
/// Controls › Jot).
struct RecordControl: ControlWidget {
    static let kind = "com.jamescronin.Jot.RecordControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: StartRecordingIntent()) {
                Label("Jot", systemImage: "mic.fill")
            }
            .tint(Color.jotAccent)
        }
        .displayName("Record with Jot")
        .description("Start capturing a thought.")
    }
}
