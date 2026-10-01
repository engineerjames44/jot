import AVFAudio
import EventKit
import Foundation
import Observation
import Speech
import UserNotifications

/// One place to read and request the permissions Jot uses.
@MainActor
@Observable
final class PermissionCenter {
    enum Kind: CaseIterable, Identifiable {
        case microphone, speech, notifications, calendar
        var id: Self { self }

        var title: String {
            switch self {
            case .microphone: "Microphone"
            case .speech: "Speech recognition"
            case .notifications: "Notifications"
            case .calendar: "Calendars"
            }
        }

        var symbol: String {
            switch self {
            case .microphone: "mic.fill"
            case .speech: "waveform"
            case .notifications: "bell.badge.fill"
            case .calendar: "calendar"
            }
        }

        /// Why Jot asks — shown before the system prompt.
        var reason: String {
            switch self {
            case .microphone: "Hear you only while you're recording, and never otherwise."
            case .speech: "Turn your voice into words, right here on your iPhone."
            case .notifications: "Nudge you when a reminder is due, and send your morning brief."
            case .calendar: "Show your events on the Today timeline. Jot never changes them."
            }
        }
    }

    enum Status: Equatable {
        case notDetermined, granted, denied
    }

    private(set) var statuses: [Kind: Status] = [:]

    func status(_ kind: Kind) -> Status { statuses[kind] ?? .notDetermined }

    func refresh() async {
        statuses[.microphone] = switch AVAudioApplication.shared.recordPermission {
        case .granted: .granted
        case .denied: .denied
        default: .notDetermined
        }

        statuses[.speech] = switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: .granted
        case .denied, .restricted: .denied
        default: .notDetermined
        }

        let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
        statuses[.notifications] = switch notificationSettings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: .granted
        case .denied: .denied
        default: .notDetermined
        }

        statuses[.calendar] = switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    func request(_ kind: Kind, calendar: CalendarService) async {
        switch kind {
        case .microphone:
            _ = await AVAudioApplication.requestRecordPermission()
        case .speech:
            await Self.requestSpeechAuthorization()
        case .notifications:
            _ = await ReminderScheduler.ensureAuthorized()
        case .calendar:
            await calendar.requestAccess()
        }
        await refresh()
    }

    /// Nonisolated: the callback arrives on a background queue, and a closure
    /// created on the main actor would trap there.
    private nonisolated static func requestSpeechAuthorization() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            SFSpeechRecognizer.requestAuthorization { _ in continuation.resume() }
        }
    }
}
