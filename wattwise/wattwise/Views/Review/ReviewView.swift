import SwiftUI

// MARK: - Review Quiz Launch Spec

private struct ReviewQuizLaunch: Identifiable, Hashable {
    let id = UUID()
    let quizType: QuizType
    let topicTags: [String]
}

// MARK: - Review View (Secondary Tab)

struct ReviewView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(ServiceContainer.self) private var services
    @State private var dashboard: PracticeDashboardSnapshot = .empty
    @State private var quizLaunch: ReviewQuizLaunch?
    @State private var showTutor = false
    @State private var tutorContext: TutorContext?
    @State private var showPaywall = false
    @State private var paywallContext: PaywallContext = .weakAreaLocked

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WWSpacing.l) {
                if dashboard.attemptCount == 0 {
                    EmptyReviewState()
                } else {
                    // Weak Topics
                    if !dashboard.weakTopics.isEmpty {
                        WeakTopicsSection(
                            topics: dashboard.weakTopics,
                            hasPaidAccess: appVM.subscriptionState.hasPaidAccess
                        ) { topic in
                            openTutor(for: topic)
                        } onRetryTopic: { topic in
                            retryTopic(topic)
                        } onRetryAll: {
                            retryAllWeak()
                        }
                    } else {
                        NoWeakTopicsCard()
                    }

                    // Recent Quiz History
                    RecentAttemptsSection(hasPaidAccess: appVM.subscriptionState.hasPaidAccess) {
                        retryAllWeak()
                    }
                }
            }
            .wwScreenPadding()
            .padding(.vertical, WWSpacing.m)
        }
        .background(Color.wwBackground)
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $quizLaunch) { launch in
            QuizContainerView(quizType: launch.quizType, topicTags: launch.topicTags)
        }
        .sheet(isPresented: $showTutor) {
            TutorSheet(context: tutorContext)
                .environment(services)
                .environment(appVM)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: paywallContext)
                .environment(services)
                .environment(appVM)
        }
        .onAppear { dashboard = PracticeHistoryStore.shared.dashboard() }
    }

    private func openTutor(for topic: WeakTopicDetail) {
        tutorContext = TutorContextBuilder.weakTopicStudy(topic, user: appVM.currentUser)
        showTutor = true
    }

    private func retryTopic(_ topic: WeakTopicDetail) {
        guard appVM.subscriptionState.hasPaidAccess else {
            paywallContext = .weakAreaLocked
            showPaywall = true
            return
        }
        quizLaunch = ReviewQuizLaunch(quizType: .weakAreaReview, topicTags: [topic.key, topic.title])
    }

    private func retryAllWeak() {
        guard appVM.subscriptionState.hasPaidAccess else {
            paywallContext = .weakAreaLocked
            showPaywall = true
            return
        }
        let tags = dashboard.weakTopics.flatMap { [$0.key, $0.title] }
        quizLaunch = ReviewQuizLaunch(quizType: .weakAreaReview, topicTags: tags)
    }
}

// MARK: - Empty Review State

private struct EmptyReviewState: View {
    var body: some View {
        WWCard {
            VStack(spacing: WWSpacing.m) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 36))
                    .foregroundColor(.wwBlue)
                VStack(spacing: WWSpacing.s) {
                    Text("No review data yet")
                        .wwSectionTitle()
                    Text("Complete a quiz on the Practice tab and your weak areas will appear here for focused follow-up.")
                        .wwBody(color: .wwTextSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, WWSpacing.m)
        }
    }
}

// MARK: - Weak Topics Section

private struct WeakTopicsSection: View {
    let topics: [WeakTopicDetail]
    let hasPaidAccess: Bool
    let onAskTutor: (WeakTopicDetail) -> Void
    let onRetryTopic: (WeakTopicDetail) -> Void
    let onRetryAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WWSpacing.m) {
            WWSectionHeader(title: "Weak Areas", action: "Practice All", onAction: onRetryAll)

            WWCard {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                        WeakTopicRow(
                            topic: topic,
                            hasPaidAccess: hasPaidAccess,
                            onAskTutor: { onAskTutor(topic) },
                            onRetry: { onRetryTopic(topic) }
                        )
                        if index < topics.count - 1 {
                            WWDivider()
                        }
                    }
                }
            }
        }
    }
}

