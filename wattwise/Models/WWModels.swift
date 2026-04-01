import Foundation

// MARK: - Common

enum LoadState<T> {
    case idle
    case loading
    case loaded(T)
    case failed(String)

    var isLoading: Bool { if case .loading = self { return true }; return false }
    var value: T? { if case .loaded(let v) = self { return v }; return nil }
    var errorMessage: String? { if case .failed(let m) = self { return m }; return nil }
}

enum ExamType: String, CaseIterable, Codable, Identifiable {
    case apprentice = "apprentice"
    case master = "master"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .apprentice: return "Apprentice"
        case .master: return "Master"
        }
    }
    var description: String {
        switch self {
        case .apprentice: return "Foundational trade knowledge, safety, tools, and basic code navigation."
        case .master: return "Advanced design, service sizing, interpretation, and complex systems."
        }
    }
}

extension ExamType {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).lowercased()
        self = ExamType(rawValue: rawValue) ?? .apprentice
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum StudyGoal: String, CaseIterable, Codable, Identifiable {
    case casual = "15"
    case moderate = "30"
    case intensive = "60"
    var id: String { rawValue }
    var minutes: Int { Int(rawValue) ?? 30 }
    var displayName: String {
        switch self {
        case .casual: return "Casual (15 min/day)"
        case .moderate: return "Moderate (30 min/day)"
        case .intensive: return "Intensive (60 min/day)"
        }
    }
}

// MARK: - User

struct WWUser: Codable, Identifiable {
    let id: UUID
    var email: String
    var displayName: String?
    var examType: ExamType
    var state: String
    var studyGoal: StudyGoal
    var streakDays: Int
    var isOnboardingComplete: Bool

    static let guest = WWUser(
        id: UUID(),
        email: "",
        displayName: nil,
        examType: .apprentice,
        state: "",
        studyGoal: .moderate,
        streakDays: 0,
        isOnboardingComplete: false
    )
}

// MARK: - Content / Modules

struct WWModule: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var lessonCount: Int
    var estimatedMinutes: Int
    var topicTags: [String]
    var progress: Double         // 0.0–1.0
    var lessons: [WWLesson]

    var completedLessons: Int {
        lessons.filter { $0.status == .completed }.count
    }
}

struct WWLesson: Identifiable, Codable {
    let id: UUID
    var moduleId: UUID
    var title: String
    var topic: String
    var estimatedMinutes: Int
    var status: LessonStatus
    var completionPercentage: Double
    var sections: [LessonSection]
    var necReferences: [NECReference]

    enum LessonStatus: String, Codable {
        case notStarted = "not_started"
        case inProgress = "in_progress"
        case completed
    }
}

struct LessonSection: Identifiable, Codable {
    let id: UUID
    var heading: String?
    var body: String
    var type: SectionType
    var necCode: String?

    enum SectionType: String, Codable {
        case paragraph, heading, bullet, callout, necCallout
    }
}

// MARK: - NEC

struct NECReference: Identifiable, Codable {
    let id: UUID
    var code: String      // e.g. "210.8"
    var title: String
    var summary: String
    var expanded: String?
}

struct NECSearchResult: Identifiable, Codable {
    let id: UUID
    var code: String
    var title: String
    var summary: String
}

// MARK: - Quiz

enum QuizType: String, Codable, CaseIterable {
    case quickQuiz = "quick_quiz"
    case fullPracticeExam = "full_practice_exam"
    case weakAreaReview = "weak_area_review"

    var displayName: String {
        switch self {
        case .quickQuiz: return "Quick Quiz"
        case .fullPracticeExam: return "Full Practice Exam"
        case .weakAreaReview: return "Review Weak Areas"
        }
    }
    var description: String {
        switch self {
        case .quickQuiz: return "A short check-in to keep your study streak moving."
        case .fullPracticeExam: return "A longer exam-style session for serious review."
        case .weakAreaReview: return "Targeted practice focused on the concepts you miss most."
        }
    }
    var bestFor: String {
        switch self {
        case .quickQuiz: return "Best for a fast refresher between lessons"
        case .fullPracticeExam: return "Best for a focused practice block"
        case .weakAreaReview: return "Best after results show weak spots"
        }
    }
    var icon: String {
        switch self {
        case .quickQuiz: return "bolt"
        case .fullPracticeExam: return "doc.text"
        case .weakAreaReview: return "chart.bar"
        }
    }
    var questionCount: Int {
        switch self {
        case .quickQuiz: return 10
        case .fullPracticeExam: return 25
        case .weakAreaReview: return 10
        }
    }

