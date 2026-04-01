import Foundation

// MARK: - Real Supabase Service Implementations
//
// Each service calls the corresponding Edge Function at:
// POST /functions/v1/{endpoint}
// All auth is handled via JWT issued by Supabase Auth.

// MARK: - Auth Service (Supabase Auth REST)

@MainActor
final class SupabaseAuthService: AuthServiceProtocol {
    private(set) var currentUser: WWUser?
    private let profileKey = "ww_profile"

    func restoreSession() async -> WWUser? {
        guard let session = await SupabaseAuthClient.shared.restoreSession() else { return nil }
        await APIClient.shared.setAccessToken(session.accessToken)
        let user = mapUser(from: session)
        persist(user)
        currentUser = user
        return user
    }

    func signIn(email: String, password: String) async throws -> WWUser {
        guard !email.isEmpty, !password.isEmpty else {
            throw AppError.invalidInput("Email and password are required.")
        }
        let session = try await SupabaseAuthClient.shared.signIn(email: email, password: password)
        await SupabaseAuthClient.shared.saveSession(session)
        await APIClient.shared.setAccessToken(session.accessToken)
        let user = mapUser(from: session)
        persist(user)
        currentUser = user
        return user
    }

    func signUp(email: String, password: String) async throws -> WWUser {
        guard !email.isEmpty else { throw AppError.invalidInput("Email is required.") }
        guard password.count >= 8 else { throw AppError.invalidInput("Password must be at least 8 characters.") }
        let session = try await SupabaseAuthClient.shared.signUp(email: email, password: password)
        await SupabaseAuthClient.shared.saveSession(session)
        await APIClient.shared.setAccessToken(session.accessToken)
        let user = mapUser(from: session)
        persist(user)
        currentUser = user
        return user
    }

    func signInWithApple(token: String) async throws -> WWUser {
        // Apple Sign-In calls Supabase Auth with the Apple identity token
        // Full implementation requires AuthorizationController setup in the View layer
        // For now, uses the same signIn flow via the token exchange
        throw AppError.invalidInput("Apple Sign-In not yet configured.")
    }

    func signOut() throws {
        Task {
            if let token = UserDefaults.standard.string(forKey: "ww_access_token") {
                try? await SupabaseAuthClient.shared.signOut(accessToken: token)
            }
            await SupabaseAuthClient.shared.clearSession()
            await APIClient.shared.setAccessToken(nil)
        }
        UserDefaults.standard.removeObject(forKey: profileKey)
        currentUser = nil
    }

    func updateProfile(_ user: WWUser) async throws {
        if let token = UserDefaults.standard.string(forKey: "ww_access_token") {
            _ = try await SupabaseAuthClient.shared.updateUserMetadata(
                accessToken: token,
                metadata: [
                    "display_name": user.displayName ?? "",
                    "exam_type": user.examType.rawValue,
                    "state": user.state,
                    "study_goal": user.studyGoal.rawValue
                ]
            )
        }
        persist(user)
        currentUser = user
    }

    // MARK: - Private

    private func mapUser(from session: AuthSession) -> WWUser {
        // Try to load saved profile preferences (exam type, state, etc.)
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let saved = try? JSONDecoder().decode(WWUser.self, from: data),
           saved.email == (session.user.email ?? "") {
            return saved
        }
        return WWUser(
            id: UUID(uuidString: session.user.id) ?? UUID(),
            email: session.user.email ?? "",
            displayName: session.user.userMetadata?.displayName,
            examType: ExamType(rawValue: session.user.userMetadata?.examType ?? "") ?? .apprentice,
            state: session.user.userMetadata?.state ?? "",
            studyGoal: StudyGoal(rawValue: session.user.userMetadata?.studyGoal ?? "") ?? .moderate,
            streakDays: 0,
            isOnboardingComplete: !(session.user.userMetadata?.state ?? "").isEmpty
        )
    }

    private func persist(_ user: WWUser) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
    }
}

// MARK: - Content Service (Edge Functions)

