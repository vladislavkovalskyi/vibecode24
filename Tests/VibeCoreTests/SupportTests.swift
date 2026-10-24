import XCTest
@testable import VibeCore

final class SupportTests: XCTestCase {
    func testEveryStringHasAllLanguagesAndSameArguments() {
        let specifier = try! NSRegularExpression(pattern: "%(\\d+\\$)?[@dfs]")
        func specs(_ s: String) -> [String] {
            specifier.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { (s as NSString).substring(with: $0.range) }
        }
        for key in L.allCases {
            guard let row = L10n.table[key] else { return XCTFail("Missing row for \(key)") }
            for value in [row.en, row.ru, row.uk] { XCTAssertFalse(value.isEmpty, "\(key)") }
            XCTAssertEqual(specs(row.en), specs(row.ru), "\(key) ru")
            XCTAssertEqual(specs(row.en), specs(row.uk), "\(key) uk")
        }
    }

    func testDurations() {
        XCTAssertEqual(L10n.duration(42 * 60, language: .en), "42 min")
        XCTAssertEqual(L10n.duration(3600 + 12 * 60, language: .ru), "1 ч 12 мин")
        XCTAssertEqual(L10n.duration(2 * 3600, language: .uk), "2 год")
        XCTAssertEqual(L10n.duration(30, language: .en), "30 s")
        XCTAssertEqual(L10n.clock(3725), "1:02:05")
        XCTAssertEqual(L10n.clock(65), "1:05")
    }

    func testLanguageFromPreferred() {
        XCTAssertEqual(AppLanguage.fromPreferred(["uk-UA", "en-US"]), .uk)
        XCTAssertEqual(AppLanguage.fromPreferred(["de-DE", "ru-RU"]), .ru)
        XCTAssertEqual(AppLanguage.fromPreferred(["de-DE"]), .en)
    }

    func testParseSleepDisabled() {
        let output = """
        System-wide power settings:
         SleepDisabled\t\t1
        Currently in use:
         standby              1
        """
        XCTAssertEqual(SleepControl.parseSleepDisabled(output), true)
        XCTAssertEqual(SleepControl.parseSleepDisabled(output.replacingOccurrences(of: "\t\t1", with: "\t\t0")), false)
        XCTAssertNil(SleepControl.parseSleepDisabled("Currently in use:\n sleep 1"))
    }

    func testRuleText() {
        let rule = HelperRule.ruleText(user: "vlad", uid: 501)
        XCTAssertTrue(rule.contains("vlad ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0"))
        XCTAssertTrue(HelperRule.ruleText(user: "bad user", uid: 502).contains("#502 ALL=(root)"))
        XCTAssertTrue(rule.hasSuffix("\n"))
    }

    func testRuleValidatesWithVisudo() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("vibecode24-test-\(UUID().uuidString)")
        try HelperRule.ruleText().write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let result = Shell.run("/usr/sbin/visudo", ["-cf", url.path])
        XCTAssertEqual(result.status, 0, result.error + result.output)
    }

    func testQuoting() {
        XCTAssertEqual(HelperRule.shellQuote("/tmp/a'b"), "'/tmp/a'\\''b'")
        XCTAssertEqual(HelperRule.appleScriptString("say \"hi\""), "\"say \\\"hi\\\"\"")
    }

    func testStatsSplitAcrossMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let midnight = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let session = AwakeSession(start: midnight.addingTimeInterval(-3600), end: midnight.addingTimeInterval(3600),
                                   lidClosedSeconds: 1800, agents: ["Codex"])
        let stats = SessionLog.stats([session], now: midnight.addingTimeInterval(7200), calendar: calendar)
        XCTAssertEqual(stats.todayAwake, 3600, accuracy: 0.1)
        XCTAssertEqual(stats.todayLidClosed, 900, accuracy: 0.1)
        XCTAssertEqual(stats.totalLidClosed, 1800, accuracy: 0.1)
    }

    func testSettingsRoundTrip() {
        let defaults = UserDefaults(suiteName: "vibecode24.tests.\(UUID().uuidString)")!
        let settings = AppSettings(defaults: defaults)
        settings.mode = .always
        settings.addCustomCommand("  my-agent ")
        settings.addCustomCommand("has space")
        settings.disabledAgents = ["goose"]
        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.mode, .always)
        XCTAssertEqual(reloaded.customCommands, ["my-agent"])
        XCTAssertFalse(reloaded.watchedDefinitions.contains { $0.id == "goose" })
        XCTAssertTrue(reloaded.watchedDefinitions.contains { $0.id == "custom:my-agent" })
    }
}
