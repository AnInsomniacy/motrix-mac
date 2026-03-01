import SwiftUI
import UniformTypeIdentifiers

struct MainWindow: View {
    @Environment(AppState.self) private var state
    let downloadService: DownloadService

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(onSelectSection: { section in
                withAnimation(.easeInOut(duration: 0.2)) {
                    state.currentSection = section
                }
            })

            ZStack {
                switch state.currentSection {
                case .tasks:
                    TaskListView(downloadService: downloadService)
                        .transition(.opacity)
                case .add:
                    AddTaskView(downloadService: downloadService)
                        .transition(.opacity)
                case .settings:
                    SettingsView()
                        .transition(.opacity)
                case .about:
                    AboutView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: state.currentSection)
        }
        .frame(minWidth: 700, minHeight: 450)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor(white: 0.18, alpha: 1)),
                    Color(nsColor: NSColor(white: 0.14, alpha: 1))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .preferredColorScheme(.dark)
        .sheet(isPresented: Bindable(state).showTaskDetail) {
            if let gid = state.detailTaskGid,
               let task = (state.allActive + state.allCompleted + state.allStopped).first(where: { $0.gid == gid }) {
                TaskDetailView(task: task)
                    .preferredColorScheme(.dark)
            }
        }
        .alert("Operation Failed", isPresented: Bindable(state).showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(state.errorAlertMessage)
        }
        .onDrop(of: [.fileURL, .url, .utf8PlainText], isTargeted: nil) { providers in
            handleDrop(providers)
            return true
        }
    }
    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    if url.pathExtension.lowercased() == "torrent" {
                        if let torrentData = try? Data(contentsOf: url) {
                            Task { @MainActor in
                                state.addTaskTorrentData = torrentData
                                state.addTaskTorrentName = url.lastPathComponent
                                state.currentSection = .add
                            }
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier("public.url") {
                provider.loadItem(forTypeIdentifier: "public.url", options: nil) { item, _ in
                    guard let url = item as? URL ?? (item as? Data).flatMap({ URL(dataRepresentation: $0, relativeTo: nil) }) else { return }
                    let raw = url.absoluteString
                    Task { @MainActor in
                        let uri = ThunderLink.decode(raw)
                        do {
                            try await downloadService.addUri(uris: [uri])
                        } catch {
                            state.presentError("Add URL failed: \(error.localizedDescription)")
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier("public.utf8-plain-text") {
                provider.loadItem(forTypeIdentifier: "public.utf8-plain-text", options: nil) { item, _ in
                    guard let data = item as? Data,
                          let text = String(data: data, encoding: .utf8) else { return }
                    Task { @MainActor in
                        let uri = ThunderLink.decode(text)
                        do {
                            try await downloadService.addUri(uris: [uri])
                        } catch {
                            state.presentError("Add URL failed: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}
