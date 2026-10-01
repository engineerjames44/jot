import SwiftData
import SwiftUI
import UIKit

/// Change notes about Jot itself: record what you'd change as you notice it,
/// then export everything as a PDF or text file in one tap.
struct DevelopView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.jotAnimation) private var animation
    @Query(sort: \DevNote.createdAt, order: .reverse) private var notes: [DevNote]

    @State private var recorder = DevNoteRecorder.make()
    @State private var filter: Filter = .open
    @State private var editing: DevNote?
    @State private var export: ExportFile?
    @State private var exportError: String?

    enum Filter: Hashable { case open, done, all }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    DevRecorderCard(recorder: recorder, screen: "Develop")
                    exportRow
                    ChipPicker(options: filterOptions, selection: $filter, inset: 0)
                    list
                }
                .padding(.horizontal, JotMetrics.gutter)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .animation(animation, value: notes.map(\.id))
                .animation(animation, value: filter)
            }
            .scrollIndicators(.hidden)
            .background(Color.jotBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editing) { note in
                DevNoteEditor(note: note)
            }
            .sheet(item: $export) { file in
                ShareSheet(url: file.url)
                    .presentationDetents([.medium, .large])
                    .ignoresSafeArea()
            }
            .alert("Couldn't export", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "")
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DEVELOP")
                .font(.jotLabel)
                .tracking(1.2)
                .foregroundStyle(Color.jotAccent)
            HStack(alignment: .firstTextBaseline) {
                Text("Change notes")
                    .font(.jotDisplay)
                    .tracking(-0.8)
                    .foregroundStyle(Color.jotTextPrimary)
                Spacer()
                Text("\(openCount)")
                    .font(.system(.title2, design: .rounded, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color.jotTextSecondary)
                    .contentTransition(.numericText(value: Double(openCount)))
                    .accessibilityLabel("\(openCount) open")
            }
            Text("Spot something you'd change? Say it here, then export the list.")
                .font(.jotCaption)
                .foregroundStyle(Color.jotTextSecondary)
        }
        .padding(.top, 12)
    }

    private var exportRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    runExport(.pdf)
                } label: {
                    Label("Export PDF", systemImage: "doc.richtext.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.jotPrimary)

                Button {
                    runExport(.text)
                } label: {
                    Label("Export TXT", systemImage: "doc.plaintext.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.jotSecondary)
            }
            .disabled(notes.isEmpty)
            .opacity(notes.isEmpty ? 0.5 : 1)

            Text(notes.isEmpty
                 ? "Your first note will make these work."
                 : "Includes \(notes.count == 1 ? "your 1 note" : "all \(notes.count) notes, open ones first"). Save to Files, AirDrop, or share anywhere.")
                .font(.jotCaption)
                .foregroundStyle(Color.jotTextSecondary)
        }
    }

    @ViewBuilder
    private var list: some View {
        let shown = filtered
        if notes.isEmpty {
            EmptyStateView(
                symbol: "hammer.fill",
                color: .jotAccent,
                orbitSymbols: ["sparkle", "waveform"],
                title: "No notes yet",
                message: "Tap the orb and say what you'd change."
            )
        } else if shown.isEmpty {
            EmptyStateView(
                symbol: filter == .done ? "checkmark.circle.fill" : "party.popper.fill",
                color: .jotTask,
                orbitSymbols: ["sparkle", "checkmark"],
                title: filter == .done ? "Nothing done yet" : "All caught up",
                message: filter == .done ? "Tick a note once it's handled." : "Every note is marked done."
            )
        } else {
            LazyVStack(spacing: 12) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, note in
                    DevNoteCard(note: note) {
                        withAnimation(animation) { note.isDone.toggle() }
                        try? modelContext.save()
                    }
                    .onTapGesture { editing = note }
                    .contextMenu { menu(for: note) }
                    .staggeredAppear(index)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
        }
    }

    @ViewBuilder
    private func menu(for note: DevNote) -> some View {
        Button(note.isDone ? "Mark as open" : "Mark as done", systemImage: "checkmark.circle") {
            withAnimation(animation) { note.isDone.toggle() }
            try? modelContext.save()
        }
        Picker("Type", selection: Binding(get: { note.category }, set: { note.category = $0; try? modelContext.save() })) {
            ForEach(DevNote.Category.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
        }
        Button("Copy text", systemImage: "doc.on.doc") {
            UIPasteboard.general.string = note.text
        }
        Button("Delete", systemImage: "trash", role: .destructive) {
            withAnimation(animation) { DevNoteActions.delete(note, in: modelContext) }
        }
    }

    // MARK: Data

    private var openCount: Int { notes.count { !$0.isDone } }

    private var filtered: [DevNote] {
        switch filter {
        case .open: notes.filter { !$0.isDone }
        case .done: notes.filter(\.isDone)
        case .all: notes
        }
    }

    private var filterOptions: [ChipPicker<Filter>.Option] {
        [
            .init(value: .open, label: "Open", count: openCount),
            .init(value: .done, label: "Done", count: notes.count - openCount),
            .init(value: .all, label: "All", count: notes.count),
        ]
    }

    private func runExport(_ format: DevNotesExport.Format) {
        do {
            export = ExportFile(url: try DevNotesExport.write(notes, format: format))
        } catch {
            exportError = error.localizedDescription
        }
    }
}

enum DevNoteActions {
    @MainActor
    static func delete(_ note: DevNote, in context: ModelContext) {
        AudioStore.remove(note.audioFileName)
        context.delete(note)
        try? context.save()
    }
}

// MARK: - Recorder card

/// Tap the orb to start, tap again to save. Shows live words while recording.
struct DevRecorderCard: View {
    let recorder: DevNoteRecorder
    /// Attached to the note so you know where you were.
    let screen: String?
    var autoStart = false
    var onSaved: (DevNote) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.jotAnimation) private var animation
    @State private var savedFlash = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                Button(action: toggle) {
                    BrandOrb(size: 64, glow: recorder.isRecording ? 0.8 : 0.3)
                        .overlay {
                            Image(systemName: symbol)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .contentTransition(.symbolEffect(.replace))
                                .symbolEffect(.pulse, isActive: recorder.phase == .finishing)
                        }
                        .scaleEffect(recorder.isRecording ? 1.08 : 1)
                }
                .buttonStyle(.pressable)
                .disabled(recorder.phase == .starting || recorder.phase == .finishing)
                .accessibilityLabel(recorder.isRecording ? "Stop and save note" : "Record a change note")

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.jotHeadline)
                        .foregroundStyle(Color.jotTextPrimary)
                    statusLine
                }
                Spacer(minLength: 0)
                if recorder.isRecording {
                    Button {
                        recorder.cancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.jotTextSecondary)
                            .frame(width: 32, height: 32)
                            .background(Color.jotRaised, in: .circle)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Discard recording")
                    .transition(.scale.combined(with: .opacity))
                }
            }

            if recorder.phase.isActive {
                LevelBars(levels: recorder.levels)
                    .frame(height: 28)
                    .transition(.opacity)
                Text(recorder.liveText.isEmpty ? "Listening…" : recorder.liveText)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(recorder.liveText.isEmpty ? Color.jotTextSecondary : Color.jotTextPrimary)
                    .lineLimit(5)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            if case .failed(let message) = recorder.phase {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.jotCaption)
                    .foregroundStyle(Color.jotReminder)
                    .onTapGesture { recorder.clearError() }
            }
        }
        .jotCard()
        .overlay {
            RoundedRectangle(cornerRadius: JotMetrics.cornerRadius, style: .continuous)
                .strokeBorder(Color.jotAccent.opacity(recorder.isRecording ? 0.6 : 0), lineWidth: 1.5)
        }
        .animation(animation, value: recorder.phase)
        .sensoryFeedback(trigger: recorder.toggleCount) { _, _ in
            recorder.isRecording ? .impact(weight: .heavy) : .impact(weight: .light)
        }
        .sensoryFeedback(.success, trigger: savedFlash)
        .onAppear { if autoStart { recorder.start() } }
    }

    private var title: String {
        switch recorder.phase {
        case .recording: "Recording, tap to save"
        case .finishing: "Saving…"
        case .starting: "Getting ready…"
        default: savedFlash > 0 ? "Saved. Tap to add another" : "Tap to record a note"
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if case .recording(let since) = recorder.phase {
            Text(timerInterval: since...Date.distantFuture, countsDown: false)
                .font(.jotTimeSmall)
                .foregroundStyle(Color.jotAccent)
        } else {
            Text(screen.map { "Screen: \($0) · words kept as you say them" } ?? "Words kept as you say them")
                .font(.jotCaption)
                .foregroundStyle(Color.jotTextSecondary)
        }
    }

    private var symbol: String {
        switch recorder.phase {
        case .recording: "stop.fill"
        case .finishing: "sparkles"
        default: "mic.fill"
        }
    }

    private func toggle() {
        if recorder.isRecording {
            Task {
                if let note = await recorder.stop(screen: screen, into: modelContext) {
                    savedFlash += 1
                    onSaved(note)
                }
            }
        } else {
            recorder.start()
        }
    }
}

