import SwiftUI

struct HomeView: View {
    @State private var vm = HomeViewModel()
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        ScrollView {
            VStack(spacing: WWSpacing.l) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.greeting)
                            .wwCaption()
                        if let user = appVM.currentUser {
                            Text(user.displayName ?? user.email.components(separatedBy: "@").first?.capitalized ?? "Electrician")
                                .wwHeading()
                        }
                    }
                    Spacer()
                    // Streak badge
                    if let summary = vm.loadState.value, summary.streakDays > 0 {
                        StreakBadge(days: summary.streakDays)
                    }
                }

                // Content
                switch vm.loadState {
                case .idle, .loading:
                    HomeSkeletonView()
                case .loaded(let summary):
                    HomeContentView(summary: summary)
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
        .task { await vm.load(services: services) }
        .refreshable { await vm.refresh(services: services) }
    }
}

// MARK: - Home Content

private struct HomeContentView: View {
    let summary: ProgressSummary

    var body: some View {
        VStack(spacing: WWSpacing.l) {
            // Continue Learning Card
            if let cl = summary.continueLearning {
                ContinueLearningCard(lesson: cl)
            }

            // Today's Focus
            if let rec = summary.recommendedAction {
                TodaysFocusCard(message: rec)
            }

            // Daily Goal
            DailyGoalCard(goal: summary.dailyGoal)

            // Quick Actions
            QuickActionsSection()
        }
    }
}

// MARK: - Continue Learning Card

private struct ContinueLearningCard: View {
    let lesson: ProgressSummary.ContinueLearning
    @State private var navigateToLesson = false

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Continue Learning")
                            .wwLabel()
                            .textCase(.uppercase)
                        Text(lesson.lessonTitle)
                            .wwSectionTitle()
                        Text(lesson.moduleTitle)
                            .wwCaption()
                    }
                    Spacer()
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 36, weight: .regular))
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

                NavigationLink {
                    LessonView(lessonId: lesson.lessonId)
                } label: {
                    Text("Resume Lesson")
                        .font(WWFont.body(.semibold))
                        .foregroundColor(.wwBlue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.wwBlueDim)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Today's Focus Card

private struct TodaysFocusCard: View {
    let message: String

    var body: some View {
        WWCard {
            HStack(spacing: WWSpacing.m) {
                ZStack {
                    Circle()
                        .fill(Color.wwBlueDim)
                        .frame(width: 44, height: 44)
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.wwBlue)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Focus")
                        .wwLabel()
                        .textCase(.uppercase)
                    Text(message)
                        .wwBody()
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Daily Goal Card

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
                     ? "Goal reached! Great work today."
                     : "\(goal.targetMinutes - goal.minutesCompleted) minutes left to reach your goal")
                    .wwCaption(color: goal.minutesCompleted >= goal.targetMinutes ? .wwSuccess : .wwTextSecondary)
            }
        }
    }
}

// MARK: - Quick Actions

private struct QuickActionsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: WWSpacing.m) {
            Text("Quick Actions")
                .wwLabel()
                .textCase(.uppercase)

            HStack(spacing: WWSpacing.m) {
                NavigationLink {
                    QuizContainerView(quizType: .quickQuiz)
                } label: {
                    QuickActionCard(icon: "bolt.fill", label: "Start Quiz")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    TutorView()
                } label: {
                    QuickActionCard(icon: "bubble.left.fill", label: "Ask Tutor")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    NECView()
                } label: {
                    QuickActionCard(icon: "book.pages.fill", label: "NEC Code")
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct QuickActionCard: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: WWSpacing.s) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(.wwBlue)
                .frame(height: 28)
            Text(label)
                .font(WWFont.caption(.medium))
                .foregroundColor(.wwTextPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, WWSpacing.m)
        .background(Color.wwSurface)
        .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous))
    }
}

// MARK: - Streak Badge

private struct StreakBadge: View {
    let days: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#FF6B35"))
            Text("\(days) day\(days == 1 ? "" : "s")")
                .font(WWFont.caption(.semibold))
                .foregroundColor(.wwTextPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(hex: "#FF6B35").opacity(0.1))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color(hex: "#FF6B35").opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Skeleton

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

// MARK: - Shimmer modifier

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

#Preview {
    NavigationStack {
        HomeView()
            .environment(ServiceContainer())
            .environment(AppViewModel())
    }
}
