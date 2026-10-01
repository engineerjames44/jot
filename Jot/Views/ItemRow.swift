import SwiftUI

struct ItemRow: View {
    let item: JotItem
    var showsTime = false
    var isOverdue = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    .lineLimit(2)

                if !item.details.isEmpty {
                    Text(item.details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let meta = metadata {
                    Text(meta)
                        .font(.caption)
                        .foregroundStyle(isOverdue ? .red : .secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var icon: String {
        if item.isCompleted { return "checkmark.circle.fill" }
        if item.recurrence != nil, item.kind == .reminder { return "bell.badge" }
        return item.kind.symbol
    }

    private var tint: Color {
        switch item.kind {
        case .note: .yellow
        case .task: .blue
        case .reminder: .orange
        case .event: .purple
        }
    }

    private var metadata: String? {
        var parts: [String] = []
        if item.kind == .note {
            parts.append(showsTime
                ? item.createdAt.formatted(date: .omitted, time: .shortened)
                : item.createdAt.formatted(.relative(presentation: .named)))
        } else if let due = item.dueDate {
            if showsTime {
                parts.append(due.formatted(date: .omitted, time: .shortened))
            } else {
                parts.append(due.formatted(date: .abbreviated, time: .shortened))
            }
            if isOverdue { parts.append("Overdue") }
        }
        if let recurrence = item.recurrence {
            parts.append("Repeats \(recurrence.label.lowercased())")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
