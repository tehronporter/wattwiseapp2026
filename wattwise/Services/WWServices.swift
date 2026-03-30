import Foundation
import Observation

// MARK: - Auth Service

protocol AuthServiceProtocol: AnyObject {
    var currentUser: WWUser? { get }
    func signIn(email: String, password: String) async throws -> WWUser
    func signUp(email: String, password: String) async throws -> WWUser
    func signInWithApple(token: String) async throws -> WWUser
    func signOut() throws
    func restoreSession() async -> WWUser?
    func updateProfile(_ user: WWUser) async throws
}

@MainActor
final class MockAuthService: AuthServiceProtocol {
    private(set) var currentUser: WWUser?

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

    func signUp(email: String, password: String) async throws -> WWUser {
        try await Task.sleep(for: .milliseconds(800))
        guard !email.isEmpty else { throw AppError.invalidInput("Email is required.") }
        guard password.count >= 8 else { throw AppError.invalidInput("Password must be at least 8 characters.") }
        let user = WWUser(
            id: UUID(),
            email: email,
            displayName: nil,
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
    }

    func updateProfile(_ user: WWUser) async throws {
        persist(user)
        currentUser = user
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
        return MockData.modules
    }

    func fetchLesson(id: UUID) async throws -> WWLesson {
        try await Task.sleep(for: .milliseconds(400))
        let all = MockData.modules.flatMap(\.lessons)
        guard let lesson = all.first(where: { $0.id == id }) else {
            throw AppError.notFound("Lesson not found.")
        }
        return lesson
    }

    func saveProgress(lessonId: UUID, completion: Double) async throws {
        try await Task.sleep(for: .milliseconds(200))
        // In production: POST /functions/v1/save_progress
    }
}

// MARK: - Quiz Service

protocol QuizServiceProtocol: AnyObject {
    func generateQuiz(type: QuizType, topicTags: [String]) async throws -> WWQuiz
    func submitQuiz(quizId: UUID, answers: [QuizAnswer]) async throws -> QuizResult
}

final class MockQuizService: QuizServiceProtocol {
    func generateQuiz(type: QuizType, topicTags: [String]) async throws -> WWQuiz {
        try await Task.sleep(for: .milliseconds(800))
        let count = type.questionCount
        let questions = Array(MockData.sampleQuestions.shuffled().prefix(count))
        return WWQuiz(id: UUID(), type: type, questions: questions)
    }

    func submitQuiz(quizId: UUID, answers: [QuizAnswer]) async throws -> QuizResult {
        try await Task.sleep(for: .milliseconds(600))
        let questions = MockData.sampleQuestions
        var correct = 0
        var results: [QuestionResult] = []

        for answer in answers {
            if let q = questions.first(where: { $0.id == answer.questionId }) {
                let isCorrect = answer.selected == q.correctChoice
                if isCorrect { correct += 1 }
                results.append(QuestionResult(
                    id: UUID(),
                    questionId: q.id,
                    question: q.question,
                    userAnswer: q.choices[answer.selected] ?? answer.selected,
                    correctAnswer: q.choices[q.correctChoice] ?? q.correctChoice,
                    explanation: q.explanation,
                    isCorrect: isCorrect
                ))
            }
        }

        let score = answers.isEmpty ? 0.0 : Double(correct) / Double(answers.count)
        return QuizResult(
            id: UUID(),
            quizId: quizId,
            score: score,
            correctCount: correct,
            totalCount: answers.count,
            results: results,
            weakTopics: score < 0.7 ? ["grounding", "nec"] : []
        )
    }
}

// MARK: - Tutor Service

protocol TutorServiceProtocol: AnyObject {
    func sendMessage(_ text: String, context: TutorContext?) async throws -> TutorMessage
}

final class MockTutorService: TutorServiceProtocol {
    func sendMessage(_ text: String, context: TutorContext?) async throws -> TutorMessage {
        try await Task.sleep(for: .milliseconds(1200))

        let responses: [(String, [String], [String])] = [
            (
                "That's a great question! Ohm's Law (V = IR) is the foundation of all electrical calculations. Voltage equals current times resistance.",
                ["Identify your known values (any two of V, I, R)", "Rearrange the formula: V=IR, I=V/R, R=V/I", "Calculate and verify units: volts, amps, ohms"],
                ["How do I apply this to a 240V circuit?", "What's the power formula?", "Can you give me a practice problem?"]
            ),
            (
                "GFCI protection is one of the most tested topics on the electrical exam. It's required wherever water and electricity might meet.",
                ["NEC 210.8 lists all required GFCI locations", "Bathrooms: any receptacle", "Garages: all receptacles", "Outdoors: all receptacles", "Kitchens: within 6 feet of a sink"],
                ["What about AFCI vs GFCI?", "Are there exceptions to GFCI requirements?", "What code cycle introduced new GFCI requirements?"]
            ),
            (
                "Grounding and bonding serve different purposes, and this distinction is heavily tested. Don't mix them up!",
                ["Grounding: connects to earth to establish a reference voltage", "Bonding: connects metal parts together to equalize potential", "Grounding protects against lightning; bonding protects against touch hazards"],
                ["What is a grounding electrode system?", "Where is bonding required?", "Explain NEC 250.50"]
            )
        ]

        let choice = responses.randomElement()!
        return TutorMessage(
            id: UUID(),
            content: choice.0,
            role: .assistant,
            timestamp: Date(),
            steps: choice.1,
            followUps: choice.2
        )
    }
}

// MARK: - NEC Service

protocol NECServiceProtocol: AnyObject {
    func search(query: String) async throws -> [NECSearchResult]
    func detail(id: UUID) async throws -> NECReference
    func explain(id: UUID) async throws -> String
}

final class MockNECService: NECServiceProtocol {
    func search(query: String) async throws -> [NECSearchResult] {
        try await Task.sleep(for: .milliseconds(400))
        if query.isEmpty { return MockData.necReferences }
        let q = query.lowercased()
        return MockData.necReferences.filter {
            $0.code.lowercased().contains(q) ||
            $0.title.lowercased().contains(q) ||
            $0.summary.lowercased().contains(q)
        }
    }

