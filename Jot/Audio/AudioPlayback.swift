@preconcurrency import AVFAudio
import Foundation
import Observation

/// Plays back an item's original recording and draws its waveform.
@MainActor
@Observable
final class AudioPlayback {
    private(set) var isPlaying = false
    private(set) var progress: Double = 0
    private(set) var duration: TimeInterval = 0
    /// Loudness of the whole recording in even slices, for drawing.
    private(set) var waveform: [Float] = []

    private var player: AVAudioPlayer?
    private var ticker: Task<Void, Never>?

    var isLoaded: Bool { player != nil }

    func load(fileName: String?) async {
        guard player == nil, let fileName else { return }
        let url = AudioStore.url(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        duration = player?.duration ?? 0
        waveform = await Task.detached { Self.waveform(of: url, bars: 56) }.value
    }

    func toggle() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            ticker?.cancel()
        } else {
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try? AVAudioSession.sharedInstance().setActive(true)
            #endif
            if progress >= 1 { player.currentTime = 0 }
            player.play()
            isPlaying = true
            startTicking()
        }
    }

    func seek(to fraction: Double) {
        guard let player else { return }
        player.currentTime = max(0, min(fraction, 1)) * player.duration
        progress = fraction
    }

    func stop() {
        player?.stop()
        ticker?.cancel()
        isPlaying = false
    }

    private func startTicking() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let player = self.player else { return }
                if player.isPlaying {
                    self.progress = player.duration > 0 ? player.currentTime / player.duration : 0
                } else {
                    // Reached the end.
                    self.progress = 1
                    self.isPlaying = false
                    return
                }
                try? await Task.sleep(for: .milliseconds(40))
            }
        }
    }

    private nonisolated static func waveform(of url: URL, bars: Int) -> [Float] {
        guard let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil
        else { return [] }
        return AudioMeter.levels(of: buffer, segments: bars)
    }
}
