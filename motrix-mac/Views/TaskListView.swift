import SwiftUI
import AppKit

struct TaskListView: View {
    @Environment(AppState.self) private var state
    let downloadService: DownloadService

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().opacity(0.2)
            content
        }
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor(white: 0.175, alpha: 1)),
                    Color(nsColor: NSColor(white: 0.16, alpha: 1))
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var toolbar: some View {
        HStack {
            Text(state.currentList.rawValue)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            HStack(spacing: 6) {
                SpeedBadge(speed: state.globalStat.downloadSpeed, direction: .download)
                SpeedBadge(speed: state.globalStat.uploadSpeed, direction: .upload)
            }
            .padding(.trailing, 8)

            toolbarBtn("xmark", "Clear") {
                for task in state.completedTasks {
                    Task {
                        do {
                            try await downloadService.removeTaskRecord(gid: task.gid)
                        } catch {
                            state.presentError("Clear failed: \(error.localizedDescription)")
                        }
                    }
                }
            }
            toolbarBtn("arrow.clockwise", "Refresh") {
                Task { await downloadService.refresh() }
            }
            toolbarBtn("play.fill", "Resume All") {
                Task {
                    do {
                        try await downloadService.resumeAll()
                    } catch {
                        state.presentError("Resume all failed: \(error.localizedDescription)")
                    }
                }
            }
            toolbarBtn("pause.fill", "Pause All") {
                Task {
                    do {
                        try await downloadService.pauseAll()
                    } catch {
                        state.presentError("Pause all failed: \(error.localizedDescription)")
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.05),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func toolbarBtn(_ icon: String, _ tip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
        }
        .buttonStyle(MotrixIconButtonStyle())
        .help(tip)
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            if state.filteredTasks.isEmpty {
                emptyState
                    .transition(.opacity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(state.filteredTasks) { task in
                            TaskRowView(
                                task: task,
                                onToggle: { toggleTask(task) },
                                onRemove: { confirmRemoveTask(task) }
                            )
                            .onTapGesture(count: 2) { showDetail(task) }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.currentList)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.08), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: "arrow.down.to.line.circle")
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            Text(emptyTitle)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))

            Spacer()

            HStack {
                Spacer()
                Image(systemName: "wand.and.rays")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.15))
                    .padding(16)
            }
        }
    }

    private func toggleTask(_ task: DownloadTask) {
        Task {
            do {
                if task.status == .active {
                    try await downloadService.pauseTask(gid: task.gid)
                } else {
                    try await downloadService.resumeTask(gid: task.gid)
                }
            } catch {
                state.presentError("Task action failed: \(error.localizedDescription)")
            }
        }
    }

    private func confirmRemoveTask(_ task: DownloadTask) {
        let alsoDeleteFiles = showDeleteConfirmation()
        guard let alsoDeleteFiles else { return }
        removeTask(task, deleteFiles: alsoDeleteFiles)
    }

    private func removeTask(_ task: DownloadTask, deleteFiles: Bool) {
        Task {
            do {
                switch task.status {
                case .complete, .error, .removed:
                    try await downloadService.removeTaskRecord(gid: task.gid)
                default:
                    try await downloadService.removeTask(gid: task.gid)
                }
                if deleteFiles {
                    deleteFilesForTask(task)
                }
            } catch {
                state.presentError("Remove failed: \(error.localizedDescription)")
            }
        }
    }

    private func showDeleteConfirmation() -> Bool? {
        let alert = NSAlert()
        alert.messageText = "Remove this task?"
        alert.informativeText = "You can also delete downloaded files from disk."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        let checkbox = NSButton(checkboxWithTitle: "Also delete files", target: nil, action: nil)
        checkbox.state = .off
        alert.accessoryView = checkbox
        let response = alert.runModal()
        if response != .alertFirstButtonReturn { return nil }
        return checkbox.state == .on
    }

    private func deleteFilesForTask(_ task: DownloadTask) {
        var candidates = Set(task.files.map(\.path).filter { !$0.isEmpty })
        if candidates.isEmpty {
            let fallback = (task.dir as NSString).appendingPathComponent(task.name)
            candidates.insert(fallback)
        }
        var failures: [String] = []
        for path in candidates {
            let url = URL(fileURLWithPath: path)
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
            } catch {
                failures.append(url.lastPathComponent)
            }
        }
        if !failures.isEmpty {
            state.presentError("Task removed, but failed to delete: \(failures.joined(separator: ", "))")
        }
    }

    private func showDetail(_ task: DownloadTask) {
        state.detailTaskGid = task.gid
        state.showTaskDetail = true
    }

    private var emptyTitle: String {
        switch state.currentList {
        case .active: return "No active downloads"
        case .completed: return "No completed downloads"
        case .stopped: return "No stopped downloads"
        }
    }
}
