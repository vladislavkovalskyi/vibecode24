import Foundation

public enum AwakeMode: String, Codable, CaseIterable, Sendable {
    case off, auto, always, timer
}

public enum HoldReason: Equatable, Sendable {
    case agents([String])
    case grace(until: Date)
    case always
    case timer(until: Date)
}

public enum ReleaseReason: Equatable, Sendable {
    case off
    case noAgents
    case timerDone
    case battery(Int)
    case onBattery
    case thermal
    case agentsIdle
}

public enum AwakeDecision: Equatable, Sendable {
    case hold(HoldReason)
    case release(ReleaseReason)

    public var isHolding: Bool {
        if case .hold = self { return true }
        return false
    }
}

/// Everything the policy needs to decide, gathered by the controller on each tick.
public struct PolicyInput: Sendable {
    public var mode: AwakeMode
    public var now: Date
    public var timerEnd: Date?
    public var activeAgentNames: [String]
    public var lastAgentSeen: Date?
    public var allIdleSince: Date?
    public var graceSeconds: TimeInterval
    public var idleReleaseEnabled: Bool
    public var idleSeconds: TimeInterval
    public var battery: BatteryState?
    public var batteryFloorEnabled: Bool
    public var batteryFloor: Int
    public var thermalGuardEnabled: Bool
    public var thermalCritical: Bool
    public var requireCharger: Bool

    public init(mode: AwakeMode, now: Date = Date(), timerEnd: Date? = nil, activeAgentNames: [String] = [],
                lastAgentSeen: Date? = nil, allIdleSince: Date? = nil, graceSeconds: TimeInterval = 120,
                idleReleaseEnabled: Bool = false, idleSeconds: TimeInterval = 600, battery: BatteryState? = nil,
                batteryFloorEnabled: Bool = true, batteryFloor: Int = 15, thermalGuardEnabled: Bool = true,
                thermalCritical: Bool = false, requireCharger: Bool = false) {
        self.mode = mode
        self.now = now
        self.timerEnd = timerEnd
        self.activeAgentNames = activeAgentNames
        self.lastAgentSeen = lastAgentSeen
        self.allIdleSince = allIdleSince
        self.graceSeconds = graceSeconds
        self.idleReleaseEnabled = idleReleaseEnabled
        self.idleSeconds = idleSeconds
        self.battery = battery
        self.batteryFloorEnabled = batteryFloorEnabled
        self.batteryFloor = batteryFloor
        self.thermalGuardEnabled = thermalGuardEnabled
        self.thermalCritical = thermalCritical
        self.requireCharger = requireCharger
    }
}

/// Pure decision: should the Mac stay awake right now, and why.
public enum AwakePolicy {
    public static func decide(_ input: PolicyInput) -> AwakeDecision {
        if input.mode == .off { return .release(.off) }

        // Guards come first: they protect the hardware whatever the mode says.
        if input.thermalGuardEnabled && input.thermalCritical { return .release(.thermal) }
        if input.batteryFloorEnabled, let battery = input.battery, battery.onBattery, !battery.charging,
           battery.percent <= input.batteryFloor {
            return .release(.battery(battery.percent))
        }
        if input.requireCharger, let battery = input.battery, battery.onBattery {
            return .release(.onBattery)
        }

        switch input.mode {
        case .off:
            return .release(.off)
        case .always:
            return .hold(.always)
        case .timer:
            guard let end = input.timerEnd, input.now < end else { return .release(.timerDone) }
            return .hold(.timer(until: end))
        case .auto:
            if !input.activeAgentNames.isEmpty {
                if input.idleReleaseEnabled, let since = input.allIdleSince,
                   input.now.timeIntervalSince(since) >= input.idleSeconds {
                    return .release(.agentsIdle)
                }
                return .hold(.agents(input.activeAgentNames))
            }
            if let last = input.lastAgentSeen {
                let until = last.addingTimeInterval(input.graceSeconds)
                if input.now < until { return .hold(.grace(until: until)) }
            }
            return .release(.noAgents)
        }
    }
}
