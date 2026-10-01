import Foundation
import Observation
import SwiftData

/// Drives the hold-to-record loop: record → transcribe → classify → save.
@MainActor
@Observable
final class CaptureController {
    enum Phase: Equatable {
        case idle
        case starting
        case recording(since: Date)
        case transcribing
        case classifying(transcript: String)
        case saved(title: String, kind: ItemKind)
        case failed(String)

        var isBusy: Bool {
            switch self {
            case .starting, .recording, .transcribing, .classifying: true
            default: false
            }
        }
    }

    private(set) var phase: Phase = .idle

    /// Changes on every start/stop so views can attach haptics to it.
    private(set) var recordingToggleCount = 0
    var isRecording: Bool {
        if case .recording = phase { true } else { false }
    }

    private let source: any AudioSource
    private let transcription: SpeechTranscription
    private let classifier: ClaudeClassifier

    private var isHeld = false
    private var transcriptionTask: Task<String, any Error>?
    private var resetTask: Task<Void, Never>?

    init(
        source: any AudioSource = MicAudioSource(),
        transcription: SpeechTranscription = SpeechTranscription(),
        classifier: ClaudeClassifier = ClaudeClassifier()
    ) {
        self.source = source
        self.transcription = transcription
        self.classifier = classifier
    }

    /// Call when the record button is pressed down.
    func beginCapture() {
        guard !phase.isBusy else { return }
        resetTask?.cancel()
        isHeld = true
        phase = .starting

        Task {
            do {
                let audio = try await source.start()
                let transcription = self.transcription
                transcriptionTask = Task.detached { try await transcription.transcribe(audio) }
                phase = .recording(since: .now)
                recordingToggleCount += 1
                // Released while permissions or the engine were still starting up.
                if !isHeld { finishRecording() }
            } catch {
                fail(error)
            }
        }
    }

    /// Call when the record button is released. `context` receives the new item.
    func endCapture(into context: ModelContext) {
        isHeld = false
        pendingContext = context
        if isRecording { finishRecording() }
    }

    private var pendingContext: ModelContext?

    private func finishRecording() {
        guard case .recording(let since) = phase, let context = pendingContext else { return }
        source.stop()
        recordingToggleCount += 1

        guard Date.now.timeIntervalSince(since) >= 0.4 else {
            transcriptionTask?.cancel()
            transcriptionTask = nil
            fail(message: "Hold the button while you speak.")
            return
        }

        phase = .transcribing
        let task = transcriptionTask
        transcriptionTask = nil

        Task {
            do {
                guard let transcript = try await task?.value, !transcript.isEmpty else {
                    fail(message: "Didn't catch that — try again.")
                    return
                }
                phase = .classifying(transcript: transcript)
                let result: ClassifiedItem
                do {
                    result = try await classifier.classify(transcript: transcript)
                } catch {
                    // Never lose what was said: keep it as a plain note.
                    let fallback = ClassifiedItem(type: .note, title: String(transcript.prefix(60)), details: "")
                    save(fallback, transcript: transcript, into: context)
                    fail(message: "Saved as a note. \(error.localizedDescription)")
                    return
                }
                let item = save(result, transcript: transcript, into: context)
                phase = .saved(title: item.title, kind: item.kind)
                await ReminderScheduler.refill(using: context)
                scheduleReset(after: 3)
            } catch {
                fail(error)
            }
        }
    }

    @discardableResult
    func save(_ result: ClassifiedItem, transcript: String, into context: ModelContext) -> JotItem {
        let item = JotItem(
            kind: result.type,
            title: result.title.isEmpty ? String(transcript.prefix(60)) : result.title,
            details: result.details,
            dueDate: result.dueDate(),
            recurrence: result.recurrence,
            transcript: transcript
        )
        context.insert(item)
        try? context.save()
        return item
    }

    func dismissStatus() {
        guard !phase.isBusy else { return }
        phase = .idle
    }

    private func fail(_ error: any Error) {
        if isRecording {
            source.stop()
            recordingToggleCount += 1
        }
        fail(message: error.localizedDescription)
    }

    private func fail(message: String) {
        phase = .failed(message)
        scheduleReset(after: 6)
    }

    private func scheduleReset(after seconds: Double) {
        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            if !phase.isBusy { phase = .idle }
        }
    }
}
