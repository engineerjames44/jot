import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen and Dynamic Island while Jot is listening and thinking.
struct CaptureLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CaptureActivityAttributes.self) { context in
            LockScreenCapture(state: context.state)
                .activityBackgroundTint(Color.jotBackground)
                .activitySystemActionForegroundColor(Color.jotAccent)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PhaseOrb(phase: state.phase, size: 36)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PhaseTrailing(state: state)
                        .font(.system(.title3, design: .rounded, weight: .semibold).monospacedDigit())
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(state.phase.headline)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(state.phase.tint)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CaptureDetail(state: state)
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                }
            } compactLeading: {
                PhaseOrb(phase: state.phase, size: 18)
            } compactTrailing: {
                PhaseTrailing(state: state)
                    .font(.system(.caption, design: .rounded, weight: .bold).monospacedDigit())
                    .frame(maxWidth: 44)
            } minimal: {
                PhaseOrb(phase: state.phase, size: 18)
            }
            .keylineTint(Color.jotAccent)
        }
    }
}

private extension CaptureActivityAttributes.Phase {
    var headline: String {
        switch self {
        case .recording: "Listening"
        case .thinking: "Thinking"
        case .saved: "Saved"
        case .failed: "Didn't save"
        }
    }

    var tint: Color {
        switch self {
        case .recording, .thinking: .jotAccent
        case .saved: .jotTask
        case .failed: .jotReminder
        }
    }
}

/// The orb, with a symbol for the phase.
private struct PhaseOrb: View {
    let phase: CaptureActivityAttributes.Phase
    let size: CGFloat

    var body: some View {
        BrandOrb(size: size, glow: phase == .recording ? 0.6 : 0.2)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, isActive: phase == .thinking)
            }
    }

    private var symbol: String {
        switch phase {
        case .recording: "waveform"
        case .thinking: "sparkles"
        case .saved: "checkmark"
        case .failed: "exclamationmark"
        }
    }
}

private struct PhaseTrailing: View {
    let state: CaptureActivityAttributes.ContentState

    var body: some View {
        switch state.phase {
        case .recording:
            Text(timerInterval: state.startedAt...Date.distantFuture, countsDown: false)
                .foregroundStyle(Color.jotAccent)
                .multilineTextAlignment(.trailing)
        case .thinking:
            Image(systemName: "ellipsis")
                .foregroundStyle(Color.jotAccent)
                .symbolEffect(.variableColor.iterative)
        case .saved:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.jotTask)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color.jotReminder)
        }
    }
}

/// Words while listening; the created item once saved.
private struct CaptureDetail: View {
    let state: CaptureActivityAttributes.ContentState

    var body: some View {
        Group {
            switch state.phase {
            case .recording, .thinking:
                Text(state.transcript.isEmpty ? "Say what's on your mind…" : state.transcript)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(state.transcript.isEmpty ? Color.jotTextSecondary : Color.jotTextPrimary)
                    .lineLimit(2)
                    .truncationMode(.head)
            case .saved:
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if let kind = state.resultKind.flatMap(ItemKind.init(rawValue:)) {
                            KindLabel(kind: kind)
                        }
                        if let when = state.resultWhen {
                            Text("· \(when)")
                                .font(.jotTimeSmall)
                                .foregroundStyle(Color.jotTextSecondary)
                        }
                    }
                    Text(state.resultTitle ?? "")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Color.jotTextPrimary)
                        .lineLimit(1)
                }
            case .failed:
                Text(state.message ?? "Something went wrong.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.jotTextSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LockScreenCapture: View {
    let state: CaptureActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            PhaseOrb(phase: state.phase, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(state.phase.headline)
                        .font(.jotSection)
                        .foregroundStyle(state.phase.tint)
                    Spacer()
                    PhaseTrailing(state: state)
                        .font(.jotTimeSmall)
                }
                CaptureDetail(state: state)
            }
        }
        .padding(16)
    }
}
