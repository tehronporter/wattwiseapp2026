import SwiftUI

struct WelcomeView: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.openURL) private var openURL
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
                        FeatureRow(icon: "checkmark.seal", text: "Verified state-aware guidance where available")
                    }
                    .wwScreenPadding()

                    Spacer()

                    if let status = appVM.authStatusMessage {
                        Text(status)
                            .wwBody(color: .wwTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, WWSpacing.xl)
                            .padding(.bottom, WWSpacing.l)
                    }

                    if let error = appVM.authErrorMessage {
                        Text(error)
                            .font(WWFont.caption(.medium))
                            .foregroundColor(.wwError)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, WWSpacing.xl)
                            .padding(.bottom, WWSpacing.m)
                    }

                    // CTAs
                    VStack(spacing: WWSpacing.m) {
                        WWPrimaryButton(title: "Get Started") {
                            appVM.authStatusMessage = nil
                            appVM.authErrorMessage = nil
                            onboardingVM.isSignIn = false
                            onboardingVM.step = 1
                        }
                        WWSecondaryButton(title: "Sign In") {
                            appVM.authStatusMessage = nil
                            appVM.authErrorMessage = nil
                            onboardingVM.isSignIn = true
                            onboardingVM.step = 4
                        }
                    }
                    .wwScreenPadding()

                    HStack(spacing: WWSpacing.m) {
                        Button("Privacy") {
                            openURL(URL(string: "https://wattwiseapp.com/privacy")!)
                        }
                        Button("Terms") {
                            openURL(URL(string: "https://wattwiseapp.com/terms")!)
                        }
                    }
                    .font(WWFont.caption(.medium))
                    .foregroundColor(.wwTextMuted)
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
        .onAppear {
            applyAuthPrefillIfNeeded()
        }
        .onChange(of: appVM.authEntryPrefill) { _, _ in
            applyAuthPrefillIfNeeded()
        }
    }

    private func applyAuthPrefillIfNeeded() {
        guard let prefill = appVM.consumeAuthEntryPrefill() else { return }

        onboardingVM.email = prefill.email
        onboardingVM.password = ""
        onboardingVM.confirmPassword = ""
        onboardingVM.errorMessage = nil
        onboardingVM.isSignIn = prefill.isSignIn
        onboardingVM.step = prefill.isSignIn ? 4 : 1
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
