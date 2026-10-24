import Foundation

/// One stretch of time during which the app held the Mac awake.
public struct AwakeSession: Codable, Hashable, Sendable {
    public var start: Date
    public var end: Date
    public var lidClosedSeconds: TimeInterval
    public var agents: [String]

    public init(start: Date, end: Date, lidClosedSeconds: TimeInterval, agents: [String]) {
        self.start = start
        self.end = end
        self.lidClosedSeconds = lidClosedSeconds
        self.agents = agents
    }
}

public struct AwakeStats: Equatable, Sendable {
    public var todayAwake: TimeInterval = 0
    public var todayLidClosed: TimeInterval = 0
    public var totalLidClosed: TimeInterval = 0
    public var sessionCount: Int = 0

    public init(todayAwake: TimeInterval = 0, todayLidClosed: TimeInterval = 0,
                totalLidClosed: TimeInterval = 0, sessionCount: Int = 0) {
        self.todayAwake = todayAwake
        self.todayLidClosed = todayLidClosed
        self.totalLidClosed = totalLidClosed
        self.sessionCount = sessionCount
    }
}

/// Keeps the last sessions in UserDefaults.
public final class SessionLog {
    private let defaults: UserDefaults
    private let key = "sessions"
    private let limit = 300
    public private(set) var sessions: [AwakeSession]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([AwakeSession].self, from: data) {
            sessions = decoded
        } else {
            sessions = []
        }
    }

    public func append(_ session: AwakeSession) {
        guard session.end.timeIntervalSince(session.start) >= 5 else { return }
        sessions.append(session)
        if sessions.count > limit { sessions.removeFirst(sessions.count - limit) }
        if let data = try? JSONEncoder().encode(sessions) { defaults.set(data, forKey: key) }
    }

    public func clear() {
        sessions = []
        defaults.removeObject(forKey: key)
    }

    /// Stats including a session that is still running.
    public static func stats(_ sessions: [AwakeSession], current: AwakeSession? = nil,
                             now: Date = Date(), calendar: Calendar = .current) -> AwakeStats {
        let all = sessions + (current.map { [$0] } ?? [])
        let dayStart = calendar.startOfDay(for: now)
        var stats = AwakeStats()
        stats.sessionCount = all.count
        for session in all {
            stats.totalLidClosed += session.lidClosedSeconds
            let overlapStart = max(session.start, dayStart)
            let overlapEnd = min(session.end, now)
            guard overlapEnd > overlapStart else { continue }
            let overlap = overlapEnd.timeIntervalSince(overlapStart)
            stats.todayAwake += overlap
            let length = session.end.timeIntervalSince(session.start)
            // Lid time is not stored per minute, so spread it evenly over the session.
            if length > 0 { stats.todayLidClosed += session.lidClosedSeconds * (overlap / length) }
        }
        return stats
    }
}
