import SwiftData
import SwiftUI

/// Follow-ups to an item, newest last, with a button to record another (ADR-004).
struct FollowUps: View {
    var onAdd: () -> Void
    @Query private var followUps: [JotItem]
    @Environment(CaptureController.self) private var capture

    init(parentID: UUID, onAdd: @escaping () -> Void) {
        self.onAdd = onAdd
        _followUps = Query(
            filter: #Predicate<JotItem> { $0.parentID == parentID },
            sort: \.createdAt
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Follow-ups")
                .font(.jotSection)
                .foregroundStyle(Color.jotTextSecondary)

            ForEach(followUps) { followUp in
                NavigationLink(value: followUp) {
                    HStack(alignment: .top, spacing: 10) {
                        KindDot(color: followUp.kind.color, size: 8)
                            .padding(.top, 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(followUp.title)
                                .font(.jotBodyEmphasis)
                                .foregroundStyle(Color.jotTextPrimary)
                                .multilineTextAlignment(.leading)
                            Text(followUp.dueDate.map { "\(followUp.kind.label) · \(JotDate.short($0))" }
                                 ?? followUp.createdAt.formatted(.relative(presentation: .named)))
                                .font(.jotTimeSmall)
                                .foregroundStyle(Color.jotTextSecondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.jotTextSecondary)
                            .padding(.top, 4)
                    }
                    .jotRow()
                }
                .buttonStyle(.pressable)
            }

            Button(action: onAdd) {
                Label("Add a follow-up", systemImage: "mic.fill")
                    .font(.jotHeadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.jotSecondary)
            .disabled(capture.phase.isBusy)
            .accessibilityHint("Records a follow-up and stops when you pause.")
        }
    }
}

/// "Follow-up to …" at the top of a follow-up, linking back to its item.
struct ParentLink: View {
    @Query private var parents: [JotItem]

    init(parentID: UUID) {
        _parents = Query(filter: #Predicate<JotItem> { $0.id == parentID })
    }

    var body: some View {
        // A deleted parent leaves this as an ordinary item (ADR-004).
        if let parent = parents.first {
            NavigationLink(value: parent) {
                Label("Follow-up to \(parent.title)", systemImage: "arrowshape.turn.up.left")
                    .font(.jotCaption.weight(.semibold))
                    .foregroundStyle(Color.jotAccentText)
                    .lineLimit(1)
            }
        }
    }
}

/// Shown on a capture that was kept as a note without being sorted.
struct NotSortedBanner: View {
    let isSorting: Bool
    var onSort: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.jotReminder)
            Text("Not sorted yet. Jot will try again, or sort it now.")
                .font(.jotCaption)
                .foregroundStyle(Color.jotTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(isSorting ? "Sorting…" : "Sort now", action: onSort)
                .buttonStyle(.jotSecondary)
                .controlSize(.small)
                .disabled(isSorting)
                .fixedSize()
        }
        .jotRow()
    }
}