private struct WeakTopicRow: View {
    let topic: WeakTopicDetail
    let hasPaidAccess: Bool
    let onAskTutor: () -> Void
    let onRetry: () -> Void

    private var accuracyColor: Color {
        topic.accuracy >= 0.7 ? .wwSuccess : topic.accuracy >= 0.5 ? .wwWarning : .wwError
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WWSpacing.s) {
            HStack(alignment: .top, spacing: WWSpacing.s) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.wwWarning)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(topic.title)
                        .wwBody()
                    Text("\(topic.incorrectCount) miss\(topic.incorrectCount == 1 ? "" : "es") · \(Int(topic.accuracy * 100))% accuracy")
                        .wwCaption(color: .wwTextMuted)
                }

                Spacer()

                // Accuracy pill
                Text("\(Int(topic.accuracy * 100))%")
                    .font(WWFont.caption(.bold))
                    .foregroundColor(accuracyColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accuracyColor.opacity(0.1))
                    .clipShape(Capsule())
            }

            HStack(spacing: WWSpacing.s) {
                Button(action: onRetry) {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(WWFont.caption(.semibold))
                        .foregroundColor(hasPaidAccess ? .wwBlue : .wwTextMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(hasPaidAccess ? Color.wwBlueDim : Color.wwSurface)
                        .clipShape(Capsule())
                }

                Button(action: onAskTutor) {
                    Label("Ask Tutor", systemImage: "bubble.left")
                        .font(WWFont.caption(.semibold))
                        .foregroundColor(.wwTextSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.wwSurface)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(WWSpacing.m)
    }
}

// MARK: - No Weak Topics Card

private struct NoWeakTopicsCard: View {
    var body: some View {
        WWCard {
            HStack(spacing: WWSpacing.m) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.wwSuccess)
                VStack(alignment: .leading, spacing: 4) {
                    Text("No weak areas detected")
                        .wwSectionTitle()
                    Text("Strong work. Keep quizzing to stay sharp.")
                        .wwBody(color: .wwTextSecondary)
                }
            }
        }
    }
}

// MARK: - Recent Attempts Section

private struct RecentAttemptsSection: View {
    let hasPaidAccess: Bool
    let onPracticeWeak: () -> Void
    private let allAttempts = PracticeHistoryStore.shared.allAttempts()

    private var recentAttempts: [PracticeAttemptSummary] {
        Array(allAttempts.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WWSpacing.m) {
            WWSectionHeader(title: "Recent Quizzes")

            if recentAttempts.isEmpty {
                WWCard {
                    Text("No quiz history yet.")
                        .wwBody(color: .wwTextMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, WWSpacing.s)
                }
            } else {
                WWCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(recentAttempts.enumerated()), id: \.element.id) { index, attempt in
                            AttemptRow(attempt: attempt)
                            if index < recentAttempts.count - 1 {
                                WWDivider().padding(.leading, WWSpacing.m)
                            }
                        }
                    }
                }
            }

            // CTA
            if hasPaidAccess && !allAttempts.isEmpty {
                WWGhostButton(title: "Practice Weak Areas", color: .wwBlue, action: onPracticeWeak)
            }
        }
    }
}

private struct AttemptRow: View {
    let attempt: PracticeAttemptSummary

    private var scoreColor: Color {
        attempt.passed ? .wwSuccess : .wwError
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: attempt.completedAt, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: WWSpacing.m) {
            ZStack {
                Circle()
                    .fill(scoreColor.opacity(0.1))
                    .frame(width: 36, height: 36)
                Text("\(attempt.percentage)%")
                    .font(WWFont.label(.bold))
                    .foregroundColor(scoreColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(attempt.quizType.displayName)
                    .wwBody()
                Text("\(attempt.correctCount)/\(attempt.totalCount) correct · \(formattedDate)")
                    .wwCaption(color: .wwTextMuted)
            }

            Spacer()

            Image(systemName: attempt.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(attempt.passed ? .wwSuccess : .wwError)
        }
        .padding(WWSpacing.m)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReviewView()
            .environment(ServiceContainer())
            .environment({
                let vm = AppViewModel()
                vm.authState = .authenticated(WWUser(
                    id: UUID(), email: "test@example.com", displayName: "Alex",
                    examType: .journeyman, state: "TX", studyGoal: .moderate,
                    streakDays: 3, isOnboardingComplete: true
                ))
                return vm
            }())
    }
}
