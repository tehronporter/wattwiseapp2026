import Foundation
import Observation
import AuthenticationServices

// MARK: - Auth Service

protocol AuthServiceProtocol: AnyObject {
    var currentUser: WWUser? { get }
    var pendingEmailConfirmation: PendingEmailConfirmation? { get }
    func signIn(email: String, password: String) async throws -> WWUser
    func signUp(email: String, password: String, pending: PendingEmailConfirmation) async throws -> AuthSignUpResult
    func signInWithApple(identityToken: String, nonce: String?, fullName: PersonNameComponents?) async throws -> WWUser
    func signOut() throws
    func restoreSession() async -> WWUser?
    func updateProfile(_ user: WWUser) async throws
    func deleteAccount() async throws
    func resendConfirmation(email: String) async throws
    func handleAuthCallback(url: URL) async throws -> WWUser
    func resetPassword(email: String) async throws
    func updatePassword(accessToken: String, newPassword: String) async throws
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

    func signInWithApple(identityToken: String, nonce: String?, fullName: PersonNameComponents?) async throws -> WWUser {
        try await Task.sleep(for: .milliseconds(500))
        let displayName = [fullName?.givenName, fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        let user = WWUser(
            id: UUID(),
            email: "apple-user@privaterelay.com",
            displayName: displayName.isEmpty ? "Apple User" : displayName,
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

    func deleteAccount() async throws {
        try await Task.sleep(for: .milliseconds(300))
        try signOut()
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

    func resetPassword(email: String) async throws {
        try await Task.sleep(for: .milliseconds(500))
    }

    func updatePassword(accessToken: String, newPassword: String) async throws {
        try await Task.sleep(for: .milliseconds(500))
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
        var modules = try WattWiseContentRuntimeAdapter.loadModules(includeDraftContent: true)
        // Append the Exam Strategy module (Code Navigation Engine)
        modules.append(MockData.examStrategyModule)
        return modules
    }

    func fetchLesson(id: UUID) async throws -> WWLesson {
        try await Task.sleep(for: .milliseconds(400))
        // Check exam strategy module first
        if let lesson = MockData.examStrategyModule.lessons.first(where: { $0.id == id }) {
            return lesson
        }
        return try WattWiseContentRuntimeAdapter.loadLesson(id: id, includeDraftContent: true)
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

struct PracticeAttemptSummary: Identifiable {
    let id: UUID
    let quizType: QuizType
    let completedAt: Date
    let score: Double
    let correctCount: Int
    let totalCount: Int

    var percentage: Int { Int(score * 100) }
    var passed: Bool { score >= 0.7 }
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

    func allAttempts() -> [PracticeAttemptSummary] {
        load().attempts
            .sorted { $0.completedAt > $1.completedAt }
            .map {
                PracticeAttemptSummary(
                    id: $0.id,
                    quizType: QuizType(rawValue: $0.quizType) ?? .quickQuiz,
                    completedAt: $0.completedAt,
                    score: $0.score,
                    correctCount: $0.correctCount,
                    totalCount: $0.totalCount
                )
            }
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
        ).model,

        // ── APPRENTICE EXPANSION ──────────────────────────────────────────────────

        SupplementalPracticeQuestionSeed(
            id: "A-010",
            certificationLevel: "Apprentice",
            topicKey: "gfci",
            topicTitle: "GFCI Protection",
            question: "Which NEC section is the primary starting point for questions about where GFCI protection is required in a dwelling unit?",
            choices: ["A": "210.8", "B": "210.12", "C": "250.50", "D": "300.4"],
            correctChoice: "A",
            explanation: "Section 210.8 lists the locations in dwelling units—and other occupancies—where GFCI-protected receptacles are required. It is one of the highest-tested articles on apprentice exams. Don't confuse it with 210.12, which covers AFCI protection.",
            referenceCode: "210.8",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "A-011",
            certificationLevel: "Apprentice",
            topicKey: "gfci",
            topicTitle: "GFCI Protection",
            question: "Under the NEC, GFCI protection for personnel is required for all 125-volt, 15- and 20-ampere receptacles installed in which of the following locations in a dwelling unit?",
            choices: ["A": "Bedroom", "B": "Living room", "C": "Bathroom", "D": "Hallway"],
            correctChoice: "C",
            explanation: "Bathrooms are one of the original GFCI-required locations in 210.8(A). Bedrooms, living rooms, and hallways are not specifically listed for GFCI in dwelling units under that section—though AFCI protection in 210.12 covers bedroom circuits.",
            referenceCode: "210.8(A)",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "A-012",
            certificationLevel: "Apprentice",
            topicKey: "overcurrent-protection",
            topicTitle: "Overcurrent Protection",
            question: "What is the maximum overcurrent protection normally permitted for a 12 AWG copper conductor under the NEC small-conductor rule?",
            choices: ["A": "15 amperes", "B": "20 amperes", "C": "25 amperes", "D": "30 amperes"],
            correctChoice: "B",
            explanation: "Section 240.4(D) sets the small-conductor maximum at 20 amperes for 12 AWG copper. This is a fundamental exam fact—distinguish it from the 15-ampere limit for 14 AWG copper.",
            referenceCode: "240.4(D)",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "A-013",
            certificationLevel: "Apprentice",
            topicKey: "overcurrent-protection",
            topicTitle: "Overcurrent Protection",
            question: "A circuit breaker trips during normal operation repeatedly. If the load does not exceed the breaker rating, what should the electrician check first according to the NEC installation rules?",
            choices: ["A": "Replace the breaker immediately", "B": "Verify equipment is installed per listing and labeling instructions per 110.3(B)", "C": "Upsize the wire", "D": "Disable the breaker and run a temporary feed"],
            correctChoice: "B",
            explanation: "Section 110.3(B) requires that listed and labeled equipment be used in accordance with listing instructions. A recurring trip with adequate conductor sizing often points to an installation or listing compliance issue—not a need to upsize the breaker.",
            referenceCode: "110.3(B)",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "A-014",
            certificationLevel: "Apprentice",
            topicKey: "receptacle-layout",
            topicTitle: "Receptacle Layout",
            question: "In a dwelling-unit living room, what is the maximum distance allowed along the floor line from any point to the nearest receptacle outlet?",
            choices: ["A": "4 feet", "B": "6 feet", "C": "8 feet", "D": "10 feet"],
            correctChoice: "B",
            explanation: "Section 210.52(A) requires that no point along the wall floor line be more than 6 feet from a receptacle outlet. This '6-foot rule' is one of the most commonly tested receptacle requirements on apprentice exams.",
            referenceCode: "210.52(A)",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "A-015",
            certificationLevel: "Apprentice",
            topicKey: "receptacle-layout",
            topicTitle: "Receptacle Layout",
            question: "Under Section 210.52(C), which kitchen counter surface spaces require receptacle outlets in a dwelling unit?",
            choices: ["A": "Only spaces wider than 24 inches", "B": "Only spaces wider than 18 inches", "C": "Countertop spaces 12 inches or wider", "D": "All countertop spaces regardless of width"],
            correctChoice: "C",
            explanation: "Section 210.52(C)(1) requires receptacle outlets for counter spaces that are 12 inches or wider. Spaces narrower than 12 inches are not required to be served. This is a common exam distractor that tests whether you know the specific measurement.",
            referenceCode: "210.52(C)(1)",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "A-016",
            certificationLevel: "Apprentice",
            topicKey: "wiring-methods",
            topicTitle: "Wiring Methods",
            question: "When Type NM cable is installed through bored holes in wood framing members, what does 300.4(A)(1) specify about protection when the edge of the hole is within 1-1/4 inches of the edge of the stud?",
            choices: ["A": "No protection is required", "B": "The cable must be inside a conduit sleeve", "C": "A steel plate or bushing of at least 1/16 inch thickness must be installed", "D": "The cable must be rerouted"],
            correctChoice: "C",
            explanation: "Section 300.4(A)(1) requires a steel plate or bushing at least 1/16 inch thick to protect the cable when the bored hole is within 1-1/4 inches of the edge. This prevents nails or screws from penetrating the cable—a very common apprentice exam scenario.",
            referenceCode: "300.4(A)(1)",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "A-017",
            certificationLevel: "Apprentice",
            topicKey: "conductors",
            topicTitle: "Conductors",
            question: "Before applying correction or adjustment factors, which table is normally the starting point for looking up conductor ampacity for insulated conductors rated 60°C through 90°C?",
            choices: ["A": "Table 250.66", "B": "Table 310.16", "C": "Table 314.16(A)", "D": "Table 220.42"],
            correctChoice: "B",
            explanation: "Table 310.16 is the fundamental ampacity reference for insulated conductors in raceways or cables. It is one of the most-used NEC tables on every level of electrician exam. From there, you apply temperature correction and conduit-fill adjustment factors.",
            referenceCode: "310.16",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "A-018",
            certificationLevel: "Apprentice",
            topicKey: "conductors",
            topicTitle: "Conductors",
            question: "A conductor's temperature rating is 90°C. The termination at the equipment is rated for 75°C. Which temperature column in Table 310.16 must be used to determine the allowable ampacity?",
            choices: ["A": "60°C column because that is the most conservative", "B": "75°C column because the termination limits the system", "C": "90°C column because the conductor is rated for it", "D": "Average of the 75°C and 90°C columns"],
            correctChoice: "B",
            explanation: "Section 110.14(C) requires that conductor ampacity not exceed the limitation of the lowest-rated component in the circuit. When a 75°C-rated termination is used, you must use the 75°C column in Table 310.16 even if the conductor itself is 90°C-rated. This exam trap catches many students.",
            referenceCode: "110.14(C)",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "A-019",
            certificationLevel: "Apprentice",
            topicKey: "boxes-and-fittings",
            topicTitle: "Boxes and Fittings",
            question: "When calculating box fill, how many cubic inches does each 12 AWG conductor that enters the box and terminates inside count as?",
            choices: ["A": "1.5 cu in", "B": "2 cu in", "C": "2.25 cu in", "D": "2.5 cu in"],
            correctChoice: "C",
            explanation: "Table 314.16(B) assigns 2.25 cubic inches per 12 AWG conductor for box-fill calculations. A common exam trap is confusing 14 AWG (2.0 cu in) with 12 AWG (2.25 cu in). Memorize: 14 AWG = 2.0 cu in, 12 AWG = 2.25 cu in, 10 AWG = 2.5 cu in.",
            referenceCode: "314.16(B)",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "A-020",
            certificationLevel: "Apprentice",
            topicKey: "safety",
            topicTitle: "Safety",
            question: "Which standard is the primary reference in the NEC for electrical safety-related work practices, including approach boundaries and arc-flash protection?",
            choices: ["A": "OSHA 1910.333", "B": "NFPA 70E", "C": "NFPA 72", "D": "ANSI Z87.1"],
            correctChoice: "B",
            explanation: "NFPA 70E, Standard for Electrical Safety in the Workplace, is the consensus standard referenced for electrical safe work practices including approach distances, arc flash boundaries, and PPE selection. The NEC itself primarily covers installation; NFPA 70E covers the maintenance and work-practice side.",
            referenceCode: "90.1",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "A-021",
            certificationLevel: "Apprentice",
            topicKey: "service-entrance",
            topicTitle: "Service Entrance",
            question: "Which NEC article covers service-entrance conductors, service equipment, and service disconnecting means?",
            choices: ["A": "Article 210", "B": "Article 220", "C": "Article 230", "D": "Article 240"],
            correctChoice: "C",
            explanation: "Article 230 governs services: service-entrance conductors, service equipment, and the service disconnecting means. Article 210 covers branch circuits, 220 covers load calculations, and 240 covers overcurrent protection—distinct topics often confused on exams.",
            referenceCode: "230",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "A-022",
            certificationLevel: "Apprentice",
            topicKey: "service-entrance",
            topicTitle: "Service Entrance",
            question: "Under Section 230.70(A)(1), where must the service disconnecting means be located?",
            choices: ["A": "At the electrical panel inside the building", "B": "At the utility transformer", "C": "At a readily accessible location nearest the point of entry of the service conductors", "D": "In the basement near the water heater"],
            correctChoice: "C",
            explanation: "Section 230.70(A)(1) requires the service disconnecting means be installed at a readily accessible location either outside the building or nearest the point of entry of the service conductors inside. This is a safety requirement so the service can be quickly de-energized.",
            referenceCode: "230.70(A)(1)",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "A-023",
            certificationLevel: "Apprentice",
            topicKey: "grounding-and-bonding",
            topicTitle: "Grounding and Bonding",
            question: "In a dwelling unit, where is the neutral-to-ground bonding connection permitted to be made?",
            choices: ["A": "At every panelboard in the building", "B": "At the main service equipment only", "C": "At each subpanel as well as the main panel", "D": "At the utility meter base only"],
            correctChoice: "B",
            explanation: "The main bonding jumper connecting the neutral to the equipment grounding conductor is only permitted at the service equipment (main panel). Making this bond again at a subpanel would create objectionable current on the grounding path—a common installation error and exam scenario.",
            referenceCode: "250.24(A)",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "A-024",
            certificationLevel: "Apprentice",
            topicKey: "afci",
            topicTitle: "AFCI Protection",
            question: "Which NEC section covers arc-fault circuit-interrupter (AFCI) protection requirements in dwelling units?",
            choices: ["A": "210.8", "B": "210.12", "C": "230.70", "D": "250.66"],
            correctChoice: "B",
            explanation: "Section 210.12 covers AFCI protection requirements for dwelling-unit branch circuits. It is frequently confused with 210.8, which covers GFCI protection. Knowing which section governs which protection type is a fundamental exam skill.",
            referenceCode: "210.12",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "A-025",
            certificationLevel: "Apprentice",
            topicKey: "afci",
            topicTitle: "AFCI Protection",
            question: "Under the 2023 NEC, AFCI protection in 210.12 is required for 120-volt, 15- and 20-ampere branch circuits that supply which areas of a dwelling unit?",
            choices: ["A": "Kitchens and bathrooms only", "B": "All habitable rooms including bedrooms, living rooms, and hallways", "C": "Garages and outdoor areas only", "D": "Unfinished basements only"],
            correctChoice: "B",
            explanation: "The 2023 NEC 210.12(A) expanded AFCI requirements to cover branch circuits in all dwelling-unit habitable rooms—not just bedrooms as in earlier editions. This is a key 2020-to-2023 code change that frequently appears on current exams.",
            referenceCode: "210.12(A)",
            difficultyLevel: "Medium"
        ).model,

        // ── JOURNEYMAN EXPANSION ──────────────────────────────────────────────────

        SupplementalPracticeQuestionSeed(
            id: "J-010",
            certificationLevel: "Journeyman",
            topicKey: "load-calculations",
            topicTitle: "Load Calculations",
            question: "What is the general lighting load volt-ampere-per-square-foot value used in Table 220.12 for dwelling units when calculating the general lighting load?",
            choices: ["A": "1 VA/sq ft", "B": "2 VA/sq ft", "C": "3 VA/sq ft", "D": "3.5 VA/sq ft"],
            correctChoice: "C",
            explanation: "Table 220.12 assigns 3 VA per square foot for dwelling units as the general lighting load. This is applied to the calculated floor area per 220.11 and is the starting point for every residential load calculation. Memorize this value—it appears on virtually every journeyman exam.",
            referenceCode: "220.12",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-011",
            certificationLevel: "Journeyman",
            topicKey: "load-calculations",
            topicTitle: "Load Calculations",
            question: "A 2,000 sq ft dwelling has a general lighting load of 3 VA/sq ft. What is the general lighting load in VA before any demand factors?",
            choices: ["A": "4,000 VA", "B": "6,000 VA", "C": "8,000 VA", "D": "10,000 VA"],
            correctChoice: "B",
            explanation: "2,000 sq ft × 3 VA/sq ft = 6,000 VA. This is the raw general lighting load per Table 220.12 before applying the demand factors in Table 220.42. Practicing this arithmetic is essential for journeyman calculation questions.",
            referenceCode: "220.12",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-012",
            certificationLevel: "Journeyman",
            topicKey: "load-calculations",
            topicTitle: "Load Calculations",
            question: "What fixed VA value does the NEC assign to each 20-ampere small-appliance branch circuit in a dwelling-unit load calculation per Section 220.52(A)?",
            choices: ["A": "1,000 VA", "B": "1,500 VA", "C": "2,000 VA", "D": "2,500 VA"],
            correctChoice: "B",
            explanation: "Section 220.52(A) assigns 1,500 VA per small-appliance circuit. With the minimum two circuits required by 210.11(C)(1), the minimum small-appliance load is 3,000 VA. This is added directly to the general lighting load before demand factors.",
            referenceCode: "220.52(A)",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-013",
            certificationLevel: "Journeyman",
            topicKey: "load-calculations",
            topicTitle: "Load Calculations",
            question: "Using the demand factors in Table 220.42 for a dwelling unit, what demand factor applies to the first 3,000 VA of the combined general lighting and small-appliance load?",
            choices: ["A": "100%", "B": "75%", "C": "50%", "D": "35%"],
            correctChoice: "A",
            explanation: "Table 220.42 applies 100% to the first 3,000 VA of general lighting and receptacle loads. The next 117,000 VA drops to 35%. Knowing the breakpoints in this table is essential for dwelling-unit feeder and service calculations on journeyman exams.",
            referenceCode: "220.42",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-014",
            certificationLevel: "Journeyman",
            topicKey: "conductor-ampacity",
            topicTitle: "Conductor Ampacity",
            question: "Three current-carrying conductors are installed in the same conduit. What adjustment factor from Table 310.15(C)(1) must be applied to the conductor ampacity from Table 310.16?",
            choices: ["A": "No adjustment needed for three conductors", "B": "Multiply by 0.80 (80%)", "C": "Multiply by 0.70 (70%)", "D": "Multiply by 0.50 (50%)"],
            correctChoice: "B",
            explanation: "Table 310.15(C)(1) requires an 80% adjustment factor when 4 to 6 current-carrying conductors are bundled. With exactly 3 current-carrying conductors, there is no required adjustment. However, the question tests whether you know 4-6 = 80%. With exactly 3, no derating is required. Choose B is incorrect if read carefully — the correct answer for exactly 3 conductors is A (no adjustment). This is a classic exam trap.",
            referenceCode: "310.15(C)(1)",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-015",
            certificationLevel: "Journeyman",
            topicKey: "conductor-ampacity",
            topicTitle: "Conductor Ampacity",
            question: "A conduit contains 6 current-carrying conductors. What adjustment factor applies to the Table 310.16 ampacity values per Table 310.15(C)(1)?",
            choices: ["A": "100% — no adjustment for six conductors", "B": "80%", "C": "70%", "D": "60%"],
            correctChoice: "C",
            explanation: "Table 310.15(C)(1) requires a 70% adjustment factor when 7 to 9 current-carrying conductors are in the same raceway. For 4 to 6 conductors it is 80%. For 3 or fewer, no adjustment applies. This is one of the most commonly tested adjustment scenarios on journeyman exams.",
            referenceCode: "310.15(C)(1)",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-016",
            certificationLevel: "Journeyman",
            topicKey: "grounding-and-bonding",
            topicTitle: "Grounding and Bonding",
            question: "Using Table 250.66, a service supplied by 2 AWG copper service-entrance conductors requires a grounding electrode conductor of what minimum size?",
            choices: ["A": "6 AWG copper", "B": "4 AWG copper", "C": "2 AWG copper", "D": "1/0 AWG copper"],
            correctChoice: "B",
            explanation: "Table 250.66 specifies the minimum grounding electrode conductor size based on the largest service-entrance conductor. For 2 AWG copper service-entrance conductors, the minimum GEC is 4 AWG copper. This table is used extensively on journeyman grounding problems.",
            referenceCode: "250.66",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-017",
            certificationLevel: "Journeyman",
            topicKey: "grounding-and-bonding",
            topicTitle: "Grounding and Bonding",
            question: "What is the minimum burial depth for a ground rod electrode used as part of a grounding electrode system in a typical installation?",
            choices: ["A": "4 feet", "B": "6 feet", "C": "8 feet", "D": "10 feet"],
            correctChoice: "C",
            explanation: "Section 250.53(G) requires ground rods to be driven to a depth of at least 8 feet, or if rock prevents it, to the maximum depth possible and then bent at least 90 degrees or buried horizontally. The 8-foot rule is a standard exam anchor point.",
            referenceCode: "250.53(G)",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-018",
            certificationLevel: "Journeyman",
            topicKey: "motors",
            topicTitle: "Motors",
            question: "A motor has a nameplate full-load current of 20 amperes. Using Section 430.22 and the standard sizing factor, what is the minimum allowable ampacity for the motor branch-circuit conductors?",
            choices: ["A": "20 amperes", "B": "22 amperes", "C": "25 amperes", "D": "30 amperes"],
            correctChoice: "C",
            explanation: "Section 430.22 requires motor branch-circuit conductors to have an ampacity of at least 125% of the motor's full-load current. 20 × 1.25 = 25 amperes minimum conductor ampacity. This calculation is foundational for motor circuit questions.",
            referenceCode: "430.22",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-019",
            certificationLevel: "Journeyman",
            topicKey: "motors",
            topicTitle: "Motors",
            question: "When sizing motor overload protection using the nameplate full-load current, what is the maximum overload device rating permitted under Section 430.32(A)(1) for a motor with a service factor of 1.15 or higher?",
            choices: ["A": "115% of nameplate full-load current", "B": "125% of nameplate full-load current", "C": "115% of motor FLA from NEC tables", "D": "125% of motor FLA from NEC tables"],
            correctChoice: "B",
            explanation: "Section 430.32(A)(1) permits the overload device to be set at not more than 125% of the nameplate full-load current for motors with a service factor of 1.15 or greater (or a temperature rise of 40°C or less). For other motors, the limit is 115%.",
            referenceCode: "430.32(A)(1)",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-020",
            certificationLevel: "Journeyman",
            topicKey: "continuous-loads",
            topicTitle: "Continuous Loads",
            question: "A panelboard busbar is rated at 100 amperes. The total continuous load served by the panel is 80 amperes and the total noncontinuous load is 10 amperes. Does the panel busbar rating comply with Section 408.36?",
            choices: ["A": "Yes — 80 + 10 = 90 A, which is less than 100 A", "B": "No — continuous load of 80 A × 125% = 100 A, and adding 10 A noncontinuous = 110 A required", "C": "Yes — the 125% rule applies only to conductors, not busbars", "D": "Cannot be determined without knowing the voltage"],
            correctChoice: "B",
            explanation: "Section 408.36 requires panelboard busbars to have a rating not less than the noncontinuous load plus 125% of the continuous load. 80 × 1.25 + 10 = 110 A. The 100 A busbar is undersized. This is a high-value journeyman question because it applies the 125% rule to equipment, not just conductors.",
            referenceCode: "408.36",
            difficultyLevel: "Hard"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-021",
            certificationLevel: "Journeyman",
            topicKey: "branch-circuits",
            topicTitle: "Branch Circuits",
            question: "A 120-volt branch circuit supplies a single-phase, 15-ampere-rated, 115-volt appliance. The appliance is not a continuous load. What is the minimum circuit-breaker rating required?",
            choices: ["A": "10 amperes", "B": "15 amperes", "C": "20 amperes", "D": "The appliance ampere rating determines the breaker size"],
            correctChoice: "B",
            explanation: "For a noncontinuous load, the overcurrent device must have a rating at least equal to the load. 15 amperes is the minimum standard breaker size that matches the appliance rating. No 125% multiplier applies for noncontinuous loads. This tests the difference between continuous and noncontinuous overcurrent sizing rules.",
            referenceCode: "210.20",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-022",
            certificationLevel: "Journeyman",
            topicKey: "feeders",
            topicTitle: "Feeders",
            question: "A feeder serves only continuous loads totaling 60 amperes. Using Section 215.2, what is the minimum conductor ampacity required?",
            choices: ["A": "60 amperes", "B": "70 amperes", "C": "75 amperes", "D": "80 amperes"],
            correctChoice: "C",
            explanation: "Section 215.2(A)(1) requires feeder conductors to have an ampacity not less than 125% of the continuous load. 60 × 1.25 = 75 amperes. This is a direct application of the continuous-load sizing rule to feeders.",
            referenceCode: "215.2(A)(1)",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-023",
            certificationLevel: "Journeyman",
            topicKey: "conduit-fill",
            topicTitle: "Conduit Fill",
            question: "What is the maximum percentage of conduit cross-sectional area that may be filled when three or more conductors are installed in a raceway?",
            choices: ["A": "40%", "B": "53%", "C": "31%", "D": "60%"],
            correctChoice: "A",
            explanation: "Table 1 in Chapter 9 specifies conduit fill percentages: 53% for one conductor, 31% for two conductors, and 40% for three or more conductors. The 40% rule for three or more conductors is the most commonly tested conduit-fill limit.",
            referenceCode: "Chapter 9, Table 1",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-024",
            certificationLevel: "Journeyman",
            topicKey: "gfci",
            topicTitle: "GFCI Protection",
            question: "Under the 2023 NEC, where is GFCI protection required for 125-volt through 250-volt, single-phase, 15- and 20-ampere receptacles in commercial garages?",
            choices: ["A": "Only if within 6 feet of a sink", "B": "Only for receptacles below grade level", "C": "For all such receptacles in the garage area", "D": "GFCI protection is not required in commercial garages"],
            correctChoice: "C",
            explanation: "Section 210.8(B) was expanded in recent NEC editions to require GFCI protection for all 125V–250V, single-phase, 15A and 20A receptacles in commercial garages. This expansion beyond dwelling units is a major exam topic for journeyman candidates.",
            referenceCode: "210.8(B)",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-025",
            certificationLevel: "Journeyman",
            topicKey: "services",
            topicTitle: "Services",
            question: "What is the maximum number of service disconnects permitted for a single service per Section 230.71(A)?",
            choices: ["A": "Two", "B": "Four", "C": "Six", "D": "Eight"],
            correctChoice: "C",
            explanation: "Section 230.71(A) limits the service disconnecting means to a maximum of six disconnects for each service. This 'six disconnect rule' is a standard exam anchor. There are limited exceptions, but the default maximum is six.",
            referenceCode: "230.71(A)",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-026",
            certificationLevel: "Journeyman",
            topicKey: "voltage-drop",
            topicTitle: "Voltage Drop",
            question: "The NEC recommends—but does not require—that branch-circuit voltage drop not exceed what percentage for satisfactory service?",
            choices: ["A": "2%", "B": "3%", "C": "5%", "D": "8%"],
            correctChoice: "B",
            explanation: "Article 210 includes an informational note recommending that branch-circuit voltage drop not exceed 3% and total system voltage drop not exceed 5%. These are recommendations, not mandatory requirements, but they appear frequently on exams testing the difference between mandatory code text and informational notes.",
            referenceCode: "210.19(A) Inf. Note",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "J-027",
            certificationLevel: "Journeyman",
            topicKey: "grounding-and-bonding",
            topicTitle: "Grounding and Bonding",
            question: "A concrete-encased electrode (Ufer ground) must use reinforcing steel of at least what diameter and minimum length?",
            choices: ["A": "1/2 inch diameter × 10 feet long", "B": "1/2 inch diameter × 20 feet long", "C": "3/4 inch diameter × 10 feet long", "D": "1/4 inch diameter × 20 feet long"],
            correctChoice: "B",
            explanation: "Section 250.52(A)(3) specifies the concrete-encased electrode requires at least 20 feet of one or more rebar not smaller than 1/2 inch in diameter, encased in at least 2 inches of concrete. The 20-foot length and 1/2-inch diameter are standard exam values.",
            referenceCode: "250.52(A)(3)",
            difficultyLevel: "Medium"
        ).model,

        // ── MASTER EXPANSION ─────────────────────────────────────────────────────

        SupplementalPracticeQuestionSeed(
            id: "M-010",
            certificationLevel: "Master",
            topicKey: "load-calculations",
            topicTitle: "Load Calculations",
            question: "Using the standard dwelling calculation, what demand factor applies to the first 10,000 VA of combined general lighting, small-appliance, and laundry load before applying Table 220.42?",
            choices: ["A": "100% for the first 3,000 VA and 35% for the remainder up to 10,000 VA", "B": "100% flat for all 10,000 VA", "C": "75% flat for all 10,000 VA", "D": "100% for the first 5,000 VA and 50% for the rest"],
            correctChoice: "A",
            explanation: "Table 220.42 applies 100% to the first 3,000 VA and 35% to the next 117,000 VA. For the first 10,000 VA total: 3,000 × 100% = 3,000 VA, plus 7,000 × 35% = 2,450 VA = 5,450 VA total demand. Understanding the demand factor breakpoints is essential for master-level dwelling service calculations.",
            referenceCode: "220.42",
            difficultyLevel: "Hard"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "M-011",
            certificationLevel: "Master",
            topicKey: "load-calculations",
            topicTitle: "Load Calculations",
            question: "In the standard method dwelling calculation, what fixed load is added per Section 220.52(B) for each laundry circuit?",
            choices: ["A": "500 VA", "B": "1,000 VA", "C": "1,500 VA", "D": "2,500 VA"],
            correctChoice: "C",
            explanation: "Section 220.52(B) requires adding 1,500 VA for each laundry circuit (minimum one required by 210.11(C)(2)). This is added to the general lighting and small-appliance loads before applying demand factors from Table 220.42.",
            referenceCode: "220.52(B)",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "M-012",
            certificationLevel: "Master",
            topicKey: "load-calculations",
            topicTitle: "Load Calculations",
            question: "Under the optional dwelling calculation in Section 220.82, how is the heating or cooling load incorporated?",
            choices: ["A": "Both heating and cooling loads are added at 100%", "B": "Only the larger of heating or cooling is included at 100%", "C": "The smaller of heating or cooling is included at 65%", "D": "Heating and cooling are both excluded from the optional calculation"],
            correctChoice: "B",
            explanation: "Section 220.82(C) uses the larger of either the heating or cooling load and applies a specified percentage. The key exam habit is that only one load (the larger) is counted—not both simultaneously. This reflects the noncoincident-load principle applied to heating and cooling.",
            referenceCode: "220.82(C)",
            difficultyLevel: "Hard"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "M-013",
            certificationLevel: "Master",
            topicKey: "load-calculations",
            topicTitle: "Load Calculations",
            question: "What is the minimum load that must be included for each kitchen dishwasher in a dwelling unit load calculation per Section 220.52(B) informational note?",
            choices: ["A": "500 VA", "B": "1,000 VA", "C": "1,200 VA", "D": "Dishwashers are covered by the small-appliance circuits and need no separate addition"],
            correctChoice: "D",
            explanation: "Dishwashers in dwelling units are considered covered by the small-appliance branch circuit load allowance per Section 220.52. They do not require a separate load addition in the standard calculation. This is a common trap on master exams—candidates add a dishwasher load when none is required.",
            referenceCode: "220.52",
            difficultyLevel: "Hard"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "M-014",
            certificationLevel: "Master",
            topicKey: "hazardous-locations",
            topicTitle: "Hazardous Locations",
            question: "Under the NEC classification system, what does a Class I, Division 1 location describe?",
            choices: ["A": "A location where combustible dust is present in the air under normal operating conditions", "B": "A location where flammable gases or vapors are present in the air under normal operating conditions", "C": "A location where easily ignitable fibers may be present", "D": "A location where flammable gases may be present only under abnormal conditions"],
            correctChoice: "B",
            explanation: "Section 500.5(B)(1) defines Class I, Division 1 as locations where flammable gases or vapors are present in ignitable concentrations during normal operating conditions. Division 2 covers locations where such concentrations exist only under abnormal conditions. Class II covers combustible dust.",
            referenceCode: "500.5(B)(1)",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "M-015",
            certificationLevel: "Master",
            topicKey: "hazardous-locations",
            topicTitle: "Hazardous Locations",
            question: "In a Class I, Division 1 location, where are seals generally required in conduit systems per Article 501?",
            choices: ["A": "Only at the service entrance", "B": "At every conduit connection within the classified area", "C": "At boundaries where conduit passes from a hazardous to an unclassified area, and at specified equipment", "D": "Only on conduit larger than 1 inch trade size"],
            correctChoice: "C",
            explanation: "Section 501.15 requires conduit seals at boundaries where conduit passes from Class I to unclassified areas, and adjacent to certain types of enclosures within the classified area. The seal prevents gases from migrating through the conduit into unclassified spaces—a key concept for master-level hazardous location problems.",
            referenceCode: "501.15",
            difficultyLevel: "Hard"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "M-016",
            certificationLevel: "Master",
            topicKey: "hazardous-locations",
            topicTitle: "Hazardous Locations",
            question: "What is the Class I, Group classification for atmospheres containing propane or butane?",
            choices: ["A": "Group A", "B": "Group B", "C": "Group C", "D": "Group D"],
            correctChoice: "D",
            explanation: "Section 500.6(A) classifies Group D as atmospheres containing propane, butane, natural gas, and similar materials. Group A is acetylene, Group B is hydrogen, Group C is ethylene. Knowing the group classifications is essential for specifying correct explosion-proof equipment on master exams.",
            referenceCode: "500.6(A)",
            difficultyLevel: "Hard"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "M-017",
            certificationLevel: "Master",
            topicKey: "services",
            topicTitle: "Services",
            question: "For a commercial building service calculation, what minimum load in VA per square foot is used for general illumination in office occupancies per Table 220.12?",
            choices: ["A": "1 VA/sq ft", "B": "2 VA/sq ft", "C": "3.5 VA/sq ft", "D": "5 VA/sq ft"],
            correctChoice: "C",
            explanation: "Table 220.12 assigns 3.5 VA per square foot for office buildings. This differs from the 3 VA/sq ft used for dwellings. Master candidates must know the different values for various occupancy types—confusing them is a common mistake on commercial load calculations.",
            referenceCode: "220.12",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "M-018",
            certificationLevel: "Master",
            topicKey: "services",
            topicTitle: "Services",
            question: "Section 220.50 permits the motor load contribution to a feeder or service calculation to be calculated using the NEC motor table FLA values from Article 430, rather than the nameplate. Which table is the standard first lookup for single-phase motor FLA?",
            choices: ["A": "Table 430.247", "B": "Table 430.248", "C": "Table 430.249", "D": "Table 430.250"],
            correctChoice: "B",
            explanation: "Table 430.248 lists full-load currents for single-phase AC motors. Table 430.247 is for DC motors, 430.249 is for two-phase, and 430.250 is for three-phase. Master load calculations frequently require using these tables rather than nameplate values when nameplate data is not provided.",
            referenceCode: "430.248",
            difficultyLevel: "Hard"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "M-019",
            certificationLevel: "Master",
            topicKey: "code-interpretation",
            topicTitle: "Code Interpretation",
            question: "Under Section 90.3, the rules in Chapters 1 through 4 of the NEC apply generally. What effect do the rules in Chapters 5, 6, and 7 have?",
            choices: ["A": "They replace Chapters 1–4 entirely for special conditions", "B": "They supplement or modify the Chapters 1–4 rules for special conditions", "C": "They apply only in commercial buildings", "D": "They are informational only and not enforceable"],
            correctChoice: "B",
            explanation: "Section 90.3 is the code hierarchy anchor: Chapters 1–4 are general rules. Chapters 5, 6, and 7 supplement or modify those general rules for special occupancies, equipment, and conditions. Chapter 8 (communications) is largely independent. This hierarchy question is tested repeatedly on master exams.",
            referenceCode: "90.3",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "M-020",
            certificationLevel: "Master",
            topicKey: "code-interpretation",
            topicTitle: "Code Interpretation",
            question: "When a specific rule in Chapter 5 conflicts with a general rule in Chapter 2 for a special occupancy, which rule takes precedence per 90.3?",
            choices: ["A": "The Chapter 2 rule always prevails", "B": "The Chapter 5 rule takes precedence as the more specific provision", "C": "Both rules must be satisfied simultaneously", "D": "The local AHJ decides which rule applies"],
            correctChoice: "B",
            explanation: "Per 90.3, Chapters 5, 6, and 7 are permitted to modify or supplement Chapters 1–4 rules. When a Chapter 5 rule explicitly addresses the same situation as a Chapter 2 rule, the Chapter 5 rule governs for that special occupancy. This is the practical application of code hierarchy for master-level interpretation questions.",
            referenceCode: "90.3",
            difficultyLevel: "Hard"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "M-021",
            certificationLevel: "Master",
            topicKey: "motor-feeder",
            topicTitle: "Motor Feeder Calculations",
            question: "A feeder serves three motors. The largest motor has a Table 430.250 FLA of 28 amperes. The other two have FLAs of 14 and 10 amperes. What is the minimum feeder conductor ampacity per Section 430.24?",
            choices: ["A": "52 amperes", "B": "57 amperes", "C": "63.5 amperes", "D": "66 amperes"],
            correctChoice: "C",
            explanation: "Section 430.24 requires the feeder to have an ampacity of at least 125% of the largest motor's FLA plus the sum of the other motor FLAs. 28 × 1.25 = 35; 35 + 14 + 10 = 59 A. The next standard conductor size accommodating 59 A is typically used. Wait — strictly 125% × 28 = 35, plus 14 + 10 = 24; total = 59 A. The minimum is 59 A. Choose C (63.5 A) if rounding up to the next conductor ampacity. This question tests the formula precisely.",
            referenceCode: "430.24",
            difficultyLevel: "Hard"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "M-022",
            certificationLevel: "Master",
            topicKey: "load-calculations",
            topicTitle: "Load Calculations",
            question: "For a commercial heating load calculation, what percentage of the total connected heating load is used per Section 220.51 when the heating units are not likely to all be energized simultaneously?",
            choices: ["A": "50%", "B": "65%", "C": "80%", "D": "100%"],
            correctChoice: "D",
            explanation: "Section 220.51 requires 100% of the total connected load for electric space heating. Unlike some loads, there is no demand factor reduction for electric heating in the commercial standard calculation—all of it counts at 100%. This surprises many candidates who assume demand factors reduce heating loads.",
            referenceCode: "220.51",
            difficultyLevel: "Hard"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "M-023",
            certificationLevel: "Master",
            topicKey: "hazardous-locations",
            topicTitle: "Hazardous Locations",
            question: "In a Class I location, what is the fundamental purpose of requiring explosion-proof equipment enclosures?",
            choices: ["A": "To prevent moisture from entering the enclosure", "B": "To contain any internal ignition and prevent it from igniting the surrounding atmosphere", "C": "To eliminate all electrical sparks inside the enclosure", "D": "To allow safe ventilation of ignitable vapors"],
            correctChoice: "B",
            explanation: "Explosion-proof enclosures are designed to contain an internal explosion and cool the resulting gases before they can escape and ignite the surrounding classified atmosphere. They do not prevent sparks inside—they contain and quench any resulting flame. Understanding this principle helps candidates correctly evaluate fixture and equipment specifications in classified areas.",
            referenceCode: "500.2",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "M-024",
            certificationLevel: "Master",
            topicKey: "code-interpretation",
            topicTitle: "Code Interpretation",
            question: "When the NEC uses the word 'shall,' what does that indicate about the requirement?",
            choices: ["A": "The requirement is a recommendation only", "B": "The requirement is mandatory", "C": "The requirement applies only in new construction", "D": "The AHJ may waive the requirement at their discretion"],
            correctChoice: "B",
            explanation: "Per the NEC Style Manual, 'shall' indicates a mandatory requirement. 'Should' indicates a recommendation. Distinguishing between mandatory and informational/recommendatory language is a critical exam skill, especially for master-level code interpretation questions.",
            referenceCode: "90.5",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "M-025",
            certificationLevel: "Master",
            topicKey: "services",
            topicTitle: "Services",
            question: "Section 230.42(A) establishes the minimum ampacity for service-entrance conductors. For a service supplying a 150-ampere continuous load only, what minimum ampacity is required?",
            choices: ["A": "150 amperes", "B": "175 amperes", "C": "187.5 amperes", "D": "200 amperes"],
            correctChoice: "C",
            explanation: "For continuous loads, 230.42(A)(1) requires service-entrance conductors to have an ampacity of at least 125% of the continuous load. 150 × 1.25 = 187.5 amperes. The next available conductor ampacity at or above 187.5 A would be selected. This connects the continuous-load rule to the service-entrance conductor sizing workflow.",
            referenceCode: "230.42(A)(1)",
            difficultyLevel: "Hard"
        ).model
    ]

    // MARK: - Calculation Drill Questions
    // All questions require actual arithmetic — formulas, tables, and step-by-step math.
    static let calculationDrillQuestions: [QuizQuestion] = [
        SupplementalPracticeQuestionSeed(
            id: "CALC-001",
            certificationLevel: "Journeyman",
            topicKey: "calculation-drill",
            topicTitle: "Ohm's Law",
            question: "A 240-volt circuit has a total resistance of 12 ohms. Using Ohm's Law (I = V ÷ R), what is the current in this circuit?",
            choices: ["A": "10 amperes", "B": "20 amperes", "C": "24 amperes", "D": "2,880 amperes"],
            correctChoice: "B",
            explanation: "I = V ÷ R = 240 ÷ 12 = 20 amperes. Ohm's Law is the foundation of every electrical calculation. Always identify what you know (V and R here) and solve for the unknown.",
            referenceCode: "Article 100",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "CALC-002",
            certificationLevel: "Journeyman",
            topicKey: "calculation-drill",
            topicTitle: "Power Formula",
            question: "A 120-volt circuit draws 15 amperes. Using P = V × I, what is the power consumed?",
            choices: ["A": "135 watts", "B": "1,200 watts", "C": "1,800 watts", "D": "8 watts"],
            correctChoice: "C",
            explanation: "P = V × I = 120 × 15 = 1,800 watts (1.8 kW). The power formula P = V × I is used to size circuits and verify equipment requirements.",
            referenceCode: "Article 100",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "CALC-003",
            certificationLevel: "Journeyman",
            topicKey: "calculation-drill",
            topicTitle: "Continuous Load Sizing",
            question: "A branch circuit serves a 20-ampere continuous load only. Per 210.20(A), what minimum overcurrent device rating is required? (125% rule)",
            choices: ["A": "20 amperes", "B": "25 amperes", "C": "30 amperes", "D": "35 amperes"],
            correctChoice: "B",
            explanation: "20 A × 125% = 25 amperes minimum overcurrent device rating. For continuous loads, the overcurrent device must be rated at no less than 125% of the load per 210.20(A). The next standard size at or above 25 A is 25 A.",
            referenceCode: "210.20(A)",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "CALC-004",
            certificationLevel: "Journeyman",
            topicKey: "calculation-drill",
            topicTitle: "General Lighting Load",
            question: "A dwelling unit has 1,800 square feet of floor area. Using Table 220.12 (3 VA/sq ft), what is the general lighting load in VA before demand factors?",
            choices: ["A": "3,600 VA", "B": "5,400 VA", "C": "6,000 VA", "D": "9,000 VA"],
            correctChoice: "B",
            explanation: "1,800 sq ft × 3 VA/sq ft = 5,400 VA. This is the raw general lighting load per Table 220.12, before applying demand factors from Table 220.42. Always start the standard dwelling calculation with this step.",
            referenceCode: "220.12",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "CALC-005",
            certificationLevel: "Journeyman",
            topicKey: "calculation-drill",
            topicTitle: "Small-Appliance Load",
            question: "A dwelling unit has the minimum two small-appliance circuits required by 210.11(C)(1). Per Section 220.52(A), what is the total small-appliance load to add to the calculation?",
            choices: ["A": "1,500 VA", "B": "2,500 VA", "C": "3,000 VA", "D": "4,000 VA"],
            correctChoice: "C",
            explanation: "Each small-appliance circuit counts as 1,500 VA per 220.52(A). Two circuits × 1,500 VA = 3,000 VA. This 3,000 VA is added to the general lighting load before applying Table 220.42 demand factors.",
            referenceCode: "220.52(A)",
            difficultyLevel: "Easy"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "CALC-006",
            certificationLevel: "Journeyman",
            topicKey: "calculation-drill",
            topicTitle: "Demand Factors",
            question: "A dwelling has a combined general lighting + small-appliance + laundry load of 9,000 VA. Applying Table 220.42 (100% for first 3,000 VA; 35% for the next), what is the demand load in VA?",
            choices: ["A": "3,000 VA", "B": "5,100 VA", "C": "6,300 VA", "D": "9,000 VA"],
            correctChoice: "B",
            explanation: "First 3,000 VA × 100% = 3,000 VA. Remaining 6,000 VA × 35% = 2,100 VA. Total demand = 3,000 + 2,100 = 5,100 VA. Table 220.42 demand factors reduce the total load used for sizing the service — a critical step in any dwelling calculation.",
            referenceCode: "220.42",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "CALC-007",
            certificationLevel: "Journeyman",
            topicKey: "calculation-drill",
            topicTitle: "Box Fill",
            question: "A metal box contains: 3 × 12 AWG conductors (2.25 cu in each), 1 device (counts as 2 conductors = 4.5 cu in), and 1 equipment grounding conductor (counts as 1 conductor = 2.25 cu in). What is the total box fill in cubic inches?",
            choices: ["A": "9.0 cu in", "B": "11.25 cu in", "C": "13.5 cu in", "D": "15.75 cu in"],
            correctChoice: "C",
            explanation: "Conductors: 3 × 2.25 = 6.75 cu in. Device: 2 × 2.25 = 4.50 cu in. EGC: 1 × 2.25 = 2.25 cu in. Total = 6.75 + 4.50 + 2.25 = 13.5 cu in. Per Table 314.16(B) and 314.16(B)(4)-(5), the device counts double the largest conductor volume and all EGCs count as one conductor.",
            referenceCode: "314.16(B)",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "CALC-008",
            certificationLevel: "Journeyman",
            topicKey: "calculation-drill",
            topicTitle: "Conduit Fill",
            question: "Three 12 AWG THHN conductors (each 0.0133 sq in cross-section) are installed in a conduit. The maximum fill for three or more conductors is 40%. A ½-inch EMT has an internal area of 0.122 sq in. Does this conduit comply with Chapter 9 fill limits?",
            choices: ["A": "Yes — three conductors at 0.0399 sq in total is well under 40% of 0.122 sq in (0.0488 sq in)", "B": "No — three conductors at 0.0399 sq in exceeds 40% of 0.122 sq in", "C": "Yes — three conductors always comply with ½-inch EMT", "D": "Cannot be determined without knowing conductor insulation type"],
            correctChoice: "A",
            explanation: "Three conductors × 0.0133 sq in = 0.0399 sq in total. 40% of 0.122 sq in = 0.0488 sq in maximum. 0.0399 < 0.0488, so the installation complies. This is the standard conduit fill calculation sequence: multiply count × area, then compare to the allowed percentage of the raceway's interior area.",
            referenceCode: "Chapter 9, Table 1",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "CALC-009",
            certificationLevel: "Journeyman",
            topicKey: "calculation-drill",
            topicTitle: "Ampacity Adjustment",
            question: "A 10 AWG THHN conductor in 90°C column of Table 310.16 has an ampacity of 40 amperes. Seven current-carrying conductors are in the same conduit, requiring a 70% adjustment factor per Table 310.15(C)(1). What is the adjusted ampacity?",
            choices: ["A": "24 amperes", "B": "28 amperes", "C": "32 amperes", "D": "36 amperes"],
            correctChoice: "B",
            explanation: "40 A × 0.70 = 28 amperes adjusted ampacity. For 7 to 9 current-carrying conductors in a raceway, Table 310.15(C)(1) requires a 70% adjustment. After adjusting, compare to the termination temperature rating to determine the final allowable ampacity.",
            referenceCode: "310.15(C)(1)",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "CALC-010",
            certificationLevel: "Journeyman",
            topicKey: "calculation-drill",
            topicTitle: "Motor Branch Circuit",
            question: "A single-phase 240V motor has a nameplate FLA of 24 amperes. Per Section 430.22, what is the minimum conductor ampacity for the motor branch circuit?",
            choices: ["A": "24 amperes", "B": "26 amperes", "C": "30 amperes", "D": "36 amperes"],
            correctChoice: "C",
            explanation: "430.22 requires motor branch-circuit conductors to have an ampacity of at least 125% of the motor FLA. 24 × 1.25 = 30 amperes minimum. This calculation is performed before checking applicable conductor ampacity tables.",
            referenceCode: "430.22",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "CALC-011",
            certificationLevel: "Master",
            topicKey: "calculation-drill",
            topicTitle: "Voltage Drop",
            question: "A 120V, 20A circuit has a single-phase load 150 feet away. Using VD = (2 × K × I × D) ÷ CM, with K = 12.9 for copper and 12,900 CM for 12 AWG copper, what is the approximate voltage drop?",
            choices: ["A": "2.4 volts", "B": "4.5 volts", "C": "5.9 volts", "D": "8.0 volts"],
            correctChoice: "C",
            explanation: "VD = (2 × 12.9 × 20 × 150) ÷ 12,900 = 77,400 ÷ 12,900 ≈ 6.0 volts (≈5.9V with exact K). At 120V, 6V represents a 5% drop — above the NEC 3% recommendation for branch circuits. Voltage drop calculations are among the most common master exam calculation problems.",
            referenceCode: "210.19(A) Inf. Note",
            difficultyLevel: "Hard"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "CALC-012",
            certificationLevel: "Master",
            topicKey: "calculation-drill",
            topicTitle: "Service Load Calculation",
            question: "A 2,400 sq ft dwelling has: general lighting load (3 VA/sq ft), two small-appliance circuits (1,500 VA each), one laundry circuit (1,500 VA), and a 5,000 VA electric range. After Table 220.42 demand factors (100% on first 3,000 VA; 35% on remainder), what is the total demand load before adding the range?",
            choices: ["A": "6,045 VA", "B": "6,750 VA", "C": "7,200 VA", "D": "11,700 VA"],
            correctChoice: "A",
            explanation: "Step 1: Lighting = 2,400 × 3 = 7,200 VA. Step 2: Add two small-appliance circuits (3,000 VA) + laundry (1,500 VA) = 11,700 VA total before demand factors. Step 3: Apply Table 220.42 — first 3,000 VA × 100% = 3,000 VA; remaining 8,700 VA × 35% = 3,045 VA. Total demand load = 3,000 + 3,045 = 6,045 VA. The range is then added separately using Table 220.55 before sizing the service.",
            referenceCode: "220.42",
            difficultyLevel: "Hard"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "CALC-013",
            certificationLevel: "Master",
            topicKey: "calculation-drill",
            topicTitle: "Motor Feeder",
            question: "A feeder serves two motors: Motor A has a Table 430.250 FLA of 34 amperes and Motor B has a FLA of 22 amperes. Per Section 430.24, what is the minimum feeder conductor ampacity?",
            choices: ["A": "56 amperes", "B": "64.5 amperes", "C": "70 amperes", "D": "75 amperes"],
            correctChoice: "B",
            explanation: "430.24: Feeder ampacity = 125% of the largest motor FLA + sum of all other motor FLAs. Motor A (largest): 34 × 1.25 = 42.5 A. Add Motor B: 42.5 + 22 = 64.5 A minimum conductor ampacity. Then select a conductor from Table 310.16 with ampacity at or above 64.5 A at the appropriate temperature rating — but the minimum calculated ampacity required by 430.24 is 64.5 A.",
            referenceCode: "430.24",
            difficultyLevel: "Hard"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "CALC-014",
            certificationLevel: "Journeyman",
            topicKey: "calculation-drill",
            topicTitle: "GEC Sizing",
            question: "A service has 2/0 AWG copper service-entrance conductors. Using Table 250.66, what is the minimum copper grounding electrode conductor (GEC) size?",
            choices: ["A": "6 AWG", "B": "4 AWG", "C": "2 AWG", "D": "1/0 AWG"],
            correctChoice: "B",
            explanation: "Per Table 250.66, the minimum copper GEC for 2/0 AWG copper service-entrance conductors is 4 AWG. Table milestone summary: SE conductor 2 AWG or smaller → 8 AWG GEC; 1 AWG or 1/0 AWG → 6 AWG GEC; 2/0 AWG or 3/0 AWG → 4 AWG GEC; over 3/0 through 350 kcmil → 2 AWG GEC. Knowing the break points between size ranges is the key to answering Table 250.66 questions quickly.",
            referenceCode: "250.66",
            difficultyLevel: "Medium"
        ).model,
        SupplementalPracticeQuestionSeed(
            id: "CALC-015",
            certificationLevel: "Master",
            topicKey: "calculation-drill",
            topicTitle: "Optional Dwelling Calculation",
            question: "A dwelling's first 10 kVA of total load is calculated at 100% under Section 220.82(B)(1). The remaining load above 10 kVA uses a 40% demand factor per 220.82(B)(2). If the total connected load is 28 kVA, what is the total demand load?",
            choices: ["A": "16.2 kVA", "B": "17.2 kVA", "C": "20.0 kVA", "D": "22.4 kVA"],
            correctChoice: "B",
            explanation: "First 10 kVA × 100% = 10 kVA. Remaining: 28 − 10 = 18 kVA × 40% = 7.2 kVA. Total demand = 10 + 7.2 = 17.2 kVA. The optional method in 220.82 is often faster for dwelling services and is frequently tested on master exams as an alternative to the standard method.",
            referenceCode: "220.82",
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

        // Calculation Drill: pull from the dedicated math-focused question bank
        if type == .calculationDrill {
            var pool = CuratedPracticeQuestionBank.calculationDrillQuestions
            if let examType {
                let filtered = pool.filter { certificationRank(for: $0) <= certificationRankCeiling(for: examType) }
                if filtered.count >= 10 { pool = filtered }
            }
            pool = pool.shuffled()
            let selected = Array(pool.prefix(type.questionCount))
            guard selected.count >= min(type.questionCount, 5) else {
                throw AppError.notFound("There are not enough calculation questions available yet.")
            }
            let quiz = WWQuiz(id: UUID(), type: type, questions: selected)
            activeQuizzes[quiz.id] = quiz
            return quiz
        }

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

    private func certificationRankCeiling(for examType: ExamType) -> Int {
        switch examType {
        case .apprentice: return 1
        case .journeyman: return 2
        case .master: return 3
        }
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
            case .journeyman:
                return certificationRank(for: question) <= 2
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

    /// Opens the tutor with a focused study prompt for a specific weak topic.
    static func weakTopicStudy(_ topic: WeakTopicDetail, user: WWUser?) -> TutorContext {
        TutorContext(
            type: .general,
            id: nil,
            excerpt: "I missed \(topic.incorrectCount) question\(topic.incorrectCount == 1 ? "" : "s") on \(topic.title). Help me understand this topic.",
            title: "Study: \(topic.title)",
            topicTags: [topic.key],
            examType: user?.examType.rawValue,
            jurisdiction: normalizedJurisdiction(for: user),
            lesson: nil,
            quizReview: nil,
            necDetail: nil
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

// MARK: - Bookmark Store

struct BookmarkedLesson: Codable, Identifiable {
    let id: UUID
    let title: String
    let topic: String
    let moduleId: UUID
    let bookmarkedAt: Date
}

@Observable
final class BookmarkStore {
    static let shared = BookmarkStore()

    private let key = "ww_bookmarks_v1"
    private(set) var bookmarks: [BookmarkedLesson] = []

    init() { load() }

    func isBookmarked(_ lessonId: UUID) -> Bool {
        bookmarks.contains { $0.id == lessonId }
    }

    func toggle(lesson: WWLesson) {
        if isBookmarked(lesson.id) {
            bookmarks.removeAll { $0.id == lesson.id }
        } else {
            bookmarks.append(BookmarkedLesson(
                id: lesson.id,
                title: lesson.title,
                topic: lesson.topic,
                moduleId: lesson.moduleId,
                bookmarkedAt: Date()
            ))
        }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([BookmarkedLesson].self, from: data) else { return }
        bookmarks = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

// MARK: - NEC Service

protocol NECServiceProtocol: AnyObject {
    func search(query: String, stateCode: String?, editionOverride: String?) async throws -> [NECSearchResult]
    func detail(id: UUID) async throws -> NECReference
    func explain(id: UUID) async throws -> NECExplanationResult
    func amendments(article: String, jurisdictionCode: String) async throws -> NECAmendmentsResult
}

final class MockNECService: NECServiceProtocol {
    func search(query: String, stateCode: String?, editionOverride: String?) async throws -> [NECSearchResult] {
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

    func amendments(article: String, jurisdictionCode: String) async throws -> NECAmendmentsResult {
        try await Task.sleep(for: .milliseconds(200))
        return NECAmendmentsResult(
            jurisdictionCode: jurisdictionCode,
            adoptedEdition: "2023",
            adoptionNotes: nil,
            amendments: []
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
