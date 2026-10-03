import SwiftUI

/// Shown instead of the app when the store can't be opened (ADR-001), so
/// nothing is captured into a store that would be thrown away on quit.
struct StoreUnavailableView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.jotAccent)
            Text("Jot couldn't open your notes")
                .font(.jotDisplay)
                .tracking(-0.8)
                .foregroundStyle(Color.jotTextPrimary)
            Text("Jot hasn't deleted anything. Close Jot from the app switcher and open it again. Recording is paused until then, so nothing new gets lost.")
                .font(.system(.title3))
                .foregroundStyle(Color.jotTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("If this keeps happening, restart your iPhone or update Jot.")
                .font(.jotBody)
                .foregroundStyle(Color.jotTextSecondary)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.jotBackground.ignoresSafeArea())
    }
}

#Preview {
    StoreUnavailableView()
}
