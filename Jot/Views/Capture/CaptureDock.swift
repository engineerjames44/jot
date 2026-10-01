import SwiftData
import SwiftUI

/// The record orb, pinned to the bottom of a screen, with the live panel floating above it.
struct CaptureDock: View {
    @Environment(CaptureController.self) private var capture
    @Environment(\.isActiveTab) private var isActiveTab

    var body: some View {
        CaptureOrb()
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)
            .overlay(alignment: .top) {
                if isActiveTab {
                    // A zero-height frame at the dock's top edge, with the panel hanging
                    // upward from it: it floats above the orb without affecting layout.
                    CapturePanel()
                        .padding(.horizontal, JotMetrics.gutter)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(height: 0, alignment: .bottom)
                }
            }
    }
}

// MARK: - Orb

struct CaptureOrb: View {
    @Environment(CaptureController.self) private var capture
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false
    @State private var spin = false

    static let orbSize: CGFloat = 78

    var body: some View {
        let recording = capture.isRecording
        let thinking = capture.phase.isThinking
        let level = CGFloat(capture.currentLevel)

        ZStack {
            // Soft orange glow that breathes with the voice.
            Circle()
                .fill(Color.jotAccent)
                .frame(width: Self.orbSize * 1.2, height: Self.orbSize * 1.2)
                .blur(radius: recording ? 22 + level * 14 : 18)
                .opacity(recording ? 0.45 + level * 0.45 : (thinking ? 0.35 : 0.22))

            // Liquid Glass halo.
            Circle()
                .fill(.clear)
                .frame(width: Self.orbSize + 18, height: Self.orbSize + 18)
                .glassEffect(.regular, in: .circle)
                .opacity(recording ? 0 : 1)

            if thinking {
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        AngularGradient(colors: [Color.jotAccent.opacity(0), Color.jotAccent], center: .center),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: Self.orbSize + 18, height: Self.orbSize + 18)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .onAppear {
                        spin = false
                        guard !reduceMotion else { return }
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { spin = true }
                    }
                    .transition(.opacity)
            }

            // The orb itself (its glow is drawn above, so it reacts to the voice).
            BrandOrb(size: Self.orbSize, glow: 0)
                .overlay { orbSymbol }
                .scaleEffect(scale(recording: recording, level: level))
        }
        .frame(width: 112, height: 104)
        .overlay {
            if recording {
                RadialWaveform(levels: capture.levels)
                    .frame(width: 190, height: 190)
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
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
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.3, dampingFraction: 0.6), value: level)
        .animation(.jot, value: recording)
        .animation(.jot, value: thinking)
        .animation(.jot, value: isPressed)
        .accessibilityElement()
        .accessibilityLabel(recording ? "Recording. Release to save." : "Record")
        .accessibilityHint("Hold, speak, and let go. Jot turns it into a note, task, reminder, or event.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            // VoiceOver: activate to start, activate again to finish.
            if capture.isRecording {
                capture.endCapture(into: modelContext)
            } else {
                capture.beginCapture()
            }
        }
    }

    private func scale(recording: Bool, level: CGFloat) -> CGFloat {
        if recording { return 1.14 + (reduceMotion ? 0 : level * 0.08) }
        return isPressed ? 0.94 : 1
    }

    @ViewBuilder
    private var orbSymbol: some View {
        let symbol = switch capture.phase {
        case .recording: "waveform"
        case .transcribing, .classifying: "sparkles"
        case .saved: "checkmark"
        case .failed: "exclamationmark"
        case .idle, .starting: "mic.fill"
        }
        Image(systemName: symbol)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.variableColor.iterative, isActive: capture.isRecording)
            .symbolEffect(.pulse, isActive: capture.phase.isThinking)
    }
}

/// Bars radiating around the orb, newest at the top, each sized by loudness.
private struct RadialWaveform: View {
    let levels: [Float]

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let inner = CaptureOrb.orbSize * 1.14 / 2 + 8
            let count = levels.count
            for (index, level) in levels.enumerated() {
                // Mirror so the newest sound sits at 12 o'clock on both sides.
                let fraction = Double(count - index) / Double(count)
                for side in [-1.0, 1.0] {
                    let angle = -Double.pi / 2 + side * fraction * Double.pi
                    let length = 3 + CGFloat(level) * 24
                    let start = CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner)
                    let end = CGPoint(x: center.x + cos(angle) * (inner + length), y: center.y + sin(angle) * (inner + length))
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    context.stroke(
                        path,
                        with: .color(Color.jotAccent.opacity(0.35 + Double(level) * 0.65)),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                }
            }
        }
    }
}

// MARK: - Panel

/// Live words while recording, a shimmer while thinking, then the confirmation card.
private struct CapturePanel: View {
    @Environment(CaptureController.self) private var capture

    var body: some View {
        Group {
            switch capture.phase {
            case .starting, .recording:
                LiveTranscriptCard()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .transcribing, .classifying:
                ThinkingCard(transcript: capture.liveTranscript)
                    .transition(.opacity)
            case .saved:
                if let confirmation = capture.confirmation {
                    ConfirmationCard(confirmation: confirmation)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity.combined(with: .scale(scale: 0.92))
                        ))
                }
            case .failed(let message):
                FailureCard(message: message)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .idle:
                EmptyView()
            }
        }
        .padding(.bottom, 8)
    }
}

