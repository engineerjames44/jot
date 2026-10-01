import Foundation
import Observation
import SwiftData
import SwiftUI
import WidgetKit

/// Drives the hold-to-record loop: record → transcribe → classify → save.
@MainActor
@Observable
final class CaptureController {
    typealias Transcribe = @Sendable (
        _ audio: AsyncStream<AudioChunk>,
        _ onUpdate: @escaping @Sendable (String) async -> Void
    ) async throws -> String
    typealias Classify = @Sendable (_ transcript: String) async throws -> ClassifiedItem

    enum Phase: Equatable {
        case idle
        case starting
        case recording(since: Date)
        case transcribing
        case classifying
        case saved
        case failed(String)

        var isBusy: Bool {
            switch self {
            case .starting, .recording, .transcribing, .classifying: true
            default: false
            }
        }

        /// After release, while the words are finalized and Claude decides.
        var isThinking: Bool { self == .transcribing || self == .classifying }
    }

    /// The card shown after an item is created, with Undo and Edit.
    struct Confirmation: Identifiable, Equatable {
        let id = UUID()
        let item: JotItem
        /// Set when something went wrong but the words were still kept.
        let notice: String?

        static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    }

    enum Feedback {
        case start, stop, success, failure

        var sensory: SensoryFeedback {
            switch self {
            case .start: .impact(weight: .heavy, intensity: 1)
            case .stop: .impact(weight: .light, intensity: 0.6)
            case .success: .success
            case .failure: .error
            }
        }
    }

    static let levelCount = 48

    private(set) var phase: Phase = .idle
    /// Words so far, updated live while recording.
    private(set) var liveTranscript = ""
    /// Recent loudness values, oldest first, for the waveform.
    private(set) var levels: [Float] = Array(repeating: 0, count: CaptureController.levelCount)
    private(set) var confirmation: Confirmation?
    /// Set to present the editor for a just-captured item.
    var editingItem: JotItem?

    /// Changes on every haptic moment; `feedback` says which one.
    private(set) var feedbackTick = 0
    private(set) var feedback: Feedback = .stop

    var isRecording: Bool {
        if case .recording = phase { true } else { false }
    }

    var currentLevel: Float { levels.last ?? 0 }

    /// The item whose card is about to fly into the timeline.
    var landingItemID: UUID? { confirmation?.item.id }

    private let source: any AudioSource
    private let transcribe: Transcribe
    private let classify: Classify

    private var isHeld = false
    /// Started from the Action Button, Control Center, or a widget: no finger on
    /// the orb, so recording stops after a pause in speech (or a tap on the orb).
    private(set) var isHandsFree = false
    private var heardSpeechAt: Date?
    private let liveActivity = LiveActivityController()
    private var context: ModelContext?
    private var transcriptionTask: Task<String, any Error>?
    private var recordingTask: Task<String?, Never>?
    private var dismissTask: Task<Void, Never>?

    init(
        source: any AudioSource = MicAudioSource(),
        transcribe: @escaping Transcribe = { audio, onUpdate in
            try await SpeechTranscription().transcribe(audio, onUpdate: onUpdate)
        },
        classify: @escaping Classify = { transcript in
            try await ClaudeClassifier().classify(transcript: transcript)
        }
    ) {
        self.source = source
        self.transcribe = transcribe
        self.classify = classify
    }

    // MARK: - Capture

    /// Call when the orb is pressed down.
    func beginCapture() {
        guard !phase.isBusy else { return }
        if confirmation != nil { dismissConfirmation() }
        dismissTask?.cancel()
        isHeld = true
        liveTranscript = ""
        levels = Array(repeating: 0, count: Self.levelCount)
        animate { phase = .starting }

        Task {
            do {
                let audio = try await source.start()
                let tee = AudioTee(input: audio) { [weak self] newLevels in
                    await self?.appendLevels(newLevels)
                }
                recordingTask = tee.recording

                let transcribe = self.transcribe
                let onUpdate: @Sendable (String) async -> Void = { [weak self] text in
                    await self?.updateTranscript(text)
                }
                transcriptionTask = Task.detached {
                    try await transcribe(tee.output, onUpdate)
                }

                animate { phase = .recording(since: .now) }
                emit(.start)
                liveActivity.start()
                // Released while permissions or the engine were still starting up.
                if !isHeld { finishRecording() }
            } catch {
                fail(error)
            }
        }
    }

    /// Starts recording without a held orb, or finishes a hands-free recording.
    func toggleHandsFree(into context: ModelContext) {
        if isRecording {
            endCapture(into: context)
        } else if !phase.isBusy {
            self.context = context
            isHandsFree = true
            heardSpeechAt = nil
            beginCapture()
        }
    }

    /// Call when the orb is released. `context` receives the new item.
    func endCapture(into context: ModelContext) {
        isHeld = false
        self.context = context
        if isRecording { finishRecording() }
    }

