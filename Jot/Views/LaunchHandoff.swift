import Observation
import SwiftUI

/// Where the record orb is on screen, so the launch orb can fly into it.
@MainActor
@Observable
final class OrbLocator {
    var frame: CGRect?
}

/// Picks up from the static launch screen (the orb alone, centered): the orb
/// shrinks and glides into the record button's position while the launch
/// background fades away.
struct LaunchHandoff: View {
    /// The record orb's frame in global coordinates, if it's on screen.
    let target: CGRect?
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false
    @State private var fading = false

    /// Matches the 120 pt orb in the LaunchOrb launch image.
    private let launchSize: CGFloat = 120

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            // Resolved here, not in `run()`: the task holds a copy of this view from
            // before the record orb reported its position.
            let destination = target.map { CGPoint(x: $0.midX, y: $0.midY) }
            let flies = landed && destination != nil
            let scale = flies ? CaptureOrb.orbSize / launchSize : 1

            ZStack {
                Color.launchBackground
                    .opacity(landed || fading ? 0 : 1)
                BrandOrb(size: launchSize, glow: 0.35)
                    .scaleEffect(scale)
                    .position(flies ? destination! : center)
                    .opacity(fading ? 0 : 1)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .task { await run() }
    }

    private func run() async {
        if reduceMotion {
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeOut(duration: 0.3)) { fading = true }
            try? await Task.sleep(for: .milliseconds(320))
            onFinish()
            return
        }

        // Straight into the record button (the real orb is underneath, identical):
        // capture should be one press away, so keep this short. With nothing to
        // land on, e.g. under onboarding, the orb just fades.
        try? await Task.sleep(for: .milliseconds(60))
        withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) { landed = true }
        try? await Task.sleep(for: .milliseconds(380))
        withAnimation(.easeOut(duration: 0.15)) { fading = true }
        try? await Task.sleep(for: .milliseconds(160))
        onFinish()
    }
}
