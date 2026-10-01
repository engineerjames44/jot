import ActivityKit
import Foundation

/// Keeps the capture Live Activity in step with the capture pipeline.
@MainActor
final class LiveActivityController {
    /// The ID only: `Activity` isn't `Sendable`, so each update looks it up
    /// inside its own task rather than sending a stored instance across.
    private var activityID: String?
    private var state: CaptureActivityAttributes.ContentState?
    private var lastTranscriptUpdate = Date.distantPast

    func start() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endImmediately()
        let initial = CaptureActivityAttributes.ContentState(phase: .recording, startedAt: .now, transcript: "")
        state = initial
        activityID = try? Activity.request(
            attributes: CaptureActivityAttributes(),
            content: ActivityContent(state: initial, staleDate: nil)
        ).id
    }

    /// Live words; throttled so frequent partial results don't flood ActivityKit.
    func updateTranscript(_ text: String) {
        guard var state, Date.now.timeIntervalSince(lastTranscriptUpdate) > 0.8 else { return }
        lastTranscriptUpdate = .now
        state.transcript = text
        push(state)
    }

    func thinking(transcript: String) {
        guard var state else { return }
        state.phase = .thinking
        state.transcript = transcript
        push(state)
    }

    func saved(kind: ItemKind, title: String, when: String?) {
        guard var state else { return }
        state.phase = .saved
        state.resultKind = kind.rawValue
        state.resultTitle = title
        state.resultWhen = when
        finish(with: state, after: 4)
    }

    func failed(_ message: String) {
        guard var state else { return }
        state.phase = .failed
        state.message = message
        finish(with: state, after: 3)
    }

    func endImmediately() {
        guard let activityID else { return }
        self.activityID = nil
        state = nil
        Self.withActivity(activityID) { await $0.end(nil, dismissalPolicy: .immediate) }
    }

    private func push(_ newState: CaptureActivityAttributes.ContentState) {
        state = newState
        guard let activityID else { return }
        Self.withActivity(activityID) { await $0.update(ActivityContent(state: newState, staleDate: nil)) }
    }

    private func finish(with finalState: CaptureActivityAttributes.ContentState, after seconds: TimeInterval) {
        guard let activityID else { return }
        self.activityID = nil
        state = nil
        let dismissal = Date.now.addingTimeInterval(seconds)
        Self.withActivity(activityID) {
            await $0.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .after(dismissal))
        }
    }

    private nonisolated static func withActivity(
        _ id: String,
        _ body: @escaping @Sendable (Activity<CaptureActivityAttributes>) async -> Void
    ) {
        Task.detached {
            guard let activity = Activity<CaptureActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
            await body(activity)
        }
    }
}
