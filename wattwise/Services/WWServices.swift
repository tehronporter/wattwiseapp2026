import Foundation
import Observation

// MARK: - Auth Service

protocol AuthServiceProtocol: AnyObject {
    var currentUser: WWUser? { get }
    var pendingEmailConfirmation: PendingEmailConfirmation? { get }
    func signIn(email: String, password: String) async throws -> WWUser
    func signUp(email: String, password: String, pending: PendingEmailConfirmation) async throws -> AuthSignUpResult
    func signInWithApple(token: String) async throws -> WWUser
    func signOut() throws
    func restoreSession() async -> WWUser?
    func updateProfile(_ user: WWUser) async throws
    func resendConfirmation(email: String) async throws
    func handleAuthCallback(url: URL) async throws -> WWUser
}

@MainActor
final class MockAuthService: AuthServiceProtocol {
    private(set) var currentUser: WWUser?
    var pendingEmailConfirmation: PendingEmailConfirmation? = PendingEmailConfirmationStore.load()

    private let userKey = "ww_user"

    func restoreSession() async -> WWUser? {
        if let data = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(WWUser.self, from: data) {
            currentUser = user
            return user
        }
        return nil
    }

    func signIn(email: String, password: String) async throws -> WWUser {
        try await Task.sleep(for: .milliseconds(800))
        guard !email.isEmpty, !password.isEmpty else {
            throw AppError.invalidInput("Email and password are required.")
        }
        let user = WWUser(
            id: UUID(),
            email: email,
            displayName: email.components(separatedBy: "@").first?.capitalized,
            examType: .apprentice,
            state: "TX",
            studyGoal: .moderate,
            streakDays: 4,
            isOnboardingComplete: true
        )
        persist(user)
        currentUser = user
        return user
    }

    func signUp(email: String, password: String, pending: PendingEmailConfirmation) async throws -> AuthSignUpResult {
        try await Task.sleep(for: .milliseconds(800))
        guard !email.isEmpty else { throw AppError.invalidInput("Email is required.") }
        guard password.count >= 8 else { throw AppError.invalidInput("Password must be at least 8 characters.") }
        let user = WWUser(
            id: UUID(),
            email: email,
            displayName: nil,
            examType: pending.examType,
            state: pending.state,
            studyGoal: pending.studyGoal,
            streakDays: 0,
            isOnboardingComplete: true
        )
        persist(user)
        currentUser = user
        pendingEmailConfirmation = nil
        return .authenticated(user)
    }

    func signInWithApple(token: String) async throws -> WWUser {
        try await Task.sleep(for: .milliseconds(500))
        let user = WWUser(
            id: UUID(),
            email: "apple-user@privaterelay.com",
            displayName: "Apple User",
            examType: .apprentice,
            state: "",
            studyGoal: .moderate,
            streakDays: 0,
            isOnboardingComplete: false
        )
        persist(user)
        currentUser = user
        return user
    }

    func signOut() throws {
        UserDefaults.standard.removeObject(forKey: userKey)
        currentUser = nil
        pendingEmailConfirmation = nil
        PendingEmailConfirmationStore.clear()
    }

    func updateProfile(_ user: WWUser) async throws {
        persist(user)
        currentUser = user
    }

    func resendConfirmation(email: String) async throws {
        pendingEmailConfirmation = PendingEmailConfirmation(
            email: email,
            examType: .apprentice,
            state: "TX",
            studyGoal: .moderate,
            requestedAt: Date()
        )
        if let pendingEmailConfirmation {
            PendingEmailConfirmationStore.save(pendingEmailConfirmation)
        }
    }

    func handleAuthCallback(url: URL) async throws -> WWUser {
        guard let pending = pendingEmailConfirmation else {
            throw AuthError.invalidCallback("No confirmation is waiting on this device. Sign in to continue.")
        }

        let user = WWUser(
            id: UUID(),
            email: pending.email,
            displayName: nil,
            examType: pending.examType,
            state: pending.state,
            studyGoal: pending.studyGoal,
            streakDays: 0,
            isOnboardingComplete: pending.state.isEmpty == false
        )
        persist(user)
        currentUser = user
        pendingEmailConfirmation = nil
        PendingEmailConfirmationStore.clear()
        return user
    }

    private func persist(_ user: WWUser) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }
}

// MARK: - Content Service

protocol ContentServiceProtocol: AnyObject {
    func fetchModules() async throws -> [WWModule]
    func fetchLesson(id: UUID) async throws -> WWLesson
    func saveProgress(lessonId: UUID, completion: Double) async throws
}

final class MockContentService: ContentServiceProtocol {
    func fetchModules() async throws -> [WWModule] {
        try await Task.sleep(for: .milliseconds(600))
        return try WattWiseContentRuntimeAdapter.loadModules()
    }

    func fetchLesson(id: UUID) async throws -> WWLesson {
        try await Task.sleep(for: .milliseconds(400))
        return try WattWiseContentRuntimeAdapter.loadLesson(id: id)
    }