    func detail(id: UUID) async throws -> NECReference {
        try await Task.sleep(for: .milliseconds(300))
        return NECReference(
            id: id,
            code: "210.8",
            title: "GFCI Protection for Personnel",
            summary: "Ground-fault circuit-interrupter protection required for personnel in specified locations.",
            expanded: "NEC 210.8 requires GFCI protection in all 125-volt, single-phase, 15- and 20-ampere receptacles installed in bathrooms, garages, outdoors, crawl spaces, unfinished basements, kitchen countertop surfaces, boat houses, and other wet/damp locations. The intent is to protect persons from ground fault shock hazards where water contact is likely. GFCI devices trip when they detect a ground fault current of 4–6 milliamperes, which is below the ventricular fibrillation threshold."
        )
    }

    func explain(id: UUID) async throws -> String {
        try await Task.sleep(for: .milliseconds(1000))
        return "This code section requires GFCI protection because water dramatically lowers the resistance of the human body, making even small ground faults potentially fatal. The GFCI device constantly monitors the current balance between the hot and neutral conductors — if more than ~5mA flows through an unintended path (like a person), the GFCI trips within 1/40th of a second. This is fast enough to prevent cardiac arrest, which typically requires sustained current exposure. For exam purposes, memorize all 210.8 required locations — bathrooms, garages, outdoors, crawl spaces, unfinished basements, kitchen countertops within 6 feet of sinks, and boathouses are the most commonly tested."
    }
}

// MARK: - Progress Service

protocol ProgressServiceProtocol: AnyObject {
    func fetchSummary() async throws -> ProgressSummary
}

final class MockProgressService: ProgressServiceProtocol {
    func fetchSummary() async throws -> ProgressSummary {
        try await Task.sleep(for: .milliseconds(500))
        return MockData.progressSummary
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
    private(set) var state: SubscriptionState = .freeTier

    func fetchState() async throws -> SubscriptionState {
        try await Task.sleep(for: .milliseconds(300))
        return state
    }

    func purchase(productId: String) async throws -> SubscriptionState {
        try await Task.sleep(for: .milliseconds(1500))
        state = .proTier
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
        case .rateLimited: return "You've reached today's limit. Upgrade to Pro for unlimited access."
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

    init() {
        if AppConfig.useMockServices {
            self.auth         = MockAuthService()
            self.content      = MockContentService()
            self.quiz         = MockQuizService()
            self.tutor        = MockTutorService()
            self.nec          = MockNECService()
            self.progress     = MockProgressService()
            self.subscription = MockSubscriptionService()
        } else {
            self.auth         = SupabaseAuthService()
            self.content      = SupabaseContentService()
            self.quiz         = SupabaseQuizService()
            self.tutor        = SupabaseTutorService()
            self.nec          = SupabaseNECService()
            self.progress     = SupabaseProgressService()
            self.subscription = SupabaseSubscriptionService()
        }
    }
}