    private func finishRecording() {
        guard case .recording(let since) = phase, let context else { return }
        source.stop()
        emit(.stop)
        isHandsFree = false

        let transcription = transcriptionTask
        let recording = recordingTask
        transcriptionTask = nil
        recordingTask = nil

        guard Date.now.timeIntervalSince(since) >= 0.4 else {
            transcription?.cancel()
            Task { AudioStore.remove(await recording?.value) }
            fail(message: "Hold the orb while you speak.")
            return
        }

        animate { phase = .transcribing }

        Task {
            let audioFile = await recording?.value
            do {
                let transcript = try await transcription?.value
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !transcript.isEmpty else {
                    AudioStore.remove(audioFile)
                    fail(message: "Didn't catch that. Try again?")
                    return
                }
                liveTranscript = transcript
                animate { phase = .classifying }
                liveActivity.thinking(transcript: transcript)

                do {
                    let result = try await classify(transcript)
                    let item = save(result, transcript: transcript, audioFile: audioFile, into: context)
                    showConfirmation(for: item, notice: nil)
                } catch {
                    // Never lose what was said: keep it as a plain note.
                    let fallback = ClassifiedItem(type: .note, title: String(transcript.prefix(60)), details: "")
                    let item = save(fallback, transcript: transcript, audioFile: audioFile, into: context)
                    showConfirmation(for: item, notice: "Saved as a note. \(error.localizedDescription)")
                }
                await ReminderScheduler.refill(using: context)
            } catch {
                AudioStore.remove(audioFile)
                fail(error)
            }
        }
    }

    @discardableResult
    func save(
        _ result: ClassifiedItem,
        transcript: String,
        audioFile: String? = nil,
        into context: ModelContext
    ) -> JotItem {
        Self.insert(result, transcript: transcript, audioFile: audioFile, into: context)
    }

    /// Creates and saves an item from Claude's result. Also used by Siri.
    @discardableResult
    static func insert(
        _ result: ClassifiedItem,
        transcript: String,
        audioFile: String? = nil,
        into context: ModelContext
    ) -> JotItem {
        let item = JotItem(
            kind: result.type,
            title: result.title.isEmpty ? String(transcript.prefix(60)) : result.title,
            details: result.details,
            dueDate: result.dueDate(),
            recurrence: result.recurrence,
            transcript: transcript
        )
        item.audioFileName = audioFile
        context.insert(item)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return item
    }

    // MARK: - Confirmation

    private func showConfirmation(for item: JotItem, notice: String?) {
        animate {
            phase = .saved
            confirmation = Confirmation(item: item, notice: notice)
        }
        emit(notice == nil ? .success : .failure)
        scheduleDismiss(after: notice == nil ? 4 : 6)
        liveActivity.saved(kind: item.kind, title: item.title, when: item.dueDate.map { JotDate.short($0) })
    }

    /// Removes the card; on Today it flies into its place in the timeline.
    func dismissConfirmation() {
        dismissTask?.cancel()
        guard confirmation != nil || phase == .saved || isFailed else { return }
        animate {
            confirmation = nil
            if !phase.isBusy { phase = .idle }
        }
    }

    /// Deletes the item that was just created.
    func undo() {
        guard let item = confirmation?.item, let context else { return }
        dismissTask?.cancel()
        AudioStore.remove(item.audioFileName)
        animate {
            confirmation = nil
            phase = .idle
            context.delete(item)
        }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        Task { await ReminderScheduler.refill(using: context) }
    }

    func edit() {
        guard let item = confirmation?.item else { return }
        dismissConfirmation()
        editingItem = item
    }

    // MARK: - Helpers

    private var isFailed: Bool {
        if case .failed = phase { true } else { false }
    }

    private func appendLevels(_ newLevels: [Float]) {
        guard isRecording, !newLevels.isEmpty else { return }
        levels.append(contentsOf: newLevels)
        if levels.count > Self.levelCount {
            levels.removeFirst(levels.count - Self.levelCount)
        }
        if isHandsFree { checkForPause(newLevels) }
    }

    /// Hands-free: stop after ~2 s of quiet once speech has started, or give up
    /// if nothing is said for 8 s. Recordings are capped at 90 s.
    private func checkForPause(_ newLevels: [Float]) {
        guard case .recording(let since) = phase, let context else { return }
        let now = Date.now
        if newLevels.contains(where: { $0 > 0.35 }) { heardSpeechAt = now }
        let elapsed = now.timeIntervalSince(since)
        let quietFor = heardSpeechAt.map { now.timeIntervalSince($0) }
        if (quietFor ?? 0) > 2.2 || (heardSpeechAt == nil && elapsed > 8) || elapsed > 90 {
            endCapture(into: context)
        }
    }

    private func updateTranscript(_ text: String) {
        guard phase.isBusy else { return }
        animate { liveTranscript = text }
        liveActivity.updateTranscript(text)
    }

    private func emit(_ feedback: Feedback) {
        self.feedback = feedback
        feedbackTick += 1
    }

    private func fail(_ error: any Error) {
        if isRecording {
            source.stop()
            emit(.stop)
        }
        fail(message: error.localizedDescription)
    }

    private func fail(message: String) {
        isHandsFree = false
        animate { phase = .failed(message) }
        emit(.failure)
        scheduleDismiss(after: 5)
        liveActivity.failed(message)
    }

    private func scheduleDismiss(after seconds: Double) {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            dismissConfirmation()
        }
    }

    private func animate(_ body: () -> Void) {
        withAnimation(Self.reduceMotion ? .easeInOut(duration: 0.2) : .jot, body)
    }

    private static var reduceMotion: Bool {
        #if os(iOS)
        UIAccessibility.isReduceMotionEnabled
        #else
        false
        #endif
    }
}