    func saveProgress(lessonId: UUID, completion: Double) async throws {
        try await Task.sleep(for: .milliseconds(200))
        try WattWiseContentRuntimeAdapter.saveProgress(lessonId: lessonId, completion: completion)
    }
}

// MARK: - Quiz Service

protocol QuizServiceProtocol: AnyObject {
    func generateQuiz(type: QuizType, topicTags: [String], examType: ExamType?) async throws -> WWQuiz
    func submitQuiz(quizId: UUID, answers: [QuizAnswer]) async throws -> QuizResult
}

struct PracticeDashboardSnapshot {
    var attemptCount: Int
    var latestScorePercentage: Int?
    var weakTopics: [WeakTopicDetail]
    var latestCompletedAt: Date?

    var canStartWeakAreaReview: Bool {
        attemptCount > 0 && !weakTopics.isEmpty
    }

    static let empty = PracticeDashboardSnapshot(
        attemptCount: 0,
        latestScorePercentage: nil,
        weakTopics: [],
        latestCompletedAt: nil
    )
}

final class PracticeHistoryStore {
    static let shared = PracticeHistoryStore()

    private struct StoredHistory: Codable {
        var attempts: [StoredAttempt] = []
        var topicPerformance: [String: StoredTopicPerformance] = [:]
    }

    private struct StoredAttempt: Codable {
        var id: UUID
        var quizId: UUID
        var quizType: String
        var completedAt: Date
        var score: Double
        var correctCount: Int
        var totalCount: Int
        var outcomes: [StoredOutcome]
    }

    private struct StoredOutcome: Codable {
        var questionId: UUID
        var isCorrect: Bool
        var topicKeys: [String]
        var topicTitles: [String]
    }

    private struct StoredTopicPerformance: Codable {
        var key: String
        var title: String
        var correctCount: Int
        var incorrectCount: Int
        var lastSeenAt: Date
        var lastIncorrectAt: Date?
        var missedQuestionIDs: [UUID]
    }

    private let defaults = UserDefaults.standard
    private let storageKey = "ww_practice_history_v1"
    private let maxAttemptsToKeep = 24

    private init() {}

    func dashboard() -> PracticeDashboardSnapshot {
        let history = load()
        let latestAttempt = history.attempts.sorted { $0.completedAt > $1.completedAt }.first
        return PracticeDashboardSnapshot(
            attemptCount: history.attempts.count,
            latestScorePercentage: latestAttempt.map { Int($0.score * 100) },
            weakTopics: topWeakTopics(limit: 3, history: history),
            latestCompletedAt: latestAttempt?.completedAt
        )
    }

    func hasAttempts() -> Bool {
        load().attempts.isEmpty == false
    }

    func suggestedWeakTopicKeys(limit: Int = 3) -> [String] {
        topWeakTopics(limit: limit, history: load()).map(\.key)
    }

    func topicDetails(for keys: [String]) -> [WeakTopicDetail] {
        let history = load()
        let keySet = Set(keys)
        return topWeakTopics(limit: max(keySet.count, 1), history: history)
            .filter { keySet.contains($0.key) }
    }

    func missedQuestionIDs(for topicKeys: Set<String>) -> Set<UUID> {
        guard topicKeys.isEmpty == false else { return [] }
        let history = load()
        return Set(
            history.topicPerformance.values
                .filter { topicKeys.contains($0.key) }
                .flatMap(\.missedQuestionIDs)
        )
    }

    func lastSeenByQuestion() -> [UUID: Date] {
        let attempts = load().attempts.sorted { $0.completedAt > $1.completedAt }
        var map: [UUID: Date] = [:]

        for attempt in attempts {
            for outcome in attempt.outcomes where map[outcome.questionId] == nil {
                map[outcome.questionId] = attempt.completedAt
            }
        }

        return map
    }

    func missedCountByQuestion() -> [UUID: Int] {
        let history = load()
        var counts: [UUID: Int] = [:]

        for attempt in history.attempts {
            for outcome in attempt.outcomes where outcome.isCorrect == false {
                counts[outcome.questionId, default: 0] += 1
            }
        }

        return counts
    }

    func recordAttempt(quiz: WWQuiz, results: [QuestionResult], score: Double, correctCount: Int, totalCount: Int) {
        var history = load()
        let now = Date()
        let attempt = StoredAttempt(
            id: UUID(),
            quizId: quiz.id,
            quizType: quiz.type.rawValue,
            completedAt: now,
            score: score,
            correctCount: correctCount,
            totalCount: totalCount,
            outcomes: results.map {
                StoredOutcome(
                    questionId: $0.questionId,
                    isCorrect: $0.isCorrect,
                    topicKeys: $0.topics,
                    topicTitles: $0.topicTitles
                )
            }
        )

        history.attempts.insert(attempt, at: 0)
        history.attempts = Array(history.attempts.prefix(maxAttemptsToKeep))

        for result in results {
            let pairs = zipTopicKeys(result.topics, titles: result.topicTitles)
            for pair in pairs {
                var performance = history.topicPerformance[pair.key] ?? StoredTopicPerformance(
                    key: pair.key,
                    title: pair.title,
                    correctCount: 0,
                    incorrectCount: 0,
                    lastSeenAt: now,
                    lastIncorrectAt: nil,
                    missedQuestionIDs: []
                )
                performance.title = pair.title
                performance.lastSeenAt = now
                if result.isCorrect {
                    performance.correctCount += 1
                } else {
                    performance.incorrectCount += 1
                    performance.lastIncorrectAt = now
                    if performance.missedQuestionIDs.contains(result.questionId) == false {
                        performance.missedQuestionIDs.append(result.questionId)
                    }
                }
                history.topicPerformance[pair.key] = performance
            }
        }

        save(history)
    }

