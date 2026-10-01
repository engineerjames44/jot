@preconcurrency import AVFAudio
import Foundation
import Speech

enum TranscriptionError: LocalizedError {
    case unsupportedLocale(Locale)
    case unavailable
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedLocale(let locale):
            "On-device transcription doesn't support \(locale.identifier) yet."
        case .unavailable:
            "On-device transcription isn't available on this device."
        case .conversionFailed:
            "Couldn't convert the recorded audio for transcription."
        }
    }
}

/// Turns a stream of audio into text with `SpeechAnalyzer`, entirely on-device.
struct SpeechTranscription: Sendable {
    var locale: Locale = .current

    /// Consumes `audio` until it finishes and returns the full transcript.
    /// `onUpdate` receives the words so far, including in-progress guesses, as they arrive.
    nonisolated func transcribe(
        _ audio: AsyncStream<AudioChunk>,
        onUpdate: @escaping @Sendable (String) async -> Void = { _ in }
    ) async throws -> String {
        guard SpeechTranscriber.isAvailable else { throw TranscriptionError.unavailable }
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw TranscriptionError.unsupportedLocale(self.locale)
        }

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        try await Self.ensureModelInstalled(for: transcriber)

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw TranscriptionError.unavailable
        }

        // Collect results concurrently while audio is fed in. Volatile results are
        // quick guesses for the words in progress; final ones replace them.
        let collector = Task {
            var finalized = ""
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                if result.isFinal {
                    finalized += text
                    await onUpdate(finalized)
                } else {
                    await onUpdate(finalized + text)
                }
            }
            return finalized
        }

        let (input, inputBuilder) = AsyncStream.makeStream(of: AnalyzerInput.self)
        try await analyzer.start(inputSequence: input)

        let converter = BufferConverter()
        do {
            for await chunk in audio {
                let converted = try converter.convert(chunk.buffer, to: analyzerFormat)
                inputBuilder.yield(AnalyzerInput(buffer: converted))
            }
            inputBuilder.finish()
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        } catch {
            inputBuilder.finish()
            await analyzer.cancelAndFinishNow()
            collector.cancel()
            throw error
        }

        return try await collector.value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Downloads the on-device speech model for the locale the first time it's needed.
    private nonisolated static func ensureModelInstalled(for transcriber: SpeechTranscriber) async throws {
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
    }
}

/// Converts arbitrary source buffers into the analyzer's preferred format,
/// reusing one `AVAudioConverter` while the input format stays the same.
private final class BufferConverter {
    private var converter: AVAudioConverter?

    func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        if buffer.format == format { return buffer }

        if converter == nil || converter?.inputFormat != buffer.format || converter?.outputFormat != format {
            converter = AVAudioConverter(from: buffer.format, to: format)
            converter?.primeMethod = .none
        }
        guard let converter else { throw TranscriptionError.conversionFailed }

        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw TranscriptionError.conversionFailed
        }

        let feed = SingleBufferFeed(buffer)
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if let next = feed.take() {
                inputStatus.pointee = .haveData
                return next
            }
            inputStatus.pointee = .noDataNow
            return nil
        }
        if status == .error {
            throw error ?? TranscriptionError.conversionFailed
        }
        return output
    }
}

/// Hands the converter its one input buffer, then reports "no data".
private final class SingleBufferFeed: @unchecked Sendable {
    private var buffer: AVAudioPCMBuffer?
    init(_ buffer: AVAudioPCMBuffer) { self.buffer = buffer }

    func take() -> AVAudioPCMBuffer? {
        defer { buffer = nil }
        return buffer
    }
}
