import SwiftUI

/// Permission to send what was said to a third-party AI. Asked before anything
/// leaves the device (App Review guideline 5.1.2(i)); off until turned on.
enum SmartSorting {
    static let key = "JotSmartSortingAllowed"
    static let privacyPolicy = URL(string: "https://jamescronin.dev/jot/privacy")!

    static var isAllowed: Bool { UserDefaults.standard.bool(forKey: key) }
}

/// The switch for smart sorting, with what it sends and to whom.
struct SmartSortingCard: View {
    @AppStorage(SmartSorting.key) private var isAllowed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isAllowed ? Color.jotTask : Color.jotAccent)
                    .frame(width: 44, height: 44)
                    .background(Color.jotRaised, in: .rect(cornerRadius: 14, style: .continuous))
                Text("Smart sorting")
                    .font(.jotHeadline)
                    .foregroundStyle(Color.jotTextPrimary)
                Spacer(minLength: 4)
                Toggle("Smart sorting", isOn: $isAllowed)
                    .labelsHidden()
                    .tint(Color.jotAccent)
            }
            Text("To turn what you said into a note, task, reminder, or event, Jot sends the words (never the recording) to its server and to Anthropic's Claude. Jot's server doesn't keep them. When this is off, captures are saved as notes.")
                .font(.jotCaption)
                .foregroundStyle(Color.jotTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Link("Privacy policy", destination: SmartSorting.privacyPolicy)
                .font(.jotCaption.weight(.semibold))
                .foregroundStyle(Color.jotAccent)
        }
        .jotCard()
        .sensoryFeedback(.selection, trigger: isAllowed)
    }
}

#Preview {
    SmartSortingCard()
        .padding()
        .background(Color.jotBackground)
}
