import SwiftUI

// Colors come from the asset catalog (JotBackground, JotSurface, …). Xcode
// generates `Color.jotBackground` etc. from those names, so nothing here
// hardcodes a hex value.

// MARK: - Item kind colors

extension ItemKind {
    var color: Color {
        switch self {
        case .reminder: .jotReminder
        case .task: .jotTask
        case .note: .jotNote
        case .event: .jotEvent
        }
    }
}

// MARK: - Typography

extension Font {
    /// SF Pro Rounded for headings and numbers; SF Pro for body copy.
    static let jotDisplay = Font.system(.largeTitle, design: .rounded, weight: .heavy)
    static let jotTitle = Font.system(.title2, design: .rounded, weight: .bold)
    static let jotHeadline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let jotBody = Font.body
    static let jotBodyEmphasis = Font.body.weight(.semibold)
    static let jotCaption = Font.footnote
    static let jotLabel = Font.system(.caption, design: .rounded, weight: .bold)
    /// Times and counts: rounded with fixed-width digits so columns don't jitter.
    static let jotTime = Font.system(.subheadline, design: .rounded, weight: .semibold).monospacedDigit()
    static let jotTimeSmall = Font.system(.caption, design: .rounded, weight: .semibold).monospacedDigit()
}

// MARK: - Metrics & motion

enum JotMetrics {
    static let cornerRadius: CGFloat = 20
    static let gutter: CGFloat = 20
    static let cardPadding: CGFloat = 16
}

extension Animation {
    /// The one spring the whole app moves with.
    static let jot = Animation.spring(response: 0.35, dampingFraction: 0.8)
}

extension EnvironmentValues {
    /// The app spring, or a short crossfade when Reduce Motion is on.
    var jotAnimation: Animation {
        accessibilityReduceMotion ? .easeInOut(duration: 0.2) : .jot
    }
}

// MARK: - Card

struct JotCard: ViewModifier {
    var padding: CGFloat = JotMetrics.cardPadding
    var fill: Color = .jotSurface

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: JotMetrics.cornerRadius, style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(Color.jotBorder, lineWidth: 1))
            .contentShape(shape)
    }
}

extension View {
    func jotCard(padding: CGFloat = JotMetrics.cardPadding, fill: Color = .jotSurface) -> some View {
        modifier(JotCard(padding: padding, fill: fill))
    }
}

// MARK: - Buttons

/// Capsule button. `.primary` is the orange key action; `.secondary` is a quiet raised surface.
struct JotButtonStyle: ButtonStyle {
    enum Role { case primary, secondary }
    var role: Role = .primary

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, role: role)
    }

    private struct StyledBody: View {
        let configuration: Configuration
        let role: Role
        @Environment(\.controlSize) private var controlSize

        private var isCompact: Bool { controlSize == .small || controlSize == .mini }

        var body: some View {
            configuration.label
                .font(isCompact ? .jotLabel : .jotHeadline)
                .padding(.horizontal, isCompact ? 14 : 20)
                .padding(.vertical, isCompact ? 8 : 12)
                .foregroundStyle(role == .primary ? Color.white : Color.jotTextPrimary)
                .background(role == .primary ? Color.jotAccent : Color.jotRaised, in: .capsule)
                .overlay(Capsule().strokeBorder(Color.jotBorder, lineWidth: role == .secondary ? 1 : 0))
                .scaleEffect(configuration.isPressed ? 0.96 : 1)
                .animation(.jot, value: configuration.isPressed)
        }
    }
}

/// Gives any tappable card a gentle press-down.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.jot, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == JotButtonStyle {
    static var jotPrimary: JotButtonStyle { JotButtonStyle(role: .primary) }
    static var jotSecondary: JotButtonStyle { JotButtonStyle(role: .secondary) }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

// MARK: - Small components

/// The small colored dot that marks an item's type.
struct KindDot: View {
    let color: Color
    var size: CGFloat = 8
    var glows = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: glows ? color.opacity(0.7) : .clear, radius: glows ? 6 : 0)
    }
}

/// "● Reminder" style label in the type's color.
struct KindLabel: View {
    let kind: ItemKind

    var body: some View {
        HStack(spacing: 5) {
            KindDot(color: kind.color, size: 6)
            Text(kind.label.uppercased())
                .font(.jotLabel)
                .tracking(0.6)
                .foregroundStyle(kind.color)
                .lineLimit(1)
        }
        .fixedSize()
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.jotLabel)
                .tracking(1.2)
                .foregroundStyle(Color.jotTextSecondary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.jotTimeSmall)
                    .foregroundStyle(Color.jotTextSecondary)
            }
        }
        .padding(.horizontal, 4)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Round checkbox that fills in the item's color with a bounce.
struct CheckCircle: View {
    let isChecked: Bool
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isChecked ? color : Color.jotTextSecondary.opacity(0.6), lineWidth: 2)
            if isChecked {
                Circle().fill(color)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.jotBackground)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .frame(width: 26, height: 26)
        .symbolEffect(.bounce, value: isChecked)
    }
}

// MARK: - Empty states

