import Foundation
import SwiftUI

final class ConfigService {
    static let shared = ConfigService()

    @AppStorage("theme") var theme: String = "auto"
    @AppStorage("locale") var locale: String = Locale.current.identifier
    @AppStorage("maxConcurrentDownloads") var maxConcurrentDownloads: Int = 5
    @AppStorage("maxConnectionPerServer") var maxConnectionPerServer: Int = 16
    @AppStorage("downloadDir") var downloadDir: String = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!.path
    @AppStorage("autoCheckUpdate") var autoCheckUpdate: Bool = true
    @AppStorage("openAtLogin") var openAtLogin: Bool = false
    @AppStorage("enableUPnP") var enableUPnP: Bool = true
    @AppStorage("autoSyncTracker") var autoSyncTracker: Bool = true
    @AppStorage("resumeAllOnLaunch") var resumeAllOnLaunch: Bool = false
    @AppStorage("showProgressBar") var showProgressBar: Bool = true
    @AppStorage("taskNotification") var taskNotification: Bool = true
    @AppStorage("traySpeedometer") var traySpeedometer: Bool = true
    @AppStorage("seedRatio") var seedRatio: Double = 2.0
    @AppStorage("seedTime") var seedTime: Int = 2880
    @AppStorage("keepSeeding") var keepSeeding: Bool = false
    @AppStorage("maxOverallDownloadLimit") var maxOverallDownloadLimit: Int = 0
    @AppStorage("maxOverallUploadLimit") var maxOverallUploadLimit: Int = 0
    @AppStorage("rpcSecret") var rpcSecret: String = ""

    func aria2SystemConfig() -> [String: String] {
        let safeMaxConnectionPerServer = min(max(maxConnectionPerServer, 1), 16)
        if safeMaxConnectionPerServer != maxConnectionPerServer {
            maxConnectionPerServer = safeMaxConnectionPerServer
        }
        var config: [String: String] = [
            "max-concurrent-downloads": "\(maxConcurrentDownloads)",
            "max-connection-per-server": "\(safeMaxConnectionPerServer)",
            "dir": downloadDir,
            "continue": "true",
            "max-overall-download-limit": "\(maxOverallDownloadLimit)",
            "max-overall-upload-limit": "\(maxOverallUploadLimit)",
            "seed-ratio": "\(seedRatio)",
        ]
        if keepSeeding || seedRatio == 0 {
            config["seed-ratio"] = "0"
        } else {
            config["seed-time"] = "\(seedTime)"
        }
        if !rpcSecret.isEmpty {
            config["rpc-secret"] = rpcSecret
        }
        return config
    }
}
