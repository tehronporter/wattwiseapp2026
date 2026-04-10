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
    case journeyman = "journeyman"
    case master = "master"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .apprentice: return "Apprentice"
        case .journeyman: return "Journeyman"
        case .master: return "Master"
        }
    }
    var description: String {
        switch self {
        case .apprentice: return "Foundational trade knowledge, safety, tools, and basic code navigation."
        case .journeyman: return "Intermediate wiring methods, load calculations, and code application on real installations."
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
    var examDate: Date? = nil
    var totalXP: Int = 0

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

extension WWUser {
    func updating(
        displayName: String?,
        examType: ExamType,
        state: String,
        studyGoal: StudyGoal
    ) -> WWUser {
        var copy = self
        copy.displayName = displayName ?? copy.displayName
        copy.examType = examType
        copy.state = state
        copy.studyGoal = studyGoal
        copy.isOnboardingComplete = state.isEmpty == false
        return copy
    }

    /// Days remaining until the exam, or nil if no date is set or date has passed.
    var daysUntilExam: Int? {
        guard let examDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: examDate)).day ?? 0
        return days > 0 ? days : nil
    }
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
        case paragraph, heading, bullet, callout, necCallout, examTrap
    }
}

// MARK: - NEC

struct NECReference: Identifiable, Codable {
    let id: UUID
    var code: String      // e.g. "210.8"
    var title: String
    var summary: String
    var expanded: String?
    var edition: String?  // e.g. "2023"
}

struct NECSearchResult: Identifiable, Codable {
    let id: UUID
    var code: String
    var title: String
    var summary: String
    var edition: String?  // e.g. "2023"
}

struct NECStateAmendment: Identifiable, Codable {
    let id: UUID
    var type: String          // "addition" | "modification" | "deletion" | "stricter"
    var summary: String
    var effectiveDate: String?
    var source: String?

    var typeLabel: String {
        switch type {
        case "stricter":    return "Stricter"
        case "addition":    return "Added"
        case "modification": return "Modified"
        case "deletion":    return "Removed"
        default:            return type.capitalized
        }
    }
}

struct NECAmendmentsResult {
    var jurisdictionCode: String
    var adoptedEdition: String
    var adoptionNotes: String?
    var amendments: [NECStateAmendment]
}

// MARK: - Quiz

