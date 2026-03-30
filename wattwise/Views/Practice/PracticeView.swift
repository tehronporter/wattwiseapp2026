import SwiftUI

struct PracticeView: View {
    @State private var vm = PracticeViewModel()
    @State private var quizVM = QuizViewModel()
    @State private var navigateToQuiz = false
    @State private var activeQuizType: QuizType?
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WWSpacing.l) {
                Text("Test your knowledge and track your weak areas.")
                    .wwBody(color: .wwTextSecondary)

                ForEach(QuizType.allCases, id: \.self) { type in
                    QuizOptionCard(
                        type: type,
                        isPro: appVM.subscriptionState.isPro
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
    }
}

// MARK: - Quiz Option Card

private struct QuizOptionCard: View {
    let type: QuizType
    let isPro: Bool
    let action: () -> Void

    private var isLocked: Bool {
        type == .fullPracticeExam && !isPro
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
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.wwTextMuted)
                            }
                        }
                        Text(type.description)
                            .wwBody(color: .wwTextSecondary)
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

#Preview {
    NavigationStack {
        PracticeView()
            .environment(ServiceContainer())
            .environment(AppViewModel())
    }
}
