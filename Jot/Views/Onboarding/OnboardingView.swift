import SwiftUI

/// Three short animated pages (hold → speak → done), the name to greet you by,
/// then permissions, each explained before the system asks.
struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(\.jotAnimation) private var animation
    @State private var page = 0
    private let pageCount = 5

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Wordmark(size: 34)
                Spacer()
                if page < pageCount - 1 {
                    Button("Skip") {
                        withAnimation(animation) { page = pageCount - 1 }
                    }
                    .font(.jotHeadline)
                    .foregroundStyle(Color.jotTextSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            TabView(selection: $page) {
                IntroPage(
                    step: "01",
                    title: "Hold the orb",
                    message: "One button does everything. Press and hold whenever something's on your mind.",
                    isActive: page == 0
                ) { HoldIllustration(isActive: $0) }
                .tag(0)

                IntroPage(
                    step: "02",
                    title: "Just say it",
                    message: "Talk like you would to a friend. Your voice is turned into words right on your iPhone.",
                    isActive: page == 1
                ) { SpeakIllustration(isActive: $0) }
                .tag(1)

                IntroPage(
                    step: "03",
                    title: "It's sorted",
                    message: "Jot turns it into a note, task, reminder, or event, with the time worked out for you.",
                    isActive: page == 2
                ) { DoneIllustration(isActive: $0) }
                .tag(2)

                NamePage {
                    withAnimation(animation) { page = 4 }
                }
                .tag(3)

                PermissionsPage()
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 20) {
                PageDots(count: pageCount, current: page)

                Button {
                    if page < pageCount - 1 {
                        withAnimation(animation) { page += 1 }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(page < pageCount - 1 ? "Next" : "Start jotting")
                        .frame(maxWidth: .infinity)
                        .contentTransition(.opacity)
                }
                .buttonStyle(.jotPrimary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background {
            ZStack {
                Color.jotBackground
                RadialGradient(
                    colors: [Color.jotAccent.opacity(0.18), .clear],
                    center: .top, startRadius: 0, endRadius: 420
                )
            }
            .ignoresSafeArea()
        }
        .sensoryFeedback(.selection, trigger: page)
    }
}

// MARK: - Pages

private struct IntroPage<Illustration: View>: View {
    let step: String
    let title: String
    let message: String
    let isActive: Bool
    @ViewBuilder let illustration: (Bool) -> Illustration

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 12)
            illustration(isActive)
                .frame(maxWidth: .infinity)
                .frame(height: 300)
            Spacer(minLength: 12)
            VStack(alignment: .leading, spacing: 12) {
                Text(step)
                    .font(.jotTime)
                    .foregroundStyle(Color.jotAccent)
                Text(title)
                    .font(.jotDisplay)
                    .tracking(-0.8)
                    .foregroundStyle(Color.jotTextPrimary)
                // Every page reserves at least three lines (the hidden text), so
                // the heading doesn't jump between pages but can still grow
                // with larger text sizes.
                ZStack(alignment: .topLeading) {
                    Text("\n\n").hidden()
                    Text(message)
                        .foregroundStyle(Color.jotTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(.title3))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

/// Asks what to call you, with the greeting it'll produce previewed as you type.
private struct NamePage: View {
    var onSubmit: () -> Void

    @AppStorage(UserProfile.nameKey, store: UserProfile.defaults) private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 12)

            // The Today header as it will look, updating with each letter.
            VStack(alignment: .leading, spacing: 8) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                    .font(.jotLabel)
                    .tracking(1.2)
                    .foregroundStyle(Color.jotAccent)
                Text(UserProfile.greeting(at: .now, name: name))
                    .font(.jotDisplay)
                    .tracking(-0.8)
                    .foregroundStyle(Color.jotTextPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.interpolate)
                    .animation(.jot, value: name)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .jotCard(padding: 0)
            .padding(.horizontal, 24)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Preview: \(UserProfile.greeting(at: .now, name: name))")

            Spacer(minLength: 12)

            VStack(alignment: .leading, spacing: 12) {
                Text("04")
                    .font(.jotTime)
                    .foregroundStyle(Color.jotAccent)
                Text("What should Jot call you?")
                    .font(.jotDisplay)
                    .tracking(-0.8)
                    .foregroundStyle(Color.jotTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("Your first name", text: $name)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focused)
                    .onSubmit {
                        name = UserProfile.cleaned(name)
                        onSubmit()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(Color.jotSurface, in: .rect(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(focused ? Color.jotAccent : Color.jotBorder, lineWidth: focused ? 2 : 1)
                    }

                Text("Optional. It stays on this iPhone, and you can change it in Settings.")
                    .font(.jotCaption)
                    .foregroundStyle(Color.jotTextSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .contentShape(.rect)
        .onTapGesture { focused = false }
        .onDisappear { name = UserProfile.cleaned(name) }
    }
}

private struct PermissionsPage: View {
    @Environment(CalendarService.self) private var calendar
    @State private var permissions = PermissionCenter()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("05")
                    .font(.jotTime)
                    .foregroundStyle(Color.jotAccent)
                    .padding(.top, 24)
                Text("A few permissions")
                    .font(.jotDisplay)
                    .tracking(-0.8)
                    .foregroundStyle(Color.jotTextPrimary)
                Text("Here's why Jot asks. You can change any of these later in Settings.")
                    .font(.system(.title3))
                    .foregroundStyle(Color.jotTextSecondary)
                    .padding(.bottom, 8)

                SmartSortingCard()
                    .staggeredAppear(0)

                ForEach(Array(PermissionCenter.Kind.allCases.enumerated()), id: \.element) { index, kind in
                    PermissionRow(kind: kind, status: permissions.status(kind)) {
                        Task { await permissions.request(kind, calendar: calendar) }
                    }
                    .staggeredAppear(index + 1)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .task { await permissions.refresh() }
    }
}

/// A permission with its reason and an Allow button (or its current state).
struct PermissionRow: View {
    let kind: PermissionCenter.Kind
    let status: PermissionCenter.Status
    var onRequest: () -> Void

    @Environment(\.jotAnimation) private var animation

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: kind.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(status == .granted ? Color.jotTask : Color.jotAccent)
                .frame(width: 44, height: 44)
                .background(Color.jotRaised, in: .rect(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(kind.title)
                    .font(.jotHeadline)
                    .foregroundStyle(Color.jotTextPrimary)
                Text(kind.reason)
                    .font(.jotCaption)
                    .foregroundStyle(Color.jotTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Group {
                switch status {
                case .granted:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.jotTask)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityLabel("Allowed")
                case .notDetermined:
                    Button("Allow", action: onRequest)
                        .buttonStyle(.jotSecondary)
                        .controlSize(.small)
                        .fixedSize()
                case .denied:
                    Button("Settings", action: openSystemSettings)
                        .buttonStyle(.jotSecondary)
                        .controlSize(.small)
                        .fixedSize()
                }
            }
            .animation(animation, value: status)
        }
        .jotCard()
        .sensoryFeedback(.success, trigger: status) { _, new in new == .granted }
    }
}

@MainActor
func openSystemSettings() {
    #if os(iOS)
    if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
    }
    #endif
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.jotAccent : Color.jotTextSecondary.opacity(0.35))
                    .frame(width: index == current ? 22 : 7, height: 7)
            }
        }
        .animation(.jot, value: current)
        .accessibilityElement()
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

// MARK: - Illustrations

/// The orb being pressed: it shrinks, swells, and glows on a loop.
private struct HoldIllustration: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: !isActive || reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let cycle = t.truncatingRemainder(dividingBy: 3) / 3
            // 0–0.15 press in, 0.15–0.75 held (swollen), then release.
            let held = cycle > 0.15 && cycle < 0.75
            let scale: CGFloat = reduceMotion ? 1 : (cycle < 0.15 ? 0.94 : (held ? 1.14 : 1))

            ZStack {
                ForEach(0..<3) { ring in
                    let phase = (cycle * 3 + Double(ring) / 3).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .stroke(Color.jotAccent.opacity(held ? (1 - phase) * 0.5 : 0), lineWidth: 2)
                        .frame(width: 120 + phase * 140, height: 120 + phase * 140)
                }
                BrandOrb(size: 120, glow: held ? 0.8 : 0.35)
                    .scaleEffect(scale)
                    .animation(.jot, value: held)
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.jotTextPrimary)
                    .shadow(color: .black.opacity(0.4), radius: 8)
                    .offset(x: 42, y: held ? 48 : 70)
                    .animation(.jot, value: held)
            }
        }
    }
}