private struct LevelBars: View {
    let levels: [Float]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(Color.jotAccent.opacity(0.35 + Double(level) * 0.65))
                    .frame(maxWidth: .infinity)
                    .frame(height: 3 + CGFloat(level) * 25)
            }
        }
        .animation(.easeOut(duration: 0.12), value: levels)
        .accessibilityHidden(true)
    }
}

// MARK: - Card

private struct DevNoteCard: View {
    let note: DevNote
    var onToggleDone: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: note.category.symbol)
                        .font(.jotLabel)
                    Text(note.category.label.uppercased())
                        .font(.jotLabel)
                        .tracking(0.6)
                }
                .foregroundStyle(note.category.color)

                Text(note.text.isEmpty ? "No words caught. Tap to listen." : note.text)
                    .font(.jotBody)
                    .foregroundStyle(note.isDone || note.text.isEmpty ? Color.jotTextSecondary : Color.jotTextPrimary)
                    .strikethrough(note.isDone, color: Color.jotTextSecondary)
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    if let screen = note.screen {
                        Text(screen)
                        Text("·")
                    }
                    Text(note.createdAt.formatted(.relative(presentation: .named)))
                    if note.audioFileName != nil {
                        Text("·")
                        Image(systemName: "waveform")
                        Text(Duration.seconds(note.duration).formatted(.time(pattern: .minuteSecond)))
                    }
                }
                .font(.jotTimeSmall)
                .foregroundStyle(Color.jotTextSecondary)
            }
            Spacer(minLength: 0)
            Button(action: onToggleDone) {
                CheckCircle(isChecked: note.isDone, color: .jotTask)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(note.isDone ? "Mark as open" : "Mark as done")
        }
        .jotCard()
        .overlay(alignment: .leading) {
            Capsule().fill(note.category.color).frame(width: 3).padding(.vertical, 18)
        }
        .opacity(note.isDone ? 0.7 : 1)
        .contentShape(.rect)
        .sensoryFeedback(.success, trigger: note.isDone) { _, done in done }
    }
}

