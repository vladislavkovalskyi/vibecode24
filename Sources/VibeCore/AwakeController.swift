import Foundation
import Observation

/// An agent as the popover shows it: the live activity plus a short CPU history.
public struct AgentRowModel: Identifiable, Hashable, Sendable {
    public var id: String { definition.id }
    public let definition: AgentDefinition
    public let sessionCount: Int
    public let since: Date
    public let cpuPercent: Double
    /// Oldest first, one value per tick.
    public let history: [Double]
    public let isWorking: Bool
    public let idleSince: Date?

    public init(definition: AgentDefinition, sessionCount: Int, since: Date, cpuPercent: Double,
                history: [Double], isWorking: Bool, idleSince: Date?) {
        self.definition = definition
        self.sessionCount = sessionCount
        self.since = since
        self.cpuPercent = cpuPercent
        self.history = history
        self.isWorking = isWorking
        self.idleSince = idleSince
    }
}

/// The brain of the app: scans for agents, asks the policy, and applies the decision.
@MainActor
@Observable
public final class AwakeController {
    public let settings: AppSettings

    public private(set) var decision: AwakeDecision = .release(.off)
    public private(set) var agents: [AgentRowModel] = []
    public private(set) var lidClosed: Bool?
    public private(set) var battery: BatteryState?
    public private(set) var helperInstalled = false
    /// True when lid-closed protection is actually on (`SleepDisabled 1`).
    public private(set) var lidModeActive = false
    public private(set) var sleepDisabledExternally = false
    public private(set) var lastError: String?
    public private(set) var stats = AwakeStats()
    public private(set) var holdingSince: Date?

    /// Called when an agent process tree exits after running for a while.
    @ObservationIgnored public var onAgentFinished: ((String, TimeInterval) -> Void)?
    /// Called when a guard or the end of work gives sleep back.
    @ObservationIgnored public var onReleased: ((ReleaseReason) -> Void)?
    /// Called when the lid opens after being closed for a while: how long, and which agents finished.
    @ObservationIgnored public var onLidOpened: ((TimeInterval, [String]) -> Void)?

    public static let tickInterval: TimeInterval = 3
    static let historyLength = 20
    static let workingThreshold = 3.0

    @ObservationIgnored private let sleep = SleepControl()
    @ObservationIgnored private let scanner = ProcessScanner()
    @ObservationIgnored private let log: SessionLog
    @ObservationIgnored private let queue = DispatchQueue(label: "vibecode24.scan", qos: .utility)
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var history: [String: [Double]] = [:]
    @ObservationIgnored private var idleSinceByAgent: [String: Date] = [:]
    @ObservationIgnored private var liveSessions: [Int32: (name: String, start: Date)] = [:]
    @ObservationIgnored private var lastAgentSeen: Date?
    @ObservationIgnored private var allIdleSince: Date?
    @ObservationIgnored private var currentSession: AwakeSession?
    @ObservationIgnored private var appliedHold = false
    @ObservationIgnored private var ticks = 0
    @ObservationIgnored private var lidClosedAt: Date?
    @ObservationIgnored private var finishedWhileClosed: [String] = []
    @ObservationIgnored private let isPreview: Bool

    @ObservationIgnored private let ownsKey = "ownsDisableSleep"
    private var ownsDisableSleep: Bool {
        get { UserDefaults.standard.bool(forKey: ownsKey) }
        set { UserDefaults.standard.set(newValue, forKey: ownsKey) }
    }

    public init(settings: AppSettings = .shared, log: SessionLog = SessionLog()) {
        self.settings = settings
        self.log = log
        self.isPreview = false
    }

    /// A controller with fixed data and no side effects, for screenshots and previews.
    public init(preview decision: AwakeDecision, agents: [AgentRowModel], lidClosed: Bool?,
                battery: BatteryState?, helperInstalled: Bool, stats: AwakeStats, settings: AppSettings) {
        self.settings = settings
        self.log = SessionLog(defaults: UserDefaults(suiteName: "vibecode24.preview") ?? .standard)
        self.isPreview = true
        self.decision = decision
        self.agents = agents
        self.lidClosed = lidClosed
        self.battery = battery
        self.helperInstalled = helperInstalled
        self.lidModeActive = helperInstalled && decision.isHolding
        self.stats = stats
    }

    // MARK: Lifecycle

