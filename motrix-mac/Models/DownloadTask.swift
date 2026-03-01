import Foundation

enum TaskStatus: String, Codable, CaseIterable {
    case active
    case waiting
    case paused
    case error
    case complete
    case removed
}

struct DownloadTask: Identifiable, Equatable {
    let gid: String
    var status: TaskStatus
    var totalLength: Int64
    var completedLength: Int64
    var uploadLength: Int64
    var downloadSpeed: Int64
    var uploadSpeed: Int64
    var connections: Int
    var dir: String
    var files: [TaskFile]
    var bittorrent: BTInfo?
    var infoHash: String?
    var numSeeders: Int
    var seeder: Bool
    var errorCode: String?
    var errorMessage: String?

    var id: String { gid }

    var progress: Double {
        guard totalLength > 0 else { return 0 }
        return Double(completedLength) / Double(totalLength)
    }

    var name: String {
        if let btName = bittorrent?.info?.name, !btName.isEmpty {
            return btName
        }
        if let firstFile = files.first {
            return firstFile.fileName
        }
        return gid
    }

    var isBT: Bool { bittorrent != nil }
    var isMagnet: Bool { bittorrent != nil && bittorrent?.info == nil }
    var isSeeding: Bool { isBT && seeder }

    var remaining: String {
        TimeRemainingFormatter.format(
            totalLength: totalLength,
            completedLength: completedLength,
            downloadSpeed: downloadSpeed
        )
    }

    static func == (lhs: DownloadTask, rhs: DownloadTask) -> Bool {
        lhs.gid == rhs.gid
    }

    nonisolated static func from(_ dict: [String: Any]) -> DownloadTask {
        let files = (dict["files"] as? [[String: Any]])?.map { TaskFile.from($0) } ?? []
        var btInfo: BTInfo?
        if let bt = dict["bittorrent"] as? [String: Any] {
            var info: BTInfo.Info?
            if let i = bt["info"] as? [String: Any] {
                info = BTInfo.Info(name: i["name"] as? String ?? "")
            }
            let announceList = (bt["announceList"] as? [[String]]) ?? []
            btInfo = BTInfo(announceList: announceList.flatMap { $0 }, info: info)
        }

        return DownloadTask(
            gid: dict["gid"] as? String ?? "",
            status: TaskStatus(rawValue: dict["status"] as? String ?? "") ?? .waiting,
            totalLength: Int64(dict["totalLength"] as? String ?? "0") ?? 0,
            completedLength: Int64(dict["completedLength"] as? String ?? "0") ?? 0,
            uploadLength: Int64(dict["uploadLength"] as? String ?? "0") ?? 0,
            downloadSpeed: Int64(dict["downloadSpeed"] as? String ?? "0") ?? 0,
            uploadSpeed: Int64(dict["uploadSpeed"] as? String ?? "0") ?? 0,
            connections: Int(dict["connections"] as? String ?? "0") ?? 0,
            dir: dict["dir"] as? String ?? "",
            files: files,
            bittorrent: btInfo,
            infoHash: dict["infoHash"] as? String,
            numSeeders: Int(dict["numSeeders"] as? String ?? "0") ?? 0,
            seeder: (dict["seeder"] as? String) == "true",
            errorCode: dict["errorCode"] as? String,
            errorMessage: dict["errorMessage"] as? String
        )
    }
}

struct TaskFile: Identifiable {
    let index: Int
    let path: String
    let length: Int64
    let completedLength: Int64
    let selected: Bool
    let uris: [String]

    var id: Int { index }

    var fileName: String {
        if !path.isEmpty {
            return (path as NSString).lastPathComponent
        }
        if let first = uris.first {
            return URL(string: first)?.lastPathComponent ?? first
        }
        return ""
    }

    var fileExtension: String {
        (fileName as NSString).pathExtension.lowercased()
    }

    nonisolated static func from(_ dict: [String: Any]) -> TaskFile {
        let uriList = (dict["uris"] as? [[String: Any]])?.compactMap { $0["uri"] as? String } ?? []
        return TaskFile(
            index: Int(dict["index"] as? String ?? "1") ?? 1,
            path: dict["path"] as? String ?? "",
            length: Int64(dict["length"] as? String ?? "0") ?? 0,
            completedLength: Int64(dict["completedLength"] as? String ?? "0") ?? 0,
            selected: (dict["selected"] as? String) == "true",
            uris: uriList
        )
    }
}

struct BTInfo {
    struct Info {
        let name: String
    }
    let announceList: [String]
    let info: Info?
}

struct GlobalStat {
    var downloadSpeed: Int64 = 0
    var uploadSpeed: Int64 = 0
    var numActive: Int = 0
    var numWaiting: Int = 0
    var numStopped: Int = 0

    nonisolated static func from(_ dict: [String: Any]) -> GlobalStat {
        GlobalStat(
            downloadSpeed: Int64(dict["downloadSpeed"] as? String ?? "0") ?? 0,
            uploadSpeed: Int64(dict["uploadSpeed"] as? String ?? "0") ?? 0,
            numActive: Int(dict["numActive"] as? String ?? "0") ?? 0,
            numWaiting: Int(dict["numWaiting"] as? String ?? "0") ?? 0,
            numStopped: Int(dict["numStopped"] as? String ?? "0") ?? 0
        )
    }
}
