import SwiftUI

struct HomeView: View {
    @State private var vm = HomeViewModel()
    @State private var route: HomeRoute?
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        ScrollView {
            VStack(spacing: WWSpacing.l) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.greeting)
                            .wwCaption()
                        if let user = appVM.currentUser {
                            Text(user.displayName ?? user.email.components(separatedBy: "@").first?.capitalized ?? "Electrician")
                                .wwHeading()
                        }
                    }
                    Spacer()
                    if let summary = vm.loadState.value, summary.streakDays > 0 {
                        StreakBadge(days: summary.streakDays)
                    }
                }

                switch vm.loadState {
                case .idle, .loading:
                    HomeSkeletonView()
                case .loaded(let summary):
                    HomeContentView(summary: summary) { destination in
                        route = destination
                    }
                case .failed(let msg):
                    WWEmptyState(
                        icon: "wifi.slash",
                        title: "Couldn't load",
                        message: msg,
                        actionTitle: "Retry"
                    ) {
                        Task { await vm.refresh(services: services) }
                    }
                }
            }
            .wwScreenPadding()
            .padding(.vertical, WWSpacing.m)
        }
        .background(Color.wwBackground)
        .navigationTitle("")
        .navigationBarHidden(true)
        .navigationDestination(item: $route) { destination in
            switch destination {
            case .lesson(let lessonId):
                LessonView(lessonId: lessonId)
            case .learn:
                LearnView()
            case .quiz(let type):
                QuizContainerView(quizType: type)
            case .tutor:
                TutorView()
            }
        }
        .task { await vm.load(services: services) }
        .refreshable { await vm.refresh(services: services) }
    }
}

private enum HomeRoute: Hashable, Identifiable {
    case lesson(UUID)
    case learn
    case quiz(QuizType)
    case tutor

    var id: String {
        switch self {
        case .lesson(let lessonId):
            return "lesson-\(lessonId.uuidString)"
        case .learn:
            return "learn"
        case .quiz(let type):
            return "quiz-\(type.rawValue)"
        case .tutor:
            return "tutor"
        }
    }
}

private struct HomeContentView: View {
    let summary: ProgressSummary
    let onRoute: (HomeRoute) -> Void

    private enum PresentationState {
        case newUser(ProgressSummary.ContinueLearning?)
        case active(ProgressSummary.ContinueLearning?)
        case returning(ProgressSummary.ContinueLearning?)
    }

    private var state: PresentationState {
        guard summary.hasStartedContent else { return .newUser(summary.continueLearning) }
        if let lastActivityAt = summary.lastActivityAt,
           Calendar.current.isDateInToday(lastActivityAt) || Calendar.current.isDateInYesterday(lastActivityAt) || summary.hasInProgressLesson {
            return .active(summary.continueLearning)
        }
        return .returning(summary.continueLearning)
    }

    var body: some View {
        VStack(spacing: WWSpacing.l) {
            switch state {
            case .newUser(let lesson):
                if let lesson {
                    PrimaryActionCard(
                        eyebrow: "Get Started",
                        title: "Start your first lesson",
                        message: "Begin with \(lesson.lessonTitle) and build momentum right away.",
                        primaryTitle: "Start Learning",
                        secondaryTitle: "Browse Modules",
                        icon: "book"
                    ) {
                        onRoute(.lesson(lesson.lessonId))
                    } onSecondary: {
                        onRoute(.learn)
                    }
                }
                DailyGoalCard(goal: summary.dailyGoal)

            case .active(let lesson):
                if let lesson {
                    ContinueLearningCard(
                        lesson: lesson,
                        title: "Resume Lesson",
                        actionTitle: "Resume Lesson"
                    ) {
                        onRoute(.lesson(lesson.lessonId))
                    }
                }

                TodaysFocusCard(
                    title: "Today's Focus",
                    message: summary.recommendedAction ?? "Keep moving through your study path.",
                    actionTitle: summary.hasInProgressLesson ? "Start Quick Quiz" : "Open Learn",
                    icon: summary.hasInProgressLesson ? "bolt" : "lightbulb"
                ) {
                    onRoute(summary.hasInProgressLesson ? .quiz(.quickQuiz) : .learn)
                }

                DailyGoalCard(goal: summary.dailyGoal)
                QuickActionsSection(onRoute: onRoute)

            case .returning(let lesson):
                PrimaryActionCard(
                    eyebrow: "Welcome Back",
                    title: lesson?.progress ?? 0 > 0 ? "Resume where you left off" : "Restart with a clear next step",
                    message: lesson.map {
                        "Return to \($0.lessonTitle) in \($0.moduleTitle) or take a short refresher quiz to get back into rhythm."
                    } ?? "Open Learn and jump into the next lesson when you're ready.",
                    primaryTitle: lesson == nil ? "Open Learn" : "Resume Lesson",
                    secondaryTitle: "Start Quick Quiz",
                    icon: "clock.arrow.circlepath"
                ) {
                    if let lesson {
                        onRoute(.lesson(lesson.lessonId))
                    } else {
                        onRoute(.learn)
                    }
                } onSecondary: {
                    onRoute(.quiz(.quickQuiz))
                }

                TodaysFocusCard(
                    title: "Re-entry Focus",
                    message: "A short quiz is the fastest way to rebuild confidence and remember what needs attention.",
                    actionTitle: "Review with Quiz",
                    icon: "list.bullet.clipboard"
                ) {
                    onRoute(.quiz(.quickQuiz))
                }

                DailyGoalCard(goal: summary.dailyGoal)
            }
        }
    }
}

