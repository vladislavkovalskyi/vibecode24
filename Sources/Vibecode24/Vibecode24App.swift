import AppKit
import SwiftUI
import VibeCore

@main
enum Entry {
    static func main() {
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--export-screenshots") {
            let directory = arguments.indices.contains(index + 1) ? arguments[index + 1] : "docs/assets"
            MainActor.assumeIsolated { Screenshots.export(to: URL(fileURLWithPath: directory)) }
            return
        }
        if arguments.contains("--scan") {
            // Prints what the radar sees. Handy when asking for a new agent to be supported.
            let scanner = ProcessScanner()
            let matcher = AgentMatcher(definitions: AgentCatalog.builtIn)
            _ = scanner.scan(matcher: matcher)
            Thread.sleep(forTimeInterval: 1)
            for agent in scanner.scan(matcher: matcher) {
                let pids = agent.sessions.map { "\($0.pid)" }.joined(separator: ", ")
                print("\(agent.definition.name): \(agent.sessions.count) session(s), pid \(pids), \(String(format: "%.1f", agent.cpuPercent))% CPU")
            }
            return
        }
        Vibecode24App.main()
    }
}

struct Vibecode24App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            PopoverView(
                controller: delegate.controller,
                openSettings: { delegate.showSettings() },
                quit: { NSApp.terminate(nil) }
            )
        } label: {
            MenuBarLabel(controller: delegate.controller)
        }
        .menuBarExtraStyle(.window)
    }
}
