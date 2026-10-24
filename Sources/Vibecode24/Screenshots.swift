import AppKit
import SwiftUI
import VibeCore

/// `Vibecode24 --export-screenshots <dir>` renders the popover and the settings with sample
/// data, for the README. Nothing on the system is touched.
@MainActor
enum Screenshots {
    static func export(to directory: URL) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.activate(ignoringOtherApps: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let defaults = UserDefaults(suiteName: "vibecode24.screenshots")!
        defaults.removePersistentDomain(forName: "vibecode24.screenshots")
        let settings = AppSettings(defaults: defaults)
        settings.mode = .auto
        settings.customCommands = ["my-agent"]

        let now = Date()
        func history(_ base: Double, _ spread: Double, seed: Int) -> [Double] {
            (0..<20).map { i in
                let wave = sin(Double(i + seed) * 0.55) + 0.6 * sin(Double(i * 3 + seed) * 0.8)
                return max(1, base + spread * wave)
            }
        }
        let catalog = Dictionary(uniqueKeysWithValues: AgentCatalog.builtIn.map { ($0.id, $0) })
        let agents = [
            AgentRowModel(definition: catalog["claude"]!, sessionCount: 2, since: now.addingTimeInterval(-2 * 3600 - 14 * 60),
                          cpuPercent: 38, history: history(30, 18, seed: 1), isWorking: true, idleSince: nil),
            AgentRowModel(definition: catalog["codex"]!, sessionCount: 1, since: now.addingTimeInterval(-47 * 60),
                          cpuPercent: 21, history: history(18, 12, seed: 4), isWorking: true, idleSince: nil),
            AgentRowModel(definition: catalog["gemini"]!, sessionCount: 1, since: now.addingTimeInterval(-9 * 60),
                          cpuPercent: 0.4, history: Array(repeating: 0.5, count: 14) + [1, 0, 0.5, 0, 0, 0.3],
                          isWorking: false, idleSince: now.addingTimeInterval(-4 * 60)),
        ]
        let stats = AwakeStats(todayAwake: 5 * 3600 + 12 * 60, todayLidClosed: 3 * 3600 + 40 * 60,
                               totalLidClosed: 61 * 3600, sessionCount: 12)
        let controller = AwakeController(
            preview: .hold(.agents(agents.map { $0.definition.name })), agents: agents, lidClosed: false,
            battery: BatteryState(percent: 84, onBattery: false, charging: true),
            helperInstalled: true, stats: stats, settings: settings)

        let shots: [(String, AppLanguage, NSAppearance.Name)] = [
            ("popover-dark", .en, .darkAqua),
            ("popover-light", .en, .aqua),
            ("popover-ru", .ru, .darkAqua),
            ("popover-uk", .uk, .darkAqua),
        ]
        for (name, language, appearance) in shots {
            L10n.override = language
            render(PopoverView(controller: controller), appearance: appearance, corner: 14,
                   to: directory.appendingPathComponent("\(name).png"))
        }

        L10n.override = .en
        render(AgentsPane(controller: controller, settings: settings).frame(width: 540, height: 620),
               appearance: .darkAqua, corner: 12, to: directory.appendingPathComponent("settings-agents.png"))
        render(SafetyPane(controller: controller, settings: settings).frame(width: 540, height: 640),
               appearance: .darkAqua, corner: 12, to: directory.appendingPathComponent("settings-safety.png"))
        render(OnboardingPreview(controller: controller), appearance: .darkAqua, corner: 14,
               to: directory.appendingPathComponent("onboarding.png"))
        L10n.override = nil
        print("Screenshots written to \(directory.path)")
    }

    private static func render<V: View>(_ view: V, appearance name: NSAppearance.Name, corner: CGFloat, to url: URL) {
        let appearance = NSAppearance(named: name)!
        let framed = view
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
            .padding(1)
            .environment(\.colorScheme, name == .darkAqua ? .dark : .light)

        let hosting = NSHostingView(rootView: framed)
        hosting.appearance = appearance
        let window = KeyWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: 800, height: 900),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = appearance
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)

        let size = hosting.fittingSize
        window.setContentSize(size)
        hosting.frame = NSRect(origin: .zero, size: size)
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        hosting.layoutSubtreeIfNeeded()
        hosting.display()

        let scale: CGFloat = 2
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale),
                                         pixelsHigh: Int(size.height * scale), bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = size
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: url)
        }
        window.orderOut(nil)
    }
}

/// A borderless window that can still become key, so controls draw in their active colours.
private final class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// The onboarding view with the lid already closed, as it looks a moment after opening.
private struct OnboardingPreview: View {
    var controller: AwakeController
    var body: some View {
        OnboardingView(controller: controller, done: {}, look: .holding)
    }
}