extension DevNote.Category {
    var color: Color {
        switch self {
        case .bug: .jotAccent
        case .change: .jotEvent
        case .idea: .jotNote
        }
    }
}

// MARK: - Editor

private struct DevNoteEditor: View {
    @Bindable var note: DevNote
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var playback = AudioPlayback()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ChipPicker(
                        options: DevNote.Category.allCases.map { .init(value: $0, label: $0.label, color: $0.color) },
                        selection: $note.category,
                        inset: 0
                    )

                    TextField("What should change?", text: $note.text, axis: .vertical)
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .foregroundStyle(Color.jotTextPrimary)
                        .lineLimit(3...20)
                        .jotCard()

                    if playback.isLoaded {
                        PlaybackCard(playback: playback, color: note.category.color)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if let screen = note.screen { metaRow("Screen", screen) }
                        metaRow("Captured", note.createdAt.formatted(date: .abbreviated, time: .shortened))
                        metaRow("App version", note.appVersion)
                    }
                    .jotCard()

                    Toggle("Done", isOn: $note.isDone)
                        .font(.jotHeadline)
                        .tint(Color.jotTask)
                        .jotCard()

                    Button("Delete note", systemImage: "trash", role: .destructive) {
                        playback.stop()
                        DevNoteActions.delete(note, in: modelContext)
                        dismiss()
                    }
                    .font(.jotHeadline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
                .padding(JotMetrics.gutter)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.jotBackground.ignoresSafeArea())
            .navigationTitle("Change note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await playback.load(fileName: note.audioFileName) }
            .onDisappear {
                playback.stop()
                try? modelContext.save()
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func metaRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Color.jotTextSecondary)
            Spacer()
            Text(value).foregroundStyle(Color.jotTextPrimary)
        }
        .font(.jotCaption)
    }
}

// MARK: - Quick capture (shake from anywhere)

/// A small sheet that starts recording right away, tagged with the screen you were on.
struct QuickDevNoteSheet: View {
    let screen: String
    @Environment(\.dismiss) private var dismiss
    @State private var recorder = DevNoteRecorder.make()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Change note", systemImage: "hammer.fill")
                    .font(.jotHeadline)
                    .foregroundStyle(Color.jotTextPrimary)
                Spacer()
                Button("Close") {
                    recorder.cancel()
                    dismiss()
                }
                .font(.jotHeadline)
                .foregroundStyle(Color.jotTextSecondary)
            }
            DevRecorderCard(recorder: recorder, screen: screen, autoStart: true) { _ in
                Task {
                    try? await Task.sleep(for: .milliseconds(700))
                    dismiss()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(JotMetrics.gutter)
        .background(Color.jotBackground.ignoresSafeArea())
        .presentationDetents([.height(320), .medium])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(recorder.phase.isActive)
    }
}

// MARK: - Sharing

struct ExportFile: Identifiable {
    let url: URL
    var id: URL { url }
}

/// The system share sheet: Save to Files, AirDrop, Mail, Messages, and so on.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
