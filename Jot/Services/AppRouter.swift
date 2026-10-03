import Observation
import SwiftUI

/// Where a notification or widget tap asked to go. RootView switches to Inbox
/// and Inbox pushes the item.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()
    var itemToOpen: UUID?
}
