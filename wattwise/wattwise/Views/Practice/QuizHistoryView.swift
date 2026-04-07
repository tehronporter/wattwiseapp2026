import SwiftUI

struct QuizHistoryView: View {
    private let attempts: [PracticeAttemptSummary]

    init() {
        self.attempts = PracticeHistoryStore.shared.allAttempts()
    }

    var body: some View {
        Group {
            if attempts.isEmpty {
                WWEmptyState(
                    icon: "clock.arrow.circlepath",
                    title: "No quiz history yet",
                    message: "Complete a quiz and your results will appear here."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: WWSpacing.m) {
                        ScoreTrendCard(attempts: attempts)
                        ForEach(attempts) { attempt in
                            AttemptRow(attempt: attempt)
                        }
                    }
                    .wwScreenPadding()
                    .padding(.vertical, WWSpacing.m)
                }
            }
        }
        .background(Color.wwBackground)
        .navigationTitle("Quiz History")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Score Trend Card

private struct ScoreTrendCard: View {
    let attempts: [PracticeAttemptSummary]

    private var recentAttempts: [PracticeAttemptSummary] {
        Array(attempts.prefix(10).reversed())
    }

    private var averageScore: Int {
        guard !attempts.isEmpty else { return 0 }
        let sum = attempts.prefix(10).reduce(0.0) { $0 + $1.score }
        return Int((sum / Double(min(attempts.count, 10))) * 100)
    }

    private var trend: String {
        guard attempts.count >= 3 else { return "Keep going" }
        let recent = attempts.prefix(3).map(\.score)
        let older = attempts.dropFirst(3).prefix(3).map(\.score)
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let olderAvg = older.isEmpty ? recentAvg : older.reduce(0, +) / Double(older.count)
        if recentAvg > olderAvg + 0.05 { return "Improving" }
        if recentAvg < olderAvg - 0.05 { return "Review needed" }
        return "Consistent"
    }

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Score Trend")
                            .wwLabel()
                            .textCase(.uppercase)
                        Text("\(averageScore)% avg (last \(min(attempts.count, 10)))")
                            .wwSectionTitle()
                    }
                    Spacer()
                    Text(trend)
                        .wwLabel()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.wwBlueDim)
                        .foregroundColor(.wwBlue)
                        .clipShape(Capsule())
                }

                if recentAttempts.count >= 2 {
                    GeometryReader { geo in
                        let maxScore = recentAttempts.map(\.score).max() ?? 1
                        let minScore = min(recentAttempts.map(\.score).min() ?? 0, 0.5)
                        let range = max(maxScore - minScore, 0.1)
                        let width = geo.size.width
                        let height = geo.size.height
                        let stepX = width / CGFloat(recentAttempts.count - 1)

                        ZStack {
                            // Grid line at 70% pass mark
                            let passY = height - (height * CGFloat((0.7 - minScore) / range))
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: passY))
                                path.addLine(to: CGPoint(x: width, y: passY))
                            }
                            .stroke(Color.wwDivider, style: StrokeStyle(lineWidth: 1, dash: [4]))

                            Text("70%")
                                .font(WWFont.caption())
                                .foregroundColor(.wwTextMuted)
                                .position(x: 18, y: passY - 8)

                            // Score line
                            Path { path in
                                for (i, attempt) in recentAttempts.enumerated() {
                                    let x = CGFloat(i) * stepX
                                    let y = height - (height * CGFloat((attempt.score - minScore) / range))
                                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                                }
                            }
                            .stroke(Color.wwBlue, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                            // Dots
                            ForEach(Array(recentAttempts.enumerated()), id: \.element.id) { i, attempt in
                                let x = CGFloat(i) * stepX
                                let y = height - (height * CGFloat((attempt.score - minScore) / range))
                                Circle()
                                    .fill(attempt.passed ? Color.wwBlue : Color.wwError)
                                    .frame(width: 8, height: 8)
                                    .position(x: x, y: y)
                            }
                        }
                    }
                    .frame(height: 80)
                }
            }
        }
    }
}

// MARK: - Attempt Row

private struct AttemptRow: View {
    let attempt: PracticeAttemptSummary

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: attempt.completedAt, relativeTo: Date())
    }

    var body: some View {
        WWCard {
            HStack(spacing: WWSpacing.m) {
                // Score circle
                ZStack {
                    Circle()
                        .strokeBorder(attempt.passed ? Color.wwSuccess.opacity(0.3) : Color.wwError.opacity(0.3), lineWidth: 2)
                        .frame(width: 52, height: 52)
                    VStack(spacing: 0) {
                        Text("\(attempt.percentage)%")
                            .font(WWFont.sectionTitle(.bold))
                            .foregroundColor(attempt.passed ? .wwSuccess : .wwError)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(attempt.quizType.displayName)
                        .wwBody()
                    Text("\(attempt.correctCount)/\(attempt.totalCount) correct • \(relativeDate)")
                        .wwCaption(color: .wwTextMuted)
                }

                Spacer()

                Text(attempt.passed ? "Passed" : "Review")
                    .wwLabel()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(attempt.passed ? Color.wwSuccess.opacity(0.1) : Color.wwError.opacity(0.1))
                    .foregroundColor(attempt.passed ? .wwSuccess : .wwError)
                    .clipShape(Capsule())
            }
        }
    }
}