final class SupabaseContentService: ContentServiceProtocol {
    func fetchModules() async throws -> [WWModule] {
        struct Response: Decodable { let modules: [WWModule] }
        let r = try await APIClient.shared.post(endpoint: "get_modules", responseType: Response.self)
        return r.modules
    }

    func fetchLesson(id: UUID) async throws -> WWLesson {
        struct Request: Encodable { let lesson_id: String }
        struct Response: Decodable { let lesson: WWLesson }
        let r = try await APIClient.shared.post(
            endpoint: "get_lesson",
            body: Request(lesson_id: id.uuidString),
            responseType: Response.self
        )
        return r.lesson
    }

    func saveProgress(lessonId: UUID, completion: Double) async throws {
        struct Request: Encodable { let lesson_id: String; let completion_percentage: Double }
        struct Response: Decodable { let success: Bool }
        _ = try await APIClient.shared.post(
            endpoint: "save_progress",
            body: Request(lesson_id: lessonId.uuidString, completion_percentage: completion),
            responseType: Response.self
        )
    }
}

// MARK: - Quiz Service (Edge Functions)

final class SupabaseQuizService: QuizServiceProtocol {
    func generateQuiz(type: QuizType, topicTags: [String], examType: ExamType?) async throws -> WWQuiz {
        struct Request: Encodable {
            let quiz_type: String
            let topic_tags: [String]
            let question_count: Int
            let exam_type: String?
        }
        struct Response: Decodable {
            let quiz_id: String
            let questions: [RawQuestion]
        }
        struct RawQuestion: Decodable {
            let id: String
            let question: String
            let choices: [String: String]
            let topics: [String]
        }

        let r = try await APIClient.shared.post(
            endpoint: "generate_quiz",
            body: Request(
                quiz_type: type.rawValue,
                topic_tags: topicTags,
                question_count: type.questionCount,
                exam_type: examType?.rawValue
            ),
            responseType: Response.self
        )

        let questions = r.questions.map { raw in
            QuizQuestion(
                id: UUID(uuidString: raw.id) ?? UUID(),
                question: raw.question,
                choices: raw.choices,
                correctChoice: "",  // not returned until submit
                explanation: "",    // not returned until submit
                topics: raw.topics
            )
        }
        return WWQuiz(id: UUID(uuidString: r.quiz_id) ?? UUID(), type: type, questions: questions)
    }

    func submitQuiz(quizId: UUID, answers: [QuizAnswer]) async throws -> QuizResult {
        struct Request: Encodable {
            let quiz_id: String
            let answers: [AnswerDTO]
            struct AnswerDTO: Encodable { let question_id: String; let selected: String }
        }
        struct Response: Decodable {
            let score: Double
            let correct_count: Int
            let total_count: Int
            let results: [ResultDTO]
            let weak_topics: [String]
            struct ResultDTO: Decodable {
                let question_id: String
                let question: String
                let user_answer: String
                let correct_answer: String
                let explanation: String
                let is_correct: Bool
            }
        }

        let r = try await APIClient.shared.post(
            endpoint: "submit_quiz",
            body: Request(
                quiz_id: quizId.uuidString,
                answers: answers.map { .init(question_id: $0.questionId.uuidString, selected: $0.selected) }
            ),
            responseType: Response.self
        )

        let results = r.results.map { d in
            QuestionResult(
                id: UUID(),
                questionId: UUID(uuidString: d.question_id) ?? UUID(),
                question: d.question,
                userAnswer: d.user_answer,
                correctAnswer: d.correct_answer,
                explanation: d.explanation,
                isCorrect: d.is_correct
            )
        }

        return QuizResult(
            id: UUID(),
            quizId: quizId,
            score: r.score,
            correctCount: r.correct_count,
            totalCount: r.total_count,
            results: results,
            weakTopics: r.weak_topics
        )
    }
}

// MARK: - Tutor Service (Edge Function)

