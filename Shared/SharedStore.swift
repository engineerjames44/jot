import Foundation
import SwiftData

/// The SwiftData store, kept in the App Group container so the app, its
/// widgets, and its intents all read the same items.
enum SharedStore {
    static let appGroup = "group.com.jamescronin.Jot"

    static var storeURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            // Falls back to the app's own container if the group isn't provisioned yet.
            ?? URL.applicationSupportDirectory
        return base.appending(path: "Jot.store")
    }

    static let container: ModelContainer = {
        migrateLegacyStoreIfNeeded()
        let configuration = ModelConfiguration(url: storeURL)
        do {
            return try ModelContainer(for: JotItem.self, DevNote.self, configurations: configuration)
        } catch {
            // Never crash-loop on launch; run in memory and surface it in the console.
            print("Jot: couldn't open the store at \(storeURL.path): \(error)")
            return try! ModelContainer(for: JotItem.self, DevNote.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
    }()

    /// Earlier builds used SwiftData's default location in the app's own
    /// container. Copy that store (and its WAL files) into the group once.
    private static func migrateLegacyStoreIfNeeded() {
        let fileManager = FileManager.default
        let legacy = URL.applicationSupportDirectory.appending(path: "default.store")
        let target = storeURL
        guard legacy != target,
              fileManager.fileExists(atPath: legacy.path),
              !fileManager.fileExists(atPath: target.path)
        else { return }

        try? fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        for suffix in ["", "-shm", "-wal"] {
            let source = URL(filePath: legacy.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            try? fileManager.copyItem(at: source, to: URL(filePath: target.path + suffix))
        }
    }
}
