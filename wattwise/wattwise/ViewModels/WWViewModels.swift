import Foundation
import StoreKit
import SwiftUI

// MARK: - App ViewModel (root state)

@Observable
@MainActor
final class AppViewModel {
    var authState: AuthState = .loading
    var subscriptionState: SubscriptionState = .preview
    var authEntryPrefill: AuthEntryPrefill?
    var authStatusMessage: String?
    var authErrorMessage: String?
    var isHandlingAuthLink: Bool = false
    var isResendingConfirmation: Bool = false

    private let tutorConversationStoragePrefix = "ww_tutor_conversation_v1_"

    enum AuthState {
        case loading
        case unauthenticated
        case awaitingEmailConfirmation(PendingEmailConfirmation)
        case onboarding(WWUser)
        case authenticated(WWUser)
        case passwordReset(accessToken: String)
    }

    struct AuthEntryPrefill: Equatable {
        let email: String
        let isSignIn: Bool
    }

    private let cachedSubscriptionKey = "ww_cached_subscription_state"

    var currentUser: WWUser? {
        switch authState {
        case .onboarding(let u), .authenticated(let u): return u
        default: return nil
        }
    }

    var isAuthenticated: Bool {
        if case .authenticated = authState { return true }
        return false
    }

    var needsOnboarding: Bool {
        if case .onboarding = authState { return true }
        return false
    }

    var pendingEmailConfirmation: PendingEmailConfirmation? {
        if case .awaitingEmailConfirmation(let pending) = authState {
            return pending
        }
        return nil
    }

    func restoreSession(services: ServiceContainer) async {
        if let user = await services.auth.restoreSession() {
            await applyAuthenticatedUser(user, services: services)
        } else if let pending = services.auth.pendingEmailConfirmation {
            authState = .awaitingEmailConfirmation(pending)
        } else {
            authState = .unauthenticated
        }
    }

    func applyAuthenticatedUser(_ user: WWUser, services: ServiceContainer) async {
        authErrorMessage = nil
        if user.isOnboardingComplete {
            authState = .authenticated(user)
            Analytics.shared.identify(userId: user.id.uuidString, examType: user.examType.rawValue, state: user.state)
            // Crashlytics.crashlytics().setUserID(user.id.uuidString)  ← Uncomment after Firebase setup
        } else {
            authState = .onboarding(user)
        }
        if let fetched = try? await services.subscription.fetchState() {
            subscriptionState = fetched
            cacheSubscriptionState(fetched)
        } else {
            subscriptionState = loadCachedSubscriptionState() ?? .preview
        }
    }

    func requestNotificationsIfNeeded(user: WWUser) async {
        await StudyNotificationScheduler.shared.requestPermissionAndSchedule(user: user)
    }

    private func cacheSubscriptionState(_ state: SubscriptionState) {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: cachedSubscriptionKey)
        }
    }

    private func loadCachedSubscriptionState() -> SubscriptionState? {
        guard let data = UserDefaults.standard.data(forKey: cachedSubscriptionKey) else { return nil }
        return try? JSONDecoder().decode(SubscriptionState.self, from: data)
    }

    func enterAwaitingEmailConfirmation(_ pending: PendingEmailConfirmation) {
        authErrorMessage = nil
        authStatusMessage = "We sent a confirmation link to \(pending.email). Open it on this device to continue."
        authState = .awaitingEmailConfirmation(pending)
    }

    func resendConfirmation(services: ServiceContainer) async {
        guard let pending = services.auth.pendingEmailConfirmation else { return }

        isResendingConfirmation = true
        authErrorMessage = nil
        defer { isResendingConfirmation = false }

        do {
            try await services.auth.resendConfirmation(email: pending.email)
            authStatusMessage = "We sent a new confirmation link to \(pending.email)."
            if let refreshed = services.auth.pendingEmailConfirmation {
                authState = .awaitingEmailConfirmation(refreshed)
            }
        } catch {
            authErrorMessage = mapAuthFlowError(error)
        }
    }

    func handleIncomingURL(_ url: URL, services: ServiceContainer) async {
        guard AuthRedirectConfiguration.isAuthCallbackURL(url) else { return }

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if queryItems.first(where: { $0.name == "mode" })?.value == "signin" {
            showSignIn(email: services.auth.pendingEmailConfirmation?.email ?? "")
            return
        }

        // Check for password recovery link — route to SetNewPasswordView
        if let payload = AuthCallbackPayload.from(url: url),
           payload.type == "recovery",
           let accessToken = payload.accessToken, !accessToken.isEmpty {
            authState = .passwordReset(accessToken: accessToken)
            return
        }

        isHandlingAuthLink = true
        authErrorMessage = nil
        defer { isHandlingAuthLink = false }

        do {
            let user = try await services.auth.handleAuthCallback(url: url)
            authStatusMessage = "Your email is confirmed. You're signed in."
            await applyAuthenticatedUser(user, services: services)
        } catch {
            authErrorMessage = mapAuthFlowError(error)
            if let pending = services.auth.pendingEmailConfirmation {
                authState = .awaitingEmailConfirmation(pending)
            } else {
                authState = .unauthenticated
            }
        }
    }

    func showSignIn(email: String) {
        authEntryPrefill = AuthEntryPrefill(email: email, isSignIn: true)
        authState = .unauthenticated
    }

    func consumeAuthEntryPrefill() -> AuthEntryPrefill? {
        let prefill = authEntryPrefill
        authEntryPrefill = nil
        return prefill
    }

    func signOut(services: ServiceContainer) {
        try? services.auth.signOut()
        clearLocalSessionArtifacts()
        Analytics.track(.userSignedOut)
        authEntryPrefill = nil
        authStatusMessage = nil
        authErrorMessage = nil
        authState = .unauthenticated
        subscriptionState = .preview
    }

    func clearLocalSessionArtifacts() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "ww_user")
        defaults.removeObject(forKey: "ww_profile")
        defaults.removeObject(forKey: "ww_access_token")
        defaults.removeObject(forKey: "ww_refresh_token")
        defaults.removeObject(forKey: "ww_user_data")
        defaults.removeObject(forKey: cachedSubscriptionKey)
        PendingEmailConfirmationStore.clear()

        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(tutorConversationStoragePrefix) }
            .forEach { defaults.removeObject(forKey: $0) }
    }

    private func mapAuthFlowError(_ error: Error) -> String {
        let raw = error.localizedDescription

        if raw.localizedCaseInsensitiveContains("expired") || raw.localizedCaseInsensitiveContains("invalid") {
            return "That link is no longer valid. Request a new confirmation email and try again."
        }

        if raw.localizedCaseInsensitiveContains("network") {
            return "We couldn't reach the server. Check your connection and try again."
        }

        return raw
    }
}

