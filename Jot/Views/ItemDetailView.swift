import SwiftData
import SwiftUI

struct ItemDetailView: View {
    @Bindable var item: JotItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.jotAnimation) private var animation
    @Environment(CaptureController.self) private var capture
    @State private var playback = AudioPlayback()
    @State private var confirmingDelete = false
    @State private var isDeleted = false
    @State private var isSorting = false
    @State private var sortError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let parentID = item.parentID {
                    ParentLink(parentID: parentID)
                }

                kindPicker
                    .padding(.horizontal, -JotMetrics.gutter)

                if item.needsSorting {
                    NotSortedBanner(isSorting: isSorting) { sortAgain() }
                }

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Title", text: $item.title, axis: .vertical)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .tracking(-0.4)
                        .foregroundStyle(Color.jotTextPrimary)
                    TextField("Add details", text: $item.details, axis: .vertical)
                        .font(.jotBody)
                        .foregroundStyle(Color.jotTextSecondary)
                        .lineLimit(1...8)
                }

                if item.kind != .note {
                    whenCard
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if ItemActions.canComplete(item) {
                    completeButton
                }

                if playback.isLoaded {
                    PlaybackCard(playback: playback, color: item.kind.color)
                }

                TranscriptQuote(transcript: item.transcript, createdAt: item.createdAt)

                FollowUps(parentID: item.id) {
                    capture.startFollowUp(to: item, in: modelContext)
                }
            }
            .padding(.horizontal, JotMetrics.gutter)
            .padding(.top, 4)
            .padding(.bottom, 40)
            .animation(animation, value: item.kind)
            .animation(animation, value: item.dueDate == nil)
            .animation(animation, value: item.needsSorting)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Color.jotBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Add follow-up", systemImage: "arrowshape.turn.up.right") {
                        capture.startFollowUp(to: item, in: modelContext)
                    }
                    .disabled(capture.phase.isBusy)
                    if !item.transcript.isEmpty {
                        Button("Sort again", systemImage: "sparkles", action: sortAgain)
                            .disabled(isSorting)
                    }
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        confirmingDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("More")
                // Anchored to the menu button so iOS presents it from there.
                .confirmationDialog("Delete this item?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        isDeleted = true
                        playback.stop()
                        dismiss()
                        // Delete once the screen has gone: SwiftData can crash if a view
                        // still bound to the item reads it after it's deleted.
                        let item = item, context = modelContext
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(450))
                            ItemActions.delete(item, in: context)
                        }
                    }
                } message: {
                    Text("The recording is deleted too.")
                }
            }
        }
        .alert("Couldn't sort it", isPresented: Binding(get: { sortError != nil }, set: { if !$0 { sortError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sortError ?? "")
        }
        .task { await playback.load(fileName: item.audioFileName) }
        .onDisappear {
            playback.stop()
            guard !isDeleted else { return }
            ItemActions.commit(modelContext)
        }
    }

    private func sortAgain() {
        guard !isSorting else { return }
        isSorting = true
        Task {
            defer { isSorting = false }
            do {
                try await SortLater.sort(item, in: modelContext)
            } catch {
                sortError = error.localizedDescription
            }
        }
    }

    // MARK: Sections

    private var kindPicker: some View {
        ChipPicker(
            options: ItemKind.allCases.map { .init(value: $0, label: $0.label, color: $0.color) },
            selection: $item.kind
        )
    }

    private var whenCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("When", systemImage: "calendar")
                    .font(.jotHeadline)
                    .foregroundStyle(Color.jotTextPrimary)
                Spacer()
                if item.dueDate == nil {
                    Button("Add time") { setDefaultDueDate() }
                        .buttonStyle(.jotSecondary)
                        .controlSize(.small)
                } else {
                    Button {
                        withAnimation(animation) {
                            item.dueDate = nil
                            item.recurrence = nil
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.jotTextSecondary)
                            .frame(width: 28, height: 28)
                            .background(Color.jotRaised, in: .circle)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Remove time")
                }
            }

            if let dueDate = Binding($item.dueDate) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(JotDate.short(dueDate.wrappedValue))
                        .font(.system(.title2, design: .rounded, weight: .bold).monospacedDigit())
                        .foregroundStyle(item.kind.color)
                        .contentTransition(.numericText())
                    DatePicker("Date and time", selection: dueDate)
                        .labelsHidden()
                        .tint(Color.jotAccent)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("REPEAT")
                        .font(.jotLabel)
                        .tracking(1.2)
                        .foregroundStyle(Color.jotTextSecondary)
                    ChipPicker(
                        options: [.init(value: Recurrence?.none, label: "Never")]
                            + Recurrence.allCases.map { .init(value: Optional($0), label: $0.label) },
                        selection: $item.recurrence,
                        inset: JotMetrics.cardPadding
                    )
                    // Scroll edge to edge within the card.
                    .padding(.horizontal, -JotMetrics.cardPadding)
                }
            }
        }
        .jotCard()
    }

    private var completeButton: some View {
        Button {
            withAnimation(animation) { ItemActions.toggleComplete(item, in: modelContext) }
        } label: {
            HStack(spacing: 12) {
                CheckCircle(isChecked: item.isCompleted, color: item.kind.color)
                Text(item.isCompleted ? "Completed" : "Mark as done")
                    .font(.jotHeadline)
                    .foregroundStyle(Color.jotTextPrimary)
                Spacer()
                if item.recurrence != nil, !item.isCompleted {
                    Text("Moves to next time")
                        .font(.jotCaption)
                        .foregroundStyle(Color.jotTextSecondary)
                }
            }
            .jotCard()
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.success, trigger: item.isCompleted) { _, done in done }
    }

    private func setDefaultDueDate() {
        withAnimation(animation) {
            item.dueDate = Calendar.current.nextDate(
                after: .now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime
            )
        }
    }
}

