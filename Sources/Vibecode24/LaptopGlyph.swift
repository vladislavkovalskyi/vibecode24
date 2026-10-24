import SwiftUI
import VibeCore

/// The app's signature: a laptop seen from the side. When the app holds the Mac awake the
/// lid closes and the LED on the front edge lights up. It moves only when the state changes.
struct LaptopGlyph: View {
    enum Look: Equatable { case holding, waiting, off, paused }

    var look: Look
    var size: CGFloat = 64

    private var lidAngle: Double {
        switch look {
        case .holding: return -4
        case .waiting: return -58
        case .off, .paused: return -104
        }
    }

    var body: some View {
        let s = size / 64
        ZStack(alignment: .topLeading) {
            // Lid, hinged at the back of the base.
            RoundedRectangle(cornerRadius: 1.8 * s, style: .continuous)
                .fill(Color.primary.opacity(look == .holding ? 0.85 : 0.55))
                .frame(width: 52 * s, height: 3.6 * s)
                .rotationEffect(.degrees(lidAngle), anchor: .leading)
                .offset(x: 6 * s, y: 36.4 * s)

            // Base.
            RoundedRectangle(cornerRadius: 2.2 * s, style: .continuous)
                .fill(Color.primary.opacity(look == .holding ? 0.85 : 0.55))
                .frame(width: 56 * s, height: 5.5 * s)
                .offset(x: 4 * s, y: 40 * s)

            // Feet line under the base gives it a surface to stand on.
            Capsule()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 60 * s, height: 1 * s)
                .offset(x: 2 * s, y: 47.5 * s)

            led(scale: s)
                .offset(x: 61.5 * s - 4.5 * s, y: 40.6 * s)
        }
        .frame(width: 64 * s, height: 50 * s, alignment: .topLeading)
        .animation(Theme.stateChange, value: look)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func led(scale s: CGFloat) -> some View {
        switch look {
        case .holding:
            Circle().fill(Theme.led)
                .frame(width: 4.4 * s, height: 4.4 * s)
                .shadow(color: Theme.led.opacity(0.7), radius: 2.5 * s)
        case .waiting:
            Circle().strokeBorder(Theme.led, lineWidth: 1.2 * s)
                .frame(width: 4.4 * s, height: 4.4 * s)
        case .off, .paused:
            Circle().fill(Color.primary.opacity(0.18))
                .frame(width: 4.4 * s, height: 4.4 * s)
        }
    }
}

extension AwakeDecision {
    var look: LaptopGlyph.Look {
        switch self {
        case .hold: return .holding
        case .release(.noAgents): return .waiting
        case .release(.off), .release(.timerDone): return .off
        case .release: return .paused
        }
    }
}