// MARK: - Onboarding ViewModel

@Observable
@MainActor
final class OnboardingViewModel {
    // Step 0: welcome / sign in vs sign up
    // Step 1: exam type
    // Step 2: state selection
    // Step 3: study goal
    // Step 4: account creation (if new user)
    var step: Int = 0

    // Auth fields
    var email: String = ""
    var password: String = ""
    var confirmPassword: String = ""
    var isSignIn: Bool = false

    // Preferences
    var selectedExamType: ExamType = .apprentice
    var selectedState: String = ""
    var selectedGoal: StudyGoal = .moderate

    var isLoading: Bool = false
    var errorMessage: String? = nil
    var isSigningInWithApple: Bool = false

    private var isEmailValid: Bool {
        let pattern = #"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    var canProceedFromStep: Bool {
        switch step {
        case 1: return true
        case 2: return !selectedState.isEmpty
        case 3: return true
        case 4: return isSignIn
            ? (isEmailValid && !password.isEmpty)
            : (isEmailValid && password.count >= 8 && password == confirmPassword)
        default: return true
        }
    }

    func proceed(services: ServiceContainer, appVM: AppViewModel) async {
        if step < 3 {
            withAnimation { step += 1 }
        } else {
            await createAccount(services: services, appVM: appVM)
        }
    }

    func back() {
        if step > 0 { withAnimation { step -= 1 } }
    }

