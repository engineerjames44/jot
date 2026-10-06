@preconcurrency import AVFAudio

/// Audio from a Jot device. The device records while its button is held and
/// sends the whole clip on release, so the stream gets the clip all at once.
@MainActor
final class BLEAudioSource: AudioSource {
    private var continuation: AsyncStream<AudioChunk>.Continuation?

    func start() async throws -> AsyncStream<AudioChunk> {
        stop()
        let (stream, continuation) = AsyncStream.makeStream(of: AudioChunk.self, bufferingPolicy: .unbounded)
        self.continuation = continuation
        return stream
    }

    func stop() {
        continuation?.finish()
        continuation = nil
    }

    /// Passes a received clip into the stream, in 0.1 s chunks like a live mic.
    func deliver(_ samples: [Int16], sampleRate: Int) {
        guard let continuation else { return }
        for chunk in Self.chunks(of: samples, sampleRate: sampleRate) {
            continuation.yield(chunk)
        }
    }

    nonisolated static func chunks(of samples: [Int16], sampleRate: Int) -> [AudioChunk] {
        guard sampleRate > 0,
              let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)
        else { return [] }
        let gain = normalizingGain(for: samples)
        let size = max(1, sampleRate / 10)

        return stride(from: 0, to: samples.count, by: size).compactMap { start in
            let end = min(start + size, samples.count)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(end - start)),
                  let channel = buffer.floatChannelData?[0]
            else { return nil }
            for i in start..<end {
                channel[i - start] = Float(samples[i]) / 32768 * gain
            }
            buffer.frameLength = AVAudioFrameCount(end - start)
            return AudioChunk(buffer: buffer)
        }
    }

    /// The prototype's mic is quiet, so raise each clip until its loudest
    /// point is near full scale (at most 16×, so silence isn't blown up into hiss).
    nonisolated static func normalizingGain(for samples: [Int16]) -> Float {
        let peak = samples.reduce(0) { max($0, abs(Int($1))) }
        guard peak > 0 else { return 1 }
        return min(0.9 * 32768 / Float(peak), 16)
    }
}
