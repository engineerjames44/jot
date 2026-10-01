@preconcurrency import AVFAudio
import Foundation

/// Where original recordings live, so items can play back what was said.
enum AudioStore {
    nonisolated static var directory: URL {
        let base = URL.applicationSupportDirectory.appending(path: "Recordings", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    nonisolated static func url(for fileName: String) -> URL {
        directory.appending(path: fileName)
    }

    nonisolated static func remove(_ fileName: String?) {
        guard let fileName else { return }
        try? FileManager.default.removeItem(at: url(for: fileName))
    }
}

/// Tees the capture stream: writes the audio to an AAC file and reports levels,
/// passing every chunk through unchanged. Works with any `AudioSource`.
struct AudioTee: Sendable {
    let output: AsyncStream<AudioChunk>
    /// Finishes with the recording's file name once the input ends (nil if nothing was written).
    let recording: Task<String?, Never>

    init(input: AsyncStream<AudioChunk>, levels: @escaping @Sendable ([Float]) async -> Void) {
        let (output, continuation) = AsyncStream.makeStream(of: AudioChunk.self)
        self.output = output
        recording = Task.detached {
            let fileName = "\(UUID().uuidString).m4a"
            var file: AVAudioFile?
            for await chunk in input {
                continuation.yield(chunk)
                if file == nil {
                    file = Self.makeFile(fileName, format: chunk.buffer.format)
                }
                try? file?.write(from: chunk.buffer)
                await levels(AudioMeter.levels(of: chunk.buffer, segments: 3))
            }
            continuation.finish()
            return file == nil ? nil : fileName
        }
    }

    private nonisolated static func makeFile(_ name: String, format: AVAudioFormat) -> AVAudioFile? {
        // Let the encoder choose a bitrate valid for the source's sample rate
        // (a fixed one is rejected at low rates like 16 kHz).
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: min(format.channelCount, 2),
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        let url = AudioStore.url(for: name)
        do {
            return try AVAudioFile(
                forWriting: url,
                settings: settings,
                commonFormat: format.commonFormat,
                interleaved: format.isInterleaved
            )
        } catch {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }
}

/// Converts PCM buffers into 0…1 loudness values for the waveform.
enum AudioMeter {
    nonisolated static func levels(of buffer: AVAudioPCMBuffer, segments: Int) -> [Float] {
        let frames = Int(buffer.frameLength)
        guard frames > 0, segments > 0 else { return [] }
        let size = max(1, frames / segments)

        return (0..<segments).map { segment in
            let start = segment * size
            let end = segment == segments - 1 ? frames : min(frames, start + size)
            var sum: Float = 0
            if let samples = buffer.floatChannelData?[0] {
                for i in start..<end { sum += samples[i] * samples[i] }
            } else if let samples = buffer.int16ChannelData?[0] {
                for i in start..<end {
                    let value = Float(samples[i]) / Float(Int16.max)
                    sum += value * value
                }
            }
            let rms = (sum / Float(max(1, end - start))).squareRoot()
            let decibels = 20 * log10(max(rms, 0.000_001))
            // Map roughly -55 dB (room) … -10 dB (close speech) onto 0…1.
            return min(max((decibels + 55) / 45, 0), 1)
        }
    }
}
