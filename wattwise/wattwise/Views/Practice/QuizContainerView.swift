import SwiftUI

// Container that manages the quiz flow: Loading → Active Quiz → Celebration → Results
struct QuizContainerView: View {
    let quizType: QuizType
    var topicTags: [String] = []
    @State private var vm = QuizViewModel()
    @State private var showPaywall = false
    @State private var showCelebration = false
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if vm.shouldShowLoadingState {
                QuizLoadingView(message: "Preparing your quiz…")
            } else if let accessRestriction = vm.accessRestriction {
                QuizAccessRestrictedView(
                    title: quizType == .quickQuiz ? "Practice limit reached" : quizType.displayName,
                    message: accessRestriction.message,
                    actionTitle: "See Access Options"
                ) {
                    showPaywall = true
                } onSecondary: {
                    dismiss()
                }
            } else if let result = vm.result, !showCelebration {
                QuizResultsView(result: result, quizType: quizType) {
                    vm.reset()
                    Task { await vm.loadIfNeeded(type: quizType, examType: appVM.currentUser?.examType, topicTags: topicTags, services: services) }
                }
            } else if let quiz = vm.quiz, quiz.questions.isEmpty == false {
                ActiveQuizView(vm: vm, quizType: quizType)
            } else if let error = vm.errorMessage {
                WWEmptyState(icon: "exclamationmark.triangle", title: "Couldn't load quiz", message: error, actionTitle: "Retry") {
                    vm.reset()
                    Task { await vm.loadIfNeeded(type: quizType, examType: appVM.currentUser?.examType, topicTags: topicTags, services: services) }
                }
            } else {
                WWEmptyState(
                    icon: "list.bullet.clipboard",
                    title: "Quiz unavailable",
                    message: "This quiz couldn't be prepared safely. Please go back and try again."
                )
            }
        }
        .background(Color.wwBackground)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle(quizType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(vm.quiz != nil && vm.result == nil)
        .toolbar {
            if vm.quiz != nil && vm.result == nil {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        vm.showExitAlert = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.wwTextSecondary)
                    }
                }
            }
        }
        .alert("Exit Quiz?", isPresented: $vm.showExitAlert) {
            Button("Exit", role: .destructive) { dismiss() }
            Button("Continue", role: .cancel) {}
        } message: {
            Text("Your progress will be lost.")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: vm.accessRestriction?.context ?? quizType.paywallContext)
                .environment(services)
                .environment(appVM)
        }
        .task { await vm.loadIfNeeded(type: quizType, examType: appVM.currentUser?.examType, topicTags: topicTags, services: services) }
        .onChange(of: vm.result?.id) { _, newResultID in
            guard newResultID != nil else { return }
            showCelebration = true
        }
        .fullScreenCover(isPresented: $showCelebration) {
            if let result = vm.result {
                WWCelebrationOverlay(
                    headline: result.passed ? "Quiz Complete!" : "Quiz Done!",
                    xpEarned: result.xpEarned,
                    streakDays: appVM.currentUser?.streakDays ?? 0,
                    accuracyPercent: result.percentage,
                    onContinue: { showCelebration = false }
                )
            }
        }
    }
}

// MARK: - Active Quiz

private struct ActiveQuizView: View {
    @Bindable var vm: QuizViewModel
    let quizType: QuizType
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer? = nil
    @State private var hasAutoSubmitted: Bool = false
    @State private var showXPFloat: Bool = false
    @State private var lastRevealedCorrect: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            VStack(spacing: WWSpacing.s) {
                WWProgressBar(value: vm.progress, height: 4)
                HStack {
                    Text("Question \(vm.currentIndex + 1) of \(vm.quiz?.questions.count ?? 0)")
                        .wwCaption()
                    Spacer()
                    if quizType.isTimedSession {
                        TimerBadge(
                            elapsedSeconds: elapsedSeconds,
                            totalSeconds: vm.quiz?.timeLimitSeconds
                        )
                    } else if let q = vm.currentQuestion {
                        QuestionMetaBadges(question: q)
                    }
                    if quizType.isTimedSession, let q = vm.currentQuestion {
                        QuestionMetaBadges(question: q)
                    }
                }
            }
            .wwScreenPadding()
            .padding(.top, WWSpacing.s)
            .onAppear {
                guard quizType.isTimedSession else { return }
                let limit = vm.quiz?.timeLimitSeconds
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    elapsedSeconds += 1
                    if let limit,
                       elapsedSeconds >= limit,
                       hasAutoSubmitted == false {
                        hasAutoSubmitted = true
                        Task { await vm.submit(services: services, appVM: appVM) }
                    }
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }

