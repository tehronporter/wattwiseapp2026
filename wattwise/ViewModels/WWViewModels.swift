import Foundation
import SwiftUI

// MARK: - App ViewModel (root state)

@Observable
@MainActor
final class AppViewModel {
    var authState: AuthState = .loading
    var subscriptionState: SubscriptionState = .freeTier

    enum AuthState {
        case loading
        case unauthenticated
        case onboarding(WWUser)
        case authenticated(WWUser)
    }

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

    func restoreSession(services: ServiceContainer) async {
        if let user = await services.auth.restoreSession() {
            if user.isOnboardingComplete {
                authState = .authenticated(user)
            } else {
                authState = .onboarding(user)
            }
            subscriptionState = (try? await services.subscription.fetchState()) ?? .freeTier
        } else {
            authState = .unauthenticated
        }
    }

    func signOut(services: ServiceContainer) {
        try? services.auth.signOut()
        authState = .unauthenticated
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
            var user: WWUser
            if isSignIn {
                user = try await services.auth.signIn(email: email, password: password)
                // Returning users keep their saved profile; don't overwrite with defaults
                appVM.authState = .authenticated(user)
            } else {
                user = try await services.auth.signUp(email: email, password: password)
                user.examType = selectedExamType
                user.state = selectedState
                user.studyGoal = selectedGoal
                user.isOnboardingComplete = true
                try await services.auth.updateProfile(user)
                appVM.authState = .authenticated(user)
            }
        } catch {
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
            return "Please check your email and confirm your account before signing in."
        }
        if raw.contains("Password should be") || raw.contains("weak_password") {
            return "Password is too weak. Use at least 8 characters with a mix of letters and numbers."
        }
        if raw.contains("Unable to validate") || raw.contains("network") || raw.contains("URLSession") {
            return "Network error. Please check your connection and try again."
        }
        return raw
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

@Observable
@MainActor
final class LessonViewModel {
    var lesson: WWLesson?
    var isLoading: Bool = false
    var errorMessage: String?
    var scrollProgress: Double = 0.0
    var selectedNEC: NECReference? = nil
    var showNECSheet: Bool = false
    var showTutor: Bool = false

    func load(lessonId: UUID, services: ServiceContainer) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            lesson = try await services.content.fetchLesson(id: lessonId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveProgress(services: ServiceContainer) async {
        guard let lesson else { return }
        try? await services.content.saveProgress(lessonId: lesson.id, completion: scrollProgress)
    }

    func tapNEC(_ ref: NECReference) {
        selectedNEC = ref
        showNECSheet = true
    }
}

// MARK: - Practice ViewModel

@Observable
@MainActor
final class PracticeViewModel {
    var showPaywall: Bool = false
    var selectedQuizType: QuizType? = nil

    func startQuiz(_ type: QuizType, subscription: SubscriptionState) -> Bool {
        if type == .fullPracticeExam && !subscription.isPro {
            showPaywall = true
            return false
        }
        selectedQuizType = type
        return true
    }
}

// MARK: - Quiz ViewModel

@Observable
@MainActor
final class QuizViewModel {
    var quiz: WWQuiz?
    var currentIndex: Int = 0
    var answers: [UUID: String] = [:]
    var result: QuizResult?
    var isLoading: Bool = false
    var isSubmitting: Bool = false
    var errorMessage: String?
    var showExitAlert: Bool = false

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

    func load(type: QuizType, services: ServiceContainer) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            quiz = try await services.quiz.generateQuiz(type: type, topicTags: [])
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
        currentIndex += 1
    }