    var progressLabel: String {
        switch self {
        case .quickQuiz: return "Short daily check-in"
        case .fullPracticeExam: return "Exam-style mixed assessment"
        case .weakAreaReview: return "Targeted follow-up drill"
        }
    }
}

struct WWQuiz: Identifiable, Codable {
    let id: UUID
    var type: QuizType
    var questions: [QuizQuestion]
}

struct QuizQuestion: Identifiable, Codable {
    let id: UUID
    var question: String
    var choices: [String: String]  // ["A": "...", "B": "...", "C": "...", "D": "..."]
    var correctChoice: String      // "A", "B", "C", or "D"
    var explanation: String
    var topics: [String]
    var topicTitles: [String] = []
    var difficultyLevel: String? = nil
    var referenceCode: String? = nil
    var certificationLevel: String? = nil
}

struct QuizAnswer: Codable {
    var questionId: UUID
    var selected: String
}

struct QuizResult: Identifiable, Codable {
    let id: UUID
    var quizId: UUID
    var score: Double              // 0.0–1.0
    var correctCount: Int
    var totalCount: Int
    var results: [QuestionResult]
    var weakTopics: [String]
    var weakTopicDetails: [WeakTopicDetail] = []
    var completedAt: Date = Date()

    var passed: Bool { score >= 0.7 }
    var percentage: Int { Int(score * 100) }
}

struct QuestionResult: Identifiable, Codable {
    let id: UUID
    var questionId: UUID
    var question: String
    var userAnswer: String
    var correctAnswer: String
    var explanation: String
    var isCorrect: Bool
    var topics: [String] = []
    var topicTitles: [String] = []
    var referenceCode: String? = nil
}

struct WeakTopicDetail: Identifiable, Codable {
    var id: String { key }
    var key: String
    var title: String
    var incorrectCount: Int
    var attemptedCount: Int

    var accuracy: Double {
        guard attemptedCount > 0 else { return 0 }
        return Double(attemptedCount - incorrectCount) / Double(attemptedCount)
    }
}

// MARK: - Tutor

struct TutorMessage: Identifiable, Codable {
    let id: UUID
    var content: String
    var role: Role
    var timestamp: Date
    var steps: [String]?
    var followUps: [String]?

    enum Role: String, Codable { case user, assistant }
}

enum TutorContextType: String, Codable {
    case general, lesson, quizReview, necDetail
}

struct TutorContext: Codable {
    var type: TutorContextType
    var id: UUID?
    var excerpt: String?
}

// MARK: - Progress

struct ProgressSummary: Codable {
    var continueLearning: ContinueLearning?
    var dailyGoal: DailyGoal
    var streakDays: Int
    var recommendedAction: String?
    var hasStartedContent: Bool = false
    var lastActivityAt: Date? = nil

    var hasInProgressLesson: Bool {
        guard let continueLearning else { return false }
        return continueLearning.progress > 0 && continueLearning.progress < 1
    }

    struct ContinueLearning: Codable {
        var lessonId: UUID
        var lessonTitle: String
        var progress: Double
        var moduleTitle: String
    }

    struct DailyGoal: Codable {
        var minutesCompleted: Int
        var targetMinutes: Int
        var progress: Double { Double(minutesCompleted) / Double(max(1, targetMinutes)) }
    }
}

// MARK: - Subscription

enum SubscriptionTier: String, Codable {
    case free, pro
}

struct SubscriptionState: Codable {
    var tier: SubscriptionTier
    var status: String        // "active", "expired", "none"
    var expiresAt: Date?
    var dailyTutorMessagesUsed: Int
    var dailyTutorMessagesLimit: Int  // -1 = unlimited

    var isPro: Bool { tier == .pro }
    var tutorLimitReached: Bool {
        guard dailyTutorMessagesLimit != -1 else { return false }
        return dailyTutorMessagesUsed >= dailyTutorMessagesLimit
    }
    var tutorMessagesRemaining: Int {
        guard dailyTutorMessagesLimit != -1 else { return Int.max }
        return max(0, dailyTutorMessagesLimit - dailyTutorMessagesUsed)
    }

    static let freeTier = SubscriptionState(
        tier: .free,
        status: "active",
        expiresAt: nil,
        dailyTutorMessagesUsed: 0,
        dailyTutorMessagesLimit: 5
    )

    static let proTier = SubscriptionState(
        tier: .pro,
        status: "active",
        expiresAt: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
        dailyTutorMessagesUsed: 0,
        dailyTutorMessagesLimit: -1
    )
}
