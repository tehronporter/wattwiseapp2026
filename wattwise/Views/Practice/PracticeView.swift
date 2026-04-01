import SwiftUI

struct PracticeView: View {
    @State private var vm = PracticeViewModel()
    @State private var route: QuizType?
    @State private var unavailableState: PracticeUnavailableState?
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WWSpacing.l) {
                Text("Choose the kind of practice that fits your time and what you need right now.")
                    .wwBody(color: .wwTextSecondary)

                if appVM.subscriptionState.hasPaidAccess == false {
                    WWCard {
                        VStack(alignment: .leading, spacing: WWSpacing.s) {
                            Text("Preview Access")
                                .wwLabel()
                                .textCase(.uppercase)
                            Text(
                                appVM.subscriptionState.previewQuickQuizLimitReached
                                ? "You've finished your preview quiz. Full access opens more practice, weak-area review, and full exam sessions."
                                : "Preview includes one full quick quiz. Use it when you're ready for a meaningful score and review."
                            )
                            .wwBody(color: .wwTextSecondary)
                        }
                    }
                }

                if vm.dashboard.attemptCount > 0 {
                    PracticeSummaryCard(dashboard: vm.dashboard)
                }

                ForEach(QuizType.allCases, id: \.self) { type in
                    QuizOptionCard(
                        type: type,
                        hasPaidAccess: appVM.subscriptionState.hasPaidAccess,
                        previewQuizUsed: appVM.subscriptionState.previewQuickQuizLimitReached,
                        dashboard: vm.dashboard
                    ) {
                        switch vm.startQuiz(type, subscription: appVM.subscriptionState) {
                        case .start(let type):
                            route = type
                        case .paywall:
                            break
                        case .unavailable(let title, let message, let suggestedQuiz):
                            unavailableState = PracticeUnavailableState(
                                title: title,
                                message: message,
                                suggestedQuiz: suggestedQuiz
                            )
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
        .navigationDestination(item: $route) { type in
            QuizContainerView(quizType: type)
        }
        .sheet(isPresented: $vm.showPaywall) {
            PaywallView(context: vm.paywallContext)
                .environment(services)
                .environment(appVM)
        }
        .alert(item: $unavailableState) { state in
            if let suggestedQuiz = state.suggestedQuiz {
                Alert(
                    title: Text(state.title),
                    message: Text(state.message),
                    primaryButton: .default(Text(suggestedQuiz.displayName)) {
                        route = suggestedQuiz
                    },
                    secondaryButton: .cancel()
                )
            } else {
                Alert(
                    title: Text(state.title),
                    message: Text(state.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .task { vm.refreshDashboard() }
        .onAppear { vm.refreshDashboard() }
    }
}

private struct PracticeUnavailableState: Identifiable {
    let title: String
    let message: String
    let suggestedQuiz: QuizType?

    var id: String {
        [title, message, suggestedQuiz?.rawValue ?? "none"].joined(separator: "::")
    }
}

// MARK: - Quiz Option Card

private struct QuizOptionCard: View {
    let type: QuizType
    let hasPaidAccess: Bool
    let previewQuizUsed: Bool
    let dashboard: PracticeDashboardSnapshot
    let action: () -> Void

    private var isLocked: Bool {
        if hasPaidAccess {
            return false
        }
        switch type {
        case .quickQuiz:
            return previewQuizUsed
        case .fullPracticeExam, .weakAreaReview:
            return true
        }
    }

    private var detailText: String {
        if hasPaidAccess == false {
            switch type {
            case .quickQuiz where previewQuizUsed:
                return "You've used the preview quiz. Full access keeps practice going."
            case .fullPracticeExam:
                return "Locked in preview. Built for serious exam-style practice."
            case .weakAreaReview where dashboard.attemptCount > 0:
                return "Locked in preview. Use full access for targeted follow-up."
            default:
                break
            }
        }

        if type == .weakAreaReview {
            if dashboard.attemptCount == 0 {
                return "Take a scored quiz first to unlock targeted follow-up."
            }
            if let firstWeakTopic = dashboard.weakTopics.first?.title {
                return "Based on recent misses in \(firstWeakTopic)."
            }
            return "No active weak areas right now. Run a fresh quiz to surface the next focus."
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
