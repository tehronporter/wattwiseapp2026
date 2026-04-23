import SwiftUI

struct OnboardingView: View {
    @Bindable var vm: OnboardingViewModel
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.wwBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    if vm.step > 1 && !vm.isSignIn {
                        WWIconButton(systemName: "chevron.left", color: .wwTextPrimary) {
                            vm.back()
                        }
                    } else {
                        Spacer().frame(width: WWSpacing.minTapTarget)
                    }
                    Spacer()
                    if !vm.isSignIn && vm.step < 4 {
                        ProgressDots(current: vm.step - 1, total: 3)
                    }
                    Spacer()
                    WWIconButton(systemName: "xmark", color: .wwTextMuted) {
                        dismiss()
                    }
                }
                .padding(.horizontal, WWSpacing.s)
                .padding(.top, WWSpacing.s)

                // Step content
                Group {
                    switch vm.step {
                    case 1: ExamTypeStep(vm: vm)
                    case 2: StateSelectionStep(vm: vm)
                    case 3: StudyGoalStep(vm: vm)
                    case 4: AccountStep(vm: vm)
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.25), value: vm.step)
            }
        }
    }
}

// MARK: - Step 1: Exam Type

private struct ExamTypeStep: View {
    @Bindable var vm: OnboardingViewModel
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: WWSpacing.s) {
                Text("What exam are you preparing for?")
                    .wwHeading()
                Text("We'll tailor your study plan to match the requirements.")
                    .wwBody(color: .wwTextSecondary)
            }
            .wwScreenPadding()
            .padding(.top, WWSpacing.xl)

            Spacer().frame(height: WWSpacing.xl)

            VStack(spacing: WWSpacing.m) {
                ForEach(ExamType.allCases) { type in
                    ExamTypeCard(type: type, isSelected: vm.selectedExamType == type) {
                        vm.selectedExamType = type
                    }
                }
            }
            .wwScreenPadding()

            Spacer()

            WWPrimaryButton(title: "Continue") {
                withAnimation { vm.step += 1 }
            }
            .wwScreenPadding()
            .padding(.bottom, WWSpacing.xxl)
        }
    }
}

private struct ExamTypeCard: View {
    let type: ExamType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WWSpacing.m) {
                VStack(alignment: .leading, spacing: WWSpacing.xs) {
                    Text(type.displayName)
                        .font(WWFont.sectionTitle(.semibold))
                        .foregroundColor(.wwTextPrimary)
                    Text(type.description)
                        .wwBody(color: .wwTextSecondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.wwBlue : Color.wwDivider, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.wwBlue)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(WWSpacing.m)
            .background(isSelected ? Color.wwBlueDim : Color.wwSurface)
            .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous)
                    .strokeBorder(isSelected ? Color.wwBlue : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Step 2: State Selection

private struct StateSelectionStep: View {
    @Bindable var vm: OnboardingViewModel
    @State private var searchText: String = ""
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM

    private var filteredStates: [(abbreviation: String, name: String)] {
        if searchText.isEmpty { return MockData.usStates }
        return MockData.usStates.filter {
            $0.name.lowercased().contains(searchText.lowercased()) ||
            $0.abbreviation.lowercased().contains(searchText.lowercased())
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: WWSpacing.s) {
                    Text("Which state are you in?")
                        .wwHeading()
                    Text("We use your state to surface verified adoption guidance where available while keeping your lessons grounded in the national NEC baseline.")
                        .wwBody(color: .wwTextSecondary)
                }
            .wwScreenPadding()
            .padding(.top, WWSpacing.xl)

            Spacer().frame(height: WWSpacing.m)

            WWSearchField(placeholder: "Search states…", text: $searchText)
            .wwScreenPadding()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredStates, id: \.abbreviation) { state in
                        StateRow(
                            name: state.name,
                            abbreviation: state.abbreviation,
                            isSelected: vm.selectedState == state.abbreviation
                        ) {
                            vm.selectedState = state.abbreviation
                        }
                        WWDivider()
                    }
                }
            }

            WWPrimaryButton(title: "Continue", isDisabled: vm.selectedState.isEmpty) {
                withAnimation { vm.step += 1 }
            }
            .wwScreenPadding()
            .padding(.bottom, WWSpacing.xxl)
        }
    }
}

private struct StateRow: View {
    let name: String
    let abbreviation: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).wwBody()
                    Text(abbreviation).wwCaption()
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.wwBlue)
                }
            }
            .padding(.vertical, WWSpacing.m)
            .wwScreenPadding()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 3: Study Goal

private struct StudyGoalStep: View {
    @Bindable var vm: OnboardingViewModel
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: WWSpacing.s) {
                Text("How much time can you study daily?")
                    .wwHeading()
                Text("We'll set a daily goal and track your streak.")
                    .wwBody(color: .wwTextSecondary)
            }
            .wwScreenPadding()
            .padding(.top, WWSpacing.xl)

            Spacer().frame(height: WWSpacing.xl)

            VStack(spacing: WWSpacing.m) {
                ForEach(StudyGoal.allCases) { goal in
                    GoalCard(goal: goal, isSelected: vm.selectedGoal == goal) {
                        vm.selectedGoal = goal
                    }
                }
            }
            .wwScreenPadding()

            Spacer()

            WWPrimaryButton(title: "Continue") {
                withAnimation { vm.step += 1 }
            }
            .wwScreenPadding()
            .padding(.bottom, WWSpacing.xxl)
        }
    }
}

