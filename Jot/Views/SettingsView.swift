import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(CalendarService.self) private var calendar
    @Environment(\.jotAnimation) private var animation
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("JotHasOnboarded") private var hasOnboarded = false
    #if DEBUG
    @AppStorage(DevMode.enabledKey) private var devModeEnabled = DevMode.defaultEnabled
    #endif

    @State private var permissions = PermissionCenter()
    @State private var keyInput = ""
    @State private var savedKeySuffix: String?
    @State private var keyMessage: KeyMessage?
    @FocusState private var keyFocused: Bool

    private struct KeyMessage: Equatable {
        let text: String
        let isError: Bool
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    #if DEBUG
                    // Release builds sort through Jot's server; a personal key is
                    // only for development.
                    section("Claude") { apiKeyCard }
                    #endif

                    section("Morning brief") { MorningBriefCard() }

                    section("Permissions") {
                        VStack(spacing: 10) {
                            ForEach(PermissionCenter.Kind.allCases) { kind in
                                PermissionRow(kind: kind, status: permissions.status(kind)) {
                                    Task { await permissions.request(kind, calendar: calendar) }
                                }
                            }
                        }
                    }

                    #if DEBUG
                    section("Developer") { developerCard }
                    #endif

                    section("About") { aboutCard }
                }
                .padding(.horizontal, JotMetrics.gutter)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Color.jotBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: loadKey)
            .task { await permissions.refresh() }
            .onChange(of: scenePhase) { _, phase in
                // Pick up changes made in the Settings app.
                if phase == .active { Task { await permissions.refresh() } }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Wordmark(size: 56)
            Text("Hold. Speak. Done.")
                .font(.jotHeadline)
                .foregroundStyle(Color.jotTextSecondary)
        }
        .padding(.top, 20)
        .accessibilityElement(children: .combine)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title)
            content()
        }
    }

    // MARK: API key

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.jotAccent)
                    .frame(width: 44, height: 44)
                    .background(Color.jotRaised, in: .rect(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("API key")
                        .font(.jotHeadline)
                        .foregroundStyle(Color.jotTextPrimary)
                    if let savedKeySuffix {
                        HStack(spacing: 6) {
                            KindDot(color: .jotTask, size: 7)
                            Text("Saved · ends in \(savedKeySuffix)")
                                .font(.jotTimeSmall)
                                .foregroundStyle(Color.jotTextSecondary)
                        }
                    } else {
                        Text("Needed to sort what you say")
                            .font(.jotCaption)
                            .foregroundStyle(Color.jotTextSecondary)
                    }
                }
                Spacer()
            }

            HStack(spacing: 10) {
                SecureField(savedKeySuffix == nil ? "sk-ant-…" : "Paste a new key to replace it", text: $keyInput)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.password)
                    .focused($keyFocused)
                    .submitLabel(.done)
                    .onSubmit(saveKey)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.jotRaised, in: .rect(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(keyFocused ? Color.jotAccent.opacity(0.6) : Color.jotBorder, lineWidth: 1)
                    )

                if !keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("Save", action: saveKey)
                        .buttonStyle(.jotPrimary)
                        .controlSize(.small)
                        .fixedSize()
                        .transition(.scale.combined(with: .opacity))
                }
            }

            if let keyMessage {
                Label(keyMessage.text, systemImage: keyMessage.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.jotCaption)
                    .foregroundStyle(keyMessage.isError ? Color.jotReminder : Color.jotTask)
                    .transition(.opacity)
            }

            HStack {
                Label("Stored only in this iPhone's Keychain", systemImage: "lock.fill")
                    .font(.jotCaption)
                    .foregroundStyle(Color.jotTextSecondary)
                Spacer()
                if savedKeySuffix != nil {
                    Button("Remove", role: .destructive, action: removeKey)
                        .font(.jotCaption.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
        }
        .jotCard()
        .animation(animation, value: keyInput.isEmpty)
        .animation(animation, value: keyMessage)
        .animation(animation, value: savedKeySuffix)
        .sensoryFeedback(.success, trigger: savedKeySuffix) { old, new in new != nil && old != new }
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
            keyFocused = false
            keyMessage = KeyMessage(text: "Saved to the Keychain.", isError: false)
            loadKey()
        } catch {
            keyMessage = KeyMessage(text: error.localizedDescription, isError: true)
        }
    }

    private func removeKey() {
        do {
            try KeychainStore.deleteAPIKey()
            keyMessage = KeyMessage(text: "Key removed.", isError: false)
            loadKey()
        } catch {
            keyMessage = KeyMessage(text: error.localizedDescription, isError: true)
        }
    }

    // MARK: Developer

    #if DEBUG
    private var developerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.jotAccent)
                .frame(width: 44, height: 44)
                .background(Color.jotRaised, in: .rect(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Develop tab")
                    .font(.jotHeadline)
                    .foregroundStyle(Color.jotTextPrimary)
                Text("Record change notes about Jot and export them. Shake anywhere to add one.")
                    .font(.jotCaption)
                    .foregroundStyle(Color.jotTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Toggle("Develop tab", isOn: $devModeEnabled)
                .labelsHidden()
                .tint(Color.jotAccent)
        }
        .jotCard()
    }
    #endif

    // MARK: About

    private var aboutCard: some View {
        VStack(spacing: 0) {
            aboutRow("Sorting", value: "Claude Haiku 4.5", symbol: "sparkles")
            Divider().overlay(Color.jotBorder)
            aboutRow("Transcription", value: "On-device", symbol: "waveform")
            Divider().overlay(Color.jotBorder)
            aboutRow("Version", value: Bundle.main.appVersion, symbol: "info.circle")
            Divider().overlay(Color.jotBorder)
            Button {
                hasOnboarded = false
            } label: {
                HStack {
                    Label("Replay the intro", systemImage: "play.circle")
                        .font(.jotBody)
                        .foregroundStyle(Color.jotTextPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.jotTextSecondary)
                }
                .padding(.vertical, 14)
                .contentShape(.rect)
            }
            .buttonStyle(.pressable)
        }
        .jotCard(padding: 16)
    }

    private func aboutRow(_ title: String, value: String, symbol: String) -> some View {
        HStack {
            Label(title, systemImage: symbol)
                .font(.jotBody)
                .foregroundStyle(Color.jotTextPrimary)
            Spacer()
            Text(value)
                .font(.jotCaption)
                .foregroundStyle(Color.jotTextSecondary)
        }
        .padding(.vertical, 14)
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Morning brief

private struct MorningBriefCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.jotAnimation) private var animation
    @AppStorage(MorningBrief.Keys.enabled) private var isEnabled = false
    @AppStorage(MorningBrief.Keys.minutes) private var minutes = MorningBrief.defaultMinutes
    @Query private var items: [JotItem]
    @State private var previewSent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.jotReminder)
                    .frame(width: 44, height: 44)
                    .background(Color.jotRaised, in: .rect(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily brief")
                        .font(.jotHeadline)
                        .foregroundStyle(Color.jotTextPrimary)
                    Text("Today's events, reminders, and open tasks")
                        .font(.jotCaption)
                        .foregroundStyle(Color.jotTextSecondary)
                }
                Spacer()
                Toggle("Daily brief", isOn: $isEnabled)
                    .labelsHidden()
                    .tint(Color.jotAccent)
            }

            if isEnabled {
                HStack {
                    Text("Deliver at")
                        .font(.jotBody)
                        .foregroundStyle(Color.jotTextPrimary)
                    Spacer()
                    DatePicker("Deliver at", selection: time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(Color.jotAccent)
                }

                BriefPreview(summary: preview)

                Button {
                    Task {
                        previewSent = await MorningBrief.sendPreview(using: modelContext)
                    }
                } label: {
                    Label(previewSent ? "Sent. Check your notifications" : "Send a preview now", systemImage: previewSent ? "checkmark" : "paperplane.fill")
                        .frame(maxWidth: .infinity)
                        .contentTransition(.opacity)
                }
                .buttonStyle(.jotSecondary)
                .controlSize(.small)
                .sensoryFeedback(.success, trigger: previewSent) { _, sent in sent }
            }
        }
        .jotCard()
        .animation(animation, value: isEnabled)
        .animation(animation, value: previewSent)
        .onChange(of: isEnabled) { resync() }
        .onChange(of: minutes) { resync() }
    }

    private var time: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes = (parts.hour ?? 8) * 60 + (parts.minute ?? 0)
            }
        )
    }

    /// The next brief, exactly as it will be delivered.
    private var preview: MorningBrief.Summary {
        let day = MorningBrief.upcomingDeliveries().first ?? .now
        return MorningBrief.summary(for: day, items: items, events: CalendarService.events(on: day))
    }

    private func resync() {
        previewSent = false
        Task { await ReminderScheduler.refill(using: modelContext) }
    }
}

/// A notification-shaped preview of the brief.
private struct BriefPreview: View {
    let summary: MorningBrief.Summary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.jotAccent, in: .rect(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(summary.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("PREVIEW")
                        .font(.jotLabel)
                        .tracking(1)
                        .foregroundStyle(Color.jotTextSecondary)
                }
                Text(summary.subtitle)
                    .font(.subheadline)
                Text(summary.body)
                    .font(.subheadline)
                    .foregroundStyle(Color.jotTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color.jotTextPrimary)
        }
        .padding(12)
        .background(Color.jotRaised, in: .rect(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preview: \(summary.title). \(summary.subtitle). \(summary.body)")
    }
}
