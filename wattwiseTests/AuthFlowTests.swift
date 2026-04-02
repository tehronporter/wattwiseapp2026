import Foundation
import Testing
@testable import wattwise

private final class ScenarioAuthService: AuthServiceProtocol {
    var currentUser: WWUser?
    var pendingEmailConfirmation: PendingEmailConfirmation?
    var signUpResult: AuthSignUpResult
    var signInResult: Result<WWUser, Error>
    var callbackResult: Result<WWUser, Error>
    var resendCount = 0

    init(
        signUpResult: AuthSignUpResult,
        signInResult: Result<WWUser, Error> = .failure(AppError.unknown),
        callbackResult: Result<WWUser, Error> = .failure(AppError.unknown),
        pendingEmailConfirmation: PendingEmailConfirmation? = nil
    ) {
        self.signUpResult = signUpResult
        self.signInResult = signInResult
        self.callbackResult = callbackResult
        self.pendingEmailConfirmation = pendingEmailConfirmation
    }

    func signIn(email: String, password: String) async throws -> WWUser {
        try signInResult.get()
    }

    func signUp(email: String, password: String, pending: PendingEmailConfirmation) async throws -> AuthSignUpResult {
        pendingEmailConfirmation = pending
        return signUpResult
    }

    func signInWithApple(token: String) async throws -> WWUser {
        throw AppError.invalidInput("Unsupported in tests.")
    }

    func signOut() throws {
        currentUser = nil
        pendingEmailConfirmation = nil
    }

    func restoreSession() async -> WWUser? {
        currentUser
    }

    func updateProfile(_ user: WWUser) async throws {
        currentUser = user
    }

    func resendConfirmation(email: String) async throws {
        resendCount += 1
        if let pendingEmailConfirmation {
            self.pendingEmailConfirmation = PendingEmailConfirmation(
                email: pendingEmailConfirmation.email,
                examType: pendingEmailConfirmation.examType,
                state: pendingEmailConfirmation.state,
                studyGoal: pendingEmailConfirmation.studyGoal,
                requestedAt: Date()
            )
        }
    }

    func handleAuthCallback(url: URL) async throws -> WWUser {
        try callbackResult.get()
    }
}

struct AuthFlowTests {
    @Test func confirmationBridgeUsesSupabaseEdgeFunctionByDefault() {
        let url = AuthRedirectConfiguration.confirmationBridgeURL(environment: [:])

        #expect(url.absoluteString == "https://lxjjwodpiaivtkbjrodu.supabase.co/functions/v1/auth_confirmation")
    }

    @Test func confirmationBridgeHonorsEnvironmentOverride() {
        let url = AuthRedirectConfiguration.confirmationBridgeURL(
            environment: ["WATTWISE_AUTH_CONFIRMATION_URL": "https://example.com/auth/confirm"]
        )

        #expect(url.absoluteString == "https://example.com/auth/confirm")
    }

    @Test func authCallbackParserReadsFragmentTokens() {
        let url = URL(string: "wattwise://auth/callback#access_token=abc&refresh_token=def&token_type=bearer&expires_in=3600&type=signup")!
        let payload = AuthCallbackPayload.from(url: url)

        #expect(payload?.accessToken == "abc")
        #expect(payload?.refreshToken == "def")
        #expect(payload?.expiresIn == 3600)
        #expect(payload?.type == "signup")
        #expect(payload?.hasSessionTokens == true)
    }

    @Test func authCallbackParserSurfacesErrors() {
        let url = URL(string: "wattwise://auth/callback?error=access_denied&error_description=Link+expired")!
        let payload = AuthCallbackPayload.from(url: url)

        #expect(payload?.surfacedErrorMessage == "Link expired")
    }

    @Test func resendRequestEncodesConfirmationBridgeRedirect() throws {
        let request = ResendSignUpRequest(
            email: "pending@wattwiseapp.com",
            redirectTo: "https://lxjjwodpiaivtkbjrodu.supabase.co/functions/v1/auth_confirmation"
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: String]

        #expect(json?["email"] == "pending@wattwiseapp.com")
        #expect(json?["type"] == "signup")
        #expect(json?["redirect_to"] == "https://lxjjwodpiaivtkbjrodu.supabase.co/functions/v1/auth_confirmation")
    }

    @Test func authFlowRouteUsesOnboardingCompletion() {
        var incomplete = WWUser.guest
        incomplete.email = "pending@wattwiseapp.com"

        let complete = WWUser(
            id: UUID(),
            email: "ready@wattwiseapp.com",
            displayName: nil,
            examType: .apprentice,
            state: "TX",
            studyGoal: .moderate,
            streakDays: 0,
            isOnboardingComplete: true
        )

        switch AuthFlowRoute(user: incomplete) {
        case .onboarding(let user):
            #expect(user.email == "pending@wattwiseapp.com")
        case .authenticated:
            Issue.record("Expected incomplete user to route to onboarding.")
        }

        switch AuthFlowRoute(user: complete) {
        case .authenticated(let user):
            #expect(user.email == "ready@wattwiseapp.com")
        case .onboarding:
            Issue.record("Expected complete user to route home.")
        }
    }

