import AppKit
import SwiftUI
import VibeCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = AwakeController()
    private var hotKey: HotKey?
    private var signalSources: [DispatchSourceSignal] = []
    private var windows: [String: NSWindow] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        wireEvents()
        controller.start()
        installSignalHandlers()
        updateHotKey()
        observeHotKeySetting()

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.controller.shutdown() }
        }

        if !controller.settings.onboardingDone {
            showOnboarding()
        } else {
            Notifier.requestPermission()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.shutdown()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: URL scheme: vibecode24://on|off|auto|always|toggle|timer?minutes=90

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "vibecode24" {
            let command = (url.host ?? url.path).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            switch command {
            case "on": controller.setMode(.always)
            case "off": controller.setMode(.off)
            case "auto": controller.setMode(.auto)
            case "always": controller.setMode(.always)
            case "toggle": controller.toggle()
            case "timer":
                let minutes = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first { $0.name == "minutes" }?.value.flatMap(Int.init) ?? 60
                controller.startTimer(minutes: minutes)
            case "settings": showSettings()
            default: break
            }
        }
    }

    // MARK: Events

    private func wireEvents() {
        let settings = controller.settings
        controller.onAgentFinished = { name, duration in
            guard settings.notifyOnFinish else { return }
            Notifier.post(title: L10n.t(.notifFinishedTitle, name),
                          body: L10n.t(.notifFinishedBody, L10n.duration(duration)),
                          sound: settings.playSound)
        }
        controller.onReleased = { reason in
            guard settings.notifyOnRelease else { return }
            Notifier.post(title: L10n.t(.notifReleasedTitle), body: L10n.reason(.release(reason)), sound: false)
        }
        controller.onLidOpened = { duration, finished in
            let body = finished.isEmpty
                ? L10n.t(.notifLidBodyNone, L10n.duration(duration))
                : L10n.t(.notifLidBody, L10n.duration(duration), L10n.list(Array(Set(finished)).sorted()))
            Notifier.post(title: L10n.t(.notifLidTitle), body: body, sound: false)
        }
    }

    private func installSignalHandlers() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { [weak self] in
                MainActor.assumeIsolated { self?.controller.shutdown() }
                exit(0)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    private func updateHotKey() {
        hotKey = controller.settings.hotkeyEnabled ? HotKey { [weak self] in self?.controller.toggle() } : nil
    }

    private func observeHotKeySetting() {
        withObservationTracking {
            _ = controller.settings.hotkeyEnabled
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.updateHotKey()
                self?.observeHotKeySetting()
            }
        }
    }

    // MARK: Windows

    func showSettings() {
        show(id: "settings", title: "Vibecode24") {
            SettingsView(controller: self.controller)
        }
    }

    func showOnboarding() {
        show(id: "onboarding", title: "Vibecode24") {
            OnboardingView(controller: self.controller) { [weak self] in
                guard let self else { return }
                self.controller.settings.onboardingDone = true
                self.windows["onboarding"]?.close()
                Notifier.requestPermission()
            }
        }
    }

    private func show<Content: View>(id: String, title: String, @ViewBuilder content: () -> Content) {
        if let window = windows[id] {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(rootView: content())
        let window = NSWindow(contentViewController: hosting)
        window.title = title
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = id == "onboarding"
        window.isReleasedWhenClosed = false
        window.center()
        windows[id] = window
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.windows[id] = nil
                if id == "onboarding" { self?.controller.settings.onboardingDone = true }
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
