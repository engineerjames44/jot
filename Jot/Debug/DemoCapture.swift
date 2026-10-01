#if DEBUG
@preconcurrency import AVFAudio
import Foundation
import Synchronization

/// A scripted capture for designing the record flow without a mic or API key.
/// Enable with the launch argument `-JotDemoCapture YES` (Debug builds only).
enum DemoCapture {
    static var isRequested: Bool {
        UserDefaults.standard.bool(forKey: "JotDemoCapture")
    }

    @MainActor
    static func makeController() -> CaptureController {
        CaptureController(source: DemoAudioSource(), transcribe: transcribe, classify: classify)
    }

    /// Alternates between a reminder for Thursday and a task later today
    /// (which lands on the Today timeline).
    private static let takes = Mutex(0)
    private static let scripts = [
        "Remind me to call the dentist on Thursday at two",
        "I need to pick up the dry cleaning in twenty minutes",
    ]

    /// Reveals the script a word at a time while audio flows.
    static let transcribe: CaptureController.Transcribe = { audio, onUpdate in
        let script = scripts[takes.withLock { $0 } % scripts.count]
        let words = script.split(separator: " ")
        var shown = 0
        var lastWord = ContinuousClock.now
        for await _ in audio where shown < words.count && ContinuousClock.now - lastWord > .milliseconds(280) {
            shown += 1
            lastWord = .now
            await onUpdate(words.prefix(shown).joined(separator: " "))
        }
        return script
    }

    static let classify: CaptureController.Classify = { _ in
        try await Task.sleep(for: .seconds(1.6))
        let take = takes.withLock { value in
            defer { value += 1 }
            return value
        }
        let iso = ISO8601DateFormatter()
        iso.timeZone = .current

        if take % scripts.count == 1 {
            let soon = Date.now.addingTimeInterval(20 * 60)
            return ClassifiedItem(type: .task, title: "Pick up the dry cleaning", details: "",
                                  dueDatetime: iso.string(from: soon), recurrence: nil)
        }
        let thursday = Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(hour: 14, minute: 0, weekday: 5),
            matchingPolicy: .nextTime
        ) ?? .now
        return ClassifiedItem(type: .reminder, title: "Call the dentist", details: "",
                              dueDatetime: iso.string(from: thursday), recurrence: nil)
    }
}

/// Produces a speech-like tone so the waveform has something to react to.
@MainActor
final class DemoAudioSource: AudioSource {
    private var task: Task<Void, Never>?
    private var continuation: AsyncStream<AudioChunk>.Continuation?

    func start() async throws -> AsyncStream<AudioChunk> {
        let (stream, continuation) = AsyncStream.makeStream(of: AudioChunk.self)
        self.continuation = continuation
        task = Task.detached {
            let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
            var t = 0.0
            while !Task.isCancelled {
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 800) else { break }
                buffer.frameLength = 800
                // Syllable-ish envelope: a few bursts per second.
                let envelope = Float(max(0, sin(t * 9) * 0.6 + sin(t * 2.3) * 0.4))
                let samples = buffer.floatChannelData![0]
                for i in 0..<800 {
                    samples[i] = envelope * 0.3 * Float(sin(Double(i) * 0.12) + Double.random(in: -0.2...0.2))
                }
                continuation.yield(AudioChunk(buffer: buffer))
                t += 0.05
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        return stream
    }

    func stop() {
        task?.cancel()
        task = nil
        continuation?.finish()
        continuation = nil
    }
}
#endif
