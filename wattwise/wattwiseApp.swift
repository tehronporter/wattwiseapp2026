import SwiftUI

@main
struct WattWiseApp: App {
    @State private var services = ServiceContainer()
    @State private var appVM = AppViewModel()

    init() {
        WWFontRegistrar.registerIfNeeded()
        UITestBootstrap.configureIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(services)
                .environment(appVM)
                .task { await appVM.restoreSession(services: services) }
        }
    }
}

// MARK: - Root Router

struct AppRootView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        Group {
            switch appVM.authState {
            case .loading:
                SplashView()

            case .unauthenticated:
                WelcomeView()
                    .transition(.opacity)

            case .onboarding(let user):
                // Show onboarding flow for incomplete profiles
                let _ = user
                OnboardingFlowRoot()
                    .transition(.opacity)

            case .authenticated:
                RootTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appVM.isAuthenticated)
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
    }
}
