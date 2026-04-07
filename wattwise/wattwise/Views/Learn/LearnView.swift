import SwiftUI

struct LearnView: View {
    @State private var vm = LearnViewModel()
    @Environment(ServiceContainer.self) private var services

    var body: some View {
        Group {
            switch vm.loadState {
            case .idle, .loading:
                LearnSkeletonView()
            case .loaded(let modules):
                ModuleListView(modules: modules)
            case .failed(let msg):
                WWEmptyState(
                    icon: "wifi.slash",
                    title: "Couldn't load modules",
                    message: msg,
                    actionTitle: "Retry"
                ) {
                    Task { await vm.refresh(services: services) }
                }
            }
        }
        .navigationTitle("Learn")
        .navigationBarTitleDisplayMode(.large)
        .background(Color.wwBackground)
        .task { await vm.load(services: services) }
        .refreshable { await vm.refresh(services: services) }
    }
}

// MARK: - Module List

private struct ModuleListView: View {
    let modules: [WWModule]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: WWSpacing.m) {
                ForEach(Array(modules.enumerated()), id: \.element.id) { index, module in
                    NavigationLink {
                        ModuleDetailView(module: module)
                    } label: {
                        ModuleCard(index: index + 1, module: module)
                    }
                    .buttonStyle(.plain)
                }
            }
            .wwScreenPadding()
            .padding(.vertical, WWSpacing.m)
        }
    }
}

// MARK: - Module Card

struct ModuleCard: View {
    let index: Int
    let module: WWModule

    private var statusBadge: WWStatusBadge.Status {
        if module.progress == 0 { return .notStarted }
        if module.progress >= 1 { return .completed }
        return .inProgress
    }

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                HStack(alignment: .top) {
                    // Module number
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.wwBlueDim)
                            .frame(width: 40, height: 40)
                        Text("\(index)")
                            .font(WWFont.sectionTitle(.bold))
                            .foregroundColor(.wwBlue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(module.title)
                            .wwSectionTitle()
                            .multilineTextAlignment(.leading)
                        HStack(spacing: WWSpacing.s) {
                            Label("\(module.lessonCount) lessons", systemImage: "list.bullet")
                            Label("\(module.estimatedMinutes) min", systemImage: "clock")
                        }
                        .font(WWFont.caption())
                        .foregroundColor(.wwTextMuted)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.wwTextMuted)
                }

                Text(module.description)
                    .wwBody(color: .wwTextSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Tags
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: WWSpacing.s) {
                        ForEach(module.topicTags, id: \.self) { tag in
                            Text(tag)
                                .wwLabel()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.wwDivider)
                                .clipShape(Capsule())
                        }
                    }
                }

                // Progress
                if module.progress > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            WWStatusBadge(status: statusBadge)
                            Spacer()
                            Text("\(module.completedLessons)/\(module.lessonCount) lessons")
                                .wwCaption()
                        }
                        WWProgressBar(value: module.progress)
                    }
                } else {
                    WWStatusBadge(status: .notStarted)
                }
            }
        }
    }
}

// MARK: - Skeleton

private struct LearnSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: WWSpacing.m) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous)
                        .fill(Color.wwSurface)
                        .frame(height: 160)
                        .shimmering()
                }
            }
            .wwScreenPadding()
            .padding(.vertical, WWSpacing.m)
        }
    }
}

#Preview {
    NavigationStack {
        LearnView()
            .environment(ServiceContainer())
    }
}