    private func load() -> StoredHistory {
        guard let data = defaults.data(forKey: storageKey),
              let history = try? JSONDecoder().decode(StoredHistory.self, from: data) else {
            return StoredHistory()
        }
        return history
    }

    private func save(_ history: StoredHistory) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func topWeakTopics(limit: Int, history: StoredHistory) -> [WeakTopicDetail] {
        history.topicPerformance.values
            .filter { $0.incorrectCount > 0 }
            .sorted { lhs, rhs in
                if lhs.incorrectCount != rhs.incorrectCount {
                    return lhs.incorrectCount > rhs.incorrectCount
                }
                let lhsAccuracy = topicAccuracy(lhs)
                let rhsAccuracy = topicAccuracy(rhs)
                if lhsAccuracy != rhsAccuracy {
                    return lhsAccuracy < rhsAccuracy
                }
                return (lhs.lastIncorrectAt ?? .distantPast) > (rhs.lastIncorrectAt ?? .distantPast)
            }
            .prefix(limit)
            .map {
                WeakTopicDetail(
                    key: $0.key,
                    title: $0.title,
                    incorrectCount: $0.incorrectCount,
                    attemptedCount: $0.correctCount + $0.incorrectCount
                )
            }
    }

    private func topicAccuracy(_ performance: StoredTopicPerformance) -> Double {
        let attempts = performance.correctCount + performance.incorrectCount
        guard attempts > 0 else { return 1.0 }
        return Double(performance.correctCount) / Double(attempts)
    }

    private func zipTopicKeys(_ keys: [String], titles: [String]) -> [(key: String, title: String)] {
        if titles.count == keys.count {
            return Array(zip(keys, titles))
        }

        return keys.map { key in
            (
                key: key,
                title: key
                    .replacingOccurrences(of: "-", with: " ")
                    .split(separator: " ")
                    .map { $0.capitalized }
                    .joined(separator: " ")
            )
        }
    }
}

private struct SupplementalPracticeQuestionSeed {
    let id: String
    let certificationLevel: String
    let topicKey: String
    let topicTitle: String
    let question: String
    let choices: [String: String]
    let correctChoice: String
    let explanation: String
    let referenceCode: String
    let difficultyLevel: String

    var model: QuizQuestion {
        QuizQuestion(
            id: WattWiseContentRuntimeAdapter.uuid(for: "supplemental-question:\(id)"),
            question: question,
            choices: choices,
            correctChoice: correctChoice,
            explanation: explanation,
            topics: [topicKey],
            topicTitles: [topicTitle],
            difficultyLevel: difficultyLevel,
            referenceCode: referenceCode,
            certificationLevel: certificationLevel
        )
    }
}

