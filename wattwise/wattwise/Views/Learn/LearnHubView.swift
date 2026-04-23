import SwiftUI

struct LearnHubView: View {
    @State private var modules: [WWModule] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var route: LearnRoute?
    @State private var showPaywall = false
    @State private var paywallContext: PaywallContext = .general
    @State private var isBrowsingMode = false

    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let error = errorMessage {
                    WWEmptyState(
                        icon: "wifi.slash",
                        title: "Couldn't load",
                        message: error,
                        actionTitle: "Retry"
                    ) {
                        Task { await load() }
                    }
                } else {
                    VStack(spacing: 0) {
                        // Header with browse toggle
                        HStack(spacing: WWSpacing.m) {
                            Text("Learn")
                                .font(WWFont.sectionTitle(.semibold))
                            Spacer()
                            if !isBrowsingMode {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.wwBlue)
                            }
                            HStack(spacing: 4) {
                                if isBrowsingMode {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.wwBlue)
                                }
                                Text("Browse")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(isBrowsingMode ? .wwBlue : .wwTextMuted)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isBrowsingMode ? Color.wwBlueDim : Color.clear)
                            .cornerRadius(6)
                            .onTapGesture { isBrowsingMode.toggle() }
                        }
                        .padding(.horizontal, WWSpacing.m)
                        .padding(.vertical, WWSpacing.s)
                        .background(Color.wwBackground)

                        // Content: Path or Browse mode
                        if isBrowsingMode {
                            moduleListView
                        } else {
                            pathView
                        }
                    }
                }
            }
            .navigationDestination(item: $route) { destination in
                switch destination {
                case .lesson(let lessonId):
                    LessonView(lessonId: lessonId)
                case .moduleDetail(let module):
                    ModuleDetailView(module: module)
                case .quiz(let type):
                    QuizContainerView(quizType: type)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(context: paywallContext)
                    .environment(services)
                    .environment(appVM)
            }
        }
        .task { await load() }
    }

    private var pathView: some View {
        ScrollView {
            VStack(spacing: WWSpacing.l) {
                LearnPathView(modules: modules)
                    .environment(services)
                    .environment(appVM)
            }
            .wwScreenPadding()
            .padding(.vertical, WWSpacing.m)
        }
        .background(Color.wwBackground)
    }

    private var moduleListView: some View {
        ScrollView {
            LazyVStack(spacing: WWSpacing.m) {
                ForEach(Array(modules.enumerated()), id: \.element.id) { index, module in
                    NavigationLink(value: LearnRoute.moduleDetail(module)) {
                        HubModuleCard(module: module)
                    }
                    .buttonStyle(.plain)
                }
            }
            .wwScreenPadding()
            .padding(.vertical, WWSpacing.m)
        }
        .background(Color.wwBackground)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil

        do {
            modules = try await services.content.fetchModules()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private enum LearnRoute: Hashable, Identifiable {
    case lesson(UUID)
    case moduleDetail(WWModule)
    case quiz(QuizType)

    var id: String {
        switch self {
        case .lesson(let id):
            return "lesson-\(id.uuidString)"
        case .moduleDetail(let module):
            return "module-\(module.id.uuidString)"
        case .quiz(let type):
            return "quiz-\(type.rawValue)"
        }
    }

    static func == (lhs: LearnRoute, rhs: LearnRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct HubModuleCard: View {
    let module: WWModule

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.s) {
                HStack(alignment: .top, spacing: WWSpacing.m) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(module.title)
                            .wwSectionTitle()
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(module.description)
                            .wwBody(color: .wwTextSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(module.lessonCount)")
                            .font(WWFont.sectionTitle(.semibold))
                            .foregroundColor(.wwBlue)
                        Text("lessons")
                            .wwCaption(color: .wwTextSecondary)
                    }
                }

                if module.progress > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        WWProgressBar(value: module.progress, height: 4)
                        Text("\(Int(module.progress * 100))% complete")
                            .wwCaption(color: .wwTextSecondary)
                    }
                }

                HStack(spacing: WWSpacing.m) {
                    Label("\(module.estimatedMinutes) min", systemImage: "clock")
                        .font(WWFont.caption(.medium))
                        .foregroundColor(.wwTextSecondary)
                    Spacer()
                    if module.progress >= 1.0 {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .font(WWFont.caption(.medium))
                            .foregroundColor(.wwSuccess)
                    }
                }
            }
        }
    }
}

#Preview {
    LearnHubView()
        .environment(ServiceContainer())
        .environment(AppViewModel())
}
