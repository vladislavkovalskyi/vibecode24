import Foundation

/// Runs a command without a shell and returns its exit status and output.
enum Shell {
    struct Result { let status: Int32; let output: String; let error: String }

    @discardableResult
    static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval = 10) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch {
            return Result(status: -1, output: "", error: error.localizedDescription)
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak process] in
            if let process, process.isRunning { process.terminate() }
        }
        // Read before waiting so a full pipe cannot block the child.
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Result(status: process.terminationStatus,
                      output: String(decoding: outData, as: UTF8.self),
                      error: String(decoding: errData, as: UTF8.self))
    }
}
