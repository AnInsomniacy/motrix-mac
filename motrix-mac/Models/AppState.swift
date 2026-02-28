import SwiftUI

@Observable
final class AppState {
    var tasks: [DownloadTask] = []
    var taskIndex: [String: DownloadTask] = [:]
    var selectedGids: Set<String> = []
    var currentSection: MainSection = .tasks
    var currentList: TaskFilter = .active
    var globalStat = GlobalStat()
    var completedCount = 0
    var stoppedCount = 0

    var showAddTask: Bool {
        get { currentSection == .add }
        set {
            if newValue {
                currentSection = .add
            } else if currentSection == .add {
                currentSection = .tasks
            }
        }
    }
    var addTaskURL = ""
    var addTaskTorrentData: Data?
    var addTaskTorrentName = ""

    var showTaskDetail = false
    var detailTaskGid: String?

    var showErrorAlert = false
    var errorAlertMessage = ""

    var pollingInterval: TimeInterval = 1.0

    var activeTasks: [DownloadTask] { tasks.filter { $0.status == .active || $0.status == .waiting || $0.status == .paused } }
    var completedTasks: [DownloadTask] { tasks.filter { $0.status == .complete } }
    var stoppedTasks: [DownloadTask] { tasks.filter { $0.status == .error || $0.status == .removed } }

    var filteredTasks: [DownloadTask] {
        switch currentList {
        case .active: return activeTasks
        case .completed: return completedTasks
        case .stopped: return stoppedTasks
        }
    }

    var isDownloading: Bool { globalStat.numActive > 0 }

    func upsertTasks(_ incoming: [DownloadTask]) {
        for task in incoming {
            taskIndex[task.gid] = task
        }
    }

    func replaceTaskIndex(with incoming: [DownloadTask]) {
        taskIndex = Dictionary(uniqueKeysWithValues: incoming.map { ($0.gid, $0) })
    }

    func presentError(_ message: String) {
        errorAlertMessage = message
        showErrorAlert = true
    }

    func adjustPollingInterval() {
        let active = globalStat.numActive
        if active > 0 {
            pollingInterval = max(0.5, 1.0 - Double(active) * 0.1)
        } else {
            pollingInterval = min(pollingInterval + 0.1, 6.0)
        }
    }
}

enum TaskFilter: String, CaseIterable {
    case active = "Downloading"
    case completed = "Completed"
    case stopped = "Stopped"

    var systemImage: String {
        switch self {
        case .active: return "arrow.down.circle"
        case .completed: return "checkmark.circle"
        case .stopped: return "xmark.circle"
        }
    }
}

enum MainSection: String {
    case tasks
    case add
    case settings
    case about
}
