#if canImport(ActivityKit)
import ActivityKit
import Foundation

/// The Live Activity shown on the Lock Screen and in the Dynamic Island
/// while Jot is recording and while it's working out what you said.
struct CaptureActivityAttributes: ActivityAttributes {
    enum Phase: String, Codable, Hashable {
        case recording, thinking, saved, failed
    }

    struct ContentState: Codable, Hashable {
        var phase: Phase
        var startedAt: Date
        /// Words so far, or the final transcript.
        var transcript: String
        /// Set once saved: the item's kind (raw value), title, and short date.
        var resultKind: String?
        var resultTitle: String?
        var resultWhen: String?
        /// Set when something went wrong.
        var message: String?
    }
}
#endif