/// Words appearing one by one over a live waveform.
private struct SpeakIllustration: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let words = ["Call", "mum", "on", "Thursday", "at", "two"]

    var body: some View {
        TimelineView(.animation(paused: !isActive || reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let shown = reduceMotion ? words.count : Int(t.truncatingRemainder(dividingBy: 4.2) / 0.45) + 1

            VStack(spacing: 28) {
                HStack(spacing: 4) {
                    ForEach(0..<28, id: \.self) { bar in
                        let level = reduceMotion ? 0.5 : abs(sin(t * 6 + Double(bar) * 0.55) * sin(t * 2.1 + Double(bar) * 0.2))
                        Capsule()
                            .fill(Color.jotAccent.opacity(0.4 + level * 0.6))
                            .frame(width: 4, height: 8 + level * 64)
                    }
                }
                .frame(height: 80)

                Text(sentence(showing: shown))
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.jotTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 80, alignment: .top)
            }
            .padding(.horizontal, 24)
        }
    }

    /// The whole sentence is always laid out, with unspoken words hidden, so
    /// words appear in place instead of the line re-centering as it grows.
    private func sentence(showing shown: Int) -> AttributedString {
        var result = AttributedString()
        for (index, word) in words.enumerated() {
            var part = AttributedString(index == 0 ? word : " " + word)
            if index >= shown { part.foregroundColor = .clear }
            result += part
        }
        return result
    }
}

/// The confirmation card arriving, looping.
private struct DoneIllustration: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: !isActive || reduceMotion)) { context in
            let cycle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.2)
            let visible = reduceMotion || cycle > 0.4

            VStack(spacing: 14) {
                card(kind: .reminder, when: "Thu 2:00 PM", title: "Call mum")
                    .offset(y: visible ? 0 : 60)
                    .opacity(visible ? 1 : 0)
                    .animation(.jot, value: visible)
                card(kind: .task, when: "Fri", title: "Book the cabin")
                    .opacity(0.5)
                    .scaleEffect(0.94)
                card(kind: .note, when: nil, title: "Gift idea: a record player")
                    .opacity(0.25)
                    .scaleEffect(0.88)
            }
            .padding(.horizontal, 32)
        }
    }

    private func card(kind: ItemKind, when: String?, title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                KindLabel(kind: kind)
                if let when {
                    Text("· \(when)")
                        .font(.jotTimeSmall)
                        .foregroundStyle(Color.jotTextSecondary)
                }
            }
            Text(title)
                .font(.jotHeadline)
                .foregroundStyle(Color.jotTextPrimary)
        }
        .jotCard()
        .overlay(alignment: .leading) {
            Capsule().fill(kind.color).frame(width: 3).padding(.vertical, 16)
        }
    }
}
