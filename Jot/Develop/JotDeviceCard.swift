#if DEBUG
import SwiftUI

/// Connects the Jot prototype: once connected, its button records like the orb.
struct JotDeviceCard: View {
    @Environment(JotDevice.self) private var device

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(device.status == .connected ? Color.jotAccent : Color.jotTextSecondary)
                    .frame(width: 32)
                    .symbolEffect(.pulse, isActive: device.status == .searching || device.status == .connecting)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Jot hardware")
                        .font(.jotHeadline)
                        .foregroundStyle(Color.jotTextPrimary)
                    Text(statusText)
                        .font(.jotCaption)
                        .foregroundStyle(Color.jotTextSecondary)
                }
                Spacer(minLength: 0)
                Toggle("Jot hardware", isOn: Binding(
                    get: { device.isEnabled },
                    set: { $0 ? device.enable() : device.disable() }
                ))
                .labelsHidden()
                .tint(Color.jotAccent)
            }
            if let lastClip = device.lastClip {
                Text(lastClip)
                    .font(.jotCaption.monospacedDigit())
                    .foregroundStyle(Color.jotTextSecondary)
            }
        }
        .jotCard()
    }

    private var symbol: String {
        device.status == .connected ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash"
    }

    private var statusText: String {
        switch device.status {
        case .off: "Off"
        case .unavailable(let reason): reason
        case .searching: "Looking for Jot…"
        case .connecting: "Connecting…"
        case .connected: "Connected. Hold its button and speak."
        }
    }
}
#endif
