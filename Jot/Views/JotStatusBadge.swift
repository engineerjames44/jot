import SwiftUI

/// Top left on Today and Inbox: the Jot recorder's connection and battery.
/// Tap it to connect or disconnect.
struct JotStatusBadge: View {
    @Environment(JotDevice.self) private var device
    @State private var showingPanel = false

    var body: some View {
        Button { showingPanel = true } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                Text(label)
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
            .frame(minHeight: 44)
            .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Shows Jot recorder settings")
        .popover(isPresented: $showingPanel) {
            JotDevicePanel()
                .presentationCompactAdaptation(.popover)
        }
    }

    private var connected: Bool { device.status == .connected }

    private var label: String {
        switch device.status {
        case .off: "Connect Jot"
        case .connected: "Jot"
        default: "Jot offline"
        }
    }

    private var dotColor: Color {
        switch device.status {
        case .connected: .green
        case .searching, .connecting: .orange
        default: Color.jotTextSecondary.opacity(0.5)
        }
    }

    private var accessibilityText: String {
        guard connected else { return device.isEnabled ? "Jot recorder not connected" : "Connect Jot recorder" }
        guard let battery = device.battery else { return "Jot recorder connected" }
        return "Jot recorder connected, battery \(battery.percent) percent\(battery.isCharging ? ", charging" : "")"
    }

    static func symbol(for percent: Int) -> String {
        switch percent {
        case ..<13: "battery.0percent"
        case ..<38: "battery.25percent"
        case ..<63: "battery.50percent"
        case ..<88: "battery.75percent"
        default: "battery.100percent"
        }
    }
}

/// Connect or disconnect the Jot recorder, with its battery and last clip.
struct JotDevicePanel: View {
    @Environment(JotDevice.self) private var device

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: Binding(
                get: { device.isEnabled },
                set: { $0 ? device.enable() : device.disable() }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Jot recorder")
                        .font(.jotHeadline)
                        .foregroundStyle(Color.jotTextPrimary)
                    Text(statusText)
                        .font(.jotCaption)
                        .foregroundStyle(Color.jotTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Color.jotAccent)

            if device.status == .connected, let battery = device.battery {
                Label {
                    Text("\(battery.percent)%, \(String(format: "%.2f", Double(battery.millivolts) / 1000)) V\(battery.isCharging ? ", charging" : "")")
                } icon: {
                    Image(systemName: battery.isCharging ? "battery.100percent.bolt" : JotStatusBadge.symbol(for: battery.percent))
                }
                .font(.jotCaption.monospacedDigit())
                .foregroundStyle(Color.jotTextSecondary)
            }

            if let lastClip = device.lastClip {
                Text(lastClip)
                    .font(.jotCaption.monospacedDigit())
                    .foregroundStyle(Color.jotTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(width: 300)
    }

    private var statusText: String {
        switch device.status {
        case .off: "Off. Turn on to connect over Bluetooth."
        case .unavailable(let reason): reason
        case .searching: "Looking for Jot…"
        case .connecting: "Connecting…"
        case .connected: "Connected. Hold its button and speak."
        }
    }
}
