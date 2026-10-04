import SwiftData
import SwiftUI

/// How captures get sorted. On this iPhone by default (Apple's on-device model,
/// nothing sent). Claude is a choice the person makes with the disclosure in
/// front of them (App Review guideline 5.1.2(i)); picking it is the consent.
enum SmartSorting {
    /// Consent to send what was said to Jot's server and Claude.
    static let key = "JotSmartSortingAllowed"
    static let engineKey = "JotSortingEngine"
    static let privacyPolicy = URL(string: "https://www.jamescronin.dev/jot/privacy")!

    enum Engine: String, CaseIterable, Identifiable {
        case onDevice, claude
        var id: String { rawValue }
        var label: String { self == .onDevice ? "On this iPhone" : "Claude" }
    }

    static var isAllowed: Bool { UserDefaults.standard.bool(forKey: key) }

    static var engine: Engine {
        UserDefaults.standard.string(forKey: engineKey).flatMap(Engine.init) ?? .onDevice
    }

    /// For Settings' About card.
    static var engineDescription: String {
        engine == .onDevice ? "Apple Intelligence, on device" : "Claude Haiku 4.5"
    }
}

/// The choice of where sorting happens, with what each option means.
struct SmartSortingCard: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SmartSorting.engineKey) private var engine = SmartSorting.Engine.onDevice
    @AppStorage(SmartSorting.key) private var claudeAllowed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: engine == .onDevice ? "iphone" : "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.jotTextPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.jotRaised, in: .rect(cornerRadius: 14, style: .continuous))
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sorting")
                        .font(.jotHeadline)
                        .foregroundStyle(Color.jotTextPrimary)
                    Text("Turns what you say into a note, task, reminder, or event")
                        .font(.jotCaption)
                        .foregroundStyle(Color.jotTextSecondary)
                }
            }

            Picker("Sort with", selection: $engine) {
                ForEach(SmartSorting.Engine.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            Text(explanation)
                .font(.jotCaption)
                .foregroundStyle(Color.jotTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)

            if engine == .claude {
                Link("Privacy policy", destination: SmartSorting.privacyPolicy)
                    .font(.jotCaption.weight(.semibold))
                    .foregroundStyle(Color.jotTextPrimary)
                    .underline()
            }
        }
        .jotCard()
        .animation(.jot, value: engine)
        .sensoryFeedback(.selection, trigger: engine)
        .onChange(of: engine) { _, chosen in
            // Choosing Claude, with this text on screen, is the consent to send.
            claudeAllowed = chosen == .claude
            Task { await SortLater.retryPending(in: modelContext) }
        }
    }

    private var explanation: String {
        switch engine {
        case .onDevice:
            if let reason = OnDeviceClassifier.unavailableReason {
                return reason + " Until then, captures are saved as notes and sorted later, or you can choose Claude."
            }
            return "Apple's on-device model sorts what you say. Nothing leaves your iPhone, and it works offline."
        case .claude:
            return "More accurate with dates and longer notes. Jot sends the words (never the recording) to its server and to Anthropic's Claude. Jot's server doesn't keep them."
        }
    }
}

#Preview {
    SmartSortingCard()
        .padding()
        .background(Color.jotBackground)
}
