import SwiftUI

/// The signal-orange orb: the dot of the "j", the record button, the app icon.
struct BrandOrb: View {
    var size: CGFloat = 78
    /// 0…1; how strongly the soft outer glow shows.
    var glow: Double = 0.3

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.jotAccent)
                .frame(width: size * 1.2, height: size * 1.2)
                .blur(radius: size * 0.25)
                .opacity(glow)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.jotAccent.mix(with: .white, by: 0.35),
                            Color.jotAccent,
                            Color.jotAccent.mix(with: .black, by: 0.25),
                        ],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: size * 0.02,
                        endRadius: size * 0.75
                    )
                )
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: max(0.5, size / 80)))
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// "jot" in SF Pro Rounded Heavy, with the dot of the j replaced by the orb.
struct Wordmark: View {
    var size: CGFloat = 44

    var body: some View {
        // U+0237 is a dotless j, so the orb can sit where the dot would be.
        Text("\u{0237}ot")
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .tracking(-size * 0.02)
            .foregroundStyle(Color.jotTextPrimary)
            .overlay(alignment: .topLeading) {
                BrandOrb(size: size * 0.27, glow: 0.55)
                    .offset(x: size * 0.035, y: size * 0.07)
            }
            .accessibilityElement()
            .accessibilityLabel("jot")
    }
}

#Preview {
    VStack(spacing: 40) {
        Wordmark(size: 80)
        Wordmark(size: 36)
        BrandOrb(size: 120, glow: 0.5)
    }
    .padding(40)
    .background(Color.jotBackground)
}