    private func createAccount(services: ServiceContainer, appVM: AppViewModel) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if isSignIn {
                let user = try await services.auth.signIn(email: email, password: password)
                Analytics.track(.userSignedIn)
                await appVM.applyAuthenticatedUser(user, services: services)
            } else {
                let pending = PendingEmailConfirmation(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    examType: selectedExamType,
                    state: selectedState,
                    studyGoal: selectedGoal,
                    requestedAt: Date()
                )

                switch try await services.auth.signUp(email: email, password: password, pending: pending) {
                case .authenticated(let user):
                    Analytics.track(.userSignedUp)
                    await appVM.applyAuthenticatedUser(user, services: services)
                case .awaitingEmailConfirmation(let pending):
                    password = ""
                    confirmPassword = ""
                    Analytics.track(.userSignedUp)
                    appVM.enterAwaitingEmailConfirmation(pending)
                }
            }
        } catch {
            if isSignIn,
               isEmailConfirmationRequired(error),
               let pending = services.auth.pendingEmailConfirmation,
               pending.normalizedEmail == email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                appVM.enterAwaitingEmailConfirmation(pending)
                return
            }
            errorMessage = mapAuthError(error)
        }
    }

    private func mapAuthError(_ error: Error) -> String {
        let raw = error.localizedDescription
        if raw.contains("security purposes") || raw.contains("rate limit") || raw.contains("after") {
            return "Too many attempts. Please wait a moment and try again."
        }
        if raw.contains("already registered") || raw.contains("already been registered") || raw.contains("already exists") {
            return "An account with this email already exists. Try signing in instead."
        }
        if raw.contains("Invalid login credentials") || raw.contains("invalid_credentials") {
            return "Incorrect email or password. Please try again."
        }
        if raw.contains("Email not confirmed") || raw.contains("email_not_confirmed") {
            return "Your account isn't confirmed yet. Check your inbox and open the confirmation link, or resend it."
        }
        if raw.contains("Password should be") || raw.contains("weak_password") {
            return "Password is too weak. Use at least 8 characters with a mix of letters and numbers."
        }
        if raw.contains("Unable to validate") || raw.contains("network") || raw.contains("URLSession") {
            return "Network error. Please check your connection and try again."
        }
        return raw
    }

    private func isEmailConfirmationRequired(_ error: Error) -> Bool {
        let raw = error.localizedDescription
        return raw.contains("Email not confirmed") || raw.contains("email_not_confirmed")
    }

    func signInWithApple(services: ServiceContainer, appVM: AppViewModel) async {
        isSigningInWithApple = true
        errorMessage = nil
        defer { isSigningInWithApple = false }

        do {
            let credential = try await AppleSignInCoordinator.start()
            var user = try await services.auth.signInWithApple(
                identityToken: credential.identityToken,
                nonce: credential.nonce,
                fullName: credential.fullName
            )

            if isSignIn == false && selectedState.isEmpty == false {
                var updatedUser = user
                updatedUser.examType = selectedExamType
                updatedUser.state = selectedState
                updatedUser.studyGoal = selectedGoal
                updatedUser.isOnboardingComplete = true
                try await services.auth.updateProfile(updatedUser)
                user = updatedUser
                Analytics.track(.onboardingCompleted(
                    examType: selectedExamType.rawValue,
                    state: selectedState,
                    studyGoal: selectedGoal.rawValue
                ))
            }

            Analytics.track(.userSignedIn)
            await appVM.applyAuthenticatedUser(user, services: services)
        } catch {
            errorMessage = mapAuthError(error)
        }
    }
}

// MARK: - Home ViewModel

@Observable
@MainActor
final class HomeViewModel {
    var loadState: LoadState<ProgressSummary> = .idle
    var greeting: String = "Good morning"

