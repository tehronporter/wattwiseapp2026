import SwiftUI

struct QuizResultsView: View {
    let result: QuizResult
    let quizType: QuizType
    let onRetry: () -> Void
    @State private var expandedQuestion: UUID? = nil
    @Environment(AppViewModel.self) private var appVM
    @Environment(ServiceContainer.self) private var services
    @State private var showTutor = false
    @State private var tutorContext: TutorContext? = nil
    @State private var showPaywall = false
    @State private var paywallContext: PaywallContext = .previewQuizComplete

    private var isPreviewResultsGate: Bool {
        appVM.subscriptionState.hasPaidAccess == false && quizType == .quickQuiz
    }

    var body: some View {
        ScrollView {
            VStack(spacing: WWSpacing.l) {
                // Score Hero
                ScoreHeroView(result: result)

                if isPreviewResultsGate {
                    WWCard {
                        VStack(alignment: .leading, spacing: WWSpacing.m) {
                            Text("Your preview quiz is complete")
                                .wwSectionTitle()
                            Text("Keep the momentum going with full lesson access, more practice, NEC help, and tutor support when you get stuck.")
                                .wwBody(color: .wwTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            WWPrimaryButton(title: "Start Full Prep") {
                                paywallContext = .previewQuizComplete
                                showPaywall = true
                            }
                        }
                    }
                }

                // Action Buttons
                VStack(spacing: WWSpacing.m) {
                    if isPreviewResultsGate {
                        WWSecondaryButton(title: "See Access Options") {
                            paywallContext = .previewQuizComplete
                            showPaywall = true
                        }
                    } else {
                        WWPrimaryButton(title: "Retake Quiz", action: onRetry)
                    }

                    if result.weakTopicDetails.isEmpty == false && appVM.subscriptionState.hasPaidAccess {
                        NavigationLink {
                            QuizContainerView(quizType: .weakAreaReview)
                        } label: {
                            ActionLinkLabel(title: "Review Weak Areas", style: .secondary)
                        }
                        .buttonStyle(.plain)
                    } else if result.weakTopicDetails.isEmpty == false {
                        Button {
                            paywallContext = .weakAreaLocked
                            showPaywall = true
                        } label: {
                            ActionLinkLabel(title: "Review Weak Areas", style: .secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    NavigationLink {
                        LearnView()
                    } label: {
                        ActionLinkLabel(title: "Continue Learning", style: .secondary)
                    }
                    .buttonStyle(.plain)

                    WWGhostButton(title: "Ask Tutor About Results") {
                        tutorContext = TutorContextBuilder.quizReview(result, user: appVM.currentUser)
                        showTutor = true
                    }
                }

                // Weak Topics (if any)
                if result.weakTopicDetails.isEmpty == false {
                    WeakTopicsCard(topics: result.weakTopicDetails)
                }

                // Question Breakdown
                VStack(alignment: .leading, spacing: WWSpacing.m) {
                    Text("Question Breakdown")
                        .wwSectionTitle()

                    ForEach(result.results) { qResult in
                        QuestionResultCard(
                            result: qResult,
                            isExpanded: expandedQuestion == qResult.id
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedQuestion = expandedQuestion == qResult.id ? nil : qResult.id
                            }
                        } onAskTutor: {
                            tutorContext = TutorContextBuilder.quizReview(
                                result,
                                focusedQuestion: qResult,
                                user: appVM.currentUser
                            )
                            showTutor = true
                        }
                    }
                }
            }
            .wwScreenPadding()
            .padding(.vertical, WWSpacing.m)
        }
        .background(Color.wwBackground)
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
    }
}

// MARK: - Score Hero

private struct ScoreHeroView: View {
    let result: QuizResult

    var body: some View {
        WWCard {
            VStack(spacing: WWSpacing.m) {
                // Score circle
                ZStack {
                    Circle()
                        .strokeBorder(Color.wwDivider, lineWidth: 8)
                        .frame(width: 100, height: 100)
                    Circle()
                        .trim(from: 0, to: result.score)
                        .stroke(result.passed ? Color.wwSuccess : Color.wwBlue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.8), value: result.score)
                    Text("\(result.percentage)%")
                        .font(WWFont.subheading(.bold))
                        .foregroundColor(.wwTextPrimary)
                }

                VStack(spacing: WWSpacing.s) {
                    Text(result.passed ? "Nice work!" : "Keep studying")
                        .wwHeading()
                    Text("\(result.correctCount) of \(result.totalCount) correct")
                        .wwBody(color: .wwTextSecondary)
                    if let firstWeakTopic = result.weakTopicDetails.first?.title {
                        Text(result.passed ? "Keep \(firstWeakTopic) fresh in your rotation." : "Review \(firstWeakTopic) first while this quiz is still fresh.")
                            .wwCaption()
                            .multilineTextAlignment(.center)
                    }

                    // Pass/Fail badge
                    Text(result.passed ? "PASSED" : "NEEDS REVIEW")
                        .wwLabel()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(result.passed ? Color.wwSuccess.opacity(0.12) : Color.wwBlue.opacity(0.12))
                        .foregroundColor(result.passed ? .wwSuccess : .wwBlue)
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Weak Topics Card

private struct WeakTopicsCard: View {
    let topics: [WeakTopicDetail]

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                HStack(spacing: WWSpacing.s) {
                    Image(systemName: "chart.bar")
                        .foregroundColor(.wwBlue)
                    Text("Areas to Review")
                        .wwSectionTitle()
                }
                VStack(spacing: WWSpacing.s) {
                    ForEach(topics) { topic in
                        HStack(alignment: .top, spacing: WWSpacing.s) {
                            Text(topic.title)
                                .wwLabel(color: .wwBlue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.wwBlueDim)
                                .clipShape(Capsule())
                            Spacer()
                            Text("\(topic.incorrectCount) miss\(topic.incorrectCount == 1 ? "" : "es")")
                                .wwCaption(color: .wwTextMuted)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Question Result Card

private struct QuestionResultCard: View {
    let result: QuestionResult
    let isExpanded: Bool
    let onToggle: () -> Void
    let onAskTutor: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack(spacing: WWSpacing.m) {
                    Image(systemName: result.isCorrect ? "checkmark.circle" : "xmark.circle")
                        .font(.system(size: 20))
                        .foregroundColor(result.isCorrect ? .wwSuccess : .wwError)

                    Text(result.question)
                        .wwBody()
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.wwTextMuted)
                }
                .padding(WWSpacing.m)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: WWSpacing.m) {
                    WWDivider()

                    // Your answer
                    AnswerLine(
                        label: "Your answer",
                        text: result.userAnswer,
                        isCorrect: result.isCorrect
                    )

                    if !result.isCorrect {
                        AnswerLine(
                            label: "Correct answer",
                            text: result.correctAnswer,
                            isCorrect: true
                        )
                    }

                    // Explanation
                    VStack(alignment: .leading, spacing: WWSpacing.s) {
                        if let referenceCode = result.referenceCode {
                            Text("Reference: \(referenceCode)")
                                .wwCaption(color: .wwBlue)
                        }
                        Text("Explanation")
                            .font(WWFont.caption(.semibold))
                            .foregroundColor(.wwTextSecondary)
                        Text(result.explanation)
                            .wwBody()
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                    }

                    // Ask tutor
                    Button(action: onAskTutor) {
                        Label("Ask Tutor", systemImage: "bubble.left")
                            .font(WWFont.caption(.semibold))
                            .foregroundColor(.wwBlue)
                    }
                }
                .padding(.horizontal, WWSpacing.m)
                .padding(.bottom, WWSpacing.m)
            }
        }
        .background(Color.wwSurface)
        .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous))
    }
}

private struct ActionLinkLabel: View {
    enum Style {
        case primary
        case secondary
    }

    let title: String
    let style: Style

    var body: some View {
        Text(title)
            .font(WWFont.body(.semibold))
            .foregroundColor(style == .primary ? .white : .wwBlue)
            .frame(maxWidth: .infinity)
            .frame(height: WWSpacing.minTapTarget + 4)
            .background(style == .primary ? Color.wwBlue : Color.clear)
            .overlay(
                Capsule()
                    .strokeBorder(style == .primary ? Color.clear : Color.wwBlue, lineWidth: 1.5)
            )
            .clipShape(Capsule())
    }
}

private struct AnswerLine: View {
    let label: String
    let text: String
    let isCorrect: Bool

    var body: some View {
        HStack(alignment: .top, spacing: WWSpacing.s) {
            Text(label + ":")
                .font(WWFont.caption(.medium))
                .foregroundColor(.wwTextMuted)
                .fixedSize()
            Text(text)
                .font(WWFont.caption(.semibold))
                .foregroundColor(isCorrect ? .wwSuccess : .wwError)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}


#Preview {
    NavigationStack {
        QuizResultsView(
            result: QuizResult(
                id: UUID(),
                quizId: UUID(),
                score: 0.7,
                correctCount: 7,
                totalCount: 10,
                results: [],
                weakTopics: ["grounding", "gfci"]
            ),
            quizType: .quickQuiz,
            onRetry: {}
        )
        .environment(AppViewModel())
    }
}