enum QuizType: String, Codable, CaseIterable, Identifiable {
    case quickQuiz = "quick_quiz"
    case fullPracticeExam = "full_practice_exam"
    case weakAreaReview = "weak_area_review"
    case calculationDrill = "calculation_drill"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quickQuiz: return "Quick Quiz"
        case .fullPracticeExam: return "Full Practice Exam"
        case .weakAreaReview: return "Review Weak Areas"
        case .calculationDrill: return "Calculation Drill"
        }
    }
    var description: String {
        switch self {
        case .quickQuiz: return "A short check-in to keep your study streak moving."
        case .fullPracticeExam: return "A longer exam-style session for serious review."
        case .weakAreaReview: return "Targeted practice focused on the concepts you miss most."
        case .calculationDrill: return "Step-by-step math drills: load calculations, ampacity, box fill, and voltage drop."
        }
    }
    var bestFor: String {
        switch self {
        case .quickQuiz: return "Best for a fast refresher between lessons"
        case .fullPracticeExam: return "Best for a focused practice block"
        case .weakAreaReview: return "Best after results show weak spots"
        case .calculationDrill: return "Best when math is your weakest pillar"
        }
    }
    var icon: String {
        switch self {
        case .quickQuiz: return "bolt"
        case .fullPracticeExam: return "doc.text"
        case .weakAreaReview: return "chart.bar"
        case .calculationDrill: return "function"
        }
    }
    var questionCount: Int {
        switch self {
        case .quickQuiz: return 10
        case .fullPracticeExam: return 25
        case .weakAreaReview: return 10
        case .calculationDrill: return 15
        }
    }

    var progressLabel: String {
        switch self {
        case .quickQuiz: return "Short daily check-in"
        case .fullPracticeExam: return "Exam-style mixed assessment"
        case .weakAreaReview: return "Targeted follow-up drill"
        case .calculationDrill: return "Focused math and formula drill"
        }
    }

    var paywallContext: PaywallContext {
        switch self {
        case .quickQuiz:
            return .quizLimit
        case .fullPracticeExam:
            return .practiceExamLocked
        case .weakAreaReview:
            return .weakAreaLocked
        case .calculationDrill:
            return .practiceExamLocked
        }
    }

    /// Whether this quiz type shows a live timer during the session.
    var isTimedSession: Bool {
        switch self {
        case .fullPracticeExam, .calculationDrill: return true
        default: return false
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
    var quizAttemptId: UUID? = nil
    var score: Double              // 0.0–1.0
    var correctCount: Int
    var totalCount: Int
    var results: [QuestionResult]
    var weakTopics: [String]
    var weakTopicDetails: [WeakTopicDetail] = []
    var completedAt: Date = Date()
    var totalElapsedSeconds: Double? = nil         // overall session time
    var questionTimesSeconds: [String: Double]? = nil  // questionId.uuidString → seconds

    var xpEarned: Int = 0
    var passed: Bool { score >= 0.7 }
    var percentage: Int { Int(score * 100) }

    var averageSecondsPerQuestion: Double? {
        guard let times = questionTimesSeconds, !times.isEmpty else { return nil }
        return times.values.reduce(0, +) / Double(times.count)
    }
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
    var steps: [String]? = nil
    var bullets: [String]? = nil
    var references: [String]? = nil
    var followUps: [String]? = nil

    enum Role: String, Codable { case user, assistant }
}

enum TutorContextType: String, Codable {
    case general
    case lesson
    case quizReview = "quiz_review"
    case necDetail = "nec_detail"
}

struct TutorContext: Codable {
    var type: TutorContextType
    var id: UUID?
    var excerpt: String?
    var title: String? = nil
    var topicTags: [String] = []
    var examType: String? = nil
    var jurisdiction: String? = nil
    var lesson: LessonPayload? = nil
    var quizReview: QuizReviewPayload? = nil
    var necDetail: NECDetailPayload? = nil

    struct LessonPayload: Codable {
        var lessonId: UUID
        var title: String
        var excerpt: String?
        var topic: String?
        var necReferences: [String]
    }

    struct QuizReviewPayload: Codable {
        var quizId: UUID
        var quizAttemptId: UUID?
        var score: Double
        var correctCount: Int
        var totalCount: Int
        var weakTopics: [String]
        var focusedQuestion: QuestionPayload?
    }

    struct QuestionPayload: Codable {
        var questionId: UUID
        var question: String
        var userAnswer: String
        var correctAnswer: String
        var explanation: String
        var topics: [String]
        var referenceCode: String?
    }

    struct NECDetailPayload: Codable {
        var necId: UUID
        var code: String
        var title: String
        var summary: String
    }

    var storageKey: String {
        switch type {
        case .general:
            return "general"
        case .lesson:
            if let lessonId = lesson?.lessonId ?? id {
                return "lesson:\(lessonId.uuidString)"
            }
            return "lesson:unknown"
        case .quizReview:
            if let questionId = quizReview?.focusedQuestion?.questionId {
                return "quiz-question:\(questionId.uuidString)"
            }
            let quizIdentifier = (quizReview?.quizId ?? id)?.uuidString ?? "unknown"
            return "quiz:\(quizIdentifier)"
        case .necDetail:
            if let necId = necDetail?.necId ?? id {
                return "nec:\(necId.uuidString)"
            }
            return "nec:unknown"
        }
    }

    var sourceEyebrow: String? {
        switch type {
        case .general:
            return nil
        case .lesson:
            return "Lesson Context"
        case .quizReview:
            return "Quiz Review"
        case .necDetail:
            return "NEC Detail"
        }
    }

    var sourceTitle: String? {
        switch type {
        case .general:
            return nil
        case .lesson:
            return lesson?.title ?? title
        case .quizReview:
            if let question = quizReview?.focusedQuestion?.question {
                return question
            }
            return "Review this quiz result"
        case .necDetail:
            if let detail = necDetail {
                return "NEC \(detail.code) • \(detail.title)"
            }
            return title
        }
    }

    var sourceSummary: String? {
        switch type {
        case .general:
            return nil
        case .lesson:
            return lesson?.excerpt ?? excerpt
        case .quizReview:
            if let question = quizReview?.focusedQuestion {
                return "Your answer: \(question.userAnswer)\nCorrect answer: \(question.correctAnswer)"
            }
            guard let review = quizReview else { return nil }
            return "Score \(Int(review.score * 100))% with \(review.correctCount) of \(review.totalCount) correct."
        case .necDetail:
            return necDetail?.summary ?? excerpt
        }
    }

    /// When set, the TutorView will pre-fill the input with this text on first open.
    var autoSendPrompt: String? {
        guard type == .general, let excerpt, !excerpt.isEmpty, title?.hasPrefix("Study:") == true else { return nil }
        return excerpt
    }

    var starterPrompts: [String] {
        switch type {
        case .general:
            return [
                "Explain Ohm's Law with a simple example",
                "How should I study grounding and bonding for the exam?",
                "What is a continuous load in plain English?",
                "Walk me through GFCI vs AFCI"
            ]
        case .lesson:
            return [
                "Explain this lesson more simply",
                "What should I remember for the exam?",
                "Give me a field example",
                "Where does the NEC matter here?"
            ]
        case .quizReview:
            if quizReview?.focusedQuestion != nil {
                return [
                    "Why was my answer wrong?",
                    "Walk me through the correct thinking",
                    "Which NEC reference matters here?",
                    "Give me a similar practice question"
                ]
            }
            return [
                "What pattern do you see in my misses?",
                "Which topic should I review first?",
                "How should I study after this result?",
                "Give me a focused review plan"
            ]
        case .necDetail:
            return [
                "Explain this in plain English",
                "Why does this rule matter in practice?",
                "What do students commonly confuse here?",
                "How is this tested on the exam?"
            ]
        }
    }
}

struct AIUsageSnapshot: Codable {
    var used: Int
    var limit: Int
}

struct TutorSendResult: Codable {
    var message: TutorMessage
    var sessionId: UUID? = nil
    var usage: AIUsageSnapshot? = nil
}

struct NECExplanationResult: Codable {
    var expanded: String
    var usage: AIUsageSnapshot? = nil
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

// MARK: - Access

enum SubscriptionTier: String, Codable, CaseIterable {
    case preview
    case fastTrack = "fast_track"
    case fullPrep = "full_prep"
}

enum AccessProductID: String, CaseIterable, Codable {
    case fastTrack = "wattwise.fasttrack.3month"
    case fullPrep = "wattwise.fullprep.12month"

    var tier: SubscriptionTier {
        switch self {
        case .fastTrack:
            return .fastTrack
        case .fullPrep:
            return .fullPrep
        }
    }

    var title: String {
        switch self {
        case .fastTrack:
            return "Fast Track"
        case .fullPrep:
            return "Full Prep"
        }
    }

    var price: String {
        switch self {
        case .fastTrack:
            return "$69"
        case .fullPrep:
            return "$119"
        }
    }

    var accessTerm: String {
        switch self {
        case .fastTrack:
            return "3 months access"
        case .fullPrep:
            return "Full access until you pass, up to 12 months"
        }
    }

    var cardDescription: String {
        switch self {
        case .fastTrack:
            return "For focused, fast prep"
        case .fullPrep:
            return "For serious candidates who want full confidence"
        }
    }

    var callToAction: String {
        switch self {
        case .fastTrack:
            return "Choose Fast Track"
        case .fullPrep:
            return "Start Full Prep"
        }
    }

    var isRecommended: Bool {
        self == .fullPrep
    }

    var durationMonths: Int {
        switch self {
        case .fastTrack:
            return 3
        case .fullPrep:
            return 12
        }
    }
}

struct AccessOffer: Identifiable, Codable, Equatable {
    let id: String
    let productID: String
    let tier: SubscriptionTier
    let title: String
    let price: String
    let accessTerm: String
    let description: String
    let callToAction: String
    let isRecommended: Bool

    static let fastTrack = AccessOffer(productID: .fastTrack)
    static let fullPrep = AccessOffer(productID: .fullPrep)

    init(productID: AccessProductID) {
        self.id = productID.rawValue
        self.productID = productID.rawValue
        self.tier = productID.tier
        self.title = productID.title
        self.price = productID.price
        self.accessTerm = productID.accessTerm
        self.description = productID.cardDescription
        self.callToAction = productID.callToAction
        self.isRecommended = productID.isRecommended
    }
}

enum PaywallContext: String, Codable {
    case general
    case lessonLocked = "lesson_locked"
    case previewQuizComplete = "preview_quiz_complete"
    case quizLimit = "quiz_limit"
    case practiceExamLocked = "practice_exam_locked"
    case weakAreaLocked = "weak_area_locked"
    case tutorLimit = "tutor_limit"
    case necLimit = "nec_limit"

    var eyebrow: String {
        switch self {
        case .general:
            return "Full Exam Prep Access"
        case .lessonLocked:
            return "Keep Your Prep Moving"
        case .previewQuizComplete:
            return "Preview Complete"
        case .quizLimit:
            return "More Practice Awaits"
        case .practiceExamLocked:
            return "Exam-Style Practice"
        case .weakAreaLocked:
            return "Targeted Review"
        case .tutorLimit:
            return "Tutor Access"
        case .necLimit:
            return "NEC Help"
        }
    }

    var headline: String {
        switch self {
        case .tutorLimit:
            return "Keep tutor help available when you get stuck"
        case .previewQuizComplete, .quizLimit:
            return "Unlock your full exam prep system"
        default:
            return "Study with more confidence"
        }
    }

    var subheadline: String {
        "WattWise is built for real electrician exams with structured lessons, focused practice, NEC help, and instant tutor guidance when a concept stalls you."
    }

    var contextNote: String {
        switch self {
        case .general:
            return "Get the full lesson path, more practice, clearer NEC review, and tutor support without the stop-and-start of preview limits."
        case .lessonLocked:
            return "Preview includes your first full lesson. Keep going with full access to open the rest of the learning path."
        case .previewQuizComplete:
            return "You finished the preview quiz. The next meaningful step is full access to more practice, deeper review, and tutor help."
        case .quizLimit:
            return "You've used your preview quiz. Keep practicing with more quizzes, weak-area review, and full exam sessions."
        case .practiceExamLocked:
            return "Full practice exams are part of paid access so you can pressure-test your readiness before exam day."
        case .weakAreaLocked:
            return "Weak-area review is built for serious follow-up work after a scored quiz. Full access keeps that review path open."
        case .tutorLimit:
            return "You've used your preview tutor questions. Full access keeps explanations available when you need another step-by-step walkthrough."
        case .necLimit:
            return "Preview includes a limited NEC explanation sample. Full access gives you deeper code help while you study."
        }
    }

    var trustNote: String {
        "One-time exam prep access. No monthly subscription to manage."
    }
}

struct SubscriptionState: Codable {
    var tier: SubscriptionTier
    var status: String
    var expiresAt: Date?
    var storeProductId: String? = nil
    var previewQuickQuizzesUsed: Int
    var previewQuickQuizzesLimit: Int
    var tutorMessagesUsed: Int
    var tutorMessagesLimit: Int
    var necExplanationsUsed: Int
    var necExplanationsLimit: Int

    var hasPaidAccess: Bool {
        switch tier {
        case .preview:
            return false
        case .fastTrack, .fullPrep:
            guard status == "active" else { return false }
            guard let expiresAt else { return true }
            return expiresAt > Date()
        }
    }

    var isPreview: Bool { hasPaidAccess == false }

    var accessTitle: String {
        if hasPaidAccess {
            switch tier {
            case .preview:
                return "Preview Access"
            case .fastTrack:
                return "Fast Track"
            case .fullPrep:
                return "Full Prep"
            }
        }

        if status == "expired" {
            return "Preview Access"
        }

        return "Preview Access"
    }

    var accessDescription: String {
        if hasPaidAccess {
            switch tier {
            case .preview:
                return "A guided preview of the WattWise study flow."
            case .fastTrack:
                return "Full access for focused prep over the next 3 months."
            case .fullPrep:
                return "Full access built for serious prep with the longest runway."
            }
        }

        if status == "expired" {
            if storeProductId == AccessProductID.fastTrack.rawValue {
                return "Your Fast Track access ended. Preview access is still available."
            }
            if storeProductId == AccessProductID.fullPrep.rawValue {
                return "Your Full Prep access ended. Preview access is still available."
            }
        }

        return "1 full lesson, 1 quick quiz, and guided tutor help to show how WattWise works."
    }

    var expiresDescription: String? {
        guard hasPaidAccess, let expiresAt else { return nil }
        let formatted = expiresAt.formatted(.dateTime.month().day().year())
        switch tier {
        case .fastTrack:
            return "Access through \(formatted)"
        case .fullPrep:
            return "Access through \(formatted)"
        case .preview:
            return nil
        }
    }

    var previewQuickQuizLimitReached: Bool {
        guard previewQuickQuizzesLimit != -1 else { return false }
        return previewQuickQuizzesUsed >= previewQuickQuizzesLimit
    }

    var previewQuickQuizzesRemaining: Int {
        guard previewQuickQuizzesLimit != -1 else { return Int.max }
        return max(0, previewQuickQuizzesLimit - previewQuickQuizzesUsed)
    }

    var tutorLimitReached: Bool {
        guard tutorMessagesLimit != -1 else { return false }
        return tutorMessagesUsed >= tutorMessagesLimit
    }

    var tutorMessagesRemaining: Int {
        guard tutorMessagesLimit != -1 else { return Int.max }
        return max(0, tutorMessagesLimit - tutorMessagesUsed)
    }

    var necExplanationLimitReached: Bool {
        guard necExplanationsLimit != -1 else { return false }
        return necExplanationsUsed >= necExplanationsLimit
    }

    var necExplanationsRemaining: Int {
        guard necExplanationsLimit != -1 else { return Int.max }
        return max(0, necExplanationsLimit - necExplanationsUsed)
    }

    var previewSummary: String {
        let tutorCount = tutorMessagesLimit == -1 ? "Tutor included" : "\(tutorMessagesLimit) tutor questions"
        return "Preview includes 1 full lesson, 1 quick quiz, \(tutorCount), and a limited NEC sample."
    }

    var restoreSuccessMessage: String {
        if hasPaidAccess {
            switch tier {
            case .fastTrack:
                return "Your Fast Track access is active again."
            case .fullPrep:
                return "Your Full Prep access is active again."
            case .preview:
                return "Your preview access is active."
            }
        }
        return "No paid access was found. Preview access is still available."
    }

    var purchaseSuccessMessage: String {
        switch tier {
        case .fastTrack:
            return "Fast Track is active. Your full prep access is ready."
        case .fullPrep:
            return "Full Prep is active. Your full prep system is ready."
        case .preview:
            return "Preview access is active."
        }
    }

    mutating func applyTutorUsage(_ usage: AIUsageSnapshot) {
        tutorMessagesUsed = usage.used
        tutorMessagesLimit = usage.limit
    }

    mutating func applyNECUsage(_ usage: AIUsageSnapshot) {
        necExplanationsUsed = usage.used
        necExplanationsLimit = usage.limit
    }

    mutating func markPreviewQuizUsedIfNeeded() {
        guard previewQuickQuizzesLimit != -1 else { return }
        previewQuickQuizzesUsed = min(previewQuickQuizzesLimit, previewQuickQuizzesUsed + 1)
    }

    static let preview = SubscriptionState(
        tier: .preview,
        status: "active",
        expiresAt: nil,
        storeProductId: nil,
        previewQuickQuizzesUsed: 0,
        previewQuickQuizzesLimit: 1,
        tutorMessagesUsed: 0,
        tutorMessagesLimit: 4,
        necExplanationsUsed: 0,
        necExplanationsLimit: 1
    )

    static let fastTrack = SubscriptionState(
        tier: .fastTrack,
        status: "active",
        expiresAt: Calendar.current.date(byAdding: .month, value: 3, to: Date()),
        storeProductId: AccessProductID.fastTrack.rawValue,
        previewQuickQuizzesUsed: 1,
        previewQuickQuizzesLimit: -1,
        tutorMessagesUsed: 0,
        tutorMessagesLimit: -1,
        necExplanationsUsed: 0,
        necExplanationsLimit: -1
    )

    static let fullPrep = SubscriptionState(
        tier: .fullPrep,
        status: "active",
        expiresAt: Calendar.current.date(byAdding: .month, value: 12, to: Date()),
        storeProductId: AccessProductID.fullPrep.rawValue,
        previewQuickQuizzesUsed: 1,
        previewQuickQuizzesLimit: -1,
        tutorMessagesUsed: 0,
        tutorMessagesLimit: -1,
        necExplanationsUsed: 0,
        necExplanationsLimit: -1
    )
}
