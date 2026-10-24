import XCTest
@testable import VibeCore

final class AwakePolicyTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testOffAlwaysReleases() {
        XCTAssertEqual(AwakePolicy.decide(PolicyInput(mode: .off, now: now, activeAgentNames: ["Codex"])), .release(.off))
    }

    func testAutoHoldsWhileAgentsRun() {
        let input = PolicyInput(mode: .auto, now: now, activeAgentNames: ["Claude Code"], lastAgentSeen: now)
        XCTAssertEqual(AwakePolicy.decide(input), .hold(.agents(["Claude Code"])))
    }

    func testAutoGracePeriodThenRelease() {
        var input = PolicyInput(mode: .auto, now: now, lastAgentSeen: now.addingTimeInterval(-60), graceSeconds: 120)
        XCTAssertEqual(AwakePolicy.decide(input), .hold(.grace(until: now.addingTimeInterval(60))))
        input.now = now.addingTimeInterval(61)
        XCTAssertEqual(AwakePolicy.decide(input), .release(.noAgents))
    }

    func testAutoWithoutAgentsWaits() {
        XCTAssertEqual(AwakePolicy.decide(PolicyInput(mode: .auto, now: now)), .release(.noAgents))
    }

    func testTimer() {
        let end = now.addingTimeInterval(600)
        XCTAssertEqual(AwakePolicy.decide(PolicyInput(mode: .timer, now: now, timerEnd: end)), .hold(.timer(until: end)))
        XCTAssertEqual(AwakePolicy.decide(PolicyInput(mode: .timer, now: end, timerEnd: end)), .release(.timerDone))
    }

    func testBatteryFloorOnlyOnBattery() {
        let low = BatteryState(percent: 12, onBattery: true, charging: false)
        XCTAssertEqual(AwakePolicy.decide(PolicyInput(mode: .always, now: now, battery: low)), .release(.battery(12)))
        let plugged = BatteryState(percent: 12, onBattery: false, charging: true)
        XCTAssertEqual(AwakePolicy.decide(PolicyInput(mode: .always, now: now, battery: plugged)), .hold(.always))
        XCTAssertEqual(AwakePolicy.decide(PolicyInput(mode: .always, now: now, battery: low, batteryFloorEnabled: false)), .hold(.always))
    }

    func testRequireCharger() {
        let battery = BatteryState(percent: 90, onBattery: true, charging: false)
        XCTAssertEqual(AwakePolicy.decide(PolicyInput(mode: .always, now: now, battery: battery, requireCharger: true)), .release(.onBattery))
    }

    func testThermalBeatsEverything() {
        XCTAssertEqual(AwakePolicy.decide(PolicyInput(mode: .always, now: now, thermalCritical: true)), .release(.thermal))
        XCTAssertEqual(AwakePolicy.decide(PolicyInput(mode: .always, now: now, thermalGuardEnabled: false, thermalCritical: true)), .hold(.always))
    }

    func testIdleRelease() {
        var input = PolicyInput(mode: .auto, now: now, activeAgentNames: ["Aider"], lastAgentSeen: now,
                                allIdleSince: now.addingTimeInterval(-300), idleReleaseEnabled: true, idleSeconds: 600)
        XCTAssertEqual(AwakePolicy.decide(input), .hold(.agents(["Aider"])))
        input.allIdleSince = now.addingTimeInterval(-601)
        XCTAssertEqual(AwakePolicy.decide(input), .release(.agentsIdle))
        input.idleReleaseEnabled = false
        XCTAssertEqual(AwakePolicy.decide(input), .hold(.agents(["Aider"])))
    }
}
