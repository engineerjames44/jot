import Foundation

/// URLs the widgets and notifications use to open the app at the right place.
enum JotLink: Equatable {
    /// Start a hands-free recording.
    case record
    /// Open an item.
    case item(UUID)

    var url: URL {
        switch self {
        case .record: URL(string: "jot://record")!
        case .item(let id): URL(string: "jot://item/\(id.uuidString)")!
        }
    }

    init?(url: URL) {
        guard url.scheme == "jot" else { return nil }
        switch url.host() {
        case "record":
            self = .record
        case "item":
            guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            self = .item(id)
        default:
            return nil
        }
    }
}
