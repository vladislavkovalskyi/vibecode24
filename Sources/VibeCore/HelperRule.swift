import Foundation

/// The sudoers rule that lets the app toggle `disablesleep` without asking for a password.
/// It allows exactly two commands for the current user and nothing else.
public enum HelperRule {
    public static let path = "/etc/sudoers.d/vibecode24"

    public static func ruleText(user: String = NSUserName(), uid: uid_t = getuid()) -> String {
        let subject = isSafeUserName(user) ? user : "#\(uid)"
        return """
        # Installed by Vibecode24. Lets \(subject) toggle sleep and nothing else.
        # Remove it in Vibecode24 Settings, or run: sudo rm \(path)
        \(subject) ALL=(root) NOPASSWD: \(SleepControl.pmset) -a disablesleep 1, \(SleepControl.pmset) -a disablesleep 0

        """
    }

    static func isSafeUserName(_ name: String) -> Bool {
        !name.isEmpty && name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "._-".contains($0)) }
            && !(name.first?.isNumber ?? true)
    }

    /// True when the rule file exists and sudo accepts the command without a password.
    public static func isInstalled() -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }
        let check = Shell.run(SleepControl.sudo, ["-n", "-l", SleepControl.pmset, "-a", "disablesleep", "0"])
        return check.status == 0
    }

    public enum InstallError: Error, Equatable {
        case cancelled
        case failed(String)
    }

    /// Shows the macOS administrator prompt once, validates the rule with visudo and installs it.
    public static func install(prompt: String) async -> Result<Void, InstallError> {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("vibecode24-sudoers-\(UUID().uuidString)")
        do {
            try ruleText().write(to: temp, atomically: true, encoding: .utf8)
        } catch {
            return .failure(.failed(error.localizedDescription))
        }
        defer { try? FileManager.default.removeItem(at: temp) }

        let source = shellQuote(temp.path)
        let command = "/usr/sbin/visudo -cf \(source) && /usr/bin/install -m 0440 -o root -g wheel \(source) \(path)"
        return await runPrivileged(command, prompt: prompt)
    }

    /// Restores sleep and deletes the rule.
    public static func remove(prompt: String) async -> Result<Void, InstallError> {
        let command = "\(SleepControl.pmset) -a disablesleep 0; /bin/rm -f \(path)"
        return await runPrivileged(command, prompt: prompt)
    }

    static func runPrivileged(_ command: String, prompt: String) async -> Result<Void, InstallError> {
        let script = "do shell script \(appleScriptString(command)) with prompt \(appleScriptString(prompt)) with administrator privileges"
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // No timeout: the user may take a while to type the password.
                let result = Shell.run("/usr/bin/osascript", ["-e", script], timeout: 600)
                if result.status == 0 {
                    continuation.resume(returning: .success(()))
                } else if result.error.contains("-128") {
                    continuation.resume(returning: .failure(.cancelled))
                } else {
                    continuation.resume(returning: .failure(.failed(result.error.trimmingCharacters(in: .whitespacesAndNewlines))))
                }
            }
        }
    }

    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func appleScriptString(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