private enum CuratedPracticeQuestionBank {
    static let supplementalQuestions: [QuizQuestion] = [
        SupplementalPracticeQuestionSeed(
            id: "A-006",
            certificationLevel: "Apprentice",
            topicKey: "equipment-installation",
            topicTitle: "Equipment Installation",
            question: "When a question asks how listed equipment must be installed and used, which NEC section is the common starting point?",
            choices: ["A": "110.3(B)", "B": "220.40", "C": "250.50", "D": "314.16"],
            correctChoice: "A",
            explanation: "Section 110.3(B) is the familiar starting point for questions about following listing and labeling instructions. It reminds candidates that manufacturer instructions tied to listing matter during installation.",
            referenceCode: "110.3(B)",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "A-007",
            certificationLevel: "Apprentice",
            topicKey: "wiring-methods",
            topicTitle: "Wiring Methods",
            question: "If NM cable passes through a bored hole in wood framing, how far should the hole generally be from the nearest edge before nail-plate protection is needed?",
            choices: ["A": "3/4 inch", "B": "1 inch", "C": "1-1/4 inches", "D": "2 inches"],
            correctChoice: "C",
            explanation: "A common exam trigger is the 1-1/4 inch rule in 300.4(A)(1). If the cable is closer than that to the edge, steel protection is generally required.",
            referenceCode: "300.4(A)(1)",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "A-008",
            certificationLevel: "Apprentice",
            topicKey: "branch-circuits",
            topicTitle: "Branch Circuits",
            question: "How many small-appliance branch circuits are required at minimum for a dwelling-unit kitchen and related dining areas?",
            choices: ["A": "One 20-amp circuit", "B": "Two 20-amp circuits", "C": "Three 15-amp circuits", "D": "Two 15-amp circuits"],
            correctChoice: "B",
            explanation: "Section 210.11(C)(1) requires at least two 20-amp small-appliance branch circuits. This is a foundational dwelling-unit exam topic.",
            referenceCode: "210.11(C)(1)",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "A-009",
            certificationLevel: "Apprentice",
            topicKey: "conductors",
            topicTitle: "Conductors",
            question: "What is the maximum overcurrent protection normally permitted for a 14 AWG copper conductor under the small-conductor rule?",
            choices: ["A": "10 amperes", "B": "15 amperes", "C": "20 amperes", "D": "25 amperes"],
            correctChoice: "B",
            explanation: "Questions on 240.4(D) usually test whether you know the familiar small-conductor limits. For 14 AWG copper, the standard maximum is 15 amperes unless a specific code rule allows otherwise.",
            referenceCode: "240.4(D)",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-006",
            certificationLevel: "Journeyman",
            topicKey: "continuous-loads",
            topicTitle: "Continuous Loads",
            question: "A branch circuit serves a 32-amp continuous load with no other load. Using the common 125 percent sizing step, what overcurrent device rating should you consider first?",
            choices: ["A": "35 amperes", "B": "40 amperes", "C": "45 amperes", "D": "50 amperes"],
            correctChoice: "B",
            explanation: "For a continuous load, start by multiplying by 125 percent: 32 x 1.25 = 40 amperes. The candidate should then verify the rest of the applicable conductor and equipment rules.",
            referenceCode: "210.20(A)",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-007",
            certificationLevel: "Journeyman",
            topicKey: "grounding-and-bonding",
            topicTitle: "Grounding and Bonding",
            question: "If a building has multiple grounding electrodes that qualify under the NEC, what is the usual exam-safe rule?",
            choices: ["A": "Use the metal water pipe only", "B": "Use the ground rod only", "C": "Bond the available electrodes together as one grounding electrode system", "D": "Choose the electrode nearest the service disconnect"],
            correctChoice: "C",
            explanation: "Section 250.50 teaches the exam habit: when the electrodes are present and qualify, they are bonded together into one grounding electrode system rather than chosen one at a time.",
            referenceCode: "250.50",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-008",
            certificationLevel: "Journeyman",
            topicKey: "motors",
            topicTitle: "Motors",
            question: "When a question asks for the maximum rating of motor branch-circuit short-circuit and ground-fault protection, which NEC section is the usual lookup point?",
            choices: ["A": "314.16", "B": "430.22", "C": "430.52", "D": "500.5"],
            correctChoice: "C",
            explanation: "Section 430.52 is the standard lookup path for motor branch-circuit short-circuit and ground-fault protection. Candidates should distinguish that from conductor sizing and overload protection sections.",
            referenceCode: "430.52",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-009",
            certificationLevel: "Journeyman",
            topicKey: "feeders",
            topicTitle: "Feeders",
            question: "A feeder carries a 48-amp continuous load and no other load. Using the standard 125 percent feeder step, what rating should you check first for the overcurrent device?",
            choices: ["A": "50 amperes", "B": "55 amperes", "C": "60 amperes", "D": "70 amperes"],
            correctChoice: "C",
            explanation: "A frequent journeyman pattern is continuous-load feeder sizing: 48 x 1.25 = 60 amperes. From there, the candidate still confirms the applicable conductor and equipment rules.",
            referenceCode: "215.3",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "M-006",
            certificationLevel: "Master",
            topicKey: "load-calculations",
            topicTitle: "Load Calculations",
            question: "Which NEC section is a common starting point when a problem asks whether two loads can be treated as noncoincident?",
            choices: ["A": "220.42", "B": "220.50", "C": "220.60", "D": "230.42"],
            correctChoice: "C",
            explanation: "Section 220.60 addresses noncoincident loads. Master-level questions often test whether the candidate recognizes when only the larger load can be counted because the loads will not operate at the same time.",
            referenceCode: "220.60",
            difficultyLevel: "Hard"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "M-007",
            certificationLevel: "Master",
            topicKey: "load-calculations",
            topicTitle: "Load Calculations",
            question: "When a problem asks for lighting-load demand factors, which section is commonly used first?",
            choices: ["A": "210.11", "B": "220.42", "C": "250.66", "D": "310.16"],
            correctChoice: "B",
            explanation: "Section 220.42 is the familiar starting point for lighting-load demand factors. On longer calculations, knowing where the factor table lives matters as much as the arithmetic.",
            referenceCode: "220.42",
            difficultyLevel: "Hard"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "M-008",
            certificationLevel: "Master",
            topicKey: "code-interpretation",
            topicTitle: "Code Interpretation",
            question: "When an exam question turns on who interprets and enforces the adopted electrical code, what answer is generally correct?",
            choices: ["A": "The equipment manufacturer", "B": "The utility", "C": "The authority having jurisdiction", "D": "The testing center proctor"],
            correctChoice: "C",
            explanation: "Section 90.4 points candidates toward the authority having jurisdiction for interpretation and enforcement. This matters on master-style questions that mix technical code reading with approval and compliance context.",
            referenceCode: "90.4",
            difficultyLevel: "Hard"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "M-009",
            certificationLevel: "Master",
            topicKey: "services",
            topicTitle: "Services",
            question: "After completing a service load calculation, which article is commonly used next to check service-conductor ampacity requirements?",
            choices: ["A": "Article 220", "B": "Article 230", "C": "Article 250", "D": "Article 314"],
            correctChoice: "B",
            explanation: "Article 220 handles much of the load calculation work, while Article 230 is a standard next stop for service-conductor and service-equipment questions. Master candidates are expected to know that workflow.",
            referenceCode: "230.42",
            difficultyLevel: "Hard"
        ).model
    ]
}

