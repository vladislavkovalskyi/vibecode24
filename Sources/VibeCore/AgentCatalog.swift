import Foundation

/// A coding agent the radar knows how to recognise in the process table.
public struct AgentDefinition: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    /// Short label drawn in the row tile.
    public let monogram: String
    /// Command names as they appear in argv[0], in the executable path, or as the
    /// script name after an interpreter (`node /opt/homebrew/bin/gemini`).
    public let commands: [String]
    /// Substrings that identify the agent inside an interpreter's arguments or inside the
    /// executable path, e.g. an npm package name.
    public let markers: [String]
    /// Arguments that mark a helper process of the same tool, not an agent session
    /// (`claude --chrome-native-host`, `codex app-server`).
    public let excludedArguments: [String]
    public let isCustom: Bool

    public init(id: String, name: String, monogram: String, commands: [String],
                markers: [String] = [], excludedArguments: [String] = [], isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.monogram = monogram
        self.commands = commands
        self.markers = markers
        self.excludedArguments = excludedArguments
        self.isCustom = isCustom
    }

    public static func custom(command: String) -> AgentDefinition {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        return AgentDefinition(
            id: "custom:\(trimmed)",
            name: trimmed,
            monogram: String(trimmed.prefix(2)).capitalized,
            commands: [trimmed],
            isCustom: true
        )
    }
}

public enum AgentCatalog {
    /// Built-in agents. To add one, append a definition here and a test case in
    /// `AgentMatcherTests`.
    public static let builtIn: [AgentDefinition] = [
        // Native installs run ~/.local/share/claude/versions/<version>: only argv[0] says "claude".
        AgentDefinition(id: "claude", name: "Claude Code", monogram: "Cl",
                        commands: ["claude", "claude.exe"],
                        markers: ["@anthropic-ai/claude-code", "/claude/versions/"],
                        excludedArguments: ["--chrome-native-host", "mcp", "--version"]),
        AgentDefinition(id: "codex", name: "Codex", monogram: "Cx",
                        commands: ["codex"],
                        markers: ["@openai/codex"],
                        excludedArguments: ["app-server", "mcp-server", "mcp", "--version"]),
        AgentDefinition(id: "gemini", name: "Gemini CLI", monogram: "Ge",
                        commands: ["gemini"],
                        markers: ["@google/gemini-cli"]),
        AgentDefinition(id: "aider", name: "Aider", monogram: "Ai",
                        commands: ["aider"],
                        markers: ["aider-chat", "/aider/__main__"]),
        AgentDefinition(id: "opencode", name: "OpenCode", monogram: "Oc",
                        commands: ["opencode", "opencode.exe"],
                        markers: ["opencode-ai/", "opencode-darwin"],
                        excludedArguments: ["serve"]),
        AgentDefinition(id: "cursor", name: "Cursor Agent", monogram: "Cu",
                        commands: ["cursor-agent"],
                        markers: ["/cursor-agent/"]),
        AgentDefinition(id: "copilot", name: "Copilot CLI", monogram: "Co",
                        commands: ["copilot"],
                        markers: ["@github/copilot/"]),
        AgentDefinition(id: "amp", name: "Amp", monogram: "Am",
                        commands: ["amp", "amp.exe"],
                        markers: ["@sourcegraph/amp"]),
        AgentDefinition(id: "goose", name: "Goose", monogram: "Go",
                        commands: ["goose"]),
        AgentDefinition(id: "qwen", name: "Qwen Code", monogram: "Qw",
                        commands: ["qwen"],
                        markers: ["@qwen-code/qwen-code"]),
        AgentDefinition(id: "crush", name: "Crush", monogram: "Cr",
                        commands: ["crush"]),
        AgentDefinition(id: "droid", name: "Droid", monogram: "Dr",
                        commands: ["droid"],
                        markers: ["@factory/cli"]),
        AgentDefinition(id: "kiro", name: "Kiro CLI", monogram: "Ki",
                        commands: ["kiro-cli", "kiro-cli-chat"]),
        AgentDefinition(id: "cline", name: "Cline CLI", monogram: "Cn",
                        commands: ["cline", ".cline"],
                        markers: ["@cline/cli"]),
        AgentDefinition(id: "continue", name: "Continue CLI", monogram: "Ct",
                        commands: ["cn"],
                        markers: ["@continuedev/cli"]),
        AgentDefinition(id: "auggie", name: "Auggie", monogram: "Au",
                        commands: ["auggie"],
                        markers: ["@augmentcode/auggie"]),
        AgentDefinition(id: "kilo", name: "Kilo Code", monogram: "Kl",
                        commands: ["kilo", "kilocode"],
                        markers: ["@kilocode/cli"]),
    ]
}