private struct GoalCard: View {
    let goal: StudyGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(goal.displayName)
                    .font(WWFont.body(.medium))
                    .foregroundColor(.wwTextPrimary)
                Spacer()
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.wwBlue : Color.wwDivider, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Color.wwBlue).frame(width: 12, height: 12)
                    }
                }
            }
            .padding(WWSpacing.m)
            .background(isSelected ? Color.wwBlueDim : Color.wwSurface)
            .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous)
                    .strokeBorder(isSelected ? Color.wwBlue : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Step 4: Account Creation / Sign In

private struct AccountStep: View {
    @Bindable var vm: OnboardingViewModel
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM
    @State private var showForgotPassword = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: WWSpacing.s) {
                    Text(vm.isSignIn ? "Welcome back" : "Create your account")
                        .wwHeading()
                    Text(vm.isSignIn
                         ? "Sign in to continue your exam prep."
                         : "Your progress is saved to your account.")
                        .wwBody(color: .wwTextSecondary)
                }
                .padding(.top, WWSpacing.xl)

                Spacer().frame(height: WWSpacing.xl)

                VStack(spacing: WWSpacing.m) {
                    WWLabeledField(
                        label: "Email",
                        placeholder: "you@example.com",
                        text: $vm.email,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress,
                        submitLabel: .next
                    )
                    WWLabeledField(
                        label: "Password",
                        placeholder: vm.isSignIn ? "Your password" : "8+ characters",
                        text: $vm.password,
                        isSecure: true,
                        textContentType: vm.isSignIn ? .password : .newPassword,
                        submitLabel: vm.isSignIn ? .go : .next
                    )
                    if !vm.isSignIn {
                        WWLabeledField(
                            label: "Confirm Password",
                            placeholder: "Re-enter password",
                            text: $vm.confirmPassword,
                            isSecure: true,
                            textContentType: .newPassword,
                            submitLabel: .go
                        )
                    }
                }

                if vm.isSignIn {
                    Button {
                        showForgotPassword = true
                    } label: {
                        Text("Forgot password?")
                            .font(WWFont.caption(.medium))
                            .foregroundColor(.wwBlue)
                    }
                    .padding(.top, WWSpacing.s)
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .font(WWFont.caption(.medium))
                        .foregroundColor(.wwError)
                        .padding(.top, WWSpacing.s)
                }

                Spacer().frame(height: WWSpacing.xl)

                WWPrimaryButton(
                    title: vm.isSignIn ? "Sign In" : "Create Account",
                    isLoading: vm.isLoading,
                    isDisabled: !vm.canProceedFromStep
                ) {
                    Task { await vm.proceed(services: services, appVM: appVM) }
                }

                HStack {
                    WWDivider()
                    Text("or")
                        .wwCaption(color: .wwTextMuted)
                    WWDivider()
                }
                .padding(.vertical, WWSpacing.s)

                WWAppleSignInButton(
                    title: vm.isSignIn ? "Continue with Apple" : "Sign up with Apple",
                    isLoading: vm.isSigningInWithApple
                ) {
                    Task { await vm.signInWithApple(services: services, appVM: appVM) }
                }

                Spacer().frame(height: WWSpacing.m)

                Button {
                    withAnimation {
                        vm.isSignIn.toggle()
                        vm.password = ""
                        vm.confirmPassword = ""
                        vm.errorMessage = nil
                    }
                } label: {
                    Text(vm.isSignIn ? "Don't have an account? Sign up" : "Already have an account? Sign in")
                        .font(WWFont.body(.medium))
                        .foregroundColor(.wwBlue)
                        .frame(maxWidth: .infinity)
                }

                Spacer().frame(height: WWSpacing.xxl)
            }
            .wwScreenPadding()
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet(services: services)
        }
    }
}

private struct WWAppleSignInButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WWSpacing.s) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "applelogo")
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(isLoading ? "Connecting…" : title)
                    .font(WWFont.body(.semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: WWSpacing.minTapTarget)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

// MARK: - Forgot Password Sheet

private struct ForgotPasswordSheet: View {
    let services: ServiceContainer
    @State private var email: String = ""
    @State private var isLoading = false
    @State private var successMessage: String?
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private var isEmailValid: Bool {
        let pattern = #"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: WWSpacing.xl) {
                VStack(alignment: .leading, spacing: WWSpacing.s) {
                    Text("Reset your password")
                        .wwHeading()
                    Text("Enter your email and we'll send a reset link.")
                        .wwBody(color: .wwTextSecondary)
                }

                WWLabeledField(
                    label: "Email",
                    placeholder: "you@example.com",
                    text: $email,
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress,
                    submitLabel: .go
                )

                if let success = successMessage {
                    Text(success)
                        .font(WWFont.body(.medium))
                        .foregroundColor(.wwSuccess)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(WWFont.caption(.medium))
                        .foregroundColor(.wwError)
                }

                WWPrimaryButton(
                    title: successMessage != nil ? "Sent!" : "Send Reset Link",
                    isLoading: isLoading,
                    isDisabled: !isEmailValid || successMessage != nil
                ) {
                    Task { await sendReset() }
                }

                Spacer()
            }
            .wwScreenPadding()
            .padding(.top, WWSpacing.xl)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.wwTextSecondary)
                    }
                }
            }
        }
    }

    private func sendReset() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await services.auth.resetPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
            successMessage = "Check \(email) for a password reset link."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Progress Dots

private struct ProgressDots: View {
    let current: Int  // 0-based
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.wwBlue : Color.wwDivider)
                    .frame(width: i == current ? 20 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
    }
}
