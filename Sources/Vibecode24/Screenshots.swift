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
        L10n.override = .en
        let icon = NSImage(contentsOf: directory.appendingPathComponent("icon.png"))
        render(SocialCard(controller: controller, icon: icon), appearance: .darkAqua, corner: 0,
               to: directory.appendingPathComponent("social-preview.png"), framed: false)
        L10n.override = nil
        print("Screenshots written to \(directory.path)")
    }

    private static func render<V: View>(_ view: V, appearance name: NSAppearance.Name, corner: CGFloat, to url: URL,
                                        framed isFramed: Bool = true) {
        let appearance = NSAppearance(named: name)!
        let framed = view
            .background(isFramed ? Color(nsColor: .windowBackgroundColor) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.primary.opacity(isFramed ? 0.12 : 0), lineWidth: 1))
            .padding(isFramed ? 1 : 0)
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

/// 1280 × 640 card for the repository's social preview.
private struct SocialCard: View {
    var controller: AwakeController
    var icon: NSImage?
    private let popoverScale: CGFloat = 0.74

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                if let icon {
                    Image(nsImage: icon).resizable().frame(width: 64, height: 64)
                        .padding(.leading, -6)
                }
                Text("Vibecode24")
                    .font(.system(size: 34, weight: .semibold))
                    .tracking(-0.8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Close the lid.").foregroundStyle(Color(white: 0.96))
                    Text("Your agents keep working.").foregroundStyle(Color(white: 0.56))
                }
                .font(.system(size: 18, weight: .medium))
                .tracking(-0.2)
                Text("Claude Code, Codex, Gemini CLI, Aider and 13 more agents")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color(white: 0.5))
                    .padding(.top, 4)
            }
            .frame(width: 290, alignment: .leading)
            .padding(.leading, 40)
            Spacer(minLength: 0)
            PopoverView(controller: controller)
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                .fixedSize()
                .scaleEffect(popoverScale)
                .frame(width: Theme.popoverWidth * popoverScale, height: 296)
                .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
                .padding(.trailing, 36)
        }
        .frame(width: 640, height: 320)
        .background(Color(red: 0.07, green: 0.063, blue: 0.05))
        .environment(\.colorScheme, .dark)
    }
}

/// The onboarding view with the lid already closed, as it looks a moment after opening.
private struct OnboardingPreview: View {
    var controller: AwakeController
    var body: some View {
        OnboardingView(controller: controller, done: {}, look: .holding)
    }
}
