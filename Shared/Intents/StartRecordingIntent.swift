import AppIntents
import Foundation

/// Opens Jot and starts recording hands-free; run it again (or tap the orb)
/// to finish. Powers the Control Center control and the Action Button.
struct StartRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Record with Jot"
    static let description = IntentDescription(
        "Opens Jot and starts listening. Stops by itself when you pause, or run it again to finish."
    )
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        await CaptureCommands.toggleRecording?()
        return .result()
    }
}

/// How shared intents reach the app's capture pipeline. The app installs the
/// handler at launch; in the widget extension it stays nil, and intents that
/// open the app run in the app's process anyway.
@MainActor
enum CaptureCommands {
    static var toggleRecording: (() async -> Void)?
}
