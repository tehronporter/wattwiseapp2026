import SwiftUI

// Container that manages the quiz flow: Loading → Active Quiz → Results
struct QuizContainerView: View {
    let quizType: QuizType
    @State private var vm = QuizViewModel()
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if vm.isLoading {
                QuizLoadingView()
            } else if let result = vm.result {
                QuizResultsView(result: result, quizType: quizType) {
                    vm.reset()
                    Task { await vm.load(type: quizType, examType: appVM.currentUser?.examType, services: services) }
                }
            } else if vm.quiz != nil {
                ActiveQuizView(vm: vm)
            } else if let error = vm.errorMessage {
                WWEmptyState(icon: "exclamationmark.triangle", title: "Couldn't load quiz", message: error, actionTitle: "Retry") {
                    Task { await vm.load(type: quizType, examType: appVM.currentUser?.examType, services: services) }
                }
            }
        }
        .background(Color.wwBackground)
        .navigationTitle(quizType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(vm.quiz != nil && vm.result == nil)
        .toolbar {
            if vm.quiz != nil && vm.result == nil {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        vm.showExitAlert = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.wwTextSecondary)
                    }
                }
            }
        }
        .alert("Exit Quiz?", isPresented: $vm.showExitAlert) {
            Button("Exit", role: .destructive) { dismiss() }
            Button("Continue", role: .cancel) {}
        } message: {
            Text("Your progress will be lost.")
        }
        .task { await vm.load(type: quizType, examType: appVM.currentUser?.examType, services: services) }
    }
}

// MARK: - Active Quiz

private struct ActiveQuizView: View {
    @Bindable var vm: QuizViewModel
    @Environment(ServiceContainer.self) private var services

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            VStack(spacing: WWSpacing.s) {
                WWProgressBar(value: vm.progress, height: 4)
                HStack {
                    Text("Question \(vm.currentIndex + 1) of \(vm.quiz?.questions.count ?? 0)")
                        .wwCaption()
                    Spacer()
                    Text(vm.quiz?.type.progressLabel ?? "")
                        .wwCaption(color: .wwTextMuted)
                }
            }
            .wwScreenPadding()
            .padding(.top, WWSpacing.s)

            ScrollView {
                if let question = vm.currentQuestion {
                    VStack(alignment: .leading, spacing: WWSpacing.l) {
                        // Question
                        Text(question.question)
                            .wwSubheading()
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)

                        // Answer choices
                        VStack(spacing: WWSpacing.s) {
                            ForEach(["A", "B", "C", "D"], id: \.self) { key in
                                if let choice = question.choices[key] {
                                    AnswerOption(
                                        key: key,
                                        text: choice,
                                        isSelected: vm.answers[question.id] == key
                                    ) {
                                        vm.selectAnswer(key)
                                    }
                                }
                            }
                        }
                    }
                    .wwScreenPadding()
                    .padding(.vertical, WWSpacing.l)
                }
            }

            // Navigation buttons — back is always reserved to prevent layout shift
            HStack(spacing: WWSpacing.m) {
                WWSecondaryButton(title: "Back") { vm.previous() }
                    .opacity(vm.currentIndex > 0 ? 1 : 0)
                    .disabled(vm.currentIndex == 0)

                if vm.isLastQuestion {
                    WWPrimaryButton(
                        title: "Submit",
                        isLoading: vm.isSubmitting,
                        isDisabled: vm.answers[vm.currentQuestion?.id ?? UUID()] == nil
                    ) {
                        Task { await vm.submit(services: services) }
                    }
                } else {
                    WWPrimaryButton(
                        title: "Next",
                        isDisabled: vm.answers[vm.currentQuestion?.id ?? UUID()] == nil
                    ) {
                        vm.next()
                    }
                }
            }
            .wwScreenPadding()
            .padding(.vertical, WWSpacing.m)
        }
    }
}

// MARK: - Answer Option

private struct AnswerOption: View {
    let key: String
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WWSpacing.m) {
                // Key circle
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.wwBlue : Color.wwDivider, lineWidth: 1.5)
                        .background(Circle().fill(isSelected ? Color.wwBlue : Color.clear))
                        .frame(width: 30, height: 30)
                    Text(key)
                        .font(WWFont.caption(.semibold))
                        .foregroundColor(isSelected ? .white : .wwTextSecondary)
                }

                Text(text)
                    .wwBody()
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(WWSpacing.m)
            .background(isSelected ? Color.wwBlueDim : Color.wwSurface)
            .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous)
                    .strokeBorder(isSelected ? Color.wwBlue : Color.clear, lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Loading View

private struct QuizLoadingView: View {
    var body: some View {
        VStack(spacing: WWSpacing.l) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Generating your quiz…")
                .wwBody(color: .wwTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