final class MockQuizService: QuizServiceProtocol {
    private let historyStore = PracticeHistoryStore.shared
    private var activeQuizzes: [UUID: WWQuiz] = [:]

    private lazy var allQuestions: [QuizQuestion] = {
        var pool = WattWiseContentRuntimeAdapter.loadQuestionBank()
        pool.append(contentsOf: CuratedPracticeQuestionBank.supplementalQuestions)
        return pool
    }()

    func generateQuiz(type: QuizType, topicTags: [String], examType: ExamType?) async throws -> WWQuiz {
        try await Task.sleep(for: .milliseconds(800))
        let count = type.questionCount
        let focusTags = resolveFocusTags(for: type, explicitTags: topicTags)
        let pool = questionPool(for: examType)
        let questions = selectQuestions(from: pool, count: count, type: type, focusTags: focusTags)

        guard questions.count >= min(count, 5) else {
            throw AppError.notFound("There are not enough practice questions to build this quiz yet.")
        }

        let quiz = WWQuiz(id: UUID(), type: type, questions: questions)
        activeQuizzes[quiz.id] = quiz
        return quiz
    }

    func submitQuiz(quizId: UUID, answers: [QuizAnswer]) async throws -> QuizResult {
        try await Task.sleep(for: .milliseconds(600))

        guard let quiz = activeQuizzes[quizId] else {
            throw AppError.notFound("This quiz session is no longer available. Please generate a new quiz.")
        }

        let answersByQuestion = Dictionary(uniqueKeysWithValues: answers.map { ($0.questionId, $0.selected) })
        var correct = 0
        var results: [QuestionResult] = []

        for question in quiz.questions {
            let selectedChoice = answersByQuestion[question.id]
            let isCorrect = selectedChoice == question.correctChoice
            if isCorrect {
                correct += 1
            }
            results.append(
                QuestionResult(
                    id: UUID(),
                    questionId: question.id,
                    question: question.question,
                    userAnswer: selectedChoice.flatMap { question.choices[$0] } ?? "Not answered",
                    correctAnswer: question.choices[question.correctChoice] ?? question.correctChoice,
                    explanation: question.explanation,
                    isCorrect: isCorrect,
                    topics: question.topics,
                    topicTitles: question.topicTitles,
                    referenceCode: question.referenceCode
                )
            )
        }

        let score = quiz.questions.isEmpty ? 0.0 : Double(correct) / Double(quiz.questions.count)
        historyStore.recordAttempt(
            quiz: quiz,
            results: results,
            score: score,
            correctCount: correct,
            totalCount: quiz.questions.count
        )

        let incorrectTopicKeys = Array(
            Set(results.filter { $0.isCorrect == false }.flatMap(\.topics))
        )
        let weakTopicDetails = historyStore.topicDetails(for: incorrectTopicKeys)
        activeQuizzes.removeValue(forKey: quizId)

        return QuizResult(
            id: UUID(),
            quizId: quizId,
            score: score,
            correctCount: correct,
            totalCount: quiz.questions.count,
            results: results,
            weakTopics: weakTopicDetails.map(\.title),
            weakTopicDetails: weakTopicDetails,
            completedAt: Date()
        )
    }

    private func resolveFocusTags(for type: QuizType, explicitTags: [String]) -> [String] {
        if explicitTags.isEmpty == false {
            return explicitTags.map { $0.lowercased() }
        }
        guard type == .weakAreaReview else {
            return Array(historyStore.suggestedWeakTopicKeys(limit: 2))
        }
        return historyStore.suggestedWeakTopicKeys(limit: 3)
    }

    private func questionPool(for examType: ExamType?) -> [QuizQuestion] {
        guard let examType else { return allQuestions }

        let filtered = allQuestions.filter { question in
            switch examType {
            case .apprentice:
                return certificationRank(for: question) <= 2 && difficultyRank(for: question) <= 2
            case .master:
                return true
            }
        }

        return filtered.count >= 20 ? filtered : allQuestions
    }

