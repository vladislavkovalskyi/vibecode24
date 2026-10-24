import SwiftUI
import VibeCore

/// One line about the lid, or the permission banner when lid-closed mode is not allowed yet.
struct LidStatus: View {
    @Bindable var controller: AwakeController
    @State private var installing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13))
                    .foregroundStyle(tint)
                    .frame(width: 18)
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(controller.decision.isHolding ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                if let battery = controller.battery {
                    BatteryLabel(battery: battery)
                }
            }

            if !controller.helperInstalled {
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        installing = true
                        Task {
                            await controller.installHelper(prompt: L10n.t(.adminPrompt))
                            installing = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if installing { ProgressView().controlSize(.small) }
                            Text(L10n.t(.allowLidMode))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.amber)
                    .controlSize(.regular)
                    .disabled(installing)

                    Text(L10n.t(.allowLidModeHint))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if controller.sleepDisabledExternally {
                Text(L10n.t(.sleepDisabledOutside))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = controller.lastError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.warning)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
        }
    }

    private var holding: Bool { controller.decision.isHolding }

    private var symbol: String {
        if holding && controller.lidClosed == true { return "laptopcomputer.slash" }
        return "laptopcomputer"
    }

    private var tint: AnyShapeStyle {
        holding && controller.helperInstalled ? AnyShapeStyle(Theme.amber) : AnyShapeStyle(.secondary)
    }

    private var text: String {
        if !holding { return L10n.t(.lidWillSleep) }
        if !controller.helperInstalled { return L10n.t(.lidNoPermission) }
        if controller.lidClosed == true { return L10n.t(.lidClosedNow) }
        return L10n.t(.lidCanClose)
    }
}

struct BatteryLabel: View {
    var battery: BatteryState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 12))
            Text("\(battery.percent)%")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
        .foregroundStyle(.secondary)
    }

    private var symbol: String {
        if !battery.onBattery { return battery.charging ? "battery.100percent.bolt" : "powerplug" }
        switch battery.percent {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}
