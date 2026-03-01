import SwiftUI

struct Sidebar: View {
    @Environment(AppState.self) private var state
    var onSelectSection: (MainSection) -> Void

    var body: some View {
        HStack(spacing: 0) {
            iconStrip
            if state.currentSection == .tasks {
                categoryList
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.currentSection)
    }

    private var iconStrip: some View {
        VStack(spacing: 0) {
            Text("m")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.top, 24)
                .padding(.bottom, 10)

            VStack(spacing: 20) {
                iconButton("list.bullet", tip: "Tasks", isSelected: state.currentSection == .tasks) { onSelectSection(.tasks) }
                iconButton("plus", tip: "Add", isSelected: state.currentSection == .add) { onSelectSection(.add) }
            }
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 20) {
                iconButton("gearshape", tip: "Settings", isSelected: state.currentSection == .settings) { onSelectSection(.settings) }
                iconButton("questionmark.circle", tip: "About", isSelected: state.currentSection == .about) { onSelectSection(.about) }
            }
            .padding(.bottom, 24)
        }
        .frame(width: 80)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor(white: 0.11, alpha: 1)),
                    Color(nsColor: NSColor(white: 0.09, alpha: 1))
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func iconButton(_ icon: String, tip: String, isSelected: Bool = false, action: @escaping () -> Void) -> some View {
        SidebarIconButton(icon: icon, tip: tip, isSelected: isSelected, action: action)
    }

    private var categoryList: some View {
        @Bindable var state = state
        return VStack(alignment: .leading, spacing: 0) {
            Text("Task List")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 16)
                .padding(.top, 22)
                .padding(.bottom, 12)

            ForEach(TaskFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        state.currentList = filter
                    }
                } label: {
                    CategoryRow(
                        filter: filter,
                        count: count(for: filter),
                        isSelected: state.currentList == filter
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(width: 190)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor(white: 0.145, alpha: 1)),
                    Color(nsColor: NSColor(white: 0.135, alpha: 1))
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 1)
        }
    }

    private func count(for filter: TaskFilter) -> Int {
        switch filter {
        case .active: return state.globalStat.numActive + state.globalStat.numWaiting
        case .completed: return state.completedCount
        case .stopped: return state.stoppedCount
        }
    }
}

struct SidebarIconButton: View {
    let icon: String
    let tip: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue.opacity(0.25) : (isHovered ? Color.white.opacity(0.1) : Color.white.opacity(0.08)))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(isSelected ? 0.22 : 0.12), lineWidth: 1)
                    )
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isHovered)
        }
        .frame(width: 64, height: 42)
        .contentShape(Rectangle())
        .background(Color.clear)
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(tip)
    }
}

struct CategoryRow: View {
    let filter: TaskFilter
    let count: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: filter.systemImage)
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                .frame(width: 20)

            Text(filter.rawValue)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.7))

            Spacer()

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.white.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.white.opacity(0.11) : Color.white.opacity(0.001))
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
