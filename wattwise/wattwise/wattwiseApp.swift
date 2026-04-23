import SwiftUI
import StoreKit
// Firebase Crashlytics — activate by:
// 1. In Xcode: File > Add Package Dependency > https://github.com/firebase/firebase-ios-sdk
//    Add: FirebaseCrashlytics, FirebaseAnalytics
// 2. Add your GoogleService-Info.plist to the wattwise target
// 3. Uncomment the import and configure() call below
// import FirebaseCore

@main
struct WattWiseApp: App {
    @State private var services = ServiceContainer()
    @State private var appVM = AppViewModel()

    init() {
        // FirebaseApp.configure()   // ← Uncomment after step 1-2 above
        WWFontRegistrar.registerIfNeeded()
        UITestBootstrap.configureIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(services)
                .environment(appVM)
                .task { await appVM.restoreSession(services: services) }
                .onOpenURL { url in
                    Task { await appVM.handleIncomingURL(url, services: services) }
                }
        }
    }
}

// MARK: - Root Router

struct AppRootView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(ServiceContainer.self) private var services

    var body: some View {
        Group {
            switch appVM.authState {
            case .loading:
                SplashView()

            case .unauthenticated:
                WelcomeView()
                    .transition(.opacity)

            case .awaitingEmailConfirmation(let pending):
                EmailConfirmationPendingView(pending: pending)
                    .transition(.opacity)

            case .onboarding(let user):
                // Show onboarding flow for incomplete profiles
                let _ = user
                OnboardingFlowRoot()
                    .transition(.opacity)

            case .authenticated:
                RootTabView()
                    .transition(.opacity)

            case .passwordReset(let accessToken):
                SetNewPasswordView(accessToken: accessToken)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appVM.isAuthenticated)
        .onReceive(NotificationCenter.default.publisher(for: .wwSessionExpired)) { _ in
            // Token refresh failed — clear session and send user back to sign-in.
            appVM.signOut(services: services)
        }
    }
}

// MARK: - Splash Screen

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.wwBackground.ignoresSafeArea()
            VStack(spacing: WWSpacing.m) {
                ZStack {
                    Circle()
                        .fill(Color.wwBlueDim)
                        .frame(width: 80, height: 80)
                    Image(systemName: "bolt")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(.wwBlue)
                }
                Text("WattWise")
                    .wwDisplay()
            }
        }
    }
}

// MARK: - Onboarding Flow Root (for incomplete profiles)

struct OnboardingFlowRoot: View {
    @State private var vm: OnboardingViewModel = {
        let viewModel = OnboardingViewModel()
        viewModel.step = 1
        return viewModel
    }()
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack {
            OnboardingView(vm: vm)
        }
        .onAppear {
            if let user = appVM.currentUser {
                vm.email = user.email
                vm.selectedExamType = user.examType
                vm.selectedState = user.state
            }
        }
    }
}

// MARK: - Set New Password (after recovery link)

struct SetNewPasswordView: View {
    let accessToken: String
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM

    private var canSubmit: Bool {
        password.count >= 8 && password == confirmPassword && !isLoading
    }

    var body: some View {
        ZStack {
            Color.wwBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: WWSpacing.xl) {
                Spacer().frame(height: WWSpacing.xl)

                VStack(alignment: .leading, spacing: WWSpacing.s) {
                    Text("Set a new password")
                        .wwHeading()
                    Text("Choose a strong password for your account.")
                        .wwBody(color: .wwTextSecondary)
                }

                VStack(spacing: WWSpacing.m) {
                    WWLabeledField(
                        label: "New Password",
                        placeholder: "8+ characters",
                        text: $password,
                        isSecure: true,
                        textContentType: .newPassword,
                        submitLabel: .next
                    )
                    WWLabeledField(
                        label: "Confirm Password",
                        placeholder: "Re-enter password",
                        text: $confirmPassword,
                        isSecure: true,
                        textContentType: .newPassword,
                        submitLabel: .go
                    )
                }

                if let error = errorMessage {
                    Text(error)
                        .font(WWFont.caption(.medium))
                        .foregroundColor(.wwError)
                }

                WWPrimaryButton(
                    title: "Update Password",
                    isLoading: isLoading,
                    isDisabled: !canSubmit
                ) {
                    Task { await submit() }
                }

                Spacer()
            }
            .wwScreenPadding()
        }
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await services.auth.updatePassword(accessToken: accessToken, newPassword: password)
            appVM.signOut(services: services)
            appVM.authStatusMessage = "Password updated. Sign in with your new password."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum UITestBootstrap {
    static func configureIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("UITEST_MODE") else { return }

        if arguments.contains("UITEST_RESET_STATE") {
            [
                "ww_user",
                "ww_profile",
                "ww_access_token",
                "ww_refresh_token",
                "ww_content_progress_v2",
                "ww_content_study_activity_v1",
                "ww_practice_history_v1"
            ].forEach { UserDefaults.standard.removeObject(forKey: $0) }
        }

        if arguments.contains("UITEST_AUTHENTICATED") {
            let user = WWUser(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
                email: "uitest@wattwiseapp.com",
                displayName: "UI Test",
                examType: .apprentice,
                state: "TX",
                studyGoal: .moderate,
                streakDays: 4,
                isOnboardingComplete: true
            )
            if let data = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(data, forKey: "ww_user")
            }
        }

        if arguments.contains("UITEST_PENDING_CONFIRMATION") {
            PendingEmailConfirmationStore.save(
                PendingEmailConfirmation(
                    email: "pending@wattwiseapp.com",
                    examType: .apprentice,
                    state: "TX",
                    studyGoal: .moderate,
                    requestedAt: Date()
                )
            )
        }
    }
}
