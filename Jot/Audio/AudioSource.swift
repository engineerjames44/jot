@preconcurrency import AVFAudio

/// A chunk of PCM audio handed from a source to the transcription pipeline.
///
/// Each buffer is produced once and only read afterwards, so passing it across
/// concurrency domains is safe even though `AVAudioPCMBuffer` isn't `Sendable`.
struct AudioChunk: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
}

/// Anything that can capture speech: the iPhone mic today, a BLE device later.
///
/// The rest of the pipeline only sees the stream of `AudioChunk`s, in whatever
/// PCM format the source produces; the transcriber converts as needed.
@MainActor
protocol AudioSource: AnyObject {
    /// Starts capturing. The returned stream finishes when `stop()` is called.
    func start() async throws -> AsyncStream<AudioChunk>
    /// Stops capturing and finishes the stream returned by `start()`.
    func stop()
}

enum AudioSourceError: LocalizedError {
    case permissionDenied
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Jot needs the microphone to hear you. Turn it on in Settings."
        case .unavailable:
            "Jot can't hear the microphone right now. Check that no other app is using it, then try again."
        }
    }
}
