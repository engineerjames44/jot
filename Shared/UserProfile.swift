import Foundation

/// What Jot knows about the person using it: just a name to greet them by.
/// Kept in the App Group defaults so widgets and notifications can use it too.
enum UserProfile {
    static let nameKey = "JotUserName"
    // UserDefaults is thread-safe; it just isn't marked Sendable.
    nonisolated(unsafe) static let defaults = UserDefaults(suiteName: SharedStore.appGroup) ?? .standard

    /// The name as typed in onboarding or Settings, trimmed. Empty if not set.
    static var name: String { cleaned(defaults.string(forKey: nameKey) ?? "") }

    static func cleaned(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "James Cronin" greets as "James": the first word is what people use.
    static func firstName(_ name: String) -> String {
        cleaned(name).split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
    }

    /// "Good morning, James", or just "Good morning" without a name.
    static func greeting(at date: Date, name: String) -> String {
        let first = firstName(name)
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: return first.isEmpty ? "Good morning" : "Good morning, \(first)"
        case 12..<17: return first.isEmpty ? "Good afternoon" : "Good afternoon, \(first)"
        case 17..<22: return first.isEmpty ? "Good evening" : "Good evening, \(first)"
        default: return first.isEmpty ? "Hello, night owl" : "Still up, \(first)?"
        }
    }
}
