import SwiftUI

struct PracticeView: View {
    @State private var vm = PracticeViewModel()
    @State private var route: QuizType?
    @State private var unavailableState: PracticeUnavailableState?
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM

    private var recommendedQuizType: QuizType {
        guard vm.dashboard.attemptCount > 0 else { return .quickQuiz }
        if !vm.dashboard.weakTopics.isEmpty && appVM.subscriptionState.hasPaidAccess {
            return .weakAreaReview
        }
        return vm.dashboard.attemptCount >= 3 ? .fullPracticeExam : .quickQuiz
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WWSpacing.l) {
                Text("Drill questions, track accuracy, and close your weak areas before exam day.")
                    .wwBody(color: .wwTextSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

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
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if vm.dashboard.attemptCount > 0 {
                    PracticeSummaryCard(dashboard: vm.dashboard)
                }

                // Practice modes section
                VStack(alignment: .leading, spacing: WWSpacing.s) {
                    Text("Practice Modes")
                        .wwLabel()
                        .textCase(.uppercase)
                        .foregroundColor(.wwTextMuted)

                    ForEach(QuizType.allCases.filter { $0 != .calculationDrill }, id: \.self) { type in
                        QuizOptionCard(
                            type: type,
                            hasPaidAccess: appVM.subscriptionState.hasPaidAccess,
                            previewQuizUsed: appVM.subscriptionState.previewQuickQuizLimitReached,
                            isRecommended: type == recommendedQuizType,
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

                // Specialty drills section
                VStack(alignment: .leading, spacing: WWSpacing.s) {
                    Text("Specialty Drills")
                        .wwLabel()
                        .textCase(.uppercase)
                        .foregroundColor(.wwTextMuted)

                    CalculationDrillCard(hasPaidAccess: appVM.subscriptionState.hasPaidAccess) {
                        switch vm.startQuiz(.calculationDrill, subscription: appVM.subscriptionState) {
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

                    NavigationLink {
                        FlashcardView()
                            .environment(services)
                            .environment(appVM)
                    } label: {
                        FlashcardOptionCard()
                    }
                    .buttonStyle(.plain)
                }
            }
            .wwScreenPadding()
            .padding(.vertical, WWSpacing.m)
        }
        .background(Color.wwBackground)
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if vm.dashboard.attemptCount > 0 {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        QuizHistoryView()
                    } label: {
                        Label("History", systemImage: "clock.arrow.circlepath")
                            .font(.system(size: 15))
                    }
                }
            }
        }
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
    var isRecommended: Bool = false
    let dashboard: PracticeDashboardSnapshot
    let action: () -> Void

    private var isLocked: Bool {
        if hasPaidAccess {
            return false
        }
        switch type {
        case .quickQuiz:
            return previewQuizUsed
        case .fullPracticeExam, .weakAreaReview, .calculationDrill:
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
                            if isRecommended && !isLocked {
                                Text("Recommended")
                                    .font(WWFont.label(.semibold))
                                    .foregroundColor(.wwBlue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.wwBlueDim)
                                    .clipShape(Capsule())
                            }
                        }
                        Text(detailText)
                            .wwBody(color: .wwTextSecondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(type.bestFor)
                            .wwCaption()
                            .lineLimit(2)
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

    private let allAttempts = PracticeHistoryStore.shared.allAttempts()

    private var overallAccuracy: Int {
        guard !allAttempts.isEmpty else { return 0 }
        let totalCorrect = allAttempts.reduce(0) { $0 + $1.correctCount }
        let totalQuestions = allAttempts.reduce(0) { $0 + $1.totalCount }
        return totalQuestions > 0 ? (totalCorrect * 100) / totalQuestions : 0
    }

    private var bestScore: Int {
        guard !allAttempts.isEmpty else { return 0 }
        return Int((allAttempts.map(\.score).max() ?? 0) * 100)
    }

    private var trendIndicator: String {
        guard allAttempts.count >= 3 else { return "" }
        let recent = Array(allAttempts.prefix(3))
        let older = Array(allAttempts.dropFirst(3).prefix(3))
        guard !older.isEmpty else { return "" }

        let recentAvg = recent.map(\.score).reduce(0, +) / Double(recent.count)
        let olderAvg = older.map(\.score).reduce(0, +) / Double(older.count)

        if recentAvg > olderAvg + 0.05 { return "📈" }
        if recentAvg < olderAvg - 0.05 { return "📉" }
        return "→"
    }

    private var accuracyColor: Color {
        if overallAccuracy >= 80 { return .wwSuccess }
        if overallAccuracy >= 70 { return .wwBlue }
        return .wwError
    }

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                Text("Your Performance")
                    .wwSectionTitle()

                HStack(spacing: WWSpacing.s) {
                    PerformanceMetricPill(
                        value: "\(dashboard.attemptCount)",
                        label: "Quizzes\nCompleted",
                        color: .wwBlue
                    )
                    PerformanceMetricPill(
                        value: "\(overallAccuracy)%",
                        label: "Avg\nAccuracy",
                        color: accuracyColor
                    )
                    PerformanceMetricPill(
                        value: "\(dashboard.weakTopics.count)",
                        label: "Areas\nIdentified",
                        color: dashboard.weakTopics.isEmpty ? .wwSuccess : .wwBlue
                    )
                }

                VStack(alignment: .leading, spacing: WWSpacing.xs) {
                    if !trendIndicator.isEmpty {
                        HStack(spacing: 4) {
                            Text(trendIndicator)
                                .font(.system(size: 14))
                            Text(trendIndicator == "📈" ? "Trending up" : trendIndicator == "📉" ? "Room to improve" : "Consistent performance")
                                .wwCaption(color: .wwTextSecondary)
                        }
                    }

                    if bestScore >= 80 {
                        HStack(spacing: 4) {
                            Text("🏆")
                            Text("Best: \(bestScore)%")
                                .wwCaption(color: .wwTextSecondary)
                        }
                    }
                }
            }
        }
    }
}

private struct PerformanceMetricPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: WWSpacing.xs) {
            Text(value)
                .font(WWFont.heading(.semibold))
                .foregroundColor(color)
            Text(label)
                .wwCaption(color: .wwTextSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, WWSpacing.m)
        .background(Color.wwSurface)
        .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous))
    }
}

