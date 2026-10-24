import AppKit
import SwiftUI

/// The few design tokens the app uses. One accent, used only for "awake".
enum Theme {
    /// Standby-LED amber. Darker in light mode so text in it keeps its contrast.
    static let amber = Color(nsColor: NSColor(name: "amber") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 1.00, green: 0.69, blue: 0.13, alpha: 1)
            : NSColor(srgbRed: 0.80, green: 0.47, blue: 0.00, alpha: 1)
    })
    /// The LED itself is always the bright amber: it is a light, not text.
    static let led = Color(nsColor: NSColor(srgbRed: 1.00, green: 0.69, blue: 0.13, alpha: 1))
    static let warning = Color(nsColor: .systemOrange)

    static let line = Color.primary.opacity(0.08)
    static let tile = Color.primary.opacity(0.06)

    static let popoverWidth: CGFloat = 330
    static let gutter: CGFloat = 16

    /// State changes are the only thing that moves.
    static let stateChange = Animation.easeInOut(duration: 0.45)
}

extension View {
    func sectionLabel() -> some View {
        font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
    }
}

/// A switch in the app's accent. The system switch ignores `.tint` in some contexts, and the
/// accent is the one place the app's colour shows, so it is drawn here.
struct AmberSwitch: ToggleStyle {
    var labelSpacing: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: labelSpacing) {
            configuration.label
            Spacer(minLength: 0)
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? Theme.led : Color.primary.opacity(0.16))
                    .overlay(Capsule().strokeBorder(Color.black.opacity(configuration.isOn ? 0.08 : 0.04), lineWidth: 0.5))
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                    .padding(2)
            }
            .frame(width: 34, height: 20)
            .contentShape(Capsule())
            .onTapGesture { configuration.isOn.toggle() }
            .animation(.easeInOut(duration: 0.18), value: configuration.isOn)
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(configuration.isOn ? "on" : "off")
            .accessibilityAction { configuration.isOn.toggle() }
        }
    }
}
