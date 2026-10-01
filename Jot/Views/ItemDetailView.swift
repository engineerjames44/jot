import SwiftData
import SwiftUI

struct ItemDetailView: View {
    @Bindable var item: JotItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $item.title, axis: .vertical)
                    .font(.headline)
                TextField("Details", text: $item.details, axis: .vertical)
                    .lineLimit(2...8)
            }

            Section {
                Picker("Type", selection: $item.kind) {
                    ForEach(ItemKind.allCases) { kind in
                        Label(kind.label, systemImage: kind.symbol).tag(kind)
                    }
                }

                if item.kind != .note {
                    Toggle("Date", isOn: hasDueDate)
                    if let dueDate = Binding($item.dueDate) {
                        DatePicker("When", selection: dueDate)
                        Picker("Repeat", selection: $item.recurrence) {
                            Text("Never").tag(Recurrence?.none)
                            ForEach(Recurrence.allCases) { Text($0.label).tag(Optional($0)) }
                        }
                    }
                }

                if item.kind == .task || item.kind == .reminder {
                    Toggle("Completed", isOn: $item.isCompleted)
                }
            }

            Section("What you said") {
                Text(item.transcript.isEmpty ? "No transcript" : item.transcript)
                    .foregroundStyle(item.transcript.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                LabeledContent("Captured", value: item.createdAt.formatted(date: .abbreviated, time: .shortened))
            }

            Section {
                Button("Delete", role: .destructive) { confirmingDelete = true }
            }
        }
        .navigationTitle(item.kind.label)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this item?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(item)
                try? modelContext.save()
                Task { await ReminderScheduler.refill(using: modelContext) }
                dismiss()
            }
        }
        .onDisappear {
            try? modelContext.save()
            Task { await ReminderScheduler.refill(using: modelContext) }
        }
    }

    private var hasDueDate: Binding<Bool> {
        Binding(
            get: { item.dueDate != nil },
            set: { on in
                if on {
                    item.dueDate = Calendar.current.nextDate(
                        after: .now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime
                    )
                } else {
                    item.dueDate = nil
                    item.recurrence = nil
                }
            }
        )
    }
}