    public func start() {
        guard !isPreview, timer == nil else { return }
        recoverAfterCrash()
        refreshHelperState()
        tick()
        let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Gives sleep back synchronously. Called on quit, logout and SIGTERM.
    public func shutdown() {
        guard !isPreview else { return }
        timer?.invalidate()
        timer = nil
        sleep.setIdleAssertion(false, keepDisplayOn: false)
        if ownsDisableSleep {
            if case .success = SleepControl.setSleepDisabled(false) { ownsDisableSleep = false }
        }
        sleep.stopWatchdog()
        closeSession()
    }

    /// If the app died while holding `disablesleep`, the setting is still on. Undo it.
    private func recoverAfterCrash() {
        guard ownsDisableSleep else { return }
        if SleepControl.readSleepDisabled() == true {
            if case .success = SleepControl.setSleepDisabled(false) { ownsDisableSleep = false }
        } else {
            ownsDisableSleep = false
        }
    }

    public func refreshHelperState() {
        guard !isPreview else { return }
        queue.async { [weak self] in
            let installed = HelperRule.isInstalled()
            let current = SleepControl.readSleepDisabled() ?? false
            DispatchQueue.main.async {
                guard let self else { return }
                self.helperInstalled = installed
                self.sleepDisabledExternally = current && !self.ownsDisableSleep
                self.lidModeActive = current
            }
        }
    }

    // MARK: Commands

    public func setMode(_ mode: AwakeMode) {
        if mode == .timer {
            settings.timerEnd = Date().addingTimeInterval(TimeInterval(settings.timerMinutes * 60))
        }
        if mode != .off { settings.lastActiveMode = mode }
        settings.mode = mode
        tick()
    }

    public func startTimer(minutes: Int) {
        settings.timerMinutes = max(1, minutes)
        setMode(.timer)
    }

    public func toggle() {
        setMode(settings.mode == .off ? settings.lastActiveMode : .off)
    }

    public func installHelper(prompt: String) async {
        lastError = nil
        switch await HelperRule.install(prompt: prompt) {
        case .success: break
        case .failure(.cancelled): break
        case .failure(.failed(let message)): lastError = message
        }
        refreshHelperState()
        appliedHold = false   // re-apply so pmset is set now that it is allowed
        tick()
    }

    public func removeHelper(prompt: String) async {
        lastError = nil
        switch await HelperRule.remove(prompt: prompt) {
        case .success: ownsDisableSleep = false
        case .failure(.cancelled): break
        case .failure(.failed(let message)): lastError = message
        }
        refreshHelperState()
    }

    /// Emergency switch: `disablesleep 0` whatever the app thinks.
    public func forceRestoreSleep() {
        queue.async { [weak self] in
            let result = SleepControl.setSleepDisabled(false)
            DispatchQueue.main.async {
                guard let self else { return }
                if case .failure(let error) = result { self.lastError = "\(error)" } else { self.ownsDisableSleep = false }
                self.refreshHelperState()
            }
        }
    }

    public func clearHistory() {
        log.clear()
        stats = SessionLog.stats([], current: currentSession)
    }

    // MARK: Tick

    private func tick() {
        guard !isPreview else { return }
        let matcher = AgentMatcher(definitions: settings.watchedDefinitions)
        let scanner = self.scanner
        queue.async { [weak self] in
            let activity = scanner.scan(matcher: matcher)
            let battery = SystemSensors.battery()
            let lid = SystemSensors.isLidClosed()
            let thermal = SystemSensors.isThermalCritical
            DispatchQueue.main.async {
                self?.process(activity: activity, battery: battery, lid: lid, thermal: thermal)
            }
        }
    }

    private func process(activity: [AgentActivity], battery: BatteryState?, lid: Bool?, thermal: Bool) {
        let now = Date()
        ticks += 1
        self.battery = battery
        let previousLid = lidClosed
        lidClosed = lid

        updateAgents(activity, now: now)
        handleLid(previous: previousLid, current: lid, now: now)

        let input = PolicyInput(
            mode: settings.mode, now: now, timerEnd: settings.timerEnd,
            activeAgentNames: agents.map(\.definition.name),
            lastAgentSeen: lastAgentSeen, allIdleSince: allIdleSince,
            graceSeconds: TimeInterval(settings.graceMinutes * 60),
            idleReleaseEnabled: settings.idleReleaseEnabled,
            idleSeconds: TimeInterval(settings.idleMinutes * 60),
            battery: battery, batteryFloorEnabled: settings.batteryFloorEnabled,
            batteryFloor: settings.batteryFloor, thermalGuardEnabled: settings.thermalGuardEnabled,
            thermalCritical: thermal, requireCharger: settings.requireCharger)
        let newDecision = AwakePolicy.decide(input)

        if case .release(.timerDone) = newDecision, settings.mode == .timer {
            settings.mode = .off
        }
        let wasHolding = decision.isHolding
        decision = newDecision
        if wasHolding, case .release(let reason) = newDecision, reason != .off {
            onReleased?(reason)
        }

        apply(hold: newDecision.isHolding)
        trackSession(now: now, lidWasClosed: previousLid == true)
        stats = SessionLog.stats(log.sessions, current: currentSession, now: now)

        // Every 30 s check the real setting, in case something else changed it.
        if ticks % 10 == 0 { verifySleepSetting() }
    }

    private func updateAgents(_ activity: [AgentActivity], now: Date) {
        // Finished sessions: a pid that was there last tick and is gone now.
        let currentPIDs = Dictionary(uniqueKeysWithValues: activity.flatMap { a in
            a.sessions.map { ($0.pid, (a.definition.name, $0.startTime)) }
        })
        for (pid, info) in liveSessions where currentPIDs[pid] == nil {
            let duration = now.timeIntervalSince(info.start)
            if duration >= 60 { onAgentFinished?(info.name, duration) }
            if lidClosedAt != nil { finishedWhileClosed.append(info.name) }
        }
        liveSessions = currentPIDs.mapValues { (name: $0.0, start: $0.1) }

        var rows: [AgentRowModel] = []
        var anyWorking = false
        for item in activity {
            var samples = history[item.id] ?? []
            samples.append(item.cpuPercent)
            if samples.count > Self.historyLength { samples.removeFirst(samples.count - Self.historyLength) }
            history[item.id] = samples

            let working = (samples.suffix(5).max() ?? 0) >= Self.workingThreshold
            if working {
                idleSinceByAgent[item.id] = nil
                anyWorking = true
            } else if idleSinceByAgent[item.id] == nil {
                idleSinceByAgent[item.id] = now
            }
            rows.append(AgentRowModel(definition: item.definition, sessionCount: item.sessions.count,
                                      since: item.earliestStart, cpuPercent: item.cpuPercent,
                                      history: samples, isWorking: working,
                                      idleSince: idleSinceByAgent[item.id]))
        }
        let activeIDs = Set(activity.map(\.id))
        history = history.filter { activeIDs.contains($0.key) }
        idleSinceByAgent = idleSinceByAgent.filter { activeIDs.contains($0.key) }

        if !rows.isEmpty { lastAgentSeen = now }
        if rows.isEmpty || anyWorking {
            allIdleSince = nil
        } else if allIdleSince == nil {
            allIdleSince = now
        }
        agents = rows
    }

    private func handleLid(previous: Bool?, current: Bool?, now: Date) {
        if previous != true, current == true {
            lidClosedAt = now
            finishedWhileClosed = []
            if decision.isHolding, settings.displayOffOnLidClose {
                queue.async { SleepControl.displaySleepNow() }
            }
        } else if previous == true, current != true, let closedAt = lidClosedAt {
            let duration = now.timeIntervalSince(closedAt)
            if duration >= 120, settings.summaryOnLidOpen { onLidOpened?(duration, finishedWhileClosed) }
            lidClosedAt = nil
            finishedWhileClosed = []
        }
    }

    private func apply(hold: Bool) {
        let keepDisplay = settings.keepDisplayOn
        sleep.setIdleAssertion(hold, keepDisplayOn: keepDisplay)
        guard hold != appliedHold else { return }
        appliedHold = hold

        let ownsNow = ownsDisableSleep
        let sleepControl = sleep
        queue.async { [weak self] in
            let current = SleepControl.readSleepDisabled() ?? false
            var error: String?
            var owns = ownsNow
            if hold {
                if current {
                    // Already on: either ours from before, or the user's own setting.
                } else {
                    switch SleepControl.setSleepDisabled(true) {
                    case .success: owns = true
                    case .failure(.notAuthorized): break   // no rule yet; the assertion still works
                    case .failure(.failed(let message)): error = message
                    }
                }
            } else if owns {
                switch SleepControl.setSleepDisabled(false) {
                case .success: owns = false
                case .failure(let failure): error = "\(failure)"
                }
            }
            let final = SleepControl.readSleepDisabled() ?? false
            if owns && final { sleepControl.startWatchdog() } else { sleepControl.stopWatchdog() }
            DispatchQueue.main.async {
                guard let self else { return }
                self.ownsDisableSleep = owns
                self.lidModeActive = final
                self.sleepDisabledExternally = final && !owns
                if let error { self.lastError = error }
            }
        }
    }

    private func verifySleepSetting() {
        let hold = appliedHold
        let owns = ownsDisableSleep
        let installed = helperInstalled
        let sleepControl = sleep
        queue.async { [weak self] in
            let current = SleepControl.readSleepDisabled() ?? false
            var newOwns = owns
            if hold, !current, installed {
                if case .success = SleepControl.setSleepDisabled(true) { newOwns = true }
            } else if !hold, current, owns {
                if case .success = SleepControl.setSleepDisabled(false) { newOwns = false }
            }
            let final = SleepControl.readSleepDisabled() ?? current
            if newOwns && final { sleepControl.startWatchdog() } else if !newOwns { sleepControl.stopWatchdog() }
            DispatchQueue.main.async {
                guard let self else { return }
                self.ownsDisableSleep = newOwns
                self.lidModeActive = final
                self.sleepDisabledExternally = final && !newOwns
            }
        }
    }

    // MARK: Sessions

    private func trackSession(now: Date, lidWasClosed: Bool) {
        if decision.isHolding {
            if currentSession == nil {
                currentSession = AwakeSession(start: now, end: now, lidClosedSeconds: 0, agents: [])
                holdingSince = now
            }
            currentSession?.end = now
            if lidWasClosed || lidClosed == true {
                currentSession?.lidClosedSeconds += Self.tickInterval
            }
            for name in agents.map(\.definition.name) where !(currentSession?.agents.contains(name) ?? true) {
                currentSession?.agents.append(name)
            }
        } else {
            closeSession()
        }
    }

    private func closeSession() {
        if let session = currentSession { log.append(session) }
        currentSession = nil
        holdingSince = nil
    }
}
