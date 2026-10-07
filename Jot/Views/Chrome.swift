import SwiftUI

// The app's frame: the bottom bar with the orb between Today and Inbox, the
// badge that opens Settings, and the dimmed stage a capture plays out on.

extension EnvironmentValues {
    @Entry var currentScreen: RootView.Screen = .today
    @Entry var selectScreen: (RootView.Screen) -> Void = { _ in }
    @Entry var openSettings: () -> Void = {}
}

// MARK: - Profile badge

/// Your initial in a circle, top right on Today. Opens Settings.
struct ProfileBadge: View {
    @AppStorage(UserProfile.nameKey, store: UserProfile.defaults) private var name = ""
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(action: openSettings) {
            Group {
                if let initial = UserProfile.firstName(name).first {
                    Text(String(initial).uppercased())
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundStyle(Color.jotTextPrimary)
            .frame(width: 38, height: 38)
            .background(Color.jotRaised, in: .circle)
            .frame(width: 44, height: 44)
            .contentShape(.circle)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Settings")
    }
}

// MARK: - Bottom bar

/// Today and Inbox either side of the orb (and Develop, in debug builds).
/// While recording only the orb stays.
struct BottomBar: View {
    @Environment(CaptureController.self) private var capture
    @Environment(\.currentScreen) private var current
    @Environment(\.selectScreen) private var select
    #if DEBUG
    @AppStorage(DevMode.enabledKey) private var devModeEnabled = DevMode.defaultEnabled
    #endif

    var body: some View {
        let live = capture.phase.isBusy

        ZStack {
            HStack(spacing: 0) {
                tab(.today, title: "Today", symbol: "sun.max.fill")
                    .frame(maxWidth: .infinity)
                Color.clear.frame(width: CaptureOrb.orbSize + 24)
                // Equal halves keep the orb centred whatever's on the right.
                HStack(spacing: 4) {
                    tab(.inbox, title: "Inbox", symbol: "tray.full.fill")
                    #if DEBUG
                    if devModeEnabled {
                        tab(.develop, title: "Develop", symbol: "hammer.fill")
                    }
                    #endif
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)
            .frame(height: 64)
            .glassEffect(.regular, in: .capsule)
            .opacity(live ? 0 : 1)
            .padding(.horizontal, JotMetrics.gutter)

            CaptureOrb()
                .offset(y: -8)
        }
        .animation(.jot, value: live)
    }

    private func tab(_ screen: RootView.Screen, title: String, symbol: String) -> some View {
        let selected = current == screen
        return Button {
            select(screen)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 26, height: 22)
                Text(title)
                    .font(.system(size: 11, weight: selected ? .bold : .semibold, design: .rounded))
                    .lineLimit(1)
                    .fixedSize()
            }
            // Same size for every tab; the current one sits in an orange pill.
            .foregroundStyle(selected ? Color.jotAccentText : Color.jotTextSecondary)
            .frame(width: 64, height: 50)
            .background(Color.jotAccent.opacity(selected ? 0.18 : 0), in: .capsule)
            .frame(height: 56)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        // Like the system tab bar: labels stay compact, and a long press shows
        // them enlarged for people using large text.
        .accessibilityShowsLargeContentViewer {
            Label(title, systemImage: symbol)
        }
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .sensoryFeedback(.selection, trigger: selected) { _, now in now }
    }
}

// MARK: - Capture stage

/// While you hold the orb the screen goes dark and your words fill it.
/// Sits under the bottom bar, so the orb keeps its touch.
struct CaptureStage: View {
    @Environment(CaptureController.self) private var capture
    @Environment(\.isActiveTab) private var isActiveTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let listening = isActiveTab && (capture.phase == .starting || capture.isRecording)

        ZStack(alignment: .topLeading) {
            if listening {
                Color.black
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 8) {
                        KindDot(color: .jotAccent, size: 8, glows: true)
                        Text("Listening")
                            .font(.jotSection)
                            .foregroundStyle(Color.jotAccent)
                        if case .recording(let since) = capture.phase {
                            Text(timerInterval: since...Date.distantFuture, countsDown: false)
                                .font(.jotReadout)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }

                    Text(capture.liveTranscript.isEmpty ? "Say what's on your mind." : capture.liveTranscript)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .tracking(-0.5)
                        .foregroundStyle(capture.liveTranscript.isEmpty ? .white.opacity(0.4) : .white)
                        .lineLimit(7)
                        .truncationMode(.head)
                        .minimumScaleFactor(0.6)
                        .contentTransition(reduceMotion ? .opacity : .interpolate)
                        .animation(.jot, value: capture.liveTranscript)

                    Spacer()

                    Text("Let go to save")
                        .font(.jotCaption)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 72)
                }
                .padding(.horizontal, 28)
                .padding(.top, 40)
                .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 12)))
                .accessibilityElement(children: .combine)
            }
        }
        .allowsHitTesting(false)
        .animation(.jot, value: listening)
    }
}
