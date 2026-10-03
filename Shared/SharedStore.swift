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

    /// The store, opened once with the versioned schema (ADR-001). If opening
    /// fails, `openError` says why and the container is an empty in-memory store
    /// that exists only so the app can launch and explain. Nothing may write to it.
    private static let loaded: (container: ModelContainer, openError: String?) = {
        migrateLegacyStoreIfNeeded()
        let schema = Schema(versionedSchema: JotSchemaV1.self)
        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: JotMigrationPlan.self,
                configurations: ModelConfiguration(url: storeURL)
            )
            return (container, nil)
        } catch {
            print("Jot: couldn't open the store at \(storeURL.path): \(error)")
            let placeholder = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            return (placeholder, String(describing: error))
        }
    }()

    static var container: ModelContainer { loaded.container }

    /// Why the store couldn't be opened, if it couldn't.
    static var openError: String? { loaded.openError }

    /// False when captures would be lost because the real store isn't open.
    static var canWrite: Bool { openError == nil }

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