// MARK: - Playback

struct PlaybackCard: View {
    let playback: AudioPlayback
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Button {
                playback.toggle()
            } label: {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 48, height: 48)
                    .background(Color.jotAccent, in: .circle)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(playback.isPlaying ? "Pause recording" : "Play recording")

            VStack(alignment: .leading, spacing: 6) {
                PlaybackWaveform(levels: playback.waveform, progress: playback.progress, color: color) { fraction in
                    playback.seek(to: fraction)
                }
                .frame(height: 30)

                HStack {
                    Text(Duration.seconds(playback.progress * playback.duration).formatted(.time(pattern: .minuteSecond)))
                    Spacer()
                    Text(Duration.seconds(playback.duration).formatted(.time(pattern: .minuteSecond)))
                }
                .font(.jotTimeSmall)
                .foregroundStyle(Color.jotTextSecondary)
            }
        }
        .jotCard()
        .sensoryFeedback(.impact(weight: .light), trigger: playback.isPlaying)
    }
}

/// The recording's shape; played portion in color, tap or drag to seek.
private struct PlaybackWaveform: View {
    let levels: [Float]
    let progress: Double
    let color: Color
    var onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { proxy in
            let count = max(levels.count, 1)
            let spacing: CGFloat = 2
            let barWidth = max(1, (proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                    let played = Double(index) / Double(count) < progress
                    Capsule()
                        .fill(played ? color : Color.jotTextSecondary.opacity(0.35))
                        .frame(width: barWidth, height: max(3, CGFloat(level) * proxy.size.height))
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    onSeek(min(max(value.location.x / proxy.size.width, 0), 1))
                }
            )
        }
        .accessibilityElement()
        .accessibilityLabel("Recording progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

// MARK: - Transcript

private struct TranscriptQuote: View {
    let transcript: String
    let createdAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHAT YOU SAID")
                .font(.jotLabel)
                .tracking(1.2)
                .foregroundStyle(Color.jotTextSecondary)

            HStack(alignment: .top, spacing: 14) {
                Capsule()
                    .fill(Color.jotNote)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(Color.jotNote)
                    Text(transcript.isEmpty ? "No transcript for this item." : transcript)
                        .font(.system(.title3, design: .serif))
                        .italic()
                        .foregroundStyle(transcript.isEmpty ? Color.jotTextSecondary : Color.jotTextPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Captured \(createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.jotTimeSmall)
                        .foregroundStyle(Color.jotTextSecondary)
                }
            }
        }
        .jotCard(padding: 20)
    }
}
