import AppIntents
import Foundation
import SwiftData

/// "Jot this": Siri asks what to jot, Claude sorts it, and it's saved
/// without opening the app.
struct JotThisIntent: AppIntent {
    static let title: LocalizedStringResource = "Jot This"
    static let description = IntentDescription(
        "Capture a note, task, reminder, or event without opening Jot.",
        categoryName: "Capture"
    )

    @Parameter(title: "What to jot", requestValueDialog: "What should I jot down?")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Jot \(\.$text)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let transcript = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            return .result(dialog: "There was nothing to jot.")
        }

        guard SharedStore.canWrite else {
            return .result(dialog: "Jot can't open your notes right now, so nothing was saved. Open Jot for details.")
        }
        let context = SharedStore.container.mainContext
        let dialog: IntentDialog
        do {
            let result = try await Classifier.classify(transcript)
            let item = CaptureController.insert(result, transcript: transcript, into: context)
            dialog = Self.confirmation(for: item)
        } catch {
            // Never lose it: keep the words as a note and say why.
            let fallback = ClassifiedItem(type: .note, title: String(transcript.prefix(60)), details: "")
            let item = CaptureController.insert(fallback, transcript: transcript, into: context)
            item.needsSorting = true
            try? context.save()
            dialog = "Saved it as a note. \(error.localizedDescription)"
        }

        await ReminderScheduler.refill(using: context)
        return .result(dialog: dialog)
    }

    private static func confirmation(for item: JotItem) -> IntentDialog {
        let kind = item.kind.label.lowercased()
        if let due = item.dueDate {
            return "Got it. \(item.title), \(kind) for \(JotDate.short(due))."
        }
        return "Got it. \(item.title), saved as a \(kind)."
    }
}

/// Phrases Siri and Spotlight offer without any setup.
struct JotShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: JotThisIntent(),
            phrases: [
                "\(.applicationName) this",
                "\(.applicationName) something down",
                "Add to \(.applicationName)",
            ],
            shortTitle: "Jot This",
            systemImageName: "text.badge.plus"
        )
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Record with \(.applicationName)",
                "Start \(.applicationName)",
            ],
            shortTitle: "Record",
            systemImageName: "mic.fill"
        )
    }
}