/// Floating glass card used by every panel state.
private struct PanelCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(Color.jotSurface.opacity(0.75)), in: .rect(cornerRadius: 24, style: .continuous))
    }
}

private struct LiveTranscriptCard: View {
    @Environment(CaptureController.self) private var capture

    var body: some View {
        PanelCard {
            HStack(spacing: 8) {
                KindDot(color: .jotAccent, size: 8, glows: true)
                Text("LISTENING")
                    .font(.jotLabel)
                    .tracking(1.2)
                    .foregroundStyle(Color.jotAccent)
                Spacer()
                if case .recording(let since) = capture.phase {
                    Text(timerInterval: since...Date.distantFuture, countsDown: false)
                        .font(.jotTimeSmall)
                        .foregroundStyle(Color.jotTextSecondary)
                }
            }

            Text(capture.liveTranscript.isEmpty ? "Say what's on your mind…" : capture.liveTranscript)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(capture.liveTranscript.isEmpty ? Color.jotTextSecondary : Color.jotTextPrimary)
                .lineLimit(4)
                .truncationMode(.head)
                .contentTransition(.interpolate)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ThinkingCard: View {
    let transcript: String

    var body: some View {
        PanelCard {
            Label("THINKING", systemImage: "sparkles")
                .font(.jotLabel)
                .tracking(1.2)
                .foregroundStyle(Color.jotAccent)
                .shimmering()

            Text(transcript.isEmpty ? "Finishing up…" : "“\(transcript)”")
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(Color.jotTextSecondary)
                .lineLimit(3)
                .shimmering()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Thinking")
    }
}

private struct ConfirmationCard: View {
    let confirmation: CaptureController.Confirmation
    @Environment(CaptureController.self) private var capture
    @Environment(\.captureNamespace) private var namespace

    var body: some View {
        let item = confirmation.item
        PanelCard {
            HStack(spacing: 6) {
                KindLabel(kind: item.kind)
                if let due = item.dueDate {
                    Text("·").foregroundStyle(Color.jotTextSecondary)
                    Text(JotDate.short(due))
                        .font(.jotTimeSmall)
                        .foregroundStyle(Color.jotTextSecondary)
                }
                if item.recurrence != nil {
                    Image(systemName: "arrow.trianglehead.2.clockwise")
                        .font(.jotLabel)
                        .foregroundStyle(Color.jotTextSecondary)
                }
            }

            Text(item.title)
                .font(.jotTitle)
                .foregroundStyle(Color.jotTextPrimary)
                .lineLimit(2)

            if let notice = confirmation.notice {
                Label(notice, systemImage: "exclamationmark.triangle.fill")
                    .font(.jotCaption)
                    .foregroundStyle(Color.jotReminder)
                    .lineLimit(3)
            }

            HStack(spacing: 10) {
                Button("Undo", systemImage: "arrow.uturn.backward") { capture.undo() }
                    .buttonStyle(.jotSecondary)
                Button("Edit", systemImage: "pencil") { capture.edit() }
                    .buttonStyle(.jotSecondary)
                Spacer()
                Button {
                    capture.dismissConfirmation()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                }
                .buttonStyle(.jotPrimary)
                .accessibilityLabel("Done")
            }
            .controlSize(.small)
            .padding(.top, 2)
        }
        .modifier(MatchedLanding(id: item.id, namespace: namespace, isSource: true))
        .accessibilityElement(children: .contain)
    }
}

private struct FailureCard: View {
    let message: String
    @Environment(CaptureController.self) private var capture

    var body: some View {
        PanelCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.jotReminder)
                Text(message)
                    .font(.jotBody)
                    .foregroundStyle(Color.jotTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onTapGesture { capture.dismissConfirmation() }
    }
}

// MARK: - Landing

/// Matches a card's position to the confirmation card so a new item flies into place.
private struct MatchedLanding: ViewModifier {
    let id: UUID
    let namespace: Namespace.ID?
    let isSource: Bool

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedGeometryEffect(id: id, in: namespace, properties: .position, isSource: isSource)
        } else {
            content
        }
    }
}

/// Apply to a timeline card. While its item is on the confirmation card it hides and
/// tracks that card; when the confirmation goes away it flies home.
struct LandingTarget: ViewModifier {
    let id: UUID
    @Environment(CaptureController.self) private var capture
    @Environment(\.captureNamespace) private var namespace
    @Environment(\.isActiveTab) private var isActiveTab

    func body(content: Content) -> some View {
        let isLanding = isActiveTab && capture.landingItemID == id
        content
            .opacity(isLanding ? 0 : 1)
            .modifier(MatchedLanding(id: id, namespace: isActiveTab ? namespace : nil, isSource: !isLanding))
    }
}

extension View {
    func landingTarget(_ id: UUID) -> some View { modifier(LandingTarget(id: id)) }
}