final class SupabaseTutorService: TutorServiceProtocol {
    func sendMessage(_ text: String, context: TutorContext?) async throws -> TutorMessage {
        struct Request: Encodable {
            let message: String
            let context: ContextDTO?
            struct ContextDTO: Encodable { let type: String; let id: String? }
        }
        struct Response: Decodable {
            let answer: String
            let steps: [String]?
            let follow_ups: [String]?
        }

        let r = try await APIClient.shared.post(
            endpoint: "tutor",
            body: Request(
                message: text,
                context: context.map { .init(type: $0.type.rawValue, id: $0.id?.uuidString) }
            ),
            responseType: Response.self
        )

        return TutorMessage(
            id: UUID(),
            content: r.answer,
            role: .assistant,
            timestamp: Date(),
            steps: r.steps,
            followUps: r.follow_ups
        )
    }
}

// MARK: - NEC Service (Edge Functions)

final class SupabaseNECService: NECServiceProtocol {
    func search(query: String) async throws -> [NECSearchResult] {
        struct Request: Encodable { let query: String }
        struct Response: Decodable { let results: [NECSearchResult] }
        let r = try await APIClient.shared.post(
            endpoint: "nec_search",
            body: Request(query: query),
            responseType: Response.self
        )
        return r.results
    }

    func detail(id: UUID) async throws -> NECReference {
        struct Request: Encodable { let nec_id: String }
        struct Response: Decodable { let detail: NECReference }
        let r = try await APIClient.shared.post(
            endpoint: "nec_detail",
            body: Request(nec_id: id.uuidString),
            responseType: Response.self
        )
        return r.detail
    }

    func explain(id: UUID) async throws -> String {
        struct Request: Encodable { let nec_id: String }
        struct Response: Decodable { let expanded: String }
        let r = try await APIClient.shared.post(
            endpoint: "nec_explain",
            body: Request(nec_id: id.uuidString),
            responseType: Response.self
        )
        return r.expanded
    }
}

// MARK: - Progress Service (Edge Function)

final class SupabaseProgressService: ProgressServiceProtocol {
    func fetchSummary() async throws -> ProgressSummary {
        struct Response: Decodable {
            let continue_learning: CLDto?
            let daily_goal: DGDto
            let streak_days: Int
            let recommended_action: String?

            struct CLDto: Decodable {
                let lesson_id: String
                let title: String
                let progress: Double
                let module_title: String
            }
            struct DGDto: Decodable {
                let minutes_completed: Int
                let target_minutes: Int
            }
        }

        let r = try await APIClient.shared.post(endpoint: "progress_summary", responseType: Response.self)
        return ProgressSummary(
            continueLearning: r.continue_learning.map {
                .init(lessonId: UUID(uuidString: $0.lesson_id) ?? UUID(),
                      lessonTitle: $0.title,
                      progress: $0.progress,
                      moduleTitle: $0.module_title)
            },
            dailyGoal: .init(minutesCompleted: r.daily_goal.minutes_completed,
                             targetMinutes: r.daily_goal.target_minutes),
            streakDays: r.streak_days,
            recommendedAction: r.recommended_action,
            hasStartedContent: r.continue_learning != nil || r.daily_goal.minutes_completed > 0 || r.streak_days > 0
        )
    }
}

// MARK: - Subscription Service (Edge Function + StoreKit)

@MainActor
final class SupabaseSubscriptionService: SubscriptionServiceProtocol {
    private(set) var state: SubscriptionState = .freeTier

    func fetchState() async throws -> SubscriptionState {
        struct Response: Decodable { let tier: String; let status: String }
        let r = try await APIClient.shared.post(endpoint: "sync_subscription", responseType: Response.self)
        state = SubscriptionState(
            tier: SubscriptionTier(rawValue: r.tier) ?? .free,
            status: r.status,
            expiresAt: nil,
            dailyTutorMessagesUsed: 0,
            dailyTutorMessagesLimit: r.tier == "pro" ? -1 : 5
        )
        return state
    }

    func purchase(productId: String) async throws -> SubscriptionState {
        // StoreKit 2 purchase flow — receipt passed to sync_subscription
        // Full implementation requires StoreKit product configuration
        struct Request: Encodable { let receipt: String }
        struct Response: Decodable { let tier: String; let status: String }
        // For now, simulate success — replace with real StoreKit transaction receipt
        state = .proTier
        return state
    }

    func restorePurchases() async throws -> SubscriptionState {
        return try await fetchState()
    }
}
