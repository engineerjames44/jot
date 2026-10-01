import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(CalendarService.self) private var calendar
    @State private var keyInput = ""
    @State private var savedKeySuffix: String?
    @State private var message: String?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let savedKeySuffix {
                        LabeledContent("Saved key", value: "••••\(savedKeySuffix)")
                    }
                    SecureField(savedKeySuffix == nil ? "sk-ant-…" : "Replace key", text: $keyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.password)
                        .onSubmit(saveKey)
                    Button("Save key", action: saveKey)
                        .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if savedKeySuffix != nil {
                        Button("Remove key", role: .destructive, action: removeKey)
                    }
                } header: {
                    Text("Claude API key")
                } footer: {
                    Text(message ?? "Stored only in this device's Keychain. Used to sort your recordings into notes, tasks, reminders, and events.")
                }

                Section("Permissions") {
                    LabeledContent("Calendar") {
                        if calendar.hasAccess {
                            Text("Read-only access").foregroundStyle(.secondary)
                        } else if calendar.authorization == .notDetermined {
                            Button("Allow") { Task { await calendar.requestAccess() } }
                        } else {
                            Button("Open Settings", action: openSystemSettings)
                        }
                    }
                    LabeledContent("Notifications") {
                        switch notificationStatus {
                        case .authorized, .provisional, .ephemeral:
                            Text("On").foregroundStyle(.secondary)
                        case .notDetermined:
                            Button("Allow") {
                                Task {
                                    _ = await ReminderScheduler.ensureAuthorized()
                                    await refreshNotificationStatus()
                                }
                            }
                        default:
                            Button("Open Settings", action: openSystemSettings)
                        }
                    }
                }

                Section {
                    LabeledContent("Model", value: ClaudeClassifier.model)
                    LabeledContent("Transcription", value: "On-device")
                } header: {
                    Text("About")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.jotBackground.ignoresSafeArea())
            .navigationTitle("Settings")
            .onAppear(perform: loadKey)
            .task { await refreshNotificationStatus() }
        }
    }

    private func loadKey() {
        savedKeySuffix = KeychainStore.apiKey().map { String($0.suffix(4)) }
    }

    private func saveKey() {
        let key = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        do {
            try KeychainStore.setAPIKey(key)
            keyInput = ""
            message = "Key saved to the Keychain."
            loadKey()
        } catch {
            message = error.localizedDescription
        }
    }

    private func removeKey() {
        do {
            try KeychainStore.deleteAPIKey()
            message = "Key removed."
            loadKey()
        } catch {
            message = error.localizedDescription
        }
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func openSystemSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