    func load(services: ServiceContainer) async {
        guard case .idle = loadState else { return }
        loadState = .loading
        greeting = Self.buildGreeting()
        do {
            let summary = try await services.progress.fetchSummary()
            loadState = .loaded(summary)
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func refresh(services: ServiceContainer) async {
        loadState = .idle
        await load(services: services)
    }

    private static func buildGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
}

// MARK: - Learn ViewModel

@Observable
@MainActor
final class LearnViewModel {
    var loadState: LoadState<[WWModule]> = .idle

    func load(services: ServiceContainer) async {
        guard case .idle = loadState else { return }
        loadState = .loading
        do {
            let modules = try await services.content.fetchModules()
            loadState = .loaded(modules)
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func refresh(services: ServiceContainer) async {
        loadState = .idle
        await load(services: services)
    }
}

// MARK: - Lesson ViewModel

struct LessonFlowContext {
    let module: WWModule
    let lessonIndex: Int
    let previousLessonId: UUID?
    let nextLessonId: UUID?

    var lessonNumber: Int { lessonIndex + 1 }
    var totalLessons: Int { module.lessons.count }
    var moduleProgress: Double { module.progress }
}

@Observable
@MainActor
final class LessonViewModel {
    var lesson: WWLesson?
    var flowContext: LessonFlowContext?
    var isLoading: Bool = false
    var errorMessage: String?
    var scrollProgress: Double = 0.0
    var selectedNEC: NECReference? = nil
    var showTutor: Bool = false

    var shouldShowLoadingState: Bool {
        isLoading || (lesson == nil && errorMessage == nil)
    }

    /// Set to true after XP is awarded for first completion so we don't double-award.
    var hasAwardedXPThisSession: Bool = false
    /// The XP earned this session — consumed by the celebration overlay.
    var sessionXPEarned: Int = 0
    /// Set to true when the lesson crosses 100% for the first time this session.
    var showCelebration: Bool = false

    func loadIfNeeded(lessonId: UUID, services: ServiceContainer) async {
        guard lesson == nil, errorMessage == nil, isLoading == false else { return }
        await load(lessonId: lessonId, services: services)
    }

    func load(lessonId: UUID, services: ServiceContainer) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let loadedLesson = try await services.content.fetchLesson(id: lessonId)
            lesson = loadedLesson
            scrollProgress = max(scrollProgress, loadedLesson.completionPercentage)
            do {
                let modules = try await services.content.fetchModules()
                if let module = modules.first(where: { $0.id == loadedLesson.moduleId }),
                   let lessonIndex = module.lessons.firstIndex(where: { $0.id == loadedLesson.id }) {
                    flowContext = LessonFlowContext(
                        module: module,
                        lessonIndex: lessonIndex,
                        previousLessonId: lessonIndex > 0 ? module.lessons[lessonIndex - 1].id : nil,
                        nextLessonId: lessonIndex < module.lessons.count - 1 ? module.lessons[lessonIndex + 1].id : nil
                    )
                } else {
                    flowContext = nil
                }
            } catch {
                flowContext = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveProgress(services: ServiceContainer) async {
        guard let lesson else { return }
        let effectiveProgress = max(scrollProgress, lesson.completionPercentage)
        try? await services.content.saveProgress(lessonId: lesson.id, completion: effectiveProgress)
        // User studied today — cancel today's streak-protection alert.
        StudyNotificationScheduler.shared.cancelStreakProtectionForToday()

        // Award XP on first-time completion (crossed 100% for the first time).
        let wasAlreadyComplete = lesson.completionPercentage >= 1.0
        if effectiveProgress >= 1.0 && !wasAlreadyComplete && !hasAwardedXPThisSession {
            hasAwardedXPThisSession = true
            let award = XPStore.shared.award(WWGamification.XP.lessonFirstComplete, source: .lessonComplete)
            sessionXPEarned = award.earned
        }
    }

    func markComplete() {
        scrollProgress = 1.0
    }

    func tapNEC(_ ref: NECReference) {
        selectedNEC = ref
    }

    /// Returns the ID of the next part if this is a mini-lesson, otherwise nil.
    func nextPartLessonId() -> UUID? {
        guard let lesson,
              let partNumber = lesson.partNumber,
              let totalParts = lesson.totalParts,
              partNumber < totalParts,
              let flowContext else { return nil }

        // Find the next part in the module's lessons
        let nextPartNumber = partNumber + 1
        let canonicalId = lesson.canonicalLessonID ?? ""
        return flowContext.module.lessons.first(where: {
            $0.partNumber == nextPartNumber && ($0.canonicalLessonID ?? "") == canonicalId
        })?.id
    }
}

// MARK: - Practice ViewModel

enum PracticeStartResolution: Equatable {
    case start(QuizType)
    case paywall(PaywallContext)
    case unavailable(title: String, message: String, suggestedQuiz: QuizType?)
}

@Observable
@MainActor
final class PracticeViewModel {
    var showPaywall: Bool = false
    var paywallContext: PaywallContext = .general
    var dashboard: PracticeDashboardSnapshot = .empty

    func startQuiz(_ type: QuizType, subscription: SubscriptionState) -> PracticeStartResolution {
        if subscription.hasPaidAccess == false {
            switch type {
            case .quickQuiz where subscription.previewQuickQuizLimitReached:
                paywallContext = .quizLimit
                showPaywall = true
                return .paywall(.quizLimit)
            case .fullPracticeExam:
                paywallContext = .practiceExamLocked
                showPaywall = true
                return .paywall(.practiceExamLocked)
            case .weakAreaReview where dashboard.canStartWeakAreaReview:
                paywallContext = .weakAreaLocked
                showPaywall = true
                return .paywall(.weakAreaLocked)
            default:
                break
            }
        }

        if type == .weakAreaReview && !dashboard.canStartWeakAreaReview {
            let message: String
            if dashboard.attemptCount == 0 {
                message = "Take a scored quiz first so WattWise can identify what to review next."
            } else {
                message = "You don't have any active weak areas right now. A fresh quick quiz is the fastest way to find your next focus."
            }
            return .unavailable(
                title: "Weak-area review isn't ready yet",
                message: message,
                suggestedQuiz: .quickQuiz
            )
        }

        return .start(type)
    }

    func refreshDashboard() {
        dashboard = PracticeHistoryStore.shared.dashboard()
    }
}

// MARK: - Quiz ViewModel

@Observable
@MainActor
final class QuizViewModel {
    var quiz: WWQuiz?
    var currentIndex: Int = 0
    var answers: [UUID: String] = [:]
    var revealedQuestions: Set<UUID> = []
    var result: QuizResult?
    var isLoading: Bool = false
    var isSubmitting: Bool = false
    var errorMessage: String?
    var showExitAlert: Bool = false
    var accessRestriction: QuizAccessRestriction?

    // Timing
    var sessionStartTime: Date? = nil
    var questionStartTime: Date? = nil
    var questionTimesSeconds: [UUID: Double] = [:]

    var shouldShowLoadingState: Bool {
        isLoading || (quiz == nil && result == nil && errorMessage == nil)
    }

    func loadIfNeeded(type: QuizType, examType: ExamType?, topicTags: [String] = [], services: ServiceContainer) async {
        guard quiz == nil, result == nil, errorMessage == nil, accessRestriction == nil, isLoading == false else { return }
        await load(type: type, examType: examType, topicTags: topicTags, services: services)
    }

    var currentQuestion: QuizQuestion? {
        guard let quiz, currentIndex < quiz.questions.count else { return nil }
        return quiz.questions[currentIndex]
    }

    var isLastQuestion: Bool {
        guard let quiz else { return false }
        return currentIndex == quiz.questions.count - 1
    }

    var progress: Double {
        guard let quiz else { return 0 }
        return Double(currentIndex + 1) / Double(max(1, quiz.questions.count))
    }

    func load(type: QuizType, examType: ExamType?, topicTags: [String] = [], services: ServiceContainer) async {
        isLoading = true
        errorMessage = nil
        accessRestriction = nil
        defer { isLoading = false }
        Analytics.track(.quizStarted(quizType: type.rawValue))
        do {
            // Caller-supplied tags take precedence; fall back to weak-area history for weakAreaReview
            let resolvedTopicTags: [String]
            if !topicTags.isEmpty {
                resolvedTopicTags = topicTags
            } else if type == .weakAreaReview {
                resolvedTopicTags = PracticeHistoryStore.shared.suggestedWeakTopicKeys()
            } else {
                resolvedTopicTags = []
            }
            let generatedQuiz = try await services.quiz.generateQuiz(type: type, topicTags: resolvedTopicTags, examType: examType)
            guard generatedQuiz.questions.isEmpty == false else {
                throw AppError.notFound("No quiz questions are available right now. Please try another quiz.")
            }
            quiz = generatedQuiz
            sessionStartTime = Date()
            questionStartTime = Date()
        } catch let apiError as APIError {
            switch apiError {
            case .forbidden(let message):
                accessRestriction = QuizAccessRestriction(context: type.paywallContext, message: message)
            default:
                errorMessage = apiError.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectAnswer(_ choice: String) {
        guard let q = currentQuestion else { return }
        answers[q.id] = choice
    }

    func next() {
        guard let quiz, currentIndex < quiz.questions.count - 1 else { return }
        // Record time for the question we're leaving
        recordTimeForCurrentQuestion()
        currentIndex += 1
        questionStartTime = Date()
    }

    func recordTimeForCurrentQuestion() {
        guard let q = currentQuestion, let start = questionStartTime else { return }
        let elapsed = Date().timeIntervalSince(start)
        questionTimesSeconds[q.id] = (questionTimesSeconds[q.id] ?? 0) + elapsed
        questionStartTime = Date()
    }

    func previous() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    func submit(services: ServiceContainer, appVM: AppViewModel) async {
        guard let quiz else { return }
        // Record time for the last question before submitting
        recordTimeForCurrentQuestion()
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let answerList = quiz.questions.compactMap { q -> QuizAnswer? in
            guard let selected = answers[q.id] else { return nil }
            return QuizAnswer(questionId: q.id, selected: selected)
        }

        let totalElapsed = sessionStartTime.map { Date().timeIntervalSince($0) }
        let timesSnapshot = Dictionary(uniqueKeysWithValues: questionTimesSeconds.map {
            ($0.key.uuidString, $0.value)
        })

        do {
            var fetchedResult = try await services.quiz.submitQuiz(quizId: quiz.id, answers: answerList)
            // Attach timing data if this was a timed session
            if quiz.type.isTimedSession {
                fetchedResult.totalElapsedSeconds = totalElapsed
                fetchedResult.questionTimesSeconds = timesSnapshot.isEmpty ? nil : timesSnapshot
            }
            // Award XP based on quiz score
            let xpAmount = XPStore.xpForQuiz(score: fetchedResult.score)
            XPStore.shared.award(xpAmount, source: fetchedResult.passed ? .quizPassed : .quizAttempt)
            fetchedResult.xpEarned = xpAmount

            result = fetchedResult
            if let result, result.quizAttemptId != nil {
                PracticeHistoryStore.shared.recordAttempt(
                    quiz: quiz,
                    results: result.results,
                    score: result.score,
                    correctCount: result.correctCount,
                    totalCount: result.totalCount
                )
                Analytics.track(.quizCompleted(quizType: quiz.type.rawValue, score: result.score, passed: result.passed))
                // Request notifications after first completed quiz — user has now seen product value
                if let user = appVM.currentUser {
                    await appVM.requestNotificationsIfNeeded(user: user)
                }
            }
            if appVM.subscriptionState.hasPaidAccess == false {
                appVM.subscriptionState.markPreviewQuizUsedIfNeeded()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        quiz = nil
        currentIndex = 0
        answers = [:]
        revealedQuestions = []
        result = nil
        errorMessage = nil
        accessRestriction = nil
        sessionStartTime = nil
        questionStartTime = nil
        questionTimesSeconds = [:]
    }
}

struct QuizAccessRestriction: Equatable {
    let context: PaywallContext
    let message: String
}

// MARK: - Tutor ViewModel

@Observable
@MainActor
final class TutorViewModel {
    var messages: [TutorMessage] = []
    var inputText: String = ""
    var isSending: Bool = false
    var showPaywall: Bool = false
    var context: TutorContext = TutorContextBuilder.general(for: nil)
    var sessionID: UUID?
    var errorState: TutorErrorState?

    private var activeRequestTask: Task<Void, Never>?
    private var lastFailedMessage: String?
    private var configuredStorageKey: String?
    private var lastSubmittedFingerprint: String?

    var hasContextHeader: Bool { context.type != .general }

    func configure(initialContext: TutorContext?, user: WWUser?) {
        let nextContext = initialContext ?? TutorContextBuilder.general(for: user)
        guard configuredStorageKey != nextContext.storageKey else {
            if context.examType == nil || context.jurisdiction == nil {
                context.examType = user?.examType.rawValue
                context.jurisdiction = user?.state.uppercased()
            }
            return
        }

        activeRequestTask?.cancel()
        context = nextContext
        configuredStorageKey = nextContext.storageKey
        restoreConversation()
        if messages.isEmpty {
            sessionID = nil
        }
        errorState = nil
        lastFailedMessage = nil
    }

    func send(services: ServiceContainer, appVM: AppViewModel) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        if appVM.subscriptionState.tutorLimitReached {
            showPaywall = true
            errorState = .quotaReached
            return
        }

        let fingerprint = "\(context.storageKey)|\(text.lowercased())"
        guard fingerprint != lastSubmittedFingerprint else { return }
        lastSubmittedFingerprint = fingerprint

        let userMsg = TutorMessage(id: UUID(), content: text, role: .user, timestamp: Date())
        messages.append(userMsg)
        inputText = ""
        isSending = true
        errorState = nil
        lastFailedMessage = text
        persistConversation()

        let requestHistory = messages
        activeRequestTask?.cancel()
        activeRequestTask = Task {
            do {
                let result = try await services.tutor.sendMessage(
                    text,
                    context: context,
                    history: requestHistory,
                    sessionID: sessionID
                )
                await MainActor.run {
                    sessionID = result.sessionId ?? sessionID
                    messages.append(result.message)
                    if let usage = result.usage {
                        appVM.subscriptionState.applyTutorUsage(usage)
                    } else if appVM.subscriptionState.hasPaidAccess == false {
                        appVM.subscriptionState.tutorMessagesUsed += 1
                    }
                    isSending = false
                    errorState = nil
                    lastSubmittedFingerprint = nil
                    persistConversation()
                }
            } catch is CancellationError {
                await MainActor.run {
                    isSending = false
                    lastSubmittedFingerprint = nil
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    errorState = makeErrorState(for: error)
                    if errorState == .quotaReached {
                        showPaywall = true
                    }
                    lastSubmittedFingerprint = nil
                    persistConversation()
                }
            }
        }
    }

    func sendFollowUp(_ text: String, services: ServiceContainer, appVM: AppViewModel) {
        inputText = text
        send(services: services, appVM: appVM)
    }

    func retry(services: ServiceContainer, appVM: AppViewModel) {
        guard let lastFailedMessage else { return }
        inputText = lastFailedMessage
        send(services: services, appVM: appVM)
    }

    func clear() {
        activeRequestTask?.cancel()
        messages = []
        sessionID = nil
        errorState = nil
        lastFailedMessage = nil
        lastSubmittedFingerprint = nil
        clearPersistedConversation()
    }

    func cancelPendingRequest() {
        activeRequestTask?.cancel()
    }

    private func makeErrorState(for error: Error) -> TutorErrorState {
        if let apiError = error as? APIError {
            switch apiError {
            case .rateLimited:
                return .quotaReached
            case .unauthorized:
                return .sessionExpired
            case .forbidden(let message):
                return .retryable(message: message)
            case .networkError, .serverError, .decodingError, .notFound:
                return .retryable(message: apiError.localizedDescription)
            }
        }
        let message = error.localizedDescription.lowercased().contains("limit")
            ? TutorErrorState.quotaReached.message
            : error.localizedDescription
        return message == TutorErrorState.quotaReached.message
            ? .quotaReached
            : .retryable(message: error.localizedDescription)
    }

    private func persistConversation() {
        guard let key = configuredStorageKey else { return }
        let snapshot = TutorConversationSnapshot(
            context: context,
            sessionID: sessionID,
            messages: messages
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.storagePrefix + key)
        }
    }

    private func restoreConversation() {
        guard let key = configuredStorageKey,
              let data = UserDefaults.standard.data(forKey: Self.storagePrefix + key),
              let snapshot = try? JSONDecoder().decode(TutorConversationSnapshot.self, from: data) else {
            messages = []
            sessionID = nil
            return
        }

        context = snapshot.context
        sessionID = snapshot.sessionID
        messages = snapshot.messages
    }

    private func clearPersistedConversation() {
        guard let key = configuredStorageKey else { return }
        UserDefaults.standard.removeObject(forKey: Self.storagePrefix + key)
    }

    private static let storagePrefix = "ww_tutor_conversation_v1_"
}

struct TutorErrorState: Equatable {
    var title: String
    var message: String
    var actionTitle: String
    var isQuotaRelated: Bool = false

    static let quotaReached = TutorErrorState(
        title: "Preview tutor limit reached",
        message: "You've used your preview tutor questions. Choose Fast Track or Full Prep for more guided help.",
        actionTitle: "See Access Options",
        isQuotaRelated: true
    )

    static let sessionExpired = TutorErrorState(
        title: "Session expired",
        message: "Sign in again so WattWise can keep your tutor context and progress in sync.",
        actionTitle: "Try Again"
    )

    static func retryable(message: String) -> TutorErrorState {
        TutorErrorState(
            title: "Tutor unavailable",
            message: message,
            actionTitle: "Retry"
        )
    }
}

private struct TutorConversationSnapshot: Codable {
    var context: TutorContext
    var sessionID: UUID?
    var messages: [TutorMessage]
}

extension TutorErrorState {
    var showsRetryAction: Bool { isQuotaRelated == false }
    var primaryActionTitle: String { actionTitle }
}

// MARK: - NEC ViewModel

@Observable
@MainActor
final class NECViewModel {
    var searchQuery: String = ""
    var results: [NECSearchResult] = []
    var isSearching: Bool = false
    var searchError: String? = nil
    var selectedDetail: NECReference? = nil
    var isLoadingDetail: Bool = false
    var detailError: String? = nil
    var isExplaining: Bool = false
    var expandedText: String? = nil
    var explainError: String? = nil
    var showPaywall: Bool = false
    // Edition state: nil = auto (resolved by edge function from user's state)
    var selectedEdition: String? = nil
    // The edition the last search resolved to (for display)
    var resolvedEdition: String? = nil
    // State amendments for the currently viewed article
    var amendments: NECAmendmentsResult? = nil
    var isLoadingAmendments: Bool = false

    private var searchTask: Task<Void, Never>? = nil

    func search(services: ServiceContainer, userState: String? = nil) {
        searchTask?.cancel()
        searchTask = Task {
            let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                isSearching = false
                searchError = nil
                results = []
                return
            }

            isSearching = true
            searchError = nil
            defer { isSearching = false }
            guard !Task.isCancelled else { return }
            do {
                try await Task.sleep(for: .milliseconds(300))  // debounce
                guard !Task.isCancelled else { return }
                let stateCode = userState.flatMap { $0.isEmpty ? nil : $0 }
                results = try await services.nec.search(
                    query: trimmed,
                    stateCode: stateCode,
                    editionOverride: selectedEdition
                )
                resolvedEdition = results.first?.edition ?? selectedEdition
            } catch is CancellationError {
                // A new search superseded this one — do not surface as error
            } catch {
                results = []
                searchError = "Search failed. Please try again."
            }
        }
    }

    func loadDetail(id: UUID, services: ServiceContainer, userState: String? = nil) async {
        isLoadingDetail = true
        expandedText = nil
        detailError = nil
        explainError = nil
        amendments = nil
        defer { isLoadingDetail = false }
        do {
            selectedDetail = try await services.nec.detail(id: id)
            // Load state amendments in parallel if user has a state set
            if let state = userState, !state.isEmpty, let code = selectedDetail?.code {
                isLoadingAmendments = true
                if let result = try? await services.nec.amendments(article: code, jurisdictionCode: state) {
                    amendments = result
                }
                isLoadingAmendments = false
            }
        } catch {
            detailError = error.localizedDescription
        }
    }

    func explain(id: UUID, services: ServiceContainer, appVM: AppViewModel) async {
        guard appVM.subscriptionState.hasPaidAccess || !appVM.subscriptionState.necExplanationLimitReached else {
            showPaywall = true
            return
        }
        isExplaining = true
        explainError = nil
        defer { isExplaining = false }
        do {
            let result = try await services.nec.explain(id: id)
            expandedText = result.expanded
            if let usage = result.usage {
                appVM.subscriptionState.applyNECUsage(usage)
            } else if appVM.subscriptionState.hasPaidAccess == false {
                appVM.subscriptionState.necExplanationsUsed += 1
            }
        } catch let apiError as APIError {
            switch apiError {
            case .rateLimited:
                showPaywall = true
            case .forbidden(let message):
                explainError = message
                showPaywall = true
            default:
                explainError = "Couldn't generate the explanation right now. Please try again."
            }
        } catch {
            explainError = "Couldn't generate the explanation right now. Please try again."
        }
    }
}

// MARK: - Profile ViewModel

@Observable
@MainActor
final class ProfileViewModel {
    var showSignOutAlert: Bool = false
    var showResetAlert: Bool = false
    var showDeleteAccountAlert: Bool = false
    var isSigningOut: Bool = false
    var isUpdatingProfile: Bool = false
    var isDeletingAccount: Bool = false
    var profileUpdateErrorMessage: String?

    func signOut(services: ServiceContainer, appVM: AppViewModel) async {
        isSigningOut = true
        appVM.signOut(services: services)
        isSigningOut = false
    }

    func updateProfileSettings(
        for user: WWUser,
        examType: ExamType,
        state: String,
        goal: StudyGoal,
        examDate: Date?,
        services: ServiceContainer,
        appVM: AppViewModel
    ) async -> Bool {
        isUpdatingProfile = true
        profileUpdateErrorMessage = nil
        defer { isUpdatingProfile = false }

        do {
            var updatedUser = user
            updatedUser.examType = examType
            updatedUser.state = state
            updatedUser.studyGoal = goal
            updatedUser.examDate = examDate
            try await services.auth.updateProfile(updatedUser)
            appVM.authState = .authenticated(updatedUser)
            Analytics.track(.onboardingCompleted(
                examType: examType.rawValue,
                state: state,
                studyGoal: goal.rawValue
            ))
            return true
        } catch {
            profileUpdateErrorMessage = error.localizedDescription
            return false
        }
    }

    func resetProgress(services: ServiceContainer, appVM: AppViewModel) {
        // Clear all locally cached profile and progress data
        let keys = [
            "ww_user",
            "ww_profile",
            "ww_access_token",
            "ww_refresh_token",
            "ww_user_data",
            "ww_content_progress_v2",
            "ww_content_study_activity_v1",
            "ww_practice_history_v1"
        ]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("ww_tutor_conversation_v1_") }
            .forEach { UserDefaults.standard.removeObject(forKey: $0) }
        // Sign out so the user starts fresh on next launch
        appVM.signOut(services: services)
    }

    func deleteAccount(services: ServiceContainer, appVM: AppViewModel) async -> Bool {
        isDeletingAccount = true
        profileUpdateErrorMessage = nil
        defer { isDeletingAccount = false }

        do {
            Analytics.track(.accountDeletionRequested)
            try await services.auth.deleteAccount()
            appVM.clearLocalSessionArtifacts()
            appVM.authState = .unauthenticated
            appVM.subscriptionState = .preview
            appVM.authStatusMessage = "Your WattWise account has been deleted."
            return true
        } catch {
            profileUpdateErrorMessage = error.localizedDescription
            Analytics.trackError(surface: "delete_account", message: error.localizedDescription)
            return false
        }
    }
}

// MARK: - Paywall ViewModel

@Observable
@MainActor
final class PaywallViewModel {
    let offers: [AccessOffer] = [.fastTrack, .fullPrep]
    var activeProductID: String?
    var isRestoring: Bool = false
    var errorMessage: String?
    var successMessage: String?
    var restoreMessage: String?
    var trialDescriptions: [String: String] = [:]

    func isPurchasing(_ productID: String) -> Bool {
        activeProductID == productID
    }

    func loadTrialInfo() async {
        guard let products = try? await Product.products(for: AccessProductID.allCases.map(\.rawValue)) else { return }
        for product in products {
            guard let introOffer = product.subscription?.introductoryOffer else { continue }
            let period = introOffer.period
            let unitStr: String
            switch period.unit {
            case .day:   unitStr = period.value == 1 ? "day" : "\(period.value) days"
            case .week:  unitStr = period.value == 1 ? "week" : "\(period.value) weeks"
            case .month: unitStr = period.value == 1 ? "month" : "\(period.value) months"
            case .year:  unitStr = period.value == 1 ? "year" : "\(period.value) years"
            @unknown default: unitStr = "\(period.value) \(period.unit)"
            }
            trialDescriptions[product.id] = "Try free for \(unitStr)"
        }
    }

    func purchase(productID: String, services: ServiceContainer, appVM: AppViewModel) async {
        activeProductID = productID
        errorMessage = nil
        successMessage = nil
        defer { activeProductID = nil }
        Analytics.track(.purchaseStarted(productId: productID))
        do {
            let state = try await services.subscription.purchase(productId: productID)
            appVM.subscriptionState = state
            successMessage = state.purchaseSuccessMessage
            Analytics.track(.purchaseCompleted(productId: productID))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore(services: ServiceContainer, appVM: AppViewModel) async {
        isRestoring = true
        errorMessage = nil
        restoreMessage = nil
        defer { isRestoring = false }
        do {
            let state = try await services.subscription.restorePurchases()
            appVM.subscriptionState = state
            restoreMessage = state.restoreSuccessMessage
        } catch {
            restoreMessage = error.localizedDescription
        }
    }
}
