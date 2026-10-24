import AppKit
import SwiftUI
import VibeCore

/// The menu bar picture: the same side-view laptop as the popover glyph, drawn as a template
/// image so macOS tints it for light and dark menu bars.
enum MenuBarIcon {
    private static var cache: [LaptopGlyph.Look: NSImage] = [:]

    static func image(for look: LaptopGlyph.Look) -> NSImage {
        if let cached = cache[look] { return cached }
        let size = NSSize(width: 22, height: 16)
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setFill()
            NSColor.black.setStroke()

            // Base slab.
            NSBezierPath(roundedRect: NSRect(x: 1.5, y: 3, width: 19, height: 2.6), xRadius: 1.1, yRadius: 1.1).fill()

            // Lid, hinged at the back left of the base.
            let angle: CGFloat
            switch look {
            case .holding: angle = 3
            case .waiting: angle = 55
            case .off, .paused: angle = 100
            }
            let lid = NSBezierPath(roundedRect: NSRect(x: 0, y: -0.9, width: 17.5, height: 1.8), xRadius: 0.9, yRadius: 0.9)
            var transform = AffineTransform(translationByX: 2.6, byY: 6.4)
            transform.rotate(byDegrees: angle)
            lid.transform(using: transform)
            lid.fill()

            // The LED: filled when holding, a ring when waiting for agents.
            let led = NSRect(x: 16.4, y: 7.6, width: 4.2, height: 4.2)
            switch look {
            case .holding:
                NSBezierPath(ovalIn: led).fill()
            case .waiting:
                let ring = NSBezierPath(ovalIn: led.insetBy(dx: 0.55, dy: 0.55))
                ring.lineWidth = 1.1
                ring.stroke()
            case .off, .paused:
                break
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Vibecode24"
        cache[look] = image
        return image
    }
}

struct MenuBarLabel: View {
    @Bindable var controller: AwakeController

    var body: some View {
        Image(nsImage: MenuBarIcon.image(for: controller.decision.look))
    }
}