    func previous() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    func submit(services: ServiceContainer) async {
        guard let quiz else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let answerList = quiz.questions.compactMap { q -> QuizAnswer? in
            guard let selected = answers[q.id] else { return nil }
            return QuizAnswer(questionId: q.id, selected: selected)
        }

        do {
            result = try await services.quiz.submitQuiz(quizId: quiz.id, answers: answerList)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        quiz = nil
        currentIndex = 0
        answers = [:]
        result = nil
        errorMessage = nil
    }
}

// MARK: - Tutor ViewModel

@Observable
@MainActor
final class TutorViewModel {
    var messages: [TutorMessage] = []
    var inputText: String = ""
    var isSending: Bool = false
    var showPaywall: Bool = false
    var context: TutorContext? = nil
    var errorMessage: String?

    func send(services: ServiceContainer, subscription: SubscriptionState) async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        if subscription.tutorLimitReached {
            showPaywall = true
            return
        }

        let userMsg = TutorMessage(id: UUID(), content: text, role: .user, timestamp: Date())
        messages.append(userMsg)
        inputText = ""
        isSending = true
        errorMessage = nil

        do {
            let response = try await services.tutor.sendMessage(text, context: context)
            messages.append(response)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }

    func sendFollowUp(_ text: String, services: ServiceContainer, subscription: SubscriptionState) {
        inputText = text
        Task { await send(services: services, subscription: subscription) }
    }

    func clear() {
        messages = []
        context = nil
    }
}

// MARK: - NEC ViewModel

@Observable
@MainActor
final class NECViewModel {
    var searchQuery: String = ""
    var results: [NECSearchResult] = []
    var isSearching: Bool = false
    var selectedDetail: NECReference? = nil
    var isLoadingDetail: Bool = false
    var isExplaining: Bool = false
    var expandedText: String? = nil
    var showPaywall: Bool = false

    private var searchTask: Task<Void, Never>? = nil

    func search(services: ServiceContainer) {
        searchTask?.cancel()
        searchTask = Task {
            isSearching = true
            defer { isSearching = false }
            guard !Task.isCancelled else { return }
            do {
                try await Task.sleep(for: .milliseconds(300))  // debounce
                guard !Task.isCancelled else { return }
                results = try await services.nec.search(query: searchQuery)
            } catch {}
        }
    }

    func loadDetail(id: UUID, services: ServiceContainer) async {
        isLoadingDetail = true
        expandedText = nil
        defer { isLoadingDetail = false }
        do {
            selectedDetail = try await services.nec.detail(id: id)
        } catch {}
    }

    func explain(id: UUID, services: ServiceContainer, subscription: SubscriptionState) async {
        guard subscription.isPro || subscription.dailyTutorMessagesUsed < 2 else {
            showPaywall = true
            return
        }
        isExplaining = true
        defer { isExplaining = false }
        do {
            expandedText = try await services.nec.explain(id: id)
        } catch {}
    }
}

// MARK: - Profile ViewModel

@Observable
@MainActor
final class ProfileViewModel {
    var showSignOutAlert: Bool = false
    var showResetAlert: Bool = false
    var isSigningOut: Bool = false

    func signOut(services: ServiceContainer, appVM: AppViewModel) async {
        isSigningOut = true
        appVM.signOut(services: services)
        isSigningOut = false
    }
}

// MARK: - Paywall ViewModel

@Observable
@MainActor
final class PaywallViewModel {
    enum Plan: String, CaseIterable { case monthly, yearly }
    var selectedPlan: Plan = .yearly
    var isPurchasing: Bool = false
    var isRestoring: Bool = false
    var errorMessage: String?

    var monthlyPrice: String { "$9.99/month" }
    var yearlyPrice: String { "$59.99/year" }
    var yearlySavings: String { "Save 50%" }

    func purchase(services: ServiceContainer, appVM: AppViewModel) async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            let productId = selectedPlan == .monthly
                ? "wattwise.pro.monthly"
                : "wattwise.pro.yearly"
            let state = try await services.subscription.purchase(productId: productId)
            appVM.subscriptionState = state
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore(services: ServiceContainer, appVM: AppViewModel) async {
        isRestoring = true
        errorMessage = nil
        defer { isRestoring = false }
        do {
            let state = try await services.subscription.restorePurchases()
            appVM.subscriptionState = state
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
