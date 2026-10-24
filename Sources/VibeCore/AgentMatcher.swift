import Foundation

/// A process as the radar sees it. Kept small and value-typed so matching is testable.
public struct ProcessSnapshot: Hashable, Sendable {
    public let pid: Int32
    public let ppid: Int32
    public let executablePath: String
    public let arguments: [String]
    public let startTime: Date

    public init(pid: Int32, ppid: Int32, executablePath: String, arguments: [String], startTime: Date) {
        self.pid = pid
        self.ppid = ppid
        self.executablePath = executablePath
        self.arguments = arguments
        self.startTime = startTime
    }
}

public struct AgentMatcher: Sendable {
    /// Interpreters whose first script argument names the real program.
    static let interpreters: Set<String> = ["node", "bun", "deno", "python", "python3", "Python", "uv", "uvx", "npx", "pipx"]

    public let definitions: [AgentDefinition]

    public init(definitions: [AgentDefinition]) {
        self.definitions = definitions
    }

    /// Returns the definition this process belongs to, or nil.
    public func match(_ process: ProcessSnapshot) -> AgentDefinition? {
        let execName = Self.basename(process.executablePath)
        let argv0 = process.arguments.first.map(Self.basename) ?? ""

        // The radar must never see itself or a search for an agent's name.
        if Self.ignored.contains(execName) || Self.ignored.contains(argv0) { return nil }

        let isInterpreter = Self.isInterpreter(execName) || Self.isInterpreter(argv0)
        // For an interpreter only the script (or `-m module`) names the program. Later
        // arguments are user data ("node server.js --name claude").
        let scriptArgs = isInterpreter ? Self.scriptArgument(process.arguments).map { [$0] } ?? [] : []

        for definition in definitions where matches(definition, process: process, execName: execName,
                                                     argv0: argv0, isInterpreter: isInterpreter,
                                                     scriptArgs: scriptArgs) {
            let skip = isInterpreter ? (process.arguments.firstIndex(of: scriptArgs.first ?? "") ?? 0) + 1 : 1
            let rest = process.arguments.dropFirst(skip)
            if let first = rest.first, definition.excludedArguments.contains(first) { return nil }
            if rest.contains(where: { $0.hasPrefix("--") && definition.excludedArguments.contains($0) }) { return nil }
            return definition
        }
        return nil
    }

    private func matches(_ definition: AgentDefinition, process: ProcessSnapshot, execName: String,
                         argv0: String, isInterpreter: Bool, scriptArgs: [String]) -> Bool {
        for command in definition.commands {
            if execName == command || argv0 == command { return true }
            if isInterpreter, scriptArgs.contains(where: { Self.basename($0) == command }) { return true }
        }
        for marker in definition.markers {
            if process.executablePath.contains(marker) { return true }
            if isInterpreter, scriptArgs.contains(where: { $0.contains(marker) }) { return true }
        }
        return false
    }

    /// The first non-flag argument after the interpreter, or the module after `-m`.
    static func scriptArgument(_ arguments: [String]) -> String? {
        var iterator = arguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            if argument == "-m" { return iterator.next() }
            if argument.hasPrefix("-") { continue }
            return argument
        }
        return nil
    }

    static let ignored: Set<String> = ["grep", "rg", "pgrep", "pkill", "kill", "man", "which", "less", "tail", "Vibecode24"]

    static func isInterpreter(_ name: String) -> Bool {
        if interpreters.contains(name) { return true }
        // python3.12, python3.13 and so on.
        return name.hasPrefix("python3.")
    }

    static func basename(_ path: String) -> String {
        guard let slash = path.lastIndex(of: "/") else { return path }
        return String(path[path.index(after: slash)...])
    }
}
