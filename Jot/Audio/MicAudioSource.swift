@preconcurrency import AVFAudio

/// Captures audio from the device microphone with `AVAudioEngine`.
@MainActor
final class MicAudioSource: AudioSource {
    private let engine = AVAudioEngine()
    private var continuation: AsyncStream<AudioChunk>.Continuation?

    func start() async throws -> AsyncStream<AudioChunk> {
        stop()

        guard await AVAudioApplication.requestRecordPermission() else {
            throw AudioSourceError.permissionDenied
        }

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default, options: [.duckOthers])
        try session.setActive(true)
        #endif

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw AudioSourceError.unavailable("no microphone input")
        }

        let (stream, continuation) = AsyncStream.makeStream(of: AudioChunk.self, bufferingPolicy: .unbounded)
        self.continuation = continuation

        input.installTap(onBus: 0, bufferSize: 4096, format: format, block: Self.makeTapBlock(continuation))
        engine.prepare()
        do {
            try engine.start()
        } catch {
            stop()
            throw AudioSourceError.unavailable(error.localizedDescription)
        }
        return stream
    }

    func stop() {
        if engine.isRunning {
            engine.stop()
        }
        engine.inputNode.removeTap(onBus: 0)
        continuation?.finish()
        continuation = nil

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    /// Built outside the main actor so the tap closure isn't main-actor isolated —
    /// it runs on the audio render thread.
    private nonisolated static func makeTapBlock(
        _ continuation: AsyncStream<AudioChunk>.Continuation
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            continuation.yield(AudioChunk(buffer: buffer))
        }
    }
}
