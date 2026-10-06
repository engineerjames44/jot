import SwiftUI

/// Top left: whether the Jot recorder is connected, and its battery.
/// Hidden until Jot hardware is turned on.
struct JotStatusBadge: View {
    @Environment(JotDevice.self) private var device

    var body: some View {
        if device.isEnabled {
            HStack(spacing: 6) {
                Circle()
                    .fill(connected ? Color.green : Color.jotTextSecondary.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text(connected ? "Jot" : "Jot offline")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.jotTextPrimary)
                if connected, let battery = device.battery {
                    Image(systemName: battery.isCharging ? "battery.100percent.bolt" : Self.symbol(for: battery.percent))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(battery.percent <= 15 && !battery.isCharging ? Color.red : Color.jotTextSecondary)
                    Text("\(battery.percent)%")
                        .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.jotTextSecondary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color.jotRaised, in: .capsule)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
        }
    }

    private var connected: Bool { device.status == .connected }

    private var accessibilityText: String {
        guard connected else { return "Jot recorder not connected" }
        guard let battery = device.battery else { return "Jot recorder connected" }
        return "Jot recorder connected, battery \(battery.percent) percent\(battery.isCharging ? ", charging" : "")"
    }

    private static func symbol(for percent: Int) -> String {
        switch percent {
        case ..<13: "battery.0percent"
        case ..<38: "battery.25percent"
        case ..<63: "battery.50percent"
        case ..<88: "battery.75percent"
        default: "battery.100percent"
        }
    }
}