            ScrollView {
                if let question = vm.currentQuestion {
                    let revealed = vm.revealedQuestions.contains(question.id)
                    let selectedKey = vm.answers[question.id]

                    VStack(alignment: .leading, spacing: WWSpacing.l) {
                        // Question text
                        Text(question.question)
                            .wwSubheading()
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)

                        // Answer choices
                        ZStack(alignment: .topTrailing) {
                            VStack(spacing: WWSpacing.s) {
                                ForEach(["A", "B", "C", "D"], id: \.self) { key in
                                    if let choice = question.choices[key] {
                                        AnswerOption(
                                            key: key,
                                            text: choice,
                                            selectedKey: selectedKey,
                                            correctKey: revealed ? question.correctChoice : nil,
                                            isLocked: revealed,
                                            isShaking: !revealed && selectedKey == key
                                        ) {
                                            guard !revealed else { return }
                                            vm.selectAnswer(key)
                                            let isCorrect = key == question.correctChoice
                                            lastRevealedCorrect = isCorrect
                                            if isCorrect {
                                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                                withAnimation(.easeOut(duration: 0.5)) { showXPFloat = true }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                                    showXPFloat = false
                                                }
                                            } else {
                                                UINotificationFeedbackGenerator().notificationOccurred(.error)
                                            }
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                _ = vm.revealedQuestions.insert(question.id)
                                            }
                                        }
                                    }
                                }
                            }

                            // Floating "+10 XP" badge on correct answer
                            if showXPFloat {
                                Text("+\(WWGamification.XP.quizAttempt) XP")
                                    .font(WWFont.caption(.bold))
                                    .foregroundColor(.wwSuccess)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.wwSuccess.opacity(0.12))
                                    .clipShape(Capsule())
                                    .offset(y: showXPFloat ? -28 : 0)
                                    .opacity(showXPFloat ? 1 : 0)
                                    .animation(.easeOut(duration: 0.5), value: showXPFloat)
                                    .allowsHitTesting(false)
                            }
                        }

                        // Feedback panel — appears after reveal
                        if revealed {
                            FeedbackPanel(
                                isCorrect: selectedKey == question.correctChoice,
                                explanation: question.explanation,
                                referenceCode: question.referenceCode
                            )
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .wwScreenPadding()
                    .padding(.vertical, WWSpacing.l)
                }
            }

            // Navigation footer
            let revealed = vm.currentQuestion.map { vm.revealedQuestions.contains($0.id) } ?? false
            HStack(spacing: WWSpacing.m) {
                if vm.isLastQuestion {
                    WWPrimaryButton(
                        title: revealed ? "Submit Quiz" : "Check Answer",
                        isLoading: vm.isSubmitting,
                        isDisabled: vm.answers[vm.currentQuestion?.id ?? UUID()] == nil && !revealed
                    ) {
                        if revealed {
                            Task { await vm.submit(services: services, appVM: appVM) }
                        } else if let q = vm.currentQuestion, vm.answers[q.id] != nil {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                _ = vm.revealedQuestions.insert(q.id)
                            }
                        }
                    }
                } else {
                    if revealed {
                        WWPrimaryButton(title: "Next Question") { vm.next() }
                    } else {
                        WWPrimaryButton(
                            title: "Check Answer",
                            isDisabled: vm.answers[vm.currentQuestion?.id ?? UUID()] == nil
                        ) {
                            if let q = vm.currentQuestion, vm.answers[q.id] != nil {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    _ = vm.revealedQuestions.insert(q.id)
                                }
                            }
                        }
                    }
                }
            }
            .wwScreenPadding()
            .padding(.vertical, WWSpacing.m)
        }
    }
}

// MARK: - Timer Badge

private struct TimerBadge: View {
    let elapsedSeconds: Int
    let totalSeconds: Int?

    private var displaySeconds: Int {
        if let totalSeconds {
            return max(0, totalSeconds - elapsedSeconds)
        }
        return elapsedSeconds
    }

    private var formatted: String {
        let m = displaySeconds / 60
        let s = displaySeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private var isWarning: Bool {
        guard let totalSeconds else { return elapsedSeconds >= 3600 }
        let remaining = max(0, totalSeconds - elapsedSeconds)
        return remaining <= 600
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .font(.system(size: 11))
            Text(formatted)
                .font(WWFont.caption(.semibold))
        }
        .foregroundColor(isWarning ? .wwError : .wwTextSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(isWarning ? Color.wwError.opacity(0.08) : Color.wwSurface)
        .clipShape(Capsule())
    }
}

// MARK: - Question Meta Badges

private struct QuestionMetaBadges: View {
    let question: QuizQuestion

    private var difficultyColor: Color {
        switch question.difficultyLevel?.lowercased() {
        case "hard":   return .wwError
        case "medium": return .wwWarning
        default:       return .wwTextMuted
        }
    }

