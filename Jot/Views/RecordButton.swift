import SwiftData
import SwiftUI

/// The floating capture control: status line plus the hold-to-record button.
struct CaptureBar: View {
    @Environment(CaptureController.self) private var capture

    var body: some View {
        VStack(spacing: 10) {
            CaptureStatus(phase: capture.phase)
                .onTapGesture { capture.dismissStatus() }
            RecordButton()
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: capture.phase)
    }
}

struct RecordButton: View {
    @Environment(CaptureController.self) private var capture
    @Environment(\.modelContext) private var modelContext
    @State private var isPressed = false

    var body: some View {
        let recording = capture.isRecording

        ZStack {
            if recording {
                Circle()
                    .stroke(Color.jotAccent.opacity(0.35), lineWidth: 6)
                    .frame(width: 96, height: 96)
                    .phaseAnimator([false, true]) { ring, expanded in
                        ring.scaleEffect(expanded ? 1.25 : 1).opacity(expanded ? 0 : 1)
                    } animation: { _ in .easeOut(duration: 1) }
            }

            Image(systemName: recording ? "waveform" : "mic.fill")
                .font(.system(size: 30, weight: .semibold))
                .symbolEffect(.variableColor.iterative, isActive: recording)
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(Color.jotAccent, in: .circle)
                .glassEffect(.regular.interactive(), in: .circle)
                .scaleEffect(isPressed ? 1.12 : 1)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .frame(width: 100, height: 100)
        .contentShape(.circle)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    isPressed = true
                    capture.beginCapture()
                }
                .onEnded { _ in
                    isPressed = false
                    capture.endCapture(into: modelContext)
                }
        )
        .disabled(capture.phase.isBusy && !recording && !isPressed)
        .sensoryFeedback(trigger: capture.recordingToggleCount) { _, _ in
            capture.isRecording ? .start : .stop
        }
        .sensoryFeedback(trigger: capture.phase) { _, phase in
            switch phase {
            case .saved: .success
            case .failed: .error
            default: nil
            }
        }
        .animation(.spring(duration: 0.25), value: isPressed)
        .accessibilityLabel(recording ? "Recording. Release to save." : "Hold to record")
        .accessibilityAddTraits(.isButton)
    }
}

private struct CaptureStatus: View {
    let phase: CaptureController.Phase

    var body: some View {
        Group {
            switch phase {
            case .idle:
                Text("Hold to capture")
                    .foregroundStyle(.secondary)
            case .starting:
                Label("Getting ready…", systemImage: "mic")
            case .recording(let since):
                HStack(spacing: 6) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                    Text("Listening")
                    Text(timerInterval: since...Date.distantFuture, countsDown: false)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            case .transcribing:
                Label("Transcribing…", systemImage: "waveform")
            case .classifying(let transcript):
                Label("“\(transcript)”", systemImage: "sparkles")
                    .lineLimit(2)
            case .saved(let title, let kind):
                Label("\(kind.label): \(title)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .lineLimit(2)
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            }
        }
        .font(.subheadline)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 24)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .id(phaseKey)
    }

    private var phaseKey: String {
        switch phase {
        case .idle: "idle"
        case .starting: "starting"
        case .recording: "recording"
        case .transcribing: "transcribing"
        case .classifying: "classifying"
        case .saved: "saved"
        case .failed: "failed"
        }
    }
}
