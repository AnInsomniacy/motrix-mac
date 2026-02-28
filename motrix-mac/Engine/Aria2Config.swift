import Foundation

struct Aria2Config: Sendable {
    private static let supportedRuntimeKeys: Set<String> = [
        "max-concurrent-downloads",
        "max-connection-per-server",
        "dir",
        "continue",
        "max-overall-download-limit",
        "max-overall-upload-limit",
        "seed-ratio",
        "seed-time",
        "rpc-secret",
        "bt-tracker"
    ]
    static let rpcPort: UInt16 = 16800
    static let rpcHost = "127.0.0.1"

    static var aria2cPath: URL {
        Bundle.main.resourceURL!.appendingPathComponent("aria2c")
    }

    static var confPath: URL {
        Bundle.main.resourceURL!.appendingPathComponent("aria2.conf")
    }

    static var dataDir: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Motrix")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var sessionPath: URL {
        dataDir.appendingPathComponent("download.session")
    }

    static var dhtPath: URL {
        dataDir.appendingPathComponent("dht.dat")
    }

    static var dht6Path: URL {
        dataDir.appendingPathComponent("dht6.dat")
    }

    static var pidPath: URL {
        dataDir.appendingPathComponent("engine.pid")
    }

    static func buildArgs(userConfig: [String: Any] = [:]) -> [String] {
        var args = [
            "--conf-path=\(confPath.path)",
            "--save-session=\(sessionPath.path)",
            "--dht-file-path=\(dhtPath.path)",
            "--dht-file-path6=\(dht6Path.path)",
            "--rpc-listen-port=\(rpcPort)",
            "--dir=\(downloadsDir.path)"
        ]

        if FileManager.default.fileExists(atPath: sessionPath.path) {
            args.append("--input-file=\(sessionPath.path)")
        }

        for (key, value) in userConfig where supportedRuntimeKeys.contains(key) {
            let v = "\(value)"
            if !v.isEmpty {
                args.append("--\(key)=\(v)")
            }
        }

        return args
    }

    static var downloadsDir: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    }
}
