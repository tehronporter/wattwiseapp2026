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
                Text("Exam requirements vary by jurisdiction.")
                    .wwBody(color: .wwTextSecondary)
            }
            .wwScreenPadding()
            .padding(.top, WWSpacing.xl)

            Spacer().frame(height: WWSpacing.m)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.wwTextMuted)
                TextField("Search states…", text: $searchText)
                    .font(WWFont.body())
            }
            .padding(WWSpacing.m)
            .background(Color.wwSurface)
            .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous))
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