/// A small illustration built from layered SF Symbols, plus a one-line prompt.
struct EmptyStateView: View {
    let symbol: String
    let color: Color
    var orbitSymbols: [String] = ["sparkle", "mic.fill"]
    let title: String
    let message: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.jotSurface)
                    .overlay(Circle().strokeBorder(Color.jotBorder, lineWidth: 1))
                    .frame(width: 128, height: 128)
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 88, height: 88)
                    .blur(radius: 12)
                Image(systemName: symbol)
                    .font(.system(size: 46, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(color)
                    .offset(y: floating ? -4 : 2)

                if let first = orbitSymbols.first {
                    Image(systemName: first)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.jotAccent)
                        .offset(x: 50, y: floating ? -48 : -42)
                }
                if orbitSymbols.count > 1 {
                    Image(systemName: orbitSymbols[1])
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.jotTextPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.jotRaised, in: .circle)
                        .overlay(Circle().strokeBorder(Color.jotBorder, lineWidth: 1))
                        .offset(x: -48, y: floating ? 40 : 46)
                }
            }
            .frame(height: 140)
            .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(title)
                    .font(.jotTitle)
                    .foregroundStyle(Color.jotTextPrimary)
                Text(message)
                    .font(.jotBody)
                    .foregroundStyle(Color.jotTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                floating = true
            }
        }
    }
}

// MARK: - Staggered appearance

/// Fades and lifts a view in, delayed by its position in a list.
struct StaggeredAppear: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 14)
            .onAppear {
                let delay = reduceMotion ? 0 : min(Double(index), 12) * 0.045
                withAnimation((reduceMotion ? Animation.easeOut(duration: 0.2) : .jot).delay(delay)) {
                    visible = true
                }
            }
    }
}

extension View {
    func staggeredAppear(_ index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }
}

// MARK: - Dates

enum JotDate {
    /// "Today 2:00 PM", "Tomorrow 9:00 AM", "Thu 2:00 PM", or "Oct 14 2:00 PM".
    static func short(_ date: Date, now: Date = .now) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) { return "Today \(time)" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow \(time)" }
        if calendar.isDateInYesterday(date) { return "Yesterday \(time)" }
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)
        ).day ?? 99
        if (0..<7).contains(days) {
            return "\(date.formatted(.dateTime.weekday(.abbreviated))) \(time)"
        }
        return "\(date.formatted(.dateTime.month(.abbreviated).day())) \(time)"
    }
}

// MARK: - Shimmer

/// A soft highlight sweeping across content, for "thinking" states.
/// With Reduce Motion on it gently pulses instead.
struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion ? (phase > 0 ? 0.55 : 1) : 1)
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.55), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.5)
                        .offset(x: phase * proxy.size.width)
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                let animation: Animation = reduceMotion
                    ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                    : .linear(duration: 1.3).repeatForever(autoreverses: false)
                withAnimation(animation) { phase = 1.2 }
            }
    }
}

extension View {
    func shimmering() -> some View { modifier(Shimmer()) }
}

// MARK: - Environment

extension EnvironmentValues {
    /// Shared by the confirmation card and timeline cards so a new item can fly into place.
    @Entry var captureNamespace: Namespace.ID?
    /// False for tabs that are kept alive but not on screen.
    @Entry var isActiveTab = true
}

// MARK: - Chips

/// A row of capsule chips with an animated selection pill.
struct ChipPicker<Value: Hashable>: View {
    struct Option {
        let value: Value
        let label: String
        var color: Color?
        var count: Int?
    }

    let options: [Option]
    @Binding var selection: Value
    /// Leading/trailing space inside the scroll area, so chips line up with content.
    var inset: CGFloat = JotMetrics.gutter

    @Namespace private var namespace
    @Environment(\.jotAnimation) private var animation

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(options, id: \.value) { option in
                    chip(option)
                }
            }
            .padding(.horizontal, inset)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func chip(_ option: Option) -> some View {
        let isSelected = option.value == selection
        return Button {
            withAnimation(animation) { selection = option.value }
        } label: {
            HStack(spacing: 6) {
                if let color = option.color {
                    KindDot(color: color, size: 7)
                }
                Text(option.label)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                if let count = option.count {
                    Text("\(count)")
                        .font(.jotTimeSmall)
                        .foregroundStyle(Color.jotTextSecondary)
                        .contentTransition(.numericText(value: Double(count)))
                }
            }
            .foregroundStyle(isSelected ? Color.jotTextPrimary : Color.jotTextSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.jotRaised)
                        .matchedGeometryEffect(id: "selection", in: namespace)
                }
            }
            .overlay(Capsule().strokeBorder(Color.jotBorder, lineWidth: 1))
            .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Search highlighting

enum SearchHighlight {
    /// `text` with every case- and accent-insensitive match of `query` highlighted.
    static func attributed(_ text: String, query: String) -> AttributedString {
        var result = AttributedString(text)
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return result }

        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let match = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], range: searchStart..<text.endIndex) {
            if let range = Range(match, in: result) {
                result[range].backgroundColor = Color.jotAccent.opacity(0.3)
                result[range].foregroundColor = Color.jotTextPrimary
            }
            searchStart = match.upperBound
        }
        return result
    }

    /// A short excerpt around the first match, for showing why something matched.
    static func snippet(_ text: String, query: String, radius: Int = 32) -> String? {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty,
              let match = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive])
        else { return nil }
        let start = text.index(match.lowerBound, offsetBy: -radius, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(match.upperBound, offsetBy: radius, limitedBy: text.endIndex) ?? text.endIndex
        let prefix = start > text.startIndex ? "…" : ""
        let suffix = end < text.endIndex ? "…" : ""
        return prefix + text[start..<end].trimmingCharacters(in: .whitespaces) + suffix
    }
}
