import Foundation
import StoreKit

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
            let metadata = session.user.userMetadata
            return saved
                .updating(
                    displayName: metadata?.displayName,
                    examType: ExamType(rawValue: metadata?.examType ?? "") ?? saved.examType,
                    state: metadata?.state ?? saved.state,
                    studyGoal: StudyGoal(rawValue: metadata?.studyGoal ?? "") ?? saved.studyGoal
                )
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
            let quiz_attempt_id: String
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
                let topics: [String]?
                let topic_titles: [String]?
                let reference_code: String?
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
                isCorrect: d.is_correct,
                topics: d.topics ?? [],
                topicTitles: d.topic_titles ?? [],
                referenceCode: d.reference_code
            )
        }

        return QuizResult(
            id: UUID(),
            quizId: quizId,
            quizAttemptId: UUID(uuidString: r.quiz_attempt_id),
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
    func sendMessage(
        _ text: String,
        context: TutorContext?,
        history: [TutorMessage],
        sessionID: UUID?
    ) async throws -> TutorSendResult {
        struct Request: Encodable {
            let message: String
            let context: TutorContext?
            let history: [HistoryDTO]
            let session_id: String?

            struct HistoryDTO: Encodable {
                let role: String
                let content: String
            }
        }
        struct Response: Decodable {
            let answer: String
            let steps: [String]?
            let bullets: [String]?
            let references: [String]?
            let follow_ups: [String]?
            let session_id: String?
            let usage: UsageDTO?

            struct UsageDTO: Decodable {
                let used: Int
                let limit: Int
            }
        }

        let r = try await APIClient.shared.post(
            endpoint: "tutor",
            body: Request(
                message: text,
                context: context,
                history: history.map { .init(role: $0.role.rawValue, content: $0.content) },
                session_id: sessionID?.uuidString
            ),
            responseType: Response.self
        )

        return TutorSendResult(
            message: TutorMessage(
                id: UUID(),
                content: r.answer,
                role: .assistant,
                timestamp: Date(),
                steps: r.steps,
                bullets: r.bullets,
                references: r.references,
                followUps: r.follow_ups
            ),
            sessionId: r.session_id.flatMap(UUID.init(uuidString:)),
            usage: r.usage.map { .init(used: $0.used, limit: $0.limit) }
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

    func explain(id: UUID) async throws -> NECExplanationResult {
        struct Request: Encodable { let nec_id: String }
        struct Response: Decodable {
            let expanded: String
            let usage: UsageDTO?

            struct UsageDTO: Decodable {
                let used: Int
                let limit: Int
            }
        }
        let r = try await APIClient.shared.post(
            endpoint: "nec_explain",
            body: Request(nec_id: id.uuidString),
            responseType: Response.self
        )
        return NECExplanationResult(
            expanded: r.expanded,
            usage: r.usage.map { .init(used: $0.used, limit: $0.limit) }
        )
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
            let has_started_content: Bool?
            let last_activity_at: String?

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
            hasStartedContent: r.has_started_content ?? (r.continue_learning != nil || r.daily_goal.minutes_completed > 0 || r.streak_days > 0),
            lastActivityAt: r.last_activity_at.flatMap(ISO8601DateFormatter().date(from:))
        )
    }
}

// MARK: - Subscription Service (Edge Function + StoreKit)

@MainActor
final class SupabaseSubscriptionService: SubscriptionServiceProtocol {
    private(set) var state: SubscriptionState = .preview

    private struct SyncRequest: Encodable {
        let product_id: String?
        let transaction_id: String?
        let original_transaction_id: String?
        let purchase_date: String?
        let expires_at: String?
        let receipt: String?
    }

    private func syncState(with request: SyncRequest? = nil) async throws -> SubscriptionState {
        if let request {
            _ = try await APIClient.shared.post(
                endpoint: "sync_subscription",
                body: request,
                responseType: EmptyResponse.self
            )
        }
        return try await fetchState()
    }

    private func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let signedType):
            return signedType
        case .unverified:
            throw AppError.unknown
        }
    }

    private func expiryDate(for productId: String, purchaseDate: Date) -> Date {
        let expiry = purchaseDate
        let months = productId == AccessProductID.fastTrack.rawValue ? 3 : 12
        return Calendar.current.date(byAdding: .month, value: months, to: expiry) ?? purchaseDate
    }

    func fetchState() async throws -> SubscriptionState {
        struct Response: Decodable {
            let tier: String
            let status: String
            let expires_at: String?
            let store_product_id: String?
            let preview_quizzes_used: Int
            let preview_quizzes_limit: Int
            let tutor_messages_used: Int
            let tutor_messages_limit: Int
            let nec_explanations_used: Int
            let nec_explanations_limit: Int
        }
        let r = try await APIClient.shared.post(endpoint: "sync_subscription", responseType: Response.self)
        state = SubscriptionState(
            tier: SubscriptionTier(rawValue: r.tier) ?? .preview,
            status: r.status,
            expiresAt: r.expires_at.flatMap(ISO8601DateFormatter().date(from:)),
            storeProductId: r.store_product_id,
            previewQuickQuizzesUsed: r.preview_quizzes_used,
            previewQuickQuizzesLimit: r.preview_quizzes_limit,
            tutorMessagesUsed: r.tutor_messages_used,
            tutorMessagesLimit: r.tutor_messages_limit,
            necExplanationsUsed: r.nec_explanations_used,
            necExplanationsLimit: r.nec_explanations_limit
        )
        return state
    }

    func purchase(productId: String) async throws -> SubscriptionState {
        let products = try await Product.products(for: [productId])
        guard let product = products.first else {
            throw AppError.notFound("This access option isn't available right now.")
        }

        let purchaseResult = try await product.purchase()

        switch purchaseResult {
        case .success(let verification):
            let transaction = try verify(verification)
            let purchaseDate = transaction.purchaseDate
            let expiresAt = expiryDate(for: transaction.productID, purchaseDate: purchaseDate)
            let syncedState = try await syncState(with: SyncRequest(
                product_id: transaction.productID,
                transaction_id: String(transaction.id),
                original_transaction_id: String(transaction.originalID),
                purchase_date: ISO8601DateFormatter().string(from: purchaseDate),
                expires_at: ISO8601DateFormatter().string(from: expiresAt),
                receipt: nil
            ))
            await transaction.finish()
            state = syncedState
            return syncedState
        case .pending:
            throw AppError.networkError("Your purchase is pending approval.")
        case .userCancelled:
            throw AppError.invalidInput("Purchase canceled.")
        @unknown default:
            throw AppError.unknown
        }
    }

    func restorePurchases() async throws -> SubscriptionState {
        try await AppStore.sync()

        var latestTransaction: Transaction?
        var latestExpiry: Date?

        for await entitlement in Transaction.all {
            guard let transaction = try? verify(entitlement) else { continue }
            guard transaction.productID == AccessProductID.fastTrack.rawValue || transaction.productID == AccessProductID.fullPrep.rawValue else {
                continue
            }

            let expiresAt = expiryDate(for: transaction.productID, purchaseDate: transaction.purchaseDate)
            guard expiresAt > Date() else { continue }

            if let latestExpiry, latestExpiry >= expiresAt {
                continue
            }

            latestTransaction = transaction
            latestExpiry = expiresAt
        }

        if let latestTransaction, let latestExpiry {
            let syncedState = try await syncState(with: SyncRequest(
                product_id: latestTransaction.productID,
                transaction_id: String(latestTransaction.id),
                original_transaction_id: String(latestTransaction.originalID),
                purchase_date: ISO8601DateFormatter().string(from: latestTransaction.purchaseDate),
                expires_at: ISO8601DateFormatter().string(from: latestExpiry),
                receipt: nil
            ))
            state = syncedState
            return syncedState
        }

        return try await syncState()
    }
}

private struct EmptyResponse: Decodable {}