private struct PrimaryActionCard: View {
    let eyebrow: String
    let title: String
    let message: String
    let primaryTitle: String
    let secondaryTitle: String?
    let icon: String
    let onPrimary: () -> Void
    var onSecondary: (() -> Void)? = nil

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                HStack(alignment: .top, spacing: WWSpacing.m) {
                    ZStack {
                        Circle()
                            .stroke(Color.wwBlue.opacity(0.18), lineWidth: 1)
                            .frame(width: 44, height: 44)
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.wwBlue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(eyebrow)
                            .wwLabel()
                            .textCase(.uppercase)
                        Text(title)
                            .wwSectionTitle()
                        Text(message)
                            .wwBody(color: .wwTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                WWPrimaryButton(title: primaryTitle, action: onPrimary)

                if let secondaryTitle, let onSecondary {
                    WWGhostButton(title: secondaryTitle, color: .wwBlue, action: onSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }
}

private struct ContinueLearningCard: View {
    let lesson: ProgressSummary.ContinueLearning
    let title: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .wwLabel()
                            .textCase(.uppercase)
                        Text(lesson.lessonTitle)
                            .wwSectionTitle()
                        Text(lesson.moduleTitle)
                            .wwCaption()
                    }
                    Spacer()
                    Image(systemName: "play.circle")
                        .font(.system(size: 34, weight: .regular))
                        .foregroundColor(.wwBlue)
                }

                VStack(alignment: .leading, spacing: WWSpacing.xs) {
                    HStack {
                        Text("\(Int(lesson.progress * 100))% complete")
                            .wwCaption()
                        Spacer()
                    }
                    WWProgressBar(value: lesson.progress)
                }

                WWPrimaryButton(title: actionTitle, action: action)
            }
        }
    }
}

private struct TodaysFocusCard: View {
    let title: String
    let message: String
    let actionTitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                HStack(spacing: WWSpacing.m) {
                    ZStack {
                        Circle()
                            .stroke(Color.wwBlue.opacity(0.16), lineWidth: 1)
                            .frame(width: 40, height: 40)
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.wwBlue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .wwLabel()
                            .textCase(.uppercase)
                        Text(message)
                            .wwBody()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                WWSecondaryButton(title: actionTitle, action: action)
            }
        }
    }
}

private struct DailyGoalCard: View {
    let goal: ProgressSummary.DailyGoal

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                HStack {
                    Text("Daily Goal")
                        .wwLabel()
                        .textCase(.uppercase)
                    Spacer()
                    Text("\(goal.minutesCompleted) / \(goal.targetMinutes) min")
                        .wwCaption()
                }
                WWProgressBar(value: goal.progress, height: 6)
                Text(goal.minutesCompleted >= goal.targetMinutes
                     ? "Goal reached. Keep going only if you have the energy."
                     : "\(goal.targetMinutes - goal.minutesCompleted) minutes left to reach your goal")
                    .wwCaption(color: .wwTextSecondary)
            }
        }
    }
}

private struct QuickActionsSection: View {
    let onRoute: (HomeRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WWSpacing.m) {
            Text("More Options")
                .wwLabel()
                .textCase(.uppercase)

            HStack(spacing: WWSpacing.m) {
                CompactActionCard(icon: "bolt", label: "Quick Quiz") {
                    onRoute(.quiz(.quickQuiz))
                }
                CompactActionCard(icon: "bubble.left", label: "Ask Tutor") {
                    onRoute(.tutor)
                }
            }
        }
    }
}

private struct CompactActionCard: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: WWSpacing.s) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.wwBlue)
                    .frame(height: 24)
                Text(label)
                    .font(WWFont.caption(.medium))
                    .foregroundColor(.wwTextPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, WWSpacing.m)
            .background(Color.wwSurface)
            .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct StreakBadge: View {
    let days: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame")
                .font(.system(size: 14))
                .foregroundColor(.wwBlue)
            Text("\(days) day\(days == 1 ? "" : "s")")
                .font(WWFont.caption(.semibold))
                .foregroundColor(.wwTextPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.wwBlueDim)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.wwBlue.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct HomeSkeletonView: View {
    var body: some View {
        VStack(spacing: WWSpacing.l) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous)
                    .fill(Color.wwSurface)
                    .frame(height: 120)
                    .shimmering()
            }
        }
    }
}

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color(UIColor.systemBackground).opacity(0.55), location: 0.4),
                            .init(color: Color(UIColor.systemBackground).opacity(0.75), location: 0.5),
                            .init(color: Color(UIColor.systemBackground).opacity(0.55), location: 0.6),
                            .init(color: .clear, location: 1),
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 3)
                    .offset(x: geo.size.width * phase)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}
