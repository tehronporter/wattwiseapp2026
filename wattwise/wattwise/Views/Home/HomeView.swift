import SwiftUI

struct HomeView: View {
    @State private var vm = HomeViewModel()
    @State private var route: HomeRoute?
    @State private var showPaywall = false
    @State private var paywallContext: PaywallContext = .general
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
                }

                if let user = appVM.currentUser, let days = user.daysUntilExam {
                    ExamCountdownBanner(daysRemaining: days, examType: user.examType)
                }

                switch vm.loadState {
                case .idle, .loading:
                    HomeSkeletonView()
                case .loaded(let summary):
                    HomeContentView(
                        summary: summary,
                        subscription: appVM.subscriptionState,
                        currentUser: appVM.currentUser
                    ) { destination in
                        handleRoute(destination)
                    } onOpenPaywall: {
                        paywallContext = .general
                        showPaywall = true
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
                LearnHubView()
            case .quiz(let type):
                QuizContainerView(quizType: type)
            case .tutor:
                TutorView()
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: paywallContext)
                .environment(services)
                .environment(appVM)
        }
        .task { await vm.load(services: services) }
        .refreshable { await vm.refresh(services: services) }
    }

    private func handleRoute(_ destination: HomeRoute) {
        switch destination {
        case .quiz(.quickQuiz) where appVM.subscriptionState.previewQuickQuizLimitReached:
            paywallContext = .quizLimit
            showPaywall = true
        case .tutor where appVM.subscriptionState.hasPaidAccess == false && appVM.subscriptionState.tutorLimitReached:
            paywallContext = .tutorLimit
            showPaywall = true
        default:
            route = destination
        }
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
    let subscription: SubscriptionState
    var currentUser: WWUser? = nil
    let onRoute: (HomeRoute) -> Void
    let onOpenPaywall: () -> Void

    @State private var weakAreas: [WeakTopicDetail] = []

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
            // Primary action — dominant card, content varies by state
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
                } else {
                    PrimaryActionCard(
                        eyebrow: "Get Started",
                        title: "Begin your study path",
                        message: "Browse modules and start your first lesson when you're ready.",
                        primaryTitle: "Open Learn",
                        secondaryTitle: nil,
                        icon: "book"
                    ) {
                        onRoute(.learn)
                    }
                }
                QuickActionsSection(onRoute: onRoute, showLearnBrowse: true)

            case .active(let lesson):
                if let lesson {
                    ContinueLearningCard(
                        lesson: lesson,
                        title: "Resume Lesson",
                        actionTitle: "Resume Lesson"
                    ) {
                        onRoute(.lesson(lesson.lessonId))
                    }
                } else {
                    PrimaryActionCard(
                        eyebrow: "Keep Going",
                        title: "Continue Learning",
                        message: "Your study path is waiting — pick up from where you left off.",
                        primaryTitle: "Open Learn",
                        secondaryTitle: nil,
                        icon: "arrow.right.circle"
                    ) {
                        onRoute(.learn)
                    }
                }

            case .returning(let lesson):
                PrimaryActionCard(
                    eyebrow: "Welcome Back",
                    title: (lesson?.progress ?? 0) > 0 ? "Resume where you left off" : "Ready to keep going?",
                    message: lesson.map {
                        "Return to \($0.lessonTitle) in \($0.moduleTitle) — or take a quick quiz to get back into rhythm."
                    } ?? "Open Learn and jump into the next lesson when you're ready.",
                    primaryTitle: lesson == nil ? "Open Learn" : "Resume Lesson",
                    secondaryTitle: "Quick Quiz",
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
            }

            // Daily goal — always visible
            DailyGoalCard(goal: summary.dailyGoal)

            // Weak areas — only when they exist
            if !weakAreas.isEmpty {
                WeakAreasCard(weakAreas: weakAreas) {
                    onRoute(.quiz(.weakAreaReview))
                }
            }

            // Preview notice — subtle, at the bottom
            if subscription.hasPaidAccess == false {
                PreviewAccessNotice(summary: subscription.previewSummary, onOpenPaywall: onOpenPaywall)
            }
        }
        .onAppear {
            loadWeakAreas()
        }
    }

    private func loadWeakAreas() {
        let keys = PracticeHistoryStore.shared.suggestedWeakTopicKeys(limit: 3)
        weakAreas = PracticeHistoryStore.shared.topicDetails(for: keys)
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
        WWCard(padding: WWSpacing.l) {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                HStack(alignment: .top, spacing: WWSpacing.m) {
                    ZStack {
                        Circle()
                            .fill(Color.wwBlueDim)
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
        .overlay(
            RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous)
                .strokeBorder(Color.wwBlue.opacity(0.2), lineWidth: 1.5)
        )
    }
}

private struct ContinueLearningCard: View {
    let lesson: ProgressSummary.ContinueLearning
    let title: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        WWCard(padding: WWSpacing.l) {
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
                    ZStack {
                        Circle()
                            .fill(Color.wwBlueDim)
                            .frame(width: 44, height: 44)
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.wwBlue)
                    }
                }

                VStack(alignment: .leading, spacing: WWSpacing.xs) {
                    HStack {
                        Text("\(Int(lesson.progress * 100))% complete")
                            .wwCaption()
                        Spacer()
                    }
                    WWProgressBar(value: lesson.progress, height: 6)
                }

                WWPrimaryButton(title: actionTitle, action: action)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous)
                .strokeBorder(Color.wwBlue.opacity(0.2), lineWidth: 1.5)
        )
    }
}


