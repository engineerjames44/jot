import SwiftUI

struct SettingsView: View {
    @Environment(CalendarService.self) private var calendar
    @Environment(\.jotAnimation) private var animation
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("JotHasOnboarded") private var hasOnboarded = false

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

                    section("Claude") { apiKeyCard }

                    section("Permissions") {
                        VStack(spacing: 10) {
                            ForEach(PermissionCenter.Kind.allCases) { kind in
                                PermissionRow(kind: kind, status: permissions.status(kind)) {
                                    Task { await permissions.request(kind, calendar: calendar) }
                                }
                            }
                        }
                    }

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

private extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
