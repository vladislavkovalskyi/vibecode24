import Foundation
import Observation

public enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case system, en, ru, uk

    /// The language actually used for text.
    public var resolved: AppLanguage {
        guard self == .system else { return self }
        return Self.fromPreferred(Locale.preferredLanguages)
    }

    static func fromPreferred(_ preferred: [String]) -> AppLanguage {
        for code in preferred {
            if code.hasPrefix("uk") { return .uk }
            if code.hasPrefix("ru") { return .ru }
            if code.hasPrefix("en") { return .en }
        }
        return .en
    }
}

/// User preferences, saved to UserDefaults on every change.
@Observable
public final class AppSettings {
    public static let shared = AppSettings()

    @ObservationIgnored private let defaults: UserDefaults

    public var mode: AwakeMode { didSet { defaults.set(mode.rawValue, forKey: Keys.mode) } }
    /// The mode the toggle returns to when switched on.
    public var lastActiveMode: AwakeMode { didSet { defaults.set(lastActiveMode.rawValue, forKey: Keys.lastActiveMode) } }
    public var timerEnd: Date? { didSet { defaults.set(timerEnd, forKey: Keys.timerEnd) } }
    public var timerMinutes: Int { didSet { defaults.set(timerMinutes, forKey: Keys.timerMinutes) } }
    public var language: AppLanguage { didSet { defaults.set(language.rawValue, forKey: Keys.language) } }

    public var disabledAgents: Set<String> { didSet { defaults.set(Array(disabledAgents).sorted(), forKey: Keys.disabledAgents) } }
    public var customCommands: [String] { didSet { defaults.set(customCommands, forKey: Keys.customCommands) } }
    public var graceMinutes: Int { didSet { defaults.set(graceMinutes, forKey: Keys.graceMinutes) } }
    public var idleReleaseEnabled: Bool { didSet { defaults.set(idleReleaseEnabled, forKey: Keys.idleRelease) } }
    public var idleMinutes: Int { didSet { defaults.set(idleMinutes, forKey: Keys.idleMinutes) } }

    public var batteryFloorEnabled: Bool { didSet { defaults.set(batteryFloorEnabled, forKey: Keys.batteryFloorEnabled) } }
    public var batteryFloor: Int { didSet { defaults.set(batteryFloor, forKey: Keys.batteryFloor) } }
    public var thermalGuardEnabled: Bool { didSet { defaults.set(thermalGuardEnabled, forKey: Keys.thermalGuard) } }
    public var requireCharger: Bool { didSet { defaults.set(requireCharger, forKey: Keys.requireCharger) } }
    /// Turns the display off when the lid closes, which also locks the Mac if a password is required.
    public var displayOffOnLidClose: Bool { didSet { defaults.set(displayOffOnLidClose, forKey: Keys.displayOffOnLidClose) } }
    public var summaryOnLidOpen: Bool { didSet { defaults.set(summaryOnLidOpen, forKey: Keys.summaryOnLidOpen) } }

    public var notifyOnFinish: Bool { didSet { defaults.set(notifyOnFinish, forKey: Keys.notifyOnFinish) } }
    public var notifyOnRelease: Bool { didSet { defaults.set(notifyOnRelease, forKey: Keys.notifyOnRelease) } }
    public var playSound: Bool { didSet { defaults.set(playSound, forKey: Keys.playSound) } }
    public var keepDisplayOn: Bool { didSet { defaults.set(keepDisplayOn, forKey: Keys.keepDisplayOn) } }
    public var hotkeyEnabled: Bool { didSet { defaults.set(hotkeyEnabled, forKey: Keys.hotkey) } }
    public var onboardingDone: Bool { didSet { defaults.set(onboardingDone, forKey: Keys.onboardingDone) } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = AwakeMode(rawValue: defaults.string(forKey: Keys.mode) ?? "") ?? .auto
        lastActiveMode = AwakeMode(rawValue: defaults.string(forKey: Keys.lastActiveMode) ?? "") ?? .auto
        timerEnd = defaults.object(forKey: Keys.timerEnd) as? Date
        timerMinutes = defaults.object(forKey: Keys.timerMinutes) as? Int ?? 60
        language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .system
        disabledAgents = Set(defaults.stringArray(forKey: Keys.disabledAgents) ?? [])
        customCommands = defaults.stringArray(forKey: Keys.customCommands) ?? []
        graceMinutes = defaults.object(forKey: Keys.graceMinutes) as? Int ?? 2
        idleReleaseEnabled = defaults.object(forKey: Keys.idleRelease) as? Bool ?? false
        idleMinutes = defaults.object(forKey: Keys.idleMinutes) as? Int ?? 15
        batteryFloorEnabled = defaults.object(forKey: Keys.batteryFloorEnabled) as? Bool ?? true
        batteryFloor = defaults.object(forKey: Keys.batteryFloor) as? Int ?? 15
        thermalGuardEnabled = defaults.object(forKey: Keys.thermalGuard) as? Bool ?? true
        requireCharger = defaults.object(forKey: Keys.requireCharger) as? Bool ?? false
        displayOffOnLidClose = defaults.object(forKey: Keys.displayOffOnLidClose) as? Bool ?? true
        summaryOnLidOpen = defaults.object(forKey: Keys.summaryOnLidOpen) as? Bool ?? true
        notifyOnFinish = defaults.object(forKey: Keys.notifyOnFinish) as? Bool ?? true
        notifyOnRelease = defaults.object(forKey: Keys.notifyOnRelease) as? Bool ?? true
        playSound = defaults.object(forKey: Keys.playSound) as? Bool ?? true
        keepDisplayOn = defaults.object(forKey: Keys.keepDisplayOn) as? Bool ?? false
        hotkeyEnabled = defaults.object(forKey: Keys.hotkey) as? Bool ?? true
        onboardingDone = defaults.bool(forKey: Keys.onboardingDone)

        if mode == .timer, (timerEnd ?? .distantPast) <= Date() { mode = .off }
    }

    /// Built-in agents that are switched on, plus the user's own commands.
    public var watchedDefinitions: [AgentDefinition] {
        AgentCatalog.builtIn.filter { !disabledAgents.contains($0.id) }
            + customCommands.filter { !$0.isEmpty }.map(AgentDefinition.custom)
    }

    public func addCustomCommand(_ raw: String) {
        let command = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty, !command.contains(" "), !customCommands.contains(command) else { return }
        customCommands.append(command)
    }

    enum Keys {
        static let mode = "mode"
        static let lastActiveMode = "lastActiveMode"
        static let timerEnd = "timerEnd"
        static let timerMinutes = "timerMinutes"
        static let language = "language"
        static let disabledAgents = "disabledAgents"
        static let customCommands = "customCommands"
        static let graceMinutes = "graceMinutes"
        static let idleRelease = "idleReleaseEnabled"
        static let idleMinutes = "idleMinutes"
        static let batteryFloorEnabled = "batteryFloorEnabled"
        static let batteryFloor = "batteryFloor"
        static let thermalGuard = "thermalGuardEnabled"
        static let requireCharger = "requireCharger"
        static let displayOffOnLidClose = "displayOffOnLidClose"
        static let summaryOnLidOpen = "summaryOnLidOpen"
        static let notifyOnFinish = "notifyOnFinish"
        static let notifyOnRelease = "notifyOnRelease"
        static let playSound = "playSound"
        static let keepDisplayOn = "keepDisplayOn"
        static let hotkey = "hotkeyEnabled"
        static let onboardingDone = "onboardingDone"
    }
}
