import SwiftUI

struct WelcomeView: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM
    @State private var onboardingVM = OnboardingViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.wwBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Logo + Brand
                    VStack(spacing: WWSpacing.l) {
                        ZStack {
                            Circle()
                                .fill(Color.wwBlueDim)
                                .frame(width: 96, height: 96)
                            Circle()
                                .fill(Color.wwBlue.opacity(0.08))
                                .frame(width: 120, height: 120)
                            Image(systemName: "bolt")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundColor(.wwBlue)
                        }

                        VStack(spacing: WWSpacing.xs) {
                            Text("WattWise")
                                .wwDisplay()
                            Text("Study smarter. Pass faster.")
                                .wwBody(color: .wwTextSecondary)
                        }
                    }

                    Spacer()

                    // Value props
                    VStack(alignment: .leading, spacing: WWSpacing.m) {
                        FeatureRow(icon: "brain.head.profile", text: "AI tutor that knows the NEC")
                        FeatureRow(icon: "chart.bar", text: "Adaptive quizzes based on your weaknesses")
                        FeatureRow(icon: "checkmark.seal", text: "State-specific exam preparation")
                    }
                    .wwScreenPadding()

                    Spacer()

                    // CTAs
                    VStack(spacing: WWSpacing.m) {
                        WWPrimaryButton(title: "Get Started") {
                            onboardingVM.isSignIn = false
                            onboardingVM.step = 1
                        }
                        WWSecondaryButton(title: "Sign In") {
                            onboardingVM.isSignIn = true
                            onboardingVM.step = 4
                        }
                    }
                    .wwScreenPadding()
                    .padding(.bottom, WWSpacing.xxl)
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { onboardingVM.step > 0 },
            set: { if !$0 { onboardingVM.step = 0 } }
        )) {
            OnboardingView(vm: onboardingVM)
                .environment(services)
                .environment(appVM)
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: WWSpacing.m) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.wwBlueDim)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.wwBlue)
            }
            Text(text)
                .wwBody()
        }
    }
}

#Preview {
    WelcomeView()
        .environment(ServiceContainer())
        .environment(AppViewModel())
}
