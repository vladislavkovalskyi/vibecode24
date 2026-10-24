import Darwin
import Foundation

/// One running agent process tree.
public struct AgentSession: Hashable, Sendable, Identifiable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let startTime: Date
    /// CPU use of the agent process plus everything it spawned, in percent of one core.
    public let cpuPercent: Double
}

/// All sessions of one agent at one moment.
public struct AgentActivity: Hashable, Sendable, Identifiable {
    public var id: String { definition.id }
    public let definition: AgentDefinition
    public let sessions: [AgentSession]

    public var cpuPercent: Double { sessions.reduce(0) { $0 + $1.cpuPercent } }
    public var earliestStart: Date { sessions.map(\.startTime).min() ?? Date() }
}

/// Reads the process table with libproc. Not thread-safe: call it from one queue.
public final class ProcessScanner: @unchecked Sendable {
    private struct CPUSample { let ticks: UInt64; let at: UInt64 }
    private struct CachedArgs { let start: Date; let path: String; let args: [String] }

    private var lastCPU: [Int32: CPUSample] = [:]
    private var argsCache: [Int32: CachedArgs] = [:]
    private let uid = getuid()

    public init() {}

    public func scan(matcher: AgentMatcher) -> [AgentActivity] {
        let now = mach_absolute_time()
        var processes: [Int32: ProcessSnapshot] = [:]
        var cpu: [Int32: Double] = [:]
        var nextCPU: [Int32: CPUSample] = [:]
        var nextArgs: [Int32: CachedArgs] = [:]

        for pid in Self.allPIDs() where pid > 0 {
            var bsd = proc_bsdinfo()
            let size = Int32(MemoryLayout<proc_bsdinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, size) == size else { continue }
            guard bsd.pbi_uid == uid else { continue }

            let start = Date(timeIntervalSince1970: TimeInterval(bsd.pbi_start_tvsec)
                             + TimeInterval(bsd.pbi_start_tvusec) / 1_000_000)
            let cached: CachedArgs
            if let hit = argsCache[pid], hit.start == start {
                cached = hit
            } else {
                cached = CachedArgs(start: start, path: Self.path(of: pid), args: Self.arguments(of: pid))
            }
            nextArgs[pid] = cached
            processes[pid] = ProcessSnapshot(pid: pid, ppid: Int32(bsd.pbi_ppid),
                                             executablePath: cached.path,
                                             arguments: cached.args, startTime: start)

            var task = proc_taskinfo()
            let taskSize = Int32(MemoryLayout<proc_taskinfo>.size)
            if proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &task, taskSize) == taskSize {
                let ticks = task.pti_total_user + task.pti_total_system
                let sample = CPUSample(ticks: ticks, at: now)
                nextCPU[pid] = sample
                if let previous = lastCPU[pid], now > previous.at, ticks >= previous.ticks {
                    // On Apple silicon task times are in Mach ticks, like mach_absolute_time,
                    // so the timebase cancels out in the ratio.
                    cpu[pid] = Double(ticks - previous.ticks) / Double(now - previous.at) * 100
                }
            }
        }
        lastCPU = nextCPU
        argsCache = nextArgs

        return Self.group(processes: processes, cpu: cpu, matcher: matcher)
    }

    /// Groups matched processes into sessions. A matched process whose ancestor matched the
    /// same agent is part of that ancestor's session (a Node wrapper and its native binary).
    static func group(processes: [Int32: ProcessSnapshot], cpu: [Int32: Double],
                      matcher: AgentMatcher) -> [AgentActivity] {
        var matches: [Int32: AgentDefinition] = [:]
        for (pid, process) in processes {
            if let definition = matcher.match(process) { matches[pid] = definition }
        }

        var children: [Int32: [Int32]] = [:]
        for (pid, process) in processes { children[process.ppid, default: []].append(pid) }

        func hasMatchedAncestor(_ pid: Int32, id: String) -> Bool {
            var current = processes[pid]?.ppid ?? 0
            var hops = 0
            while current > 1, hops < 64 {
                if matches[current]?.id == id { return true }
                current = processes[current]?.ppid ?? 0
                hops += 1
            }
            return false
        }

        func treeCPU(_ root: Int32) -> Double {
            var total = 0.0
            var stack = [root]
            var seen: Set<Int32> = []
            while let pid = stack.popLast() {
                guard seen.insert(pid).inserted else { continue }
                total += cpu[pid] ?? 0
                stack.append(contentsOf: children[pid] ?? [])
            }
            return total
        }

        var byAgent: [String: (AgentDefinition, [AgentSession])] = [:]
        for (pid, definition) in matches where !hasMatchedAncestor(pid, id: definition.id) {
            guard let process = processes[pid] else { continue }
            let session = AgentSession(pid: pid, startTime: process.startTime, cpuPercent: treeCPU(pid))
            byAgent[definition.id, default: (definition, [])].1.append(session)
        }

        let order = Dictionary(uniqueKeysWithValues: matcher.definitions.enumerated().map { ($1.id, $0) })
        return byAgent.values
            .map { AgentActivity(definition: $0.0, sessions: $0.1.sorted { $0.startTime < $1.startTime }) }
            .sorted { (order[$0.definition.id] ?? .max) < (order[$1.definition.id] ?? .max) }
    }

    // MARK: - libproc helpers

    static func allPIDs() -> [Int32] {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }
        var pids = [Int32](repeating: 0, count: Int(estimate) + 64)
        let count = pids.withUnsafeMutableBufferPointer { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count * MemoryLayout<Int32>.size))
        }
        guard count > 0 else { return [] }
        return Array(pids.prefix(Int(count)))
    }

    static func path(of pid: Int32) -> String {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return "" }
        return String(cString: buffer)
    }

    /// argv of a process, read with sysctl KERN_PROCARGS2. Works for the user's own processes.
    static func arguments(of pid: Int32) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return [] }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return [] }
        return parseProcArgs(Array(buffer.prefix(size)))
    }

    /// Layout: argc (Int32), executable path, NUL padding, then argc NUL-terminated strings.
    static func parseProcArgs(_ bytes: [UInt8]) -> [String] {
        guard bytes.count > 4 else { return [] }
        let argc = bytes.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        guard argc > 0, argc < 4096 else { return [] }
        var index = 4
        while index < bytes.count, bytes[index] != 0 { index += 1 }   // exec path
        while index < bytes.count, bytes[index] == 0 { index += 1 }   // padding
        var result: [String] = []
        while index < bytes.count, result.count < Int(argc) {
            let start = index
            while index < bytes.count, bytes[index] != 0 { index += 1 }
            result.append(String(decoding: bytes[start..<index], as: UTF8.self))
            index += 1
        }
        return result
    }
}
