import SwiftUI

@main
struct WattWiseApp: App {
    @State private var services = ServiceContainer()
    @State private var appVM = AppViewModel()

    init() {
        WWFontRegistrar.registerIfNeeded()
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
    @State private var vm = OnboardingViewModel()
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack {
            OnboardingView(vm: vm)
        }
        .onAppear {
            vm.step = 1
            if let user = appVM.currentUser {
                vm.email = user.email
                vm.selectedExamType = user.examType
                vm.selectedState = user.state
            }
        }
    }
}