    @MainActor
    @Test func signupPendingShowsCheckEmailState() async {
        let pending = PendingEmailConfirmation(
            email: "new@wattwiseapp.com",
            examType: .master,
            state: "TX",
            studyGoal: .intensive,
            requestedAt: Date()
        )
        let auth = ScenarioAuthService(signUpResult: .awaitingEmailConfirmation(pending))
        let services = ServiceContainer(
            auth: auth,
            content: MockContentService(),
            quiz: MockQuizService(),
            tutor: MockTutorService(),
            nec: MockNECService(),
            progress: MockProgressService(),
            subscription: MockSubscriptionService()
        )
        let appVM = AppViewModel()
        let onboardingVM = OnboardingViewModel()

        onboardingVM.step = 4
        onboardingVM.email = pending.email
        onboardingVM.password = "Password123"
        onboardingVM.confirmPassword = "Password123"
        onboardingVM.selectedExamType = pending.examType
        onboardingVM.selectedState = pending.state
        onboardingVM.selectedGoal = pending.studyGoal

        await onboardingVM.proceed(services: services, appVM: appVM)

        switch appVM.authState {
        case .awaitingEmailConfirmation(let saved):
            #expect(saved.email == pending.email)
            #expect(saved.state == "TX")
        default:
            Issue.record("Expected sign-up to end in confirmation-pending state.")
        }

        #expect(appVM.authStatusMessage?.contains("confirmation link") == true)
    }

    @MainActor
    @Test func unconfirmedSignInReturnsUserToPendingState() async {
        let pending = PendingEmailConfirmation(
            email: "pending@wattwiseapp.com",
            examType: .apprentice,
            state: "TX",
            studyGoal: .moderate,
            requestedAt: Date()
        )
        let auth = ScenarioAuthService(
            signUpResult: .awaitingEmailConfirmation(pending),
            signInResult: .failure(AuthError.server("Email not confirmed")),
            pendingEmailConfirmation: pending
        )
        let services = ServiceContainer(
            auth: auth,
            content: MockContentService(),
            quiz: MockQuizService(),
            tutor: MockTutorService(),
            nec: MockNECService(),
            progress: MockProgressService(),
            subscription: MockSubscriptionService()
        )
        let appVM = AppViewModel()
        let onboardingVM = OnboardingViewModel()

        onboardingVM.step = 4
        onboardingVM.isSignIn = true
        onboardingVM.email = pending.email
        onboardingVM.password = "Password123"

        await onboardingVM.proceed(services: services, appVM: appVM)

        switch appVM.authState {
        case .awaitingEmailConfirmation(let saved):
            #expect(saved.email == pending.email)
        default:
            Issue.record("Expected unconfirmed sign-in to return to confirmation-pending state.")
        }
    }

    @MainActor
    @Test func confirmationCallbackRoutesIncompleteUserToOnboarding() async {
        let user = WWUser(
            id: UUID(),
            email: "pending@wattwiseapp.com",
            displayName: nil,
            examType: .apprentice,
            state: "",
            studyGoal: .moderate,
            streakDays: 0,
            isOnboardingComplete: false
        )
        let auth = ScenarioAuthService(
            signUpResult: .authenticated(user),
            callbackResult: .success(user)
        )
        let services = ServiceContainer(
            auth: auth,
            content: MockContentService(),
            quiz: MockQuizService(),
            tutor: MockTutorService(),
            nec: MockNECService(),
            progress: MockProgressService(),
            subscription: MockSubscriptionService()
        )
        let appVM = AppViewModel()

        await appVM.handleIncomingURL(AuthRedirectConfiguration.appCallbackURL, services: services)

        switch appVM.authState {
        case .onboarding(let routed):
            #expect(routed.email == user.email)
        default:
            Issue.record("Expected callback to continue onboarding for incomplete profiles.")
        }
    }

    @MainActor
    @Test func confirmationCallbackRoutesCompleteUserHome() async {
        let user = WWUser(
            id: UUID(),
            email: "ready@wattwiseapp.com",
            displayName: nil,
            examType: .apprentice,
            state: "TX",
            studyGoal: .moderate,
            streakDays: 0,
            isOnboardingComplete: true
        )
        let auth = ScenarioAuthService(
            signUpResult: .authenticated(user),
            callbackResult: .success(user)
        )
        let services = ServiceContainer(
            auth: auth,
            content: MockContentService(),
            quiz: MockQuizService(),
            tutor: MockTutorService(),
            nec: MockNECService(),
            progress: MockProgressService(),
            subscription: MockSubscriptionService()
        )
        let appVM = AppViewModel()

        await appVM.handleIncomingURL(AuthRedirectConfiguration.appCallbackURL, services: services)

        switch appVM.authState {
        case .authenticated(let routed):
            #expect(routed.email == user.email)
        default:
            Issue.record("Expected confirmed user to land in authenticated state.")
        }
    }

    @MainActor
    @Test func resendConfirmationKeepsPendingStateAndUpdatesStatus() async {
        let pending = PendingEmailConfirmation(
            email: "pending@wattwiseapp.com",
            examType: .apprentice,
            state: "TX",
            studyGoal: .moderate,
            requestedAt: Date()
        )
        let auth = ScenarioAuthService(
            signUpResult: .awaitingEmailConfirmation(pending),
            pendingEmailConfirmation: pending
        )
        let services = ServiceContainer(
            auth: auth,
            content: MockContentService(),
            quiz: MockQuizService(),
            tutor: MockTutorService(),
            nec: MockNECService(),
            progress: MockProgressService(),
            subscription: MockSubscriptionService()
        )
        let appVM = AppViewModel()

        appVM.enterAwaitingEmailConfirmation(pending)
        await appVM.resendConfirmation(services: services)

        #expect(auth.resendCount == 1)
        #expect(appVM.authStatusMessage?.contains("new confirmation link") == true)

        switch appVM.authState {
        case .awaitingEmailConfirmation(let saved):
            #expect(saved.email == pending.email)
        default:
            Issue.record("Expected resend to keep the app in confirmation-pending state.")
        }
    }
}
