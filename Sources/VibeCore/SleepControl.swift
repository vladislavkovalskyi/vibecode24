import Foundation
import IOKit.pwr_mgt

/// The two layers that keep the Mac awake.
///
/// 1. An IOKit assertion that stops idle sleep while the lid is open. No privileges needed.
/// 2. `pmset -a disablesleep 1`, which also covers a closed lid. Needs root, granted once by
///    the sudoers rule that `HelperRule` installs.
public final class SleepControl: @unchecked Sendable {
    public static let pmset = "/usr/bin/pmset"
    public static let sudo = "/usr/bin/sudo"

    private var systemAssertion: IOPMAssertionID = 0
    private var displayAssertion: IOPMAssertionID = 0
    private let lock = NSLock()

    public init() {}

    // MARK: Assertions

    public func setIdleAssertion(_ on: Bool, keepDisplayOn: Bool) {
        lock.lock(); defer { lock.unlock() }
        if on {
            if systemAssertion == 0 {
                IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                                            IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                            "Vibecode24 keeps your agents running" as CFString,
                                            &systemAssertion)
            }
        } else if systemAssertion != 0 {
            IOPMAssertionRelease(systemAssertion)
            systemAssertion = 0
        }

        if on && keepDisplayOn {
            if displayAssertion == 0 {
                IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                            IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                            "Vibecode24 keeps the display on" as CFString,
                                            &displayAssertion)
            }
        } else if displayAssertion != 0 {
            IOPMAssertionRelease(displayAssertion)
            displayAssertion = 0
        }
    }

    /// Turns the display off now. Locks the Mac when "require password" is set to immediately.
    public static func displaySleepNow() {
        Shell.run(pmset, ["displaysleepnow"])
    }

    // MARK: Watchdog

    private var watchdog: Process?

    /// Starts a tiny shell process that outlives the app. If the app dies while holding
    /// `disablesleep`, the watchdog notices within five seconds and gives sleep back.
    public func startWatchdog() {
        lock.lock(); defer { lock.unlock() }
        if let watchdog, watchdog.isRunning { return }
        let script = """
        trap '' HUP INT
        while /bin/kill -0 "$1" 2>/dev/null; do /bin/sleep 5; done
        \(Self.sudo) -n \(Self.pmset) -a disablesleep 0
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "vibecode24-watchdog", String(getpid())]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            watchdog = process
        } catch {
            watchdog = nil
        }
    }

    public func stopWatchdog() {
        lock.lock(); defer { lock.unlock() }
        if let watchdog, watchdog.isRunning { watchdog.terminate() }
        watchdog = nil
    }

    // MARK: disablesleep

    /// Reads `SleepDisabled` from `pmset -g`. Nil when it cannot be read.
    public static func readSleepDisabled() -> Bool? {
        let result = Shell.run(pmset, ["-g"])
        guard result.status == 0 else { return nil }
        return parseSleepDisabled(result.output)
    }

    static func parseSleepDisabled(_ output: String) -> Bool? {
        for line in output.split(separator: "\n") {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if parts.count >= 2, parts[0] == "SleepDisabled" { return parts[1] == "1" }
        }
        return nil
    }

    public enum SetError: Error, Equatable {
        case notAuthorized
        case failed(String)
    }

    /// Runs `sudo -n pmset -a disablesleep 0|1`. `-n` never prompts: without the rule it fails.
    public static func setSleepDisabled(_ disabled: Bool) -> Result<Void, SetError> {
        let result = Shell.run(sudo, ["-n", pmset, "-a", "disablesleep", disabled ? "1" : "0"])
        if result.status == 0 { return .success(()) }
        if result.error.contains("password") || result.error.contains("not allowed") {
            return .failure(.notAuthorized)
        }
        return .failure(.failed(result.error.trimmingCharacters(in: .whitespacesAndNewlines)))
    }
}
