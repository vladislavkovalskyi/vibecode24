import XCTest
@testable import VibeCore

final class AgentMatcherTests: XCTestCase {
    let matcher = AgentMatcher(definitions: AgentCatalog.builtIn)

    private func process(_ path: String, _ args: [String], pid: Int32 = 100, ppid: Int32 = 1) -> ProcessSnapshot {
        ProcessSnapshot(pid: pid, ppid: ppid, executablePath: path, arguments: args, startTime: Date())
    }

    func testNativeClaudeIsMatchedByArgv0() {
        // The native installer runs a file named after the version.
        let p = process("/Users/me/.local/share/claude/versions/2.1.309", ["claude"])
        XCTAssertEqual(matcher.match(p)?.id, "claude")
    }

    func testClaudeHelperIsIgnored() {
        let p = process("/Users/me/.local/share/claude/versions/2.1.309", ["claude", "--chrome-native-host"])
        XCTAssertNil(matcher.match(p))
    }

    func testNodeScriptAgents() {
        XCTAssertEqual(matcher.match(process("/opt/homebrew/bin/node",
            ["node", "/opt/homebrew/lib/node_modules/@google/gemini-cli/bundle/gemini.js"]))?.id, "gemini")
        XCTAssertEqual(matcher.match(process("/opt/homebrew/bin/node",
            ["node", "/opt/homebrew/bin/qwen"]))?.id, "qwen")
        XCTAssertEqual(matcher.match(process("/usr/local/bin/node",
            ["node", "/usr/local/lib/node_modules/@openai/codex/bin/codex.js"]))?.id, "codex")
    }

    func testCodexAppServerIsIgnored() {
        XCTAssertNil(matcher.match(process("/opt/homebrew/bin/codex", ["codex", "app-server"])))
        XCTAssertEqual(matcher.match(process("/opt/homebrew/bin/codex", ["codex", "exec", "fix the tests"]))?.id, "codex")
    }

    func testPythonAider() {
        let p = process("/opt/homebrew/Cellar/python@3.12/3.12.4/bin/python3.12",
                        ["/opt/homebrew/opt/python@3.12/bin/python3.12", "/Users/me/.local/bin/aider"])
        XCTAssertEqual(matcher.match(p)?.id, "aider")
    }

    func testCursorAgentByPath() {
        let p = process("/Users/me/.local/share/cursor-agent/versions/2026.10.1/node", ["agent", "index.js"])
        XCTAssertEqual(matcher.match(p)?.id, "cursor")
    }

    func testUnrelatedProcessesDoNotMatch() {
        XCTAssertNil(matcher.match(process("/usr/bin/grep", ["grep", "claude"])))
        XCTAssertNil(matcher.match(process("/opt/homebrew/bin/node", ["node", "server.js", "--name", "claude"])))
        XCTAssertNil(matcher.match(process("/Applications/Claude.app/Contents/MacOS/Claude", ["Claude"])))
        XCTAssertNil(matcher.match(process("/bin/zsh", ["-zsh"])))
    }

    func testCustomCommand() {
        let custom = AgentMatcher(definitions: [.custom(command: "my-agent")])
        XCTAssertEqual(custom.match(process("/usr/local/bin/my-agent", ["my-agent"]))?.id, "custom:my-agent")
    }

    func testWrapperAndBinaryFormOneSession() {
        let wrapper = process("/opt/homebrew/bin/node", ["node", "/x/@openai/codex/bin/codex.js"], pid: 10, ppid: 5)
        let binary = process("/x/@openai/codex/vendor/aarch64-apple-darwin/codex/codex", ["codex"], pid: 11, ppid: 10)
        let shell = process("/bin/zsh", ["zsh", "-c", "swift test"], pid: 12, ppid: 11)
        let terminal = process("/bin/zsh", ["-zsh"], pid: 5, ppid: 1)
        let processes = Dictionary(uniqueKeysWithValues: [wrapper, binary, shell, terminal].map { ($0.pid, $0) })
        let groups = ProcessScanner.group(processes: processes, cpu: [10: 1, 11: 20, 12: 50, 5: 3], matcher: matcher)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].sessions.count, 1)
        XCTAssertEqual(groups[0].sessions[0].pid, 10)
        // CPU of the whole tree, not of the terminal above it.
        XCTAssertEqual(groups[0].cpuPercent, 71, accuracy: 0.001)
    }

    func testProcArgsParsing() {
        var bytes: [UInt8] = []
        withUnsafeBytes(of: Int32(2).littleEndian) { bytes.append(contentsOf: $0) }
        bytes += Array("/usr/bin/node".utf8) + [0, 0, 0]
        bytes += Array("node".utf8) + [0] + Array("/x/gemini.js".utf8) + [0]
        bytes += Array("PATH=/usr/bin".utf8) + [0]
        XCTAssertEqual(ProcessScanner.parseProcArgs(bytes), ["node", "/x/gemini.js"])
    }

    func testCatalogIDsAreUnique() {
        let ids = AgentCatalog.builtIn.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testLiveScanDoesNotCrash() {
        let scanner = ProcessScanner()
        _ = scanner.scan(matcher: matcher)
        _ = scanner.scan(matcher: matcher)
    }
}
