import Foundation
import Observation
import SwiftData

/// Records a change note: tap to start, tap to stop. Uses the same mic and
/// on-device transcription as the record orb, but skips Claude. The words
/// are kept as said.
@MainActor
@Observable
final class DevNoteRecorder {
    enum Phase: Equatable {
        case idle
        case starting
        case recording(since: Date)
        case finishing
        case failed(String)

        var isActive: Bool {
            switch self {
            case .starting, .recording, .finishing: true
            default: false
            }
        }
    }

    static let levelCount = 40

    private(set) var phase: Phase = .idle
    private(set) var liveText = ""
    private(set) var levels: [Float] = Array(repeating: 0, count: DevNoteRecorder.levelCount)
    /// Changes on start and stop, for haptics.
    private(set) var toggleCount = 0

    var isRecording: Bool {
        if case .recording = phase { true } else { false }
    }

    private let source: any AudioSource
    private let transcribe: CaptureController.Transcribe
    private var transcriptionTask: Task<String, any Error>?
    private var recordingTask: Task<String?, Never>?

    init(source: any AudioSource, transcribe: @escaping CaptureController.Transcribe) {
        self.source = source
        self.transcribe = transcribe
    }

    static func make() -> DevNoteRecorder {
        #if DEBUG
        if DemoCapture.isRequested {
            return DevNoteRecorder(source: DemoAudioSource(), transcribe: DemoCapture.transcribe)
        }
        #endif
        return DevNoteRecorder(source: MicAudioSource()) { audio, onUpdate in
            try await SpeechTranscription().transcribe(audio, onUpdate: onUpdate)
        }
    }

    func start() {
        guard !phase.isActive else { return }
        liveText = ""
        levels = Array(repeating: 0, count: Self.levelCount)
        phase = .starting

        Task {
            do {
                let audio = try await source.start()
                let tee = AudioTee(input: audio) { [weak self] newLevels in
                    await self?.append(newLevels)
                }
                recordingTask = tee.recording

                let transcribe = self.transcribe
                let onUpdate: @Sendable (String) async -> Void = { [weak self] text in
                    await self?.update(text)
                }
                transcriptionTask = Task.detached {
                    try await transcribe(tee.output, onUpdate)
                }
                phase = .recording(since: .now)
                toggleCount += 1
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    /// Stops and saves the note. Keeps the recording even if no words were caught.
    @discardableResult
    func stop(screen: String?, into context: ModelContext) async -> DevNote? {
        guard case .recording(let since) = phase else { return nil }
        source.stop()
        toggleCount += 1
        phase = .finishing

        let duration = Date.now.timeIntervalSince(since)
        let audioFile = await recordingTask?.value
        let spoken = (try? await transcriptionTask?.value) ?? liveText
        transcriptionTask = nil
        recordingTask = nil

        let text = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || duration >= 1 else {
            AudioStore.remove(audioFile)
            phase = .failed("That was too short. Tap, speak, then tap again.")
            return nil
        }

        let note = DevNote(
            text: text,
            screen: screen,
            appVersion: Bundle.main.jotVersion,
            audioFileName: audioFile,
            duration: duration
        )
        context.insert(note)
        try? context.save()
        phase = .idle
        return note
    }

    /// Stops without saving anything.
    func cancel() {
        guard phase.isActive else { return }
        source.stop()
        transcriptionTask?.cancel()
        let recording = recordingTask
        transcriptionTask = nil
        recordingTask = nil
        Task { AudioStore.remove(await recording?.value) }
        phase = .idle
        toggleCount += 1
    }

    func clearError() {
        if case .failed = phase { phase = .idle }
    }

    private func append(_ newLevels: [Float]) {
        guard isRecording else { return }
        levels.append(contentsOf: newLevels)
        if levels.count > Self.levelCount { levels.removeFirst(levels.count - Self.levelCount) }
    }

    private func update(_ text: String) {
        guard phase.isActive else { return }
        liveText = text
    }
}

extension Bundle {
    /// "1.0 (1)"
    var jotVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