// MARK: - Calculation Drill Card

private struct CalculationDrillCard: View {
    let hasPaidAccess: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            WWCard {
                VStack(alignment: .leading, spacing: WWSpacing.m) {
                    HStack(spacing: WWSpacing.m) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(hasPaidAccess ? Color.wwBlueDim : Color.wwSurface)
                                .frame(width: 50, height: 50)
                            Image(systemName: "function")
                                .font(.system(size: 20))
                                .foregroundColor(hasPaidAccess ? .wwBlue : .wwTextMuted)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: WWSpacing.s) {
                                Text("Calculation Drill")
                                    .wwSectionTitle()
                                if !hasPaidAccess {
                                    Image(systemName: "lock")
                                        .font(.system(size: 12))
                                        .foregroundColor(.wwTextMuted)
                                }
                            }
                            Text("15 math problems — load calcs, ampacity, box fill, voltage drop.")
                                .wwBody(color: .wwTextSecondary)
                            Text("Best when math is your weakest pillar")
                                .wwCaption()
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.wwTextMuted)
                    }

                    // Pillar badges
                    HStack(spacing: WWSpacing.s) {
                        ForEach(["Load Calc", "Box Fill", "Ampacity", "Voltage Drop"], id: \.self) { label in
                            Text(label)
                                .font(WWFont.caption(.medium))
                                .foregroundColor(hasPaidAccess ? .wwBlue : .wwTextMuted)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(hasPaidAccess ? Color.wwBlueDim : Color.wwSurface)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(hasPaidAccess ? 1.0 : 0.7)
    }
}

// MARK: - Flashcard Option Card

private struct FlashcardOptionCard: View {
    var body: some View {
        WWCard {
            HStack(spacing: WWSpacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.wwBlueDim)
                        .frame(width: 50, height: 50)
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.wwBlue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Flashcards")
                        .wwSectionTitle()
                    Text("Key terms, definitions, and NEC concepts.")
                        .wwBody(color: .wwTextSecondary)
                    Text("Best for memorizing exam vocabulary")
                        .wwCaption()
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.wwTextMuted)
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
