import SwiftUI
import StoreKit
import UniformTypeIdentifiers

struct QuizResultsView: View {
    let result: QuizResult
    let quizType: QuizType
    let onRetry: () -> Void
    @State private var expandedQuestion: UUID? = nil
    @Environment(AppViewModel.self) private var appVM
    @Environment(ServiceContainer.self) private var services
    @Environment(\.requestReview) private var requestReview
    @Environment(\.dismiss) private var dismiss
    @State private var showTutor = false
    @State private var tutorContext: TutorContext? = nil
    @State private var showPaywall = false
    @State private var paywallContext: PaywallContext = .previewQuizComplete

    private let completedQuizzesKey = "ww_completed_quiz_count"
    private let lastReviewRequestKey = "ww_last_review_request_date"

    private var isPreviewResultsGate: Bool {
        appVM.subscriptionState.hasPaidAccess == false && quizType == .quickQuiz
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: WWSpacing.l) {
                    // Score Hero
                    ScoreHeroView(result: result)

                    // Time analytics — shown for timed sessions (full practice exam, calculation drill)
                    if result.totalElapsedSeconds != nil || result.questionTimesSeconds != nil {
                        TimeAnalyticsCard(result: result, quizType: quizType)
                    }

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

                    // Action Buttons — max 3, Duolingo-style priority order
                    VStack(spacing: WWSpacing.m) {
                        if isPreviewResultsGate {
                            // Preview gate: upsell is already shown above; offer retry
                            WWGhostButton(title: "Try Again", action: onRetry)
                        } else {
                            // 1. Primary: Continue Learning (dismisses quiz flow)
                            WWPrimaryButton(title: "Continue Learning") {
                                dismiss()
                            }

                            // 2. Secondary: Review Mistakes (scrolls to breakdown) — only if not 100%
                            if result.percentage < 100 {
                                Button {
                                    withAnimation { proxy.scrollTo("questionBreakdown", anchor: .top) }
                                } label: {
                                    ActionLinkLabel(title: "Review Mistakes", style: .secondary)
                                }
                                .buttonStyle(.plain)
                            }

                            // 3. Ghost: Try Again
                            WWGhostButton(title: "Try Again", action: onRetry)
                        }

                        // Utility links row
                        HStack(spacing: WWSpacing.l) {
                            Button {
                                tutorContext = TutorContextBuilder.quizReview(result, user: appVM.currentUser)
                                showTutor = true
                            } label: {
                                Text("Ask Tutor About Results")
                                    .font(WWFont.caption(.medium))
                                    .foregroundColor(.wwTextMuted)
                            }

                            if !isPreviewResultsGate {
                                ShareLink(
                                    item: ScoreShareImage(result: result, quizType: quizType),
                                    preview: SharePreview(
                                        "WattWise — \(result.percentage)%",
                                        image: Image(systemName: "bolt.fill")
                                    )
                                ) {
                                    Text("Share Result")
                                        .font(WWFont.caption(.medium))
                                        .foregroundColor(.wwTextMuted)
                                }
                            }
                        }
                    }

                    // Weak Topics (if any)
                    if result.weakTopicDetails.isEmpty == false {
                        WeakTopicsCard(topics: result.weakTopicDetails) { topic in
                            tutorContext = TutorContextBuilder.weakTopicStudy(topic, user: appVM.currentUser)
                            showTutor = true
                        }
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
                    .id("questionBreakdown")
                }
                .wwScreenPadding()
                .padding(.vertical, WWSpacing.m)
            }
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
        .onAppear {
            maybeRequestReview()
        }
    }

    private func maybeRequestReview() {
        guard result.passed else { return }
        let count = UserDefaults.standard.integer(forKey: completedQuizzesKey) + 1
        UserDefaults.standard.set(count, forKey: completedQuizzesKey)
        guard count >= 3 else { return }
        // Rate-limit: don't re-prompt within 60 days of the last request
        let sixtyDays: TimeInterval = 60 * 24 * 60 * 60
        if let last = UserDefaults.standard.object(forKey: lastReviewRequestKey) as? Date,
           Date().timeIntervalSince(last) < sixtyDays { return }
        UserDefaults.standard.set(Date(), forKey: lastReviewRequestKey)
        Task { @MainActor in requestReview() }
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
    let onStudyTopic: (WeakTopicDetail) -> Void

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                HStack(spacing: WWSpacing.s) {
                    Image(systemName: "chart.bar")
                        .foregroundColor(.wwBlue)
                    Text("Areas to Review")
                        .wwSectionTitle()
                }
                Text("Tap a topic to get a focused tutor explanation.")
                    .wwCaption(color: .wwTextSecondary)
                VStack(spacing: WWSpacing.s) {
                    ForEach(topics) { topic in
                        Button {
                            onStudyTopic(topic)
                        } label: {
                            HStack(alignment: .top, spacing: WWSpacing.s) {
                                Text(topic.title)
                                    .wwLabel(color: .wwBlue)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.wwBlueDim)
                                    .clipShape(Capsule())
                                Spacer()
                                HStack(spacing: 4) {
                                    Text("\(topic.incorrectCount) miss\(topic.incorrectCount == 1 ? "" : "es")")
                                        .wwCaption(color: .wwTextMuted)
                                    Image(systemName: "arrow.right.circle")
                                        .font(.system(size: 14))
                                        .foregroundColor(.wwBlue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
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
            // Header — always visible
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: WWSpacing.m) {
                    Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(result.isCorrect ? .wwSuccess : .wwError)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.question)
                            .wwBody()
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let ref = result.referenceCode, !ref.isEmpty {
                            Text("NEC \(ref)")
                                .font(WWFont.caption(.semibold))
                                .foregroundColor(.wwBlue)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.wwBlueDim)
                                .clipShape(Capsule())
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.wwTextMuted)
                        .padding(.top, 3)
                }
                .padding(WWSpacing.m)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: WWSpacing.m) {
                    WWDivider()

                    // Answer summary
                    VStack(alignment: .leading, spacing: WWSpacing.s) {
                        ResultAnswerRow(
                            label: "Your answer",
                            text: result.userAnswer,
                            style: result.isCorrect ? .correct : .wrong
                        )
                        if !result.isCorrect {
                            ResultAnswerRow(
                                label: "Correct answer",
                                text: result.correctAnswer,
                                style: .correct
                            )
                        }
                    }

                    // Explanation
                    VStack(alignment: .leading, spacing: WWSpacing.s) {
                        Text("Why")
                            .font(WWFont.caption(.semibold))
                            .foregroundColor(.wwTextSecondary)
                            .textCase(.uppercase)
                        Text(result.explanation)
                            .wwBody()
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                    }

                    // Ask tutor button
                    Button(action: onAskTutor) {
                        Label("Ask Tutor About This", systemImage: "bubble.left")
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
        .overlay(
            RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous)
                .strokeBorder(
                    result.isCorrect ? Color.wwSuccess.opacity(0.2) : Color.wwError.opacity(0.2),
                    lineWidth: 1
                )
        )
    }
}

private struct ResultAnswerRow: View {
    enum Style { case correct, wrong }
    let label: String
    let text: String
    let style: Style

    private var icon: String { style == .correct ? "checkmark.circle.fill" : "xmark.circle.fill" }
    private var color: Color { style == .correct ? .wwSuccess : .wwError }

    var body: some View {
        HStack(alignment: .top, spacing: WWSpacing.s) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(WWFont.caption(.semibold))
                    .foregroundColor(color)
                Text(text)
                    .wwBody()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(WWSpacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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

// MARK: - Time Analytics Card

private struct TimeAnalyticsCard: View {
    let result: QuizResult
    let quizType: QuizType

    private var totalFormatted: String {
        guard let total = result.totalElapsedSeconds else { return "--" }
        let m = Int(total) / 60
        let s = Int(total) % 60
        return String(format: "%d:%02d", m, s)
    }

    private var avgFormatted: String {
        guard let avg = result.averageSecondsPerQuestion else { return "--" }
        return String(format: "%.0f sec", avg)
    }

    private var paceNote: String {
        guard let avg = result.averageSecondsPerQuestion else { return "" }
        switch avg {
        case ..<60:
            return "Fast pace — make sure you're reading each question fully."
        case 60..<120:
            return "Solid pace. Close to the 1–2 min/question target for real exams."
        default:
            return "Slower pace. Work on recognizing question patterns faster."
        }
    }

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                HStack(spacing: WWSpacing.s) {
                    Image(systemName: "timer")
                        .foregroundColor(.wwBlue)
                    Text("Timing Breakdown")
                        .wwSectionTitle()
                }

                HStack(spacing: WWSpacing.l) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Time")
                            .wwCaption(color: .wwTextSecondary)
                        Text(totalFormatted)
                            .wwSubheading()
                    }
                    Divider().frame(height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Avg / Question")
                            .wwCaption(color: .wwTextSecondary)
                        Text(avgFormatted)
                            .wwSubheading()
                    }
                    Spacer()
                }

                if !paceNote.isEmpty {
                    Text(paceNote)
                        .wwCaption(color: .wwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Score Share Card (Transferable for ShareLink)

struct ScoreShareImage: Transferable {
    let result: QuizResult
    let quizType: QuizType

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            try await MainActor.run {
                let renderer = ImageRenderer(content: item.cardView)
                renderer.scale = 3
                guard let uiImage = renderer.uiImage,
                      let data = uiImage.pngData() else {
                    throw AppError.unknown
                }
                return data
            }
        }
    }

    @ViewBuilder
    var cardView: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#2E53FF"))
                Text("WattWise")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
            }

            VStack(spacing: 8) {
                Text("\(result.percentage)%")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundColor(result.passed ? Color(hex: "#22C55E") : Color(hex: "#2E53FF"))
                Text("\(result.correctCount) of \(result.totalCount) correct")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                Text(quizType.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Text(result.passed ? "Passed ✓" : "Keep Studying")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(result.passed ? Color(hex: "#22C55E") : Color(hex: "#2E53FF"))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        result.passed
                            ? Color(hex: "#22C55E").opacity(0.12)
                            : Color(hex: "#2E53FF").opacity(0.12)
                    )
                )
        }
        .padding(32)
        .frame(width: 320)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
