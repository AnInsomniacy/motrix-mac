import SwiftUI
import AppKit

struct TaskListView: View {
    @Environment(AppState.self) private var state
    let downloadService: DownloadService
    @State private var selectedGIDs: Set<String> = []
    @State private var detailTask: DownloadTask?
    @State private var operatingGIDs: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().opacity(0.2)
            content
            VStack(spacing: 0) {
                if !selectedGIDs.isEmpty {
                    Divider().opacity(0.2)
                    batchBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedGIDs.isEmpty)
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
        .onChange(of: state.currentList) { _, _ in selectedGIDs.removeAll() }
        .onChange(of: state.filteredTasks) { _, newTasks in
            let validGIDs = Set(newTasks.map(\.gid))
            selectedGIDs.formIntersection(validGIDs)
        }
        .sheet(item: $detailTask) { task in
            TaskDetailView(task: task)
        }
    }

    private var toolbar: some View {
        HStack {
            Text(state.currentList.localizedTitle)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            HStack(spacing: 6) {
                SpeedBadge(speed: state.globalStat.downloadSpeed, direction: .download)
                SpeedBadge(speed: state.globalStat.uploadSpeed, direction: .upload)
            }
            .padding(.trailing, 8)

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
                                isSelected: selectedGIDs.contains(task.gid),
                                isOperating: operatingGIDs.contains(task.gid),
                                onToggle: { toggleTask(task) },
                                onRemove: { confirmRemoveTask(task) },
                                onSelect: { toggleSelection(task.gid) },
                                onDetail: { showDetail(task) },
                                onStopSeeding: { stopSeeding(task) }
                            )
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

    private var batchBar: some View {
        HStack(spacing: 12) {
            Text("\(selectedGIDs.count) selected")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            Button {
                batchResume()
            } label: {
                Label("Resume", systemImage: "play.fill")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(MotrixButtonStyle(prominent: false))

            Button {
                batchPause()
            } label: {
                Label("Pause", systemImage: "pause.fill")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(MotrixButtonStyle(prominent: false))

            Button {
                batchRemove()
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(MotrixButtonStyle(prominent: false))

            Button {
                selectedGIDs.removeAll()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(MotrixIconButtonStyle())
            .help("Deselect all")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.blue.opacity(0.08))
    }

    private func toggleSelection(_ gid: String) {
        if selectedGIDs.contains(gid) {
            selectedGIDs.remove(gid)
        } else {
            selectedGIDs.insert(gid)
        }
    }

    private func batchResume() {
        let gids = selectedGIDs
        Task {
            var failures = 0
            for gid in gids {
                do {
                    try await downloadService.resumeTask(gid: gid)
                } catch {
                    failures += 1
                }
            }
            if failures > 0 {
                await MainActor.run {
                    state.presentError("Failed to resume \(failures) of \(gids.count) tasks")
                }
            }
        }
        selectedGIDs.removeAll()
    }

    private func batchPause() {
        let gids = selectedGIDs
        Task {
            var failures = 0
            for gid in gids {
                do {
                    try await downloadService.pauseTask(gid: gid)
                } catch {
                    failures += 1
                }
            }
            if failures > 0 {
                await MainActor.run {
                    state.presentError("Failed to pause \(failures) of \(gids.count) tasks")
                }
            }
        }
        selectedGIDs.removeAll()
    }

    private func batchRemove() {
        let tasks = state.filteredTasks.filter { selectedGIDs.contains($0.gid) }
        guard !tasks.isEmpty else { return }
        guard let deleteFiles = showBatchDeleteConfirmation(count: tasks.count) else { return }
        Task {
            var failures = 0
            for task in tasks {
                do {
                    if task.status == .active || task.status == .waiting || task.status == .paused {
                        try await downloadService.removeTask(gid: task.gid)
                    } else {
                        try await downloadService.removeTaskRecord(gid: task.gid)
                    }
                    if deleteFiles {
                        deleteFilesForTask(task)
                    }
                } catch {
                    failures += 1
                }
            }
            if failures > 0 {
                await MainActor.run {
                    state.presentError("Failed to remove \(failures) of \(tasks.count) tasks")
                }
            }
        }
        selectedGIDs.removeAll()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.08), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "tray")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(.secondary.opacity(0.5))
            }

            Text(emptyTitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

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
        guard task.status == .active || task.status == .waiting || task.status == .paused else { return }
        guard !operatingGIDs.contains(task.gid) else { return }
        operatingGIDs.insert(task.gid)
        let shouldPause = task.status == .active || task.status == .waiting
        Task {
            defer { operatingGIDs.remove(task.gid) }
            do {
                if shouldPause {
                    try await downloadService.pauseTask(gid: task.gid)
                } else {
                    try await downloadService.resumeTask(gid: task.gid)
                }
            } catch {
                let desc = error.localizedDescription
                if desc.contains("400") { return }
                state.presentError("Toggle failed: \(desc)")
            }
        }
    }

    private func confirmRemoveTask(_ task: DownloadTask) {
        guard let deleteFiles = showDeleteConfirmation() else { return }
        Task {
            do {
                if task.status == .active || task.status == .waiting || task.status == .paused {
                    try await downloadService.removeTask(gid: task.gid)
                } else {
                    try await downloadService.removeTaskRecord(gid: task.gid)
                }
                if deleteFiles {
                    deleteFilesForTask(task)
                }
            } catch {
                state.presentError("Remove failed: \(error.localizedDescription)")
            }
        }
    }

    private func showDetail(_ task: DownloadTask) {
        detailTask = task
    }

    private func stopSeeding(_ task: DownloadTask) {
        operatingGIDs.insert(task.gid)
        Task {
            defer { operatingGIDs.remove(task.gid) }
            do {
                try await downloadService.removeTask(gid: task.gid)
            } catch {
                state.presentError("Stop seeding failed: \(error.localizedDescription)")
            }
        }
    }

    private func showDeleteConfirmation() -> Bool? {
        let lm = LanguageManager.shared
        let alert = NSAlert()
        alert.messageText = lm.localizedString("Remove this task?")
        alert.informativeText = lm.localizedString("You can also delete downloaded files from disk.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: lm.localizedString("Remove"))
        alert.addButton(withTitle: lm.localizedString("Cancel"))
        let checkbox = NSButton(checkboxWithTitle: lm.localizedString("Also delete files"), target: nil, action: nil)
        checkbox.state = .off
        alert.accessoryView = checkbox
        let response = alert.runModal()
        if response != .alertFirstButtonReturn { return nil }
        return checkbox.state == .on
    }

    private func showBatchDeleteConfirmation(count: Int) -> Bool? {
        let lm = LanguageManager.shared
        let alert = NSAlert()
        alert.messageText = lm.localizedString("Remove \(count) tasks?")
        alert.informativeText = lm.localizedString("This will remove all selected tasks. You can also delete their files.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: lm.localizedString("Remove All"))
        alert.addButton(withTitle: lm.localizedString("Cancel"))
        let checkbox = NSButton(checkboxWithTitle: lm.localizedString("Also delete files"), target: nil, action: nil)
        checkbox.state = .off
        alert.accessoryView = checkbox
        let response = alert.runModal()
        if response != .alertFirstButtonReturn { return nil }
        return checkbox.state == .on
    }

    private func deleteFilesForTask(_ task: DownloadTask) {
        let fm = FileManager.default
        let taskDir = task.dir
        let filePaths = task.files.map(\.path).filter { !$0.isEmpty }


        var contentRoots = Set<String>()
        for path in filePaths {
            var parent = (path as NSString).deletingLastPathComponent

            while !parent.isEmpty && parent != taskDir {
                let grandParent = (parent as NSString).deletingLastPathComponent
                if grandParent == taskDir {
                    contentRoots.insert(parent)
                    break
                }
                parent = grandParent
            }

            if (path as NSString).deletingLastPathComponent == taskDir {
                trashItem(at: path)
            }
        }


        for dir in contentRoots {
            trashItem(at: dir)
        }


        if filePaths.isEmpty && !task.name.isEmpty {
            let fallback = (taskDir as NSString).appendingPathComponent(task.name)
            if fm.fileExists(atPath: fallback) {
                trashItem(at: fallback)
            }
        }


        if !taskDir.isEmpty, let items = try? fm.contentsOfDirectory(atPath: taskDir) {
            for item in items {
                let lower = item.lowercased()
                let fullPath = (taskDir as NSString).appendingPathComponent(item)


                if lower.hasSuffix(".aria2") {
                    trashItem(at: fullPath)
                }


                if lower.hasSuffix(".torrent") && task.isBT {
                    let baseName = (item as NSString).deletingPathExtension
                    if isHexHash(baseName) {
                        trashItem(at: fullPath)
                    }
                }
            }
        }
    }

    private func trashItem(at path: String) {
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }


    private func isHexHash(_ str: String) -> Bool {
        let len = str.count
        guard len >= 32 && len <= 64 else { return false }
        return str.allSatisfy { $0.isHexDigit }
    }

    private var emptyTitle: String {
        let lm = LanguageManager.shared
        switch state.currentList {
        case .active: return lm.localizedString("No active downloads")
        case .completed: return lm.localizedString("No completed downloads")
        case .stopped: return lm.localizedString("No stopped downloads")
        }
    }
}