    private func selectQuestions(from pool: [QuizQuestion], count: Int, type: QuizType, focusTags: [String]) -> [QuizQuestion] {
        let focusSet = Set(focusTags.map { $0.lowercased() })
        let lastSeenByQuestion = historyStore.lastSeenByQuestion()
        let missedCountByQuestion = historyStore.missedCountByQuestion()
        let missedQuestionIDs = historyStore.missedQuestionIDs(for: focusSet)

        let ordered = pool.sorted { lhs, rhs in
            let lhsFocus = lhs.topics.contains { focusSet.contains($0.lowercased()) }
            let rhsFocus = rhs.topics.contains { focusSet.contains($0.lowercased()) }
            if lhsFocus != rhsFocus {
                return lhsFocus && !rhsFocus
            }

            let lhsMissedBefore = missedQuestionIDs.contains(lhs.id)
            let rhsMissedBefore = missedQuestionIDs.contains(rhs.id)
            if type == .weakAreaReview, lhsMissedBefore != rhsMissedBefore {
                return lhsMissedBefore && !rhsMissedBefore
            }

            let lhsSeen = lastSeenByQuestion[lhs.id] ?? .distantPast
            let rhsSeen = lastSeenByQuestion[rhs.id] ?? .distantPast
            if lhsSeen != rhsSeen {
                return lhsSeen < rhsSeen
            }

            let lhsMissCount = missedCountByQuestion[lhs.id] ?? 0
            let rhsMissCount = missedCountByQuestion[rhs.id] ?? 0
            if lhsMissCount != rhsMissCount {
                return lhsMissCount > rhsMissCount
            }

            return lhs.question.localizedCaseInsensitiveCompare(rhs.question) == .orderedAscending
        }

        return balancedSelection(from: ordered, count: min(count, ordered.count), focusTags: focusSet)
    }

    private func balancedSelection(from ordered: [QuizQuestion], count: Int, focusTags: Set<String>) -> [QuizQuestion] {
        var groups: [String: [QuizQuestion]] = [:]
        for question in ordered {
            let key = question.topicTitles.first ?? question.topics.first ?? "General Review"
            groups[key, default: []].append(question)
        }

        let groupOrder = groups.keys.sorted { lhs, rhs in
            let lhsFocus = groups[lhs]?.contains { $0.topics.contains(where: { focusTags.contains($0.lowercased()) }) } ?? false
            let rhsFocus = groups[rhs]?.contains { $0.topics.contains(where: { focusTags.contains($0.lowercased()) }) } ?? false
            if lhsFocus != rhsFocus {
                return lhsFocus && !rhsFocus
            }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }

        var selected: [QuizQuestion] = []
        var selectedIDs: Set<UUID> = []
        var didAdd = true

        while selected.count < count && didAdd {
            didAdd = false
            for key in groupOrder {
                guard let nextQuestion = groups[key]?.first(where: { selectedIDs.contains($0.id) == false }) else { continue }
                selected.append(nextQuestion)
                selectedIDs.insert(nextQuestion.id)
                didAdd = true
                if selected.count == count {
                    break
                }
            }
        }

        if selected.count < count {
            for question in ordered where selectedIDs.contains(question.id) == false {
                selected.append(question)
                if selected.count == count {
                    break
                }
            }
        }

        return selected
    }

    private func certificationRank(for question: QuizQuestion) -> Int {
        switch question.certificationLevel?.lowercased() {
        case "apprentice": return 1
        case "journeyman": return 2
        case "master": return 3
        default: return 2
        }
    }

    private func difficultyRank(for question: QuizQuestion) -> Int {
        switch question.difficultyLevel?.lowercased() {
        case "easy", "beginner": return 1
        case "medium", "intermediate": return 2
        case "hard", "advanced": return 3
        default: return 2
        }
    }
}

// MARK: - Tutor Service

protocol TutorServiceProtocol: AnyObject {
    func sendMessage(
        _ text: String,
        context: TutorContext?,
        history: [TutorMessage],
        sessionID: UUID?
    ) async throws -> TutorSendResult
}

enum TutorContextBuilder {
    static func general(for user: WWUser?) -> TutorContext {
        TutorContext(
            type: .general,
            id: nil,
            excerpt: nil,
            title: nil,
            topicTags: [],
            examType: user?.examType.rawValue,
            jurisdiction: normalizedJurisdiction(for: user),
            lesson: nil,
            quizReview: nil,
            necDetail: nil
        )
    }

    static func lesson(_ lesson: WWLesson, user: WWUser?) -> TutorContext {
        TutorContext(
            type: .lesson,
            id: lesson.id,
            excerpt: lesson.sections.first(where: { !$0.body.isEmpty })?.body,
            title: lesson.title,
            topicTags: [lesson.topic],
            examType: user?.examType.rawValue,
            jurisdiction: normalizedJurisdiction(for: user),
            lesson: .init(
                lessonId: lesson.id,
                title: lesson.title,
                excerpt: lesson.sections.first(where: { !$0.body.isEmpty })?.body,
                topic: lesson.topic,
                necReferences: lesson.necReferences.map(\.code)
            ),
            quizReview: nil,
            necDetail: nil
        )
    }

