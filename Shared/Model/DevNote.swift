import Foundation
import SwiftData

/// A note to self about a change to make to Jot, captured while using it.
@Model
final class DevNote {
    enum Category: String, CaseIterable, Identifiable, Sendable {
        case bug, change, idea

        var id: String { rawValue }

        var label: String {
            switch self {
            case .bug: "Bug"
            case .change: "Change"
            case .idea: "Idea"
            }
        }

        var plural: String {
            switch self {
            case .bug: "Bugs"
            case .change: "Changes"
            case .idea: "Ideas"
            }
        }

        var symbol: String {
            switch self {
            case .bug: "ladybug.fill"
            case .change: "slider.horizontal.3"
            case .idea: "lightbulb.fill"
            }
        }
    }

    @Attribute(.unique) var id: UUID
    var text: String
    var categoryRaw: String
    /// The screen you were on when you made the note, if known.
    var screen: String?
    /// App version and build when the note was made, e.g. "1.0 (1)".
    var appVersion: String
    var createdAt: Date
    var isDone: Bool
    var audioFileName: String?
    var duration: Double

    init(
        text: String,
        category: Category = .change,
        screen: String? = nil,
        appVersion: String,
        audioFileName: String? = nil,
        duration: Double = 0,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.text = text
        self.categoryRaw = category.rawValue
        self.screen = screen
        self.appVersion = appVersion
        self.createdAt = createdAt
        self.isDone = false
        self.audioFileName = audioFileName
        self.duration = duration
    }

    var category: Category {
        get { Category(rawValue: categoryRaw) ?? .change }
        set { categoryRaw = newValue.rawValue }
    }
}
