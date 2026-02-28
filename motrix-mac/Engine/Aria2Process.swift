import Foundation
import os

@Observable
final class Aria2Process {
    private var process: Process?
    private let logger = Logger(subsystem: "app.motrix", category: "Aria2Process")
    var isRunning: Bool { process?.isRunning ?? false }

    func start(extraArgs: [String: Any] = [:]) throws {
        guard process == nil || !isRunning else { return }

        let binPath = Aria2Config.aria2cPath
        let pidPath = Aria2Config.pidPath
        guard FileManager.default.fileExists(atPath: binPath.path) else {
            throw Aria2ProcessError.binaryNotFound(binPath.path)
        }

        let proc = Process()
        proc.executableURL = binPath
        proc.arguments = Aria2Config.buildArgs(userConfig: extraArgs)
        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardOutput = stdout
        proc.standardError = stderr

        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let line = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty else { return }
            self?.logger.error("aria2c stderr: \(line)")
        }

        proc.terminationHandler = { [weak self] p in
            self?.logger.info("aria2c terminated with status \(p.terminationStatus)")
            stderr.fileHandleForReading.readabilityHandler = nil
            Self.cleanupPidFileStatic(at: pidPath)
        }

        try proc.run()
        process = proc

        if let pid = process?.processIdentifier {
            logger.info("aria2c started with pid \(pid)")
            writePidFile(pid: pid, at: pidPath)
        }
    }

    func stop() {
        guard let proc = process, proc.isRunning else { return }
        logger.info("stopping aria2c")
        proc.terminate()
        process = nil
        cleanupPidFile()
    }

    func restart(extraArgs: [String: Any] = [:]) throws {
        stop()
        Thread.sleep(forTimeInterval: 0.5)
        try start(extraArgs: extraArgs)
    }

    private func writePidFile(pid: Int32, at pidPath: URL) {
        try? "\(pid)".write(to: pidPath, atomically: true, encoding: .utf8)
    }

    private func cleanupPidFile() {
        Self.cleanupPidFileStatic(at: Aria2Config.pidPath)
    }

    private nonisolated static func cleanupPidFileStatic(at pidPath: URL) {
        try? FileManager.default.removeItem(at: pidPath)
    }
}

enum Aria2ProcessError: LocalizedError {
    case binaryNotFound(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let path): return "aria2c binary not found at \(path)"
        }
    }
}