    var body: some View {
        HStack(spacing: WWSpacing.s) {
            if let ref = question.referenceCode, !ref.isEmpty {
                Text("NEC \(ref)")
                    .font(WWFont.caption(.semibold))
                    .foregroundColor(.wwBlue)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.wwBlueDim)
                    .clipShape(Capsule())
            }
            if let diff = question.difficultyLevel {
                Text(diff)
                    .font(WWFont.caption(.medium))
                    .foregroundColor(difficultyColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(difficultyColor.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Feedback Panel

private struct FeedbackPanel: View {
    let isCorrect: Bool
    let explanation: String
    let referenceCode: String?

    var body: some View {
        VStack(alignment: .leading, spacing: WWSpacing.s) {
            HStack(spacing: WWSpacing.s) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(isCorrect ? .wwSuccess : .wwError)
                Text(isCorrect ? "Correct!" : "Incorrect")
                    .font(WWFont.body(.semibold))
                    .foregroundColor(isCorrect ? .wwSuccess : .wwError)
                Spacer()
                if let ref = referenceCode, !ref.isEmpty {
                    Text("NEC \(ref)")
                        .font(WWFont.caption(.medium))
                        .foregroundColor(.wwBlue)
                }
            }
            Text(explanation)
                .wwBody(color: .wwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding(WWSpacing.m)
        .background(isCorrect ? Color.wwSuccess.opacity(0.07) : Color.wwError.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous)
                .strokeBorder(
                    isCorrect ? Color.wwSuccess.opacity(0.3) : Color.wwError.opacity(0.3),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Shake Effect Modifier

private struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        let bounce = sin(animatableData * .pi * 4) * 6
        return ProjectionTransform(CGAffineTransform(translationX: bounce, y: 0))
    }
}

// MARK: - Answer Option

private struct AnswerOption: View {
    let key: String
    let text: String
    let selectedKey: String?     // nil = nothing selected yet
    let correctKey: String?      // nil = not yet revealed
    let isLocked: Bool
    var isShaking: Bool = false
    let action: () -> Void

    @State private var shakeCount: CGFloat = 0

    private var isSelected: Bool { selectedKey == key }
    private var isCorrect: Bool { correctKey == key }
    private var isWrongSelected: Bool { isSelected && correctKey != nil && !isCorrect }

    private var bgColor: Color {
        if correctKey != nil {
            if isCorrect { return Color.wwSuccess.opacity(0.1) }
            if isWrongSelected { return Color.wwError.opacity(0.1) }
        }
        return isSelected ? Color.wwBlueDim : Color.wwSurface
    }

    private var borderColor: Color {
        if correctKey != nil {
            if isCorrect { return Color.wwSuccess }
            if isWrongSelected { return Color.wwError }
        }
        return isSelected ? Color.wwBlue : Color.clear
    }

    private var keyCircleBackground: Color {
        if correctKey != nil {
            if isCorrect { return .wwSuccess }
            if isWrongSelected { return .wwError }
        }
        return isSelected ? .wwBlue : .clear
    }

    private var keyCircleForeground: Color {
        if correctKey != nil && (isCorrect || isWrongSelected) { return .white }
        return isSelected ? .white : .wwTextSecondary
    }

    private var trailingIcon: String? {
        guard correctKey != nil else { return nil }
        if isCorrect { return "checkmark" }
        if isWrongSelected { return "xmark" }
        return nil
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: WWSpacing.m) {
                ZStack {
                    Circle()
                        .strokeBorder(borderColor == .clear ? Color.wwDivider : borderColor, lineWidth: 1.5)
                        .background(Circle().fill(keyCircleBackground))
                        .frame(width: 30, height: 30)
                    Text(key)
                        .font(WWFont.caption(.semibold))
                        .foregroundColor(keyCircleForeground)
                }

                Text(text)
                    .wwBody()
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                if let icon = trailingIcon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isCorrect ? .wwSuccess : .wwError)
                }
            }
            .padding(WWSpacing.m)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.2), value: correctKey)
            .modifier(ShakeEffect(animatableData: shakeCount))
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .onChange(of: isShaking) { _, shaking in
            guard shaking, isWrongSelected else { return }
            withAnimation(.linear(duration: 0.35)) {
                shakeCount += 1
            }
        }
    }
}

// MARK: - Loading View

private struct QuizLoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: WWSpacing.l) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .wwBody(color: .wwTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct QuizAccessRestrictedView: View {
    let title: String
    let message: String
    let actionTitle: String
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    var body: some View {
        VStack(spacing: WWSpacing.l) {
            WWEmptyState(
                icon: "lock",
                title: title,
                message: message,
                actionTitle: actionTitle,
                action: onPrimary
            )

            WWSecondaryButton(title: "Back", action: onSecondary)
                .frame(maxWidth: 240)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
