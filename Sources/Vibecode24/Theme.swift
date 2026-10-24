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
