import SwiftUI

struct PracticeView: View {
    @State private var vm = PracticeViewModel()
    @State private var navigateToQuiz = false
    @State private var activeQuizType: QuizType?
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WWSpacing.l) {
                Text("Choose the kind of practice that fits your time and what you need right now.")
                    .wwBody(color: .wwTextSecondary)

                if vm.dashboard.attemptCount > 0 {
                    PracticeSummaryCard(dashboard: vm.dashboard)
                }

                ForEach(QuizType.allCases, id: \.self) { type in
                    QuizOptionCard(
                        type: type,
                        isPro: appVM.subscriptionState.isPro,
                        dashboard: vm.dashboard
                    ) {
                        if vm.startQuiz(type, subscription: appVM.subscriptionState) {
                            activeQuizType = type
                            navigateToQuiz = true
                        }
                    }
                }
            }
            .wwScreenPadding()
            .padding(.vertical, WWSpacing.m)
        }
        .background(Color.wwBackground)
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $navigateToQuiz) {
            if let type = activeQuizType {
                QuizContainerView(quizType: type)
            }
        }
        .sheet(isPresented: $vm.showPaywall) {
            PaywallView(reason: "Full practice exams are a Pro feature.")
                .environment(services)
                .environment(appVM)
        }
        .task { vm.refreshDashboard() }
        .onAppear { vm.refreshDashboard() }
    }
}

// MARK: - Quiz Option Card

private struct QuizOptionCard: View {
    let type: QuizType
    let isPro: Bool
    let dashboard: PracticeDashboardSnapshot
    let action: () -> Void

    private var isLocked: Bool {
        type == .fullPracticeExam && !isPro
    }

    private var detailText: String {
        if type == .weakAreaReview {
            if let firstWeakTopic = dashboard.weakTopics.first?.title {
                return "Based on recent misses in \(firstWeakTopic)."
            }
            return "Unlocks focused follow-up after your first scored quiz."
        }

        if type == .quickQuiz, let latestScorePercentage = dashboard.latestScorePercentage {
            return "Last score: \(latestScorePercentage)%. Great for a quick check-in."
        }

        return type.description
    }

    var body: some View {
        Button(action: action) {
            WWCard {
                HStack(spacing: WWSpacing.m) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isLocked ? Color.wwSurface : Color.wwBlueDim)
                            .frame(width: 50, height: 50)
                        Image(systemName: type.icon)
                            .font(.system(size: 20))
                            .foregroundColor(isLocked ? .wwTextMuted : .wwBlue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: WWSpacing.s) {
                            Text(type.displayName)
                                .wwSectionTitle()
                            if isLocked {
                                Image(systemName: "lock")
                                    .font(.system(size: 12))
                                    .foregroundColor(.wwTextMuted)
                            }
                        }
                        Text(detailText)
                            .wwBody(color: .wwTextSecondary)
                        Text(type.bestFor)
                            .wwCaption()
                        Text("\(type.questionCount) questions")
                            .wwCaption()
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.wwTextMuted)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(isLocked ? 0.7 : 1.0)
    }
}

private struct PracticeSummaryCard: View {
    let dashboard: PracticeDashboardSnapshot

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.s) {
                Text("Practice Snapshot")
                    .wwSectionTitle()

                if let latestScorePercentage = dashboard.latestScorePercentage {
                    Text("Most recent score: \(latestScorePercentage)%")
                        .wwBody()
                }

                if let firstWeakTopic = dashboard.weakTopics.first {
                    Text("Next focus: \(firstWeakTopic.title)")
                        .wwBody(color: .wwTextSecondary)
                } else {
                    Text("No active weak areas right now. A full practice test is the best way to pressure-test your readiness.")
                        .wwBody(color: .wwTextSecondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PracticeView()
            .environment(ServiceContainer())
            .environment(AppViewModel())
    }
}
