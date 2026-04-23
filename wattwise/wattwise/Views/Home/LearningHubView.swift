import SwiftUI

struct LearningHubView: View {
    @State private var selectedTab = 0
    @State private var progressSummary: ProgressSummary?
    @State private var modules: [WWModule] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var route: LearningHubRoute?
    @State private var showPaywall = false
    @State private var paywallContext: PaywallContext = .general

    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Learning Path
            pathTab
                .tag(0)
                .tabItem {
                    Label("Learn", systemImage: "book.fill")
                }

            // Tab 2: Browse
            browseTab
                .tag(1)
                .tabItem {
                    Label("Browse", systemImage: "list.bullet")
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
        .task { await load() }
    }

    private var pathTab: some View {
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
                ScrollView {
                    VStack(alignment: .leading, spacing: WWSpacing.l) {
                        // Header with user greeting + stats
                        learningHeaderCard

                        // Suggested next lesson
                        if let suggestedLesson = progressSummary?.continueLearning {
                            SuggestedLessonCard(lesson: suggestedLesson) {
                                route = .lesson(suggestedLesson.lessonId)
                            }
                        }

                        // Learn path
                        LearnPathView()
                            .environment(services)
                            .environment(appVM)
                    }
                    .wwScreenPadding()
                    .padding(.vertical, WWSpacing.m)
                }
                .background(Color.wwBackground)
            }
        }
    }

    private var browseTab: some View {
        Group {
            if modules.isEmpty && !isLoading {
                WWEmptyState(
                    icon: "book",
                    title: "No modules available",
                    message: "Modules will appear once content is loaded."
                )
            } else {
                ScrollView {
                    VStack(spacing: WWSpacing.m) {
                        ForEach(modules) { module in
                            NavigationLink(value: LearningHubRoute.moduleDetail(module)) {
                                ModuleCard(module: module)
                            }
                        }
                    }
                    .wwScreenPadding()
                    .padding(.vertical, WWSpacing.m)
                }
                .background(Color.wwBackground)
            }
        }
    }

    private var learningHeaderCard: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Good morning")
                            .wwCaption()
                        if let user = appVM.currentUser {
                            Text(user.displayName ?? user.email.components(separatedBy: "@").first?.capitalized ?? "Learner")
                                .wwHeading()
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                            Text("\(progressSummary?.streakDays ?? 0)")
                                .font(WWFont.caption(.semibold))
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.yellow)
                            Text("\(appVM.currentUser?.totalXP ?? 0) XP")
                                .font(WWFont.caption(.semibold))
                        }
                    }
                }

                // Daily goal progress
                if let goal = progressSummary?.dailyGoal {
                    VStack(alignment: .leading, spacing: WWSpacing.s) {
                        HStack {
                            Text("Today's Goal")
                                .wwLabel()
                            Spacer()
                            Text("\(goal.minutesCompleted)/\(goal.targetMinutes) min")
                                .font(WWFont.caption(.semibold))
                                .foregroundColor(.wwBlue)
                        }
                        WWProgressBar(value: Double(goal.minutesCompleted) / Double(max(goal.targetMinutes, 1)), height: 6)
                    }
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil

        do {
            async let summary = services.content.loadProgressSummary()
            async let modulesTask = services.content.fetchModules()

            progressSummary = try await summary
            modules = try await modulesTask
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private enum LearningHubRoute: Hashable, Identifiable {
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

    static func == (lhs: LearningHubRoute, rhs: LearningHubRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct SuggestedLessonCard: View {
    let lesson: ProgressSummary.ContinueLearning
    let onTap: () -> Void

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                HStack(spacing: WWSpacing.s) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.wwBlue)
                    Text("Continue Learning")
                        .wwSectionTitle()
                }

                VStack(alignment: .leading, spacing: WWSpacing.s) {
                    Text(lesson.lessonTitle)
                        .wwHeading()
                    Text(lesson.moduleTitle)
                        .wwCaption(color: .wwTextSecondary)
                }

                if lesson.progress > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Progress")
                                .wwLabel()
                            Spacer()
                            Text("\(Int(lesson.progress * 100))%")
                                .font(WWFont.caption(.semibold))
                                .foregroundColor(.wwBlue)
                        }
                        WWProgressBar(value: lesson.progress, height: 4)
                    }
                }

                WWPrimaryButton(title: "Resume Lesson", action: onTap)
            }
        }
    }
}

private struct ModuleCard: View {
    let module: WWModule

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: WWSpacing.s) {
                        Text(module.title)
                            .wwHeading()
                        Text(module.description)
                            .wwBody(color: .wwTextSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(module.lessonCount)")
                            .font(WWFont.heading(.semibold))
                            .foregroundColor(.wwBlue)
                        Text("lessons")
                            .wwCaption(color: .wwTextSecondary)
                    }
                }

                if module.progress > 0 {
                    WWProgressBar(value: module.progress, height: 4)
                }

                HStack(spacing: WWSpacing.m) {
                    Label("\(module.estimatedMinutes) min", systemImage: "clock")
                        .font(WWFont.caption(.medium))
                        .foregroundColor(.wwTextSecondary)
                    Spacer()
                    if module.progress >= 1.0 {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .font(WWFont.caption(.medium))
                            .foregroundColor(.wwBlue)
                    }
                }
            }
        }
    }
}

#Preview {
    LearningHubView()
        .environment(ServiceContainer.preview)
        .environment(AppViewModel())
}