    static func quizReview(
        _ result: QuizResult,
        focusedQuestion: QuestionResult? = nil,
        user: WWUser?
    ) -> TutorContext {
        let topics = focusedQuestion?.topicTitles.isEmpty == false
            ? focusedQuestion?.topicTitles ?? []
            : focusedQuestion?.topics ?? result.weakTopics

        return TutorContext(
            type: .quizReview,
            id: result.quizAttemptId ?? result.quizId,
            excerpt: focusedQuestion?.explanation,
            title: focusedQuestion?.question ?? "Quiz review",
            topicTags: topics,
            examType: user?.examType.rawValue,
            jurisdiction: normalizedJurisdiction(for: user),
            lesson: nil,
            quizReview: .init(
                quizId: result.quizId,
                quizAttemptId: result.quizAttemptId,
                score: result.score,
                correctCount: result.correctCount,
                totalCount: result.totalCount,
                weakTopics: result.weakTopics,
                focusedQuestion: focusedQuestion.map {
                    .init(
                        questionId: $0.questionId,
                        question: $0.question,
                        userAnswer: $0.userAnswer,
                        correctAnswer: $0.correctAnswer,
                        explanation: $0.explanation,
                        topics: $0.topicTitles.isEmpty ? $0.topics : $0.topicTitles,
                        referenceCode: $0.referenceCode
                    )
                }
            ),
            necDetail: nil
        )
    }

    static func necDetail(_ reference: NECReference, user: WWUser?) -> TutorContext {
        TutorContext(
            type: .necDetail,
            id: reference.id,
            excerpt: reference.summary,
            title: reference.title,
            topicTags: ["NEC", reference.code],
            examType: user?.examType.rawValue,
            jurisdiction: normalizedJurisdiction(for: user),
            lesson: nil,
            quizReview: nil,
            necDetail: .init(
                necId: reference.id,
                code: reference.code,
                title: reference.title,
                summary: reference.summary
            )
        )
    }

    private static func normalizedJurisdiction(for user: WWUser?) -> String? {
        guard let state = user?.state.trimmingCharacters(in: .whitespacesAndNewlines),
              !state.isEmpty else {
            return nil
        }
        return state.uppercased()
    }
}

final class MockTutorService: TutorServiceProtocol {
    func sendMessage(
        _ text: String,
        context: TutorContext?,
        history _: [TutorMessage],
        sessionID: UUID?
    ) async throws -> TutorSendResult {
        try await Task.sleep(for: .milliseconds(1200))

        let responses: [(String, [String], [String], [String])] = [
            (
                "That's a great question! Ohm's Law (V = IR) is the foundation of all electrical calculations. Voltage equals current times resistance.",
                ["Identify your known values (any two of V, I, R)", "Rearrange the formula: V=IR, I=V/R, R=V/I", "Calculate and verify units: volts, amps, ohms"],
                ["Start with the two values you know before touching the formula.", "Write the unit beside the answer so you catch setup mistakes."],
                ["How do I apply this to a 240V circuit?", "What's the power formula?", "Can you give me a practice problem?"]
            ),
            (
                "GFCI protection is one of the most tested topics on the electrical exam. It's required wherever water and electricity might meet.",
                ["NEC 210.8 is the starting point for required GFCI locations", "Bathrooms and garages are classic tested locations", "Outdoor receptacles are another frequent exam category", "On exam questions, verify the exact occupancy and code cycle before choosing the answer"],
                ["Use the location first, then verify the occupancy and code cycle.", "Do not assume a state is already on the newest NEC edition."],
                ["What about AFCI vs GFCI?", "Are there exceptions to GFCI requirements?", "What code cycle introduced new GFCI requirements?"]
            ),
            (
                "Grounding and bonding serve different purposes, and this distinction is heavily tested. Don't mix them up!",
                ["Grounding: connects to earth to establish a reference voltage", "Bonding: connects metal parts together to equalize potential", "Grounding protects against lightning; bonding protects against touch hazards"],
                ["If the question is about fault-current path, think bonding first.", "If the question is about earth reference or electrode system, think grounding."],
                ["What is a grounding electrode system?", "Where is bonding required?", "Explain NEC 250.50"]
            )
        ]

        let choice = responses.randomElement()!
        let references: [String]
        switch context?.type {
        case .lesson:
            references = context?.lesson?.necReferences ?? []
        case .quizReview:
            references = context?.quizReview?.focusedQuestion?.referenceCode.map { [$0] } ?? []
        case .necDetail:
            references = context?.necDetail.map { [$0.code] } ?? []
        default:
            references = []
        }

        return TutorSendResult(
            message: TutorMessage(
                id: UUID(),
                content: choice.0,
                role: .assistant,
                timestamp: Date(),
                steps: choice.1,
                bullets: choice.2,
                references: references,
                followUps: choice.3
            ),
            sessionId: sessionID ?? UUID(),
            usage: nil
        )
    }
}