private struct DailyGoalCard: View {
    let goal: ProgressSummary.DailyGoal

    private var isGoalReached: Bool { goal.minutesCompleted >= goal.targetMinutes }

    var body: some View {
        VStack(spacing: WWSpacing.s) {
            HStack {
                Label("Today", systemImage: isGoalReached ? "checkmark.circle.fill" : "clock")
                    .font(WWFont.label(.semibold))
                    .foregroundColor(isGoalReached ? .wwSuccess : .wwTextMuted)
                Spacer()
                Text("\(goal.minutesCompleted) / \(goal.targetMinutes) min")
                    .font(WWFont.caption(.semibold))
                    .foregroundColor(isGoalReached ? .wwSuccess : .wwTextSecondary)
            }
            WWProgressBar(value: goal.progress, height: 5, color: isGoalReached ? .wwSuccess : .wwBlue)
        }
        .padding(.horizontal, WWSpacing.m)
        .padding(.vertical, WWSpacing.m)
        .background(Color.wwSurface)
        .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous))
    }
}

private struct QuickActionsSection: View {
    let onRoute: (HomeRoute) -> Void
    var showLearnBrowse: Bool = false

    var body: some View {
        HStack(spacing: WWSpacing.m) {
            CompactActionCard(icon: "bolt", label: "Quick Quiz") {
                onRoute(.quiz(.quickQuiz))
            }
            CompactActionCard(icon: "bubble.left", label: "Ask Tutor") {
                onRoute(.tutor)
            }
            if showLearnBrowse {
                CompactActionCard(icon: "book", label: "Browse") {
                    onRoute(.learn)
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

// MARK: - Exam Countdown Banner

private struct ExamCountdownBanner: View {
    let daysRemaining: Int
    let examType: ExamType

    private var urgencyColor: Color {
        daysRemaining <= 7 ? .wwError : .wwBlue
    }

    private var urgencyMessage: String {
        switch daysRemaining {
        case 0...7:   return "Final push — stay focused."
        case 8...30:  return "Solid window. Keep the streak going."
        default:      return "You have time. Build a consistent habit now."
        }
    }

    var body: some View {
        WWCard {
            HStack(spacing: WWSpacing.m) {
                ZStack {
                    Circle()
                        .fill(urgencyColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Text("\(daysRemaining)")
                        .font(WWFont.heading(.bold))
                        .foregroundColor(urgencyColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(daysRemaining) day\(daysRemaining == 1 ? "" : "s") until your \(examType.displayName) exam")
                        .wwSectionTitle()
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(urgencyMessage)
                        .wwCaption(color: .wwTextSecondary)
                        .lineLimit(2)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Preview Access Notice (subtle, appears at bottom)

private struct PreviewAccessNotice: View {
    let summary: String
    let onOpenPaywall: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WWSpacing.s) {
            HStack {
                Text("Preview Access")
                    .wwLabel()
                    .textCase(.uppercase)
                Spacer()
                Button("See Options", action: onOpenPaywall)
                    .font(WWFont.caption(.semibold))
                    .foregroundColor(.wwBlue)
            }
            Text(summary)
                .wwCaption(color: .wwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(WWSpacing.m)
        .background(Color.wwSurface)
        .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous))
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

private struct WeakAreasCard: View {
    let weakAreas: [WeakTopicDetail]
    let onReview: () -> Void

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                HStack(spacing: WWSpacing.s) {
                    Image(systemName: "target")
                        .font(.system(size: 14))
                        .foregroundColor(.wwBlue)
                    Text("Weak Areas")
                        .wwLabel()
                        .textCase(.uppercase)
                    Spacer()
                    Text("From recent practice")
                        .wwLabel()
                        .foregroundColor(.wwTextMuted)
                }

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(weakAreas.prefix(3).enumerated()), id: \.element.id) { index, topic in
                        HStack(spacing: WWSpacing.m) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(topic.title)
                                    .font(WWFont.body(.medium))
                                    .foregroundColor(.wwTextPrimary)
                                    .lineLimit(1)
                                Text("\(topic.incorrectCount) missed")
                                    .wwCaption(color: .wwTextSecondary)
                            }
                            Spacer()
                            Text("\(Int((1.0 - topic.accuracy) * 100))%")
                                .font(WWFont.caption(.semibold))
                                .foregroundColor(.wwError)
                        }
                        .padding(.vertical, WWSpacing.s)
                        if index < weakAreas.prefix(3).count - 1 {
                            Divider()
                        }
                    }
                }

                WWPrimaryButton(title: "Review Weak Areas", action: onReview)
            }
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}
