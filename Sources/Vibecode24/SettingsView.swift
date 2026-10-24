import ServiceManagement
import SwiftUI
import VibeCore

struct SettingsView: View {
    @Bindable var controller: AwakeController

    var body: some View {
        TabView {
            GeneralPane(settings: controller.settings)
                .tabItem { Label(L10n.t(.tabGeneral), systemImage: "gearshape") }
            AgentsPane(controller: controller, settings: controller.settings)
                .tabItem { Label(L10n.t(.tabAgents), systemImage: "terminal") }
            SafetyPane(controller: controller, settings: controller.settings)
                .tabItem { Label(L10n.t(.tabSafety), systemImage: "shield.lefthalf.filled") }
            AboutPane(controller: controller)
                .tabItem { Label(L10n.t(.tabAbout), systemImage: "info.circle") }
        }
        .frame(width: 540, height: 520)
        .tint(Theme.amber)
    }
}

// MARK: General

struct GeneralPane: View {
    @Bindable var settings: AppSettings
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Picker(L10n.t(.language), selection: $settings.language) {
                    Text(L10n.t(.languageSystem)).tag(AppLanguage.system)
                    Text("English").tag(AppLanguage.en)
                    Text("Русский").tag(AppLanguage.ru)
                    Text("Українська").tag(AppLanguage.uk)
                }
                Toggle(L10n.t(.launchAtLogin), isOn: Binding(
                    get: { launchAtLogin },
                    set: { on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {}
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                ))
                VStack(alignment: .leading, spacing: 2) {
                    Toggle(L10n.t(.globalShortcut), isOn: $settings.hotkeyEnabled)
                    Hint(L10n.t(.globalShortcutHint))
                }
            }
            Section {
                Toggle(L10n.t(.keepDisplayOn), isOn: $settings.keepDisplayOn)
                VStack(alignment: .leading, spacing: 2) {
                    Toggle(L10n.t(.displayOffOnLidClose), isOn: $settings.displayOffOnLidClose)
                    Hint(L10n.t(.displayOffOnLidCloseHint))
                }
            }
            Section(L10n.t(.notifications)) {
                Toggle(L10n.t(.notifyFinished), isOn: $settings.notifyOnFinish)
                Toggle(L10n.t(.notifyReleased), isOn: $settings.notifyOnRelease)
                Toggle(L10n.t(.notifyLidSummary), isOn: $settings.summaryOnLidOpen)
                Toggle(L10n.t(.playSound), isOn: $settings.playSound)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: Agents

struct AgentsPane: View {
    @Bindable var controller: AwakeController
    @Bindable var settings: AppSettings
    @State private var newCommand = ""

    private var runningIDs: Set<String> { Set(controller.agents.map(\.id)) }

    var body: some View {
        Form {
            Section {
                ForEach(AgentCatalog.builtIn) { agent in
                    Toggle(isOn: Binding(
                        get: { !settings.disabledAgents.contains(agent.id) },
                        set: { on in
                            if on { settings.disabledAgents.remove(agent.id) } else { settings.disabledAgents.insert(agent.id) }
                        }
                    )) {
                        HStack(spacing: 10) {
                            Monogram(text: agent.monogram, active: runningIDs.contains(agent.id))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(agent.name)
                                Text(agent.commands[0])
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text(L10n.t(.watchedAgents))
            } footer: {
                Hint(L10n.t(.watchedAgentsHint))
            }

            Section {
                ForEach(settings.customCommands, id: \.self) { command in
                    HStack {
                        Monogram(text: String(command.prefix(2)).capitalized,
                                 active: runningIDs.contains("custom:\(command)"))
                        Text(command).font(.system(size: 12, design: .monospaced))
                        Spacer()
                        Button(L10n.t(.remove)) {
                            settings.customCommands.removeAll { $0 == command }
                        }
                        .buttonStyle(.borderless)
                    }
                }
                HStack {
                    TextField(L10n.t(.customPlaceholder), text: $newCommand)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .onSubmit(addCommand)
                    Button(L10n.t(.add), action: addCommand)
                        .disabled(newCommand.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text(L10n.t(.customCommands))
            } footer: {
                Hint(L10n.t(.customCommandsHint))
            }

            Section(L10n.t(.autoMode)) {
                Picker(L10n.t(.graceAfterLast), selection: $settings.graceMinutes) {
                    ForEach([0, 1, 2, 5, 10, 15, 30], id: \.self) { Text(L10n.t(.minutesShort, $0)).tag($0) }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Toggle(L10n.t(.idleRelease), isOn: $settings.idleReleaseEnabled)
                    Hint(L10n.t(.idleReleaseHint))
                }
                if settings.idleReleaseEnabled {
                    Picker(L10n.t(.idleReleaseAfter), selection: $settings.idleMinutes) {
                        ForEach([5, 10, 15, 30, 60], id: \.self) { Text(L10n.t(.minutesShort, $0)).tag($0) }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func addCommand() {
        settings.addCustomCommand(newCommand)
        newCommand = ""
    }
}

// MARK: Safety

struct SafetyPane: View {
    @Bindable var controller: AwakeController
    @Bindable var settings: AppSettings
    @State private var busy = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Toggle(isOn: $settings.batteryFloorEnabled) {
                        HStack {
                            Text(L10n.t(.batteryFloor))
                            Spacer()
                            Text("\(settings.batteryFloor)%").monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                    if settings.batteryFloorEnabled {
                        Slider(value: Binding(get: { Double(settings.batteryFloor) },
                                              set: { settings.batteryFloor = Int($0) }),
                               in: 5...50, step: 5)
                    }
                    Hint(L10n.t(.batteryFloorHint))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Toggle(L10n.t(.requireCharger), isOn: $settings.requireCharger)
                    Hint(L10n.t(.requireChargerHint))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Toggle(L10n.t(.thermalGuard), isOn: $settings.thermalGuardEnabled)
                    Hint(L10n.t(.thermalGuardHint))
                }
            }

            Section(L10n.t(.helperRule)) {
                HStack {
                    Label(controller.helperInstalled ? L10n.t(.helperInstalled) : L10n.t(.helperMissing),
                          systemImage: controller.helperInstalled ? "checkmark.seal" : "seal")
                        .foregroundStyle(controller.helperInstalled ? AnyShapeStyle(Theme.amber) : AnyShapeStyle(.secondary))
                    Spacer()
                    if busy { ProgressView().controlSize(.small) }
                    if controller.helperInstalled {
                        Button(L10n.t(.helperRemove)) {
                            run { await controller.removeHelper(prompt: L10n.t(.adminRemovePrompt)) }
                        }
                    } else {
                        Button(L10n.t(.helperInstall)) {
                            run { await controller.installHelper(prompt: L10n.t(.adminPrompt)) }
                        }
                    }
                }
                .disabled(busy)
                VStack(alignment: .leading, spacing: 6) {
                    Hint(L10n.t(.helperHint))
                    Code("/usr/bin/pmset -a disablesleep 1\n/usr/bin/pmset -a disablesleep 0")
                    Code(HelperRule.path)
                }
            }

            Section(L10n.t(.emergency)) {
                HStack {
                    Text(L10n.t(.currentSetting))
                    Spacer()
                    Text(controller.lidModeActive ? L10n.t(.settingOn) : L10n.t(.settingOff))
                        .foregroundStyle(controller.lidModeActive ? AnyShapeStyle(Theme.amber) : AnyShapeStyle(.secondary))
                }
                HStack {
                    Button(L10n.t(.restoreSleepNow)) { controller.forceRestoreSleep() }
                        .disabled(!controller.helperInstalled)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Hint(L10n.t(.restoreSleepHint))
                    Code("sudo pmset -a disablesleep 0")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { controller.refreshHelperState() }
    }

    private func run(_ work: @escaping () async -> Void) {
        busy = true
        Task {
            await work()
            busy = false
        }
    }
}

// MARK: About

struct AboutPane: View {
    @Bindable var controller: AwakeController

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            if let icon = NSApp?.applicationIconImage {
                Image(nsImage: icon).resizable().frame(width: 96, height: 96)
            }
            VStack(spacing: 4) {
                Text("Vibecode24").font(.system(size: 22, weight: .semibold))
                Text(L10n.t(.aboutTagline)).foregroundStyle(.secondary)
                Text(L10n.t(.aboutVersion, version))
                    .font(.system(size: 11)).monospacedDigit().foregroundStyle(.tertiary)
            }
            Text(L10n.t(.aboutLidTotal, L10n.duration(controller.stats.totalLidClosed)))
                .font(.system(size: 12)).monospacedDigit()
            HStack(spacing: 16) {
                Link(L10n.t(.aboutSource), destination: URL(string: "https://github.com/vladyslavkovalskyi/vibecode24")!)
                Button(L10n.t(.clearHistory)) { controller.clearHistory() }
                    .buttonStyle(.link)
            }
            .font(.system(size: 12))
            Spacer()
            Text("© 2026 Vladyslav Kovalskyi · MIT")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: Small pieces

struct Hint: View {
    var text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct Code: View {
    var text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .textSelection(.enabled)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.tile))
    }
}
