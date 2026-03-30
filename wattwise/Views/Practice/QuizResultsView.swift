import SwiftUI

struct QuizResultsView: View {
    let result: QuizResult
    let quizType: QuizType
    let onRetry: () -> Void
    @State private var expandedQuestion: UUID? = nil
    @Environment(AppViewModel.self) private var appVM
    @State private var showTutor = false
    @State private var tutorContext: TutorContext? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: WWSpacing.l) {
                // Score Hero
                ScoreHeroView(result: result)

                // Action Buttons
                VStack(spacing: WWSpacing.m) {
                    WWPrimaryButton(title: "Retry Quiz", action: onRetry)

                    if !result.weakTopics.isEmpty {
                        WWSecondaryButton(title: "Study Weak Topics") {
                            // Navigate to learn with weak topics
                        }
                    }

                    WWGhostButton(title: "Ask Tutor About Results") {
                        tutorContext = TutorContext(type: .quizReview, id: result.id)
                        showTutor = true
                    }
                }

                // Weak Topics (if any)
                if !result.weakTopics.isEmpty {
                    WeakTopicsCard(topics: result.weakTopics)
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
                            tutorContext = TutorContext(type: .quizReview, id: result.id)
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
    let topics: [String]

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                HStack(spacing: WWSpacing.s) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.wwBlue)
                    Text("Areas to Review")
                        .wwSectionTitle()
                }
                // Use adaptive grid instead of broken fixed-height FlowLayout
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90, maximum: 200), spacing: WWSpacing.s)], spacing: WWSpacing.s) {
                    ForEach(topics, id: \.self) { topic in
                        Text(topic)
                            .wwLabel(color: .wwBlue)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.wwBlueDim)
                            .clipShape(Capsule())
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
                    Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
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
