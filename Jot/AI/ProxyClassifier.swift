import Foundation

/// Sorts a transcript through Jot's server, which holds the prompt, the model,
/// and the API key (ADR-002). Users never need a key of their own.
struct ProxyClassifier: Sendable {
    static let defaultBaseURL = URL(string: "https://www.jamescronin.dev")!

    var baseURL: URL = Self.configuredBaseURL
    var session: URLSession = .shared

    /// Debug builds can point at a local server: `-JotAPIBaseURL http://localhost:3000`.
    static var configuredBaseURL: URL {
        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: "JotAPIBaseURL"), let url = URL(string: override) {
            return url
        }
        #endif
        return defaultBaseURL
    }

    nonisolated func classify(
        transcript: String,
        now: Date = .now,
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) async throws -> ClassifiedItem {
        let iso = ISO8601DateFormatter()
        iso.timeZone = timeZone
        iso.formatOptions = [.withInternetDateTime]

        var request = URLRequest(url: baseURL.appending(path: "api/jot/classify"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(InstallID.current, forHTTPHeaderField: "x-jot-install")
        request.setValue(Bundle.main.appVersion, forHTTPHeaderField: "x-jot-version")
        request.httpBody = try JSONEncoder().encode([
            "transcript": transcript,
            "now": iso.string(from: now),
            "timeZone": timeZone.identifier,
            "locale": locale.identifier,
        ])

        do {
            return try await send(request)
        } catch let error as SortingError where error.isRetryable {
            try await Task.sleep(for: .seconds(1.5))
            return try await send(request)
        }
    }

    private nonisolated func send(_ request: URLRequest) async throws -> ClassifiedItem {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SortingError.offline
        }
        guard let http = response as? HTTPURLResponse else { throw SortingError.unavailable }

        guard http.statusCode == 200 else {
            let code = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw SortingError(status: http.statusCode, code: code)
        }
        do {
            var item = try JSONDecoder().decode(ClassifiedItem.self, from: data)
            item.title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            item.details = item.details.trimmingCharacters(in: .whitespacesAndNewlines)
            return item
        } catch {
            throw SortingError.unreadable
        }
    }
}

/// Why sorting didn't happen, in words a user can act on. The capture is kept
/// as a note either way.
enum SortingError: LocalizedError, Equatable {
    case offline
    case busy
    case dailyLimit
    case unavailable
    case unreadable
    case notAllowed
    case onDeviceUnavailable

    init(status: Int, code: String?) {
        switch (status, code) {
        case (429, "daily_limit"): self = .dailyLimit
        case (429, _): self = .busy
        case (422, _), (400, _): self = .unreadable
        default: self = .unavailable
        }
    }

    var errorDescription: String? {
        switch self {
        case .offline: "You're offline, so Jot couldn't sort it."
        case .busy: "Jot is busy right now, so it couldn't sort it."
        case .dailyLimit: "Jot has reached today's sorting limit."
        case .unavailable: "Jot's sorting is unavailable right now."
        case .unreadable: "Jot couldn't work out what kind of item this is."
        case .notAllowed: "Smart sorting is off. You can turn it on in Settings."
        case .onDeviceUnavailable: "Apple Intelligence isn't available, so this was saved as a note. It'll be sorted when it is."
        }
    }

    var isRetryable: Bool { self == .busy || self == .unavailable }
}

/// A random ID for this install, used only for fair rate limiting on Jot's server.
/// Not linked to the person; a reinstall gets a new one.
enum InstallID {
    private static let key = "JotInstallID"

    static var current: String {
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }
}

/// The classifier captures and Siri use: on this iPhone by default, or Claude
/// through Jot's server when the person has chosen it.
enum Classifier {
    /// Whether anything can sort right now. When false, captures stay notes
    /// and are sorted later.
    static var canSort: Bool {
        SmartSorting.engine == .onDevice ? OnDeviceClassifier.isAvailable : SmartSorting.isAllowed
    }

    static func classify(_ transcript: String) async throws -> ClassifiedItem {
        if SmartSorting.engine == .onDevice {
            guard OnDeviceClassifier.isAvailable else { throw SortingError.onDeviceUnavailable }
            return try await OnDeviceClassifier().classify(transcript: transcript)
        }
        // Nothing leaves the device without permission.
        guard SmartSorting.isAllowed else { throw SortingError.notAllowed }
        #if DEBUG
        // A personal key in Settings keeps calling Claude directly, for experiments.
        if KeychainStore.apiKey()?.isEmpty == false {
            return try await ClaudeClassifier().classify(transcript: transcript)
        }
        #endif
        return try await ProxyClassifier().classify(transcript: transcript)
    }
}