// MARK: - NEC Service

protocol NECServiceProtocol: AnyObject {
    func search(query: String) async throws -> [NECSearchResult]
    func detail(id: UUID) async throws -> NECReference
    func explain(id: UUID) async throws -> NECExplanationResult
}

final class MockNECService: NECServiceProtocol {
    func search(query: String) async throws -> [NECSearchResult] {
        try await Task.sleep(for: .milliseconds(400))
        return try WattWiseContentRuntimeAdapter.searchNEC(query: query)
    }

    func detail(id: UUID) async throws -> NECReference {
        try await Task.sleep(for: .milliseconds(300))
        return try WattWiseContentRuntimeAdapter.necReference(id: id)
    }

    func explain(id: UUID) async throws -> NECExplanationResult {
        try await Task.sleep(for: .milliseconds(1000))
        let reference = try WattWiseContentRuntimeAdapter.necReference(id: id)
        if let expanded = reference.expanded, expanded.isEmpty == false {
            return NECExplanationResult(expanded: expanded, usage: nil)
        }
        return NECExplanationResult(
            expanded: "\(reference.title) matters because it shapes how electricians apply NEC \(reference.code) in the field and on open-book exams. Start with the simplified summary, then ask what hazard or design problem the rule is trying to control. For exam prep, the safest habit is to connect the article number to the installation decision it changes instead of memorizing the citation by itself.",
            usage: nil
        )
    }
}

// MARK: - Progress Service

protocol ProgressServiceProtocol: AnyObject {
    func fetchSummary() async throws -> ProgressSummary
}

final class MockProgressService: ProgressServiceProtocol {
    func fetchSummary() async throws -> ProgressSummary {
        try await Task.sleep(for: .milliseconds(500))
        return try WattWiseContentRuntimeAdapter.loadProgressSummary()
    }
}

// MARK: - Subscription Service

protocol SubscriptionServiceProtocol: AnyObject {
    var state: SubscriptionState { get }
    func fetchState() async throws -> SubscriptionState
    func purchase(productId: String) async throws -> SubscriptionState
    func restorePurchases() async throws -> SubscriptionState
}

@MainActor
final class MockSubscriptionService: SubscriptionServiceProtocol {
    private(set) var state: SubscriptionState = .preview

    func fetchState() async throws -> SubscriptionState {
        try await Task.sleep(for: .milliseconds(300))
        return state
    }

    func purchase(productId: String) async throws -> SubscriptionState {
        try await Task.sleep(for: .milliseconds(1500))
        if productId == AccessProductID.fastTrack.rawValue {
            state = .fastTrack
        } else {
            state = .fullPrep
        }
        return state
    }

    func restorePurchases() async throws -> SubscriptionState {
        try await Task.sleep(for: .milliseconds(800))
        return state
    }
}

// MARK: - App Error

enum AppError: LocalizedError {
    case invalidInput(String)
    case networkError(String)
    case notFound(String)
    case unauthorized
    case rateLimited
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidInput(let msg): return msg
        case .networkError(let msg): return msg
        case .notFound(let msg): return msg
        case .unauthorized: return "You need to sign in to continue."
        case .rateLimited: return "You've reached the limit for preview access. Choose Fast Track or Full Prep to keep going."
        case .unknown: return "Something went wrong. Please try again."
        }
    }
}

// MARK: - Service Container

@Observable
@MainActor
final class ServiceContainer {
    let auth: any AuthServiceProtocol
    let content: any ContentServiceProtocol
    let quiz: any QuizServiceProtocol
    let tutor: any TutorServiceProtocol
    let nec: any NECServiceProtocol
    let progress: any ProgressServiceProtocol
    let subscription: any SubscriptionServiceProtocol

    init(
        auth: any AuthServiceProtocol,
        content: any ContentServiceProtocol,
        quiz: any QuizServiceProtocol,
        tutor: any TutorServiceProtocol,
        nec: any NECServiceProtocol,
        progress: any ProgressServiceProtocol,
        subscription: any SubscriptionServiceProtocol
    ) {
        self.auth = auth
        self.content = content
        self.quiz = quiz
        self.tutor = tutor
        self.nec = nec
        self.progress = progress
        self.subscription = subscription
    }

    convenience init() {
        if AppConfig.useMockServices {
            self.init(
                auth: MockAuthService(),
                content: MockContentService(),
                quiz: MockQuizService(),
                tutor: MockTutorService(),
                nec: MockNECService(),
                progress: MockProgressService(),
                subscription: MockSubscriptionService()
            )
        } else {
            self.init(
                auth: SupabaseAuthService(),
                content: SupabaseContentService(),
                quiz: SupabaseQuizService(),
                tutor: SupabaseTutorService(),
                nec: SupabaseNECService(),
                progress: SupabaseProgressService(),
                subscription: SupabaseSubscriptionService()
            )
        }
    }
}
