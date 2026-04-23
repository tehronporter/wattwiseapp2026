import SwiftUI

struct LessonView: View {
    let lessonId: UUID
    @State private var vm = LessonViewModel()
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM
    @State private var showTutorSheet = false
    @State private var nextLessonTarget: LessonNavigationTarget?
    @State private var showModuleDetail = false
    @State private var showPaywall = false
    @State private var bookmarks = BookmarkStore.shared
    @State private var showCelebration = false
    @State private var showCurrentnessSheet = false
    @State private var showTopicQuiz = false
    @State private var practiceTopicTags: [String] = []
    @State private var pendingTopicQuizAfterCelebration = false

    private var previewLessonID: UUID? {
        try? WattWiseContentRuntimeAdapter.previewLessonID(includeDraftContent: false)
    }

    /// Title shown in the completion bar's "Next" button.
    private var nextCompletionTitle: String? {
        if vm.nextPartLessonId() != nil {
            if let partNumber = vm.lesson?.partNumber, let totalParts = vm.lesson?.totalParts {
                return "Part \(partNumber + 1) of \(totalParts)"
            }
            return "Next Part"
        }
        if let context = vm.flowContext, context.nextLessonId != nil {
            return context.module.lessons.first(where: { $0.id == context.nextLessonId })?.title
        }
        return nil
    }

    private var isLockedForPreview: Bool {
        guard appVM.subscriptionState.hasPaidAccess == false else { return false }
        if let locked = vm.lesson?.isLocked {
            return locked
        }
        guard let previewLessonID else { return false }
        return lessonId != previewLessonID
    }

    var body: some View {
        Group {
            if isLockedForPreview {
                PreviewLessonLockView {
                    showPaywall = true
                } onOpenPreviewLesson: {
                    if let previewLessonID {
                        nextLessonTarget = LessonNavigationTarget(id: previewLessonID)
                    }
                }
            } else if vm.shouldShowLoadingState {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let lesson = vm.lesson {
                LessonContentView(
                    lesson: lesson,
                    vm: vm,
                    onOpenCurrentnessInfo: { showCurrentnessSheet = true },
                    isNextLessonLocked: appVM.subscriptionState.hasPaidAccess == false && vm.flowContext?.nextLessonId != nil,
                    onPreviousLesson: {
                        guard let previousLessonId = vm.flowContext?.previousLessonId else { return }
                        nextLessonTarget = LessonNavigationTarget(id: previousLessonId)
                    },
                    onBackToModule: {
                        showModuleDetail = true
                    },
                    onNextLesson: {
                        if appVM.subscriptionState.hasPaidAccess == false {
                            showPaywall = true
                        } else if let nextPartId = vm.nextPartLessonId() {
                            // Navigate to next part of current lesson
                            vm.markComplete()
                            nextLessonTarget = LessonNavigationTarget(id: nextPartId)
                        } else {
                            // Navigate to next lesson
                            guard let nextLessonId = vm.flowContext?.nextLessonId else { return }
                            vm.markComplete()
                            nextLessonTarget = LessonNavigationTarget(id: nextLessonId)
                        }
                    },
                    onPracticeTopicQuiz: {
                        if let topic = vm.lesson?.topic, !topic.isEmpty {
                            practiceTopicTags = [topic]
                        }
                        showTopicQuiz = true
                    }
                )
            } else if let error = vm.errorMessage {
                WWEmptyState(
                    icon: "exclamationmark.triangle",
                    title: "Couldn't load lesson",
                    message: error,
                    actionTitle: "Retry"
                ) {
                    Task { await vm.load(lessonId: lessonId, services: services) }
                }
            }
        }
        .background(Color.wwBackground)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(vm.lesson?.title ?? "")
        .toolbar {
            if isLockedForPreview == false {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if let lesson = vm.lesson {
                        Button {
                            bookmarks.toggle(lesson: lesson)
                        } label: {
                            Image(systemName: bookmarks.isBookmarked(lessonId) ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 15))
                                .foregroundColor(.wwBlue)
                        }
                    }
                    Button {
                        showTutorSheet = true
                    } label: {
                        Label("Ask Tutor", systemImage: "bubble.left")
                            .font(.system(size: 15))
                            .foregroundColor(.wwBlue)
                    }
                }
            }
        }
        .sheet(isPresented: $showTutorSheet) {
            if let lesson = vm.lesson {
                TutorSheetView(
                    context: TutorContextBuilder.lesson(lesson, user: appVM.currentUser),
                    contextTitle: "Asking about: \(lesson.title)"
                )
                .environment(services)
                .environment(appVM)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: .lessonLocked)
                .environment(services)
                .environment(appVM)
        }
        .sheet(isPresented: $showCurrentnessSheet) {
            NavigationStack {
                CurrentnessExplainerView()
            }
        }
        .sheet(item: $vm.selectedNEC) { nec in
            NECReferenceSheet(reference: nec)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            let isComplete = (vm.scrollProgress >= 1.0 || (vm.lesson?.completionPercentage ?? 0) >= 1.0) && !showCelebration
            if isComplete {
                LessonCompletionBar(
                    nextLessonTitle: nextCompletionTitle,
                    onNext: {
                        if let nextPartId = vm.nextPartLessonId() {
                            vm.markComplete()
                            nextLessonTarget = LessonNavigationTarget(id: nextPartId)
                        } else if let nextId = vm.flowContext?.nextLessonId {
                            if appVM.subscriptionState.hasPaidAccess == false {
                                showPaywall = true
                            } else {
                                vm.markComplete()
                                nextLessonTarget = LessonNavigationTarget(id: nextId)
                            }
                        } else {
                            showModuleDetail = true
                        }
                    },
                    onPractice: {
                        if let topic = vm.lesson?.topic, !topic.isEmpty {
                            practiceTopicTags = [topic]
                        }
                        showTopicQuiz = true
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isComplete)
            }
        }
        .navigationDestination(item: $nextLessonTarget) { destination in
            LessonView(lessonId: destination.id)
        }
        .navigationDestination(isPresented: $showModuleDetail) {
            if let module = vm.flowContext?.module {
                ModuleDetailView(module: module)
            } else {
                LearnView()
            }
        }
        .navigationDestination(isPresented: $showTopicQuiz) {
            QuizContainerView(quizType: .quickQuiz, topicTags: practiceTopicTags)
        }
        .task { await vm.loadIfNeeded(lessonId: lessonId, services: services) }
        .onDisappear { Task { await vm.saveProgress(services: services) } }
        .onChange(of: vm.scrollProgress) { _, newValue in
            guard !showCelebration,
                  let lesson = vm.lesson,
                  lesson.completionPercentage < 1.0,
                  !vm.hasAwardedXPThisSession,
                  newValue >= 1.0 else { return }
            Task {
                await vm.saveProgress(services: services)
                if vm.sessionXPEarned > 0 {
                    showCelebration = true
                }
            }
        }
        .fullScreenCover(isPresented: $showCelebration) {
            WWCelebrationOverlay(
                headline: "Lesson Complete!",
                xpEarned: vm.sessionXPEarned,
                streakDays: appVM.currentUser?.streakDays ?? 0,
                accuracyPercent: nil,
                onContinue: { showCelebration = false },
                secondaryActionTitle: "Practice This Topic",
                onSecondaryAction: {
                    pendingTopicQuizAfterCelebration = true
                    showCelebration = false
                }
            )
        }
        .onChange(of: showCelebration) { _, isShowing in
            guard !isShowing, pendingTopicQuizAfterCelebration else { return }
            pendingTopicQuizAfterCelebration = false
            if let topic = vm.lesson?.topic, !topic.isEmpty {
                practiceTopicTags = [topic]
            }
            showTopicQuiz = true
        }
    }
}

private struct LessonNavigationTarget: Identifiable, Hashable {
    let id: UUID
}

// MARK: - Lesson Content

private struct LessonContentView: View {
    let lesson: WWLesson
    @Bindable var vm: LessonViewModel
    let onOpenCurrentnessInfo: () -> Void
    let isNextLessonLocked: Bool
    let onPreviousLesson: () -> Void
    let onBackToModule: () -> Void
    let onNextLesson: () -> Void
    var onPracticeTopicQuiz: (() -> Void)? = nil

    private var effectiveProgress: Double {
        max(vm.scrollProgress, lesson.completionPercentage)
    }

    /// Indices of bullet sections that immediately follow a "Key Takeaways" heading.
    private var takeawayIndices: Set<Int> {
        var result = Set<Int>()
        var inTakeaways = false
        for (i, section) in lesson.sections.enumerated() {
            if section.type == .heading && section.body == "Key Takeaways" {
                inTakeaways = true
            } else if section.type == .heading {
                inTakeaways = false
            } else if inTakeaways && section.type == .bullet {
                result.insert(i)
            }
        }
        return result
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: WWSpacing.l) {
                    LessonHeaderCard(
                        lesson: lesson,
                        progress: effectiveProgress,
                        flowContext: vm.flowContext,
                        onOpenCurrentnessInfo: onOpenCurrentnessInfo
                    )

                    ForEach(Array(lesson.sections.enumerated()), id: \.element.id) { index, section in
                        let isHeadingBreak = section.type == .heading && index > 0
                        let isTakeaway = takeawayIndices.contains(index)
                        Group {
                            if isHeadingBreak {
                                VStack(alignment: .leading, spacing: WWSpacing.m) {
                                    // Skip divider before Key Takeaways — it gets its own styled header
                                    if section.body != "Key Takeaways" {
                                        WWDivider()
                                    }
                                    LessonSectionView(
                                        section: section,
                                        onNECTap: { necCode in
                                            if let ref = lesson.necReferences.first(where: { $0.code == necCode }) {
                                                vm.tapNEC(ref)
                                            }
                                        },
                                        isKeyTakeaway: isTakeaway
                                    )
                                }
                                .padding(.top, WWSpacing.s)
                            } else {
                                LessonSectionView(
                                    section: section,
                                    onNECTap: { necCode in
                                        if let ref = lesson.necReferences.first(where: { $0.code == necCode }) {
                                            vm.tapNEC(ref)
                                        }
                                    },
                                    isKeyTakeaway: isTakeaway
                                )
                            }
                        }
                    }


                    LessonNextStepCard(
                        lesson: lesson,
                        flowContext: vm.flowContext,
                        isComplete: effectiveProgress >= 1,
                        isNextLessonLocked: isNextLessonLocked,
                        onPreviousLesson: onPreviousLesson,
                        onBackToModule: onBackToModule,
                        onNextLesson: onNextLesson,
                        onPracticeTopicQuiz: onPracticeTopicQuiz
                    )

                    Spacer().frame(height: WWSpacing.xxxl)
                }
                .wwScreenPadding()
                .padding(.vertical, WWSpacing.m)
                .background(
                    GeometryReader { contentProxy in
                        Color.clear.preference(
                            key: LessonScrollMetricsPreferenceKey.self,
                            value: LessonScrollMetrics(
                                minY: contentProxy.frame(in: .named("lessonScroll")).minY,
                                contentHeight: contentProxy.size.height
                            )
                        )
                    }
                )
            }
            .coordinateSpace(name: "lessonScroll")
            .onPreferenceChange(LessonScrollMetricsPreferenceKey.self) { metrics in
                let viewportHeight = max(proxy.size.height - 1, 1)
                let totalScrollable = max(metrics.contentHeight - viewportHeight, 0)
                let offset = min(max(-metrics.minY, 0), totalScrollable)
                let progress = totalScrollable == 0
                    ? 1.0
                    : min(max(offset / totalScrollable, lesson.completionPercentage), 1.0)
                vm.scrollProgress = max(vm.scrollProgress, progress)
            }
        }
    }
}

private struct LessonHeaderCard: View {
    let lesson: WWLesson
    let progress: Double
    let flowContext: LessonFlowContext?
    let onOpenCurrentnessInfo: () -> Void

    private var moduleProgress: Double {
        guard let flowContext else { return progress }
        let totalProgress = flowContext.module.lessons.reduce(0) { partialResult, lesson in
            partialResult + lesson.completionPercentage
        }
        let adjusted = totalProgress - lesson.completionPercentage + progress
        return adjusted / Double(max(flowContext.totalLessons, 1))
    }

    private var verificationPills: [String] {
        var values: [String] = []
        if let cycle = lesson.baseCodeCycle, !cycle.isEmpty {
            values.append("Code \(cycle)")
        }
        if let scope = lesson.jurisdictionScope, !scope.isEmpty {
            values.append(scope.replacingOccurrences(of: "_", with: " ").capitalized)
        }
        if let freshness = lesson.freshnessStatus {
            values.append(freshness.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
        }
        return values
    }

    private var verificationLine: String? {
        guard let verifiedAt = lesson.lastVerifiedAt, !verifiedAt.isEmpty else { return nil }
        return "Last verified \(verifiedAt.prefix(10))"
    }

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                HStack(spacing: WWSpacing.s) {
                    Label(lesson.topic, systemImage: "tag")
                    Label("\(lesson.estimatedMinutes) min", systemImage: "clock")
                }
                .font(WWFont.caption(.medium))
                .foregroundColor(.wwTextMuted)

                Text(lesson.title)
                    .wwHeading()

                if verificationPills.isEmpty == false || verificationLine != nil {
                    VStack(alignment: .leading, spacing: WWSpacing.s) {
                        if verificationPills.isEmpty == false {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: WWSpacing.s) {
                                    ForEach(verificationPills, id: \.self) { value in
                                        Text(value)
                                            .font(WWFont.caption(.semibold))
                                            .foregroundColor(.wwBlue)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.wwBlueDim)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }

                        if let verificationLine {
                            Text(verificationLine)
                                .wwCaption(color: .wwTextSecondary)
                        }
                    }
                }

                if let flowContext {
                    VStack(alignment: .leading, spacing: WWSpacing.s) {
                        HStack(spacing: WWSpacing.s) {
                            Text("Lesson \(flowContext.lessonNumber) of \(flowContext.totalLessons)")
                                .wwCaption(color: .wwTextSecondary)
                            Text("·")
                                .wwCaption(color: .wwTextMuted)
                            Text("Module progress \(Int(moduleProgress * 100))%")
                                .wwCaption(color: .wwTextSecondary)
                        }

                        if let partNumber = lesson.partNumber, let totalParts = lesson.totalParts {
                            HStack(spacing: WWSpacing.s) {
                                Image(systemName: "books.vertical.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.wwBlue)
                                Text("Part \(partNumber) of \(totalParts)")
                                    .font(WWFont.caption(.semibold))
                                    .foregroundColor(.wwBlue)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.wwBlueDim)
                                    .clipShape(Capsule())
                                Spacer()
                            }
                        }
                    }
                }

                Text("Work through the examples, use the takeaways to lock in the idea, and tap any referenced NEC article when you want more context.")
                    .wwBody(color: .wwTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Reading Progress")
                            .wwLabel()
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(WWFont.caption(.semibold))
                            .foregroundColor(.wwBlue)
                    }
                    WWProgressBar(value: progress, height: 6)
                }

                if progress >= 1 {
                    HStack(spacing: WWSpacing.s) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.wwBlue)
                        Text("Lesson complete")
                            .font(WWFont.caption(.semibold))
                            .foregroundColor(.wwBlue)
                    }
                    .padding(.horizontal, WWSpacing.m)
                    .padding(.vertical, WWSpacing.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.wwBlueDim)
                    .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous))
                }

                if let disclaimer = lesson.disclaimer, disclaimer.isEmpty == false {
                    VStack(alignment: .leading, spacing: WWSpacing.s) {
                        Text(disclaimer)
                            .wwCaption(color: .wwTextSecondary)
                        Button("How WattWise stays current") {
                            onOpenCurrentnessInfo()
                        }
                        .font(WWFont.caption(.semibold))
                        .foregroundColor(.wwBlue)
                    }
                    .padding(WWSpacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.wwSurface)
                    .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous))
                }
            }
        }
    }
}

private struct LessonNextStepCard: View {
    let lesson: WWLesson
    let flowContext: LessonFlowContext?
    let isComplete: Bool
    let isNextLessonLocked: Bool
    let onPreviousLesson: () -> Void
    let onBackToModule: () -> Void
    let onNextLesson: () -> Void
    var onPracticeTopicQuiz: (() -> Void)? = nil

    private var hasNextPart: Bool {
        guard let partNumber = lesson.partNumber, let totalParts = lesson.totalParts else { return false }
        return partNumber < totalParts
    }

    private var primaryTitle: String {
        if hasNextPart {
            return "Continue to Next Part"
        }
        if flowContext?.nextLessonId != nil {
            return isNextLessonLocked ? "Continue With Full Access" : "Next Lesson"
        }
        return flowContext == nil ? "Open Learn" : "Back to Module"
    }

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                HStack(spacing: WWSpacing.s) {
                    Image(systemName: isComplete ? "checkmark.circle" : "arrow.right.circle")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.wwBlue)
                    Text(isComplete ? "Ready for the next lesson" : "What should you do next?")
                        .wwSectionTitle()
                }

                Text(isComplete
                     ? (isNextLessonLocked
                        ? "You've finished the preview lesson. Keep going with full access to open the next step in your study path."
                        : "Keep moving while the material is fresh, or step back to the module and review your place.")
                    : "Finish this lesson when you're ready, then move straight into the next step without losing momentum.")
                    .wwBody(color: .wwTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if flowContext?.nextLessonId != nil {
                    WWPrimaryButton(title: primaryTitle, action: onNextLesson)
                } else {
                    WWPrimaryButton(title: primaryTitle, action: onBackToModule)
                }

                // Practice bridge — appears after lesson completion to close the learn→practice loop
                if isComplete, let onPracticeTopicQuiz {
                    WWGhostButton(title: "Practice This Topic", color: .wwBlue, action: onPracticeTopicQuiz)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                HStack(spacing: WWSpacing.m) {
                    if flowContext?.previousLessonId != nil {
                        WWSecondaryButton(title: "Previous Lesson", action: onPreviousLesson)
                    }
                    if flowContext?.nextLessonId != nil && flowContext != nil {
                        WWSecondaryButton(title: "Back to Module", action: onBackToModule)
                    }
                }
            }
        }
    }
}

private struct PreviewLessonLockView: View {
    let onOpenPaywall: () -> Void
    let onOpenPreviewLesson: () -> Void

    var body: some View {
        WWEmptyState(
            icon: "lock",
            title: "This lesson is outside the preview",
            message: "Preview includes your first full lesson so you can see how WattWise teaches. Full access opens the rest of the curriculum."
        )
        .overlay(alignment: .bottom) {
            VStack(spacing: WWSpacing.m) {
                WWPrimaryButton(title: "See Access Options", action: onOpenPaywall)
                WWSecondaryButton(title: "Open Preview Lesson", action: onOpenPreviewLesson)
            }
            .wwScreenPadding()
            .padding(.bottom, WWSpacing.l)
            .background(Color.wwBackground)
        }
    }
}

// MARK: - Lesson Section View

private struct LessonSectionView: View {
    let section: LessonSection
    let onNECTap: (String) -> Void
    var isKeyTakeaway: Bool = false

    private var isPracticalExample: Bool {
        guard section.type == .paragraph else { return false }
        let heading = (section.heading ?? "").lowercased()
        return heading.contains("practical") || heading.contains("on the job")
    }

    var body: some View {
        switch section.type {
        case .heading:
            // "Key Takeaways" heading gets its own styled header
            if section.body == "Key Takeaways" {
                HStack(spacing: WWSpacing.s) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.wwBlue)
                    Text("Key Takeaways")
                        .font(WWFont.label(.semibold))
                        .textCase(.uppercase)
                        .foregroundColor(.wwBlue)
                        .tracking(0.4)
                }
                .padding(.top, WWSpacing.xs)
            } else {
                VStack(alignment: .leading, spacing: WWSpacing.xs) {
                    Text(section.heading ?? section.body)
                        .wwSubheading()
                }
            }

        case .paragraph:
            if isPracticalExample {
                // "On the Job" scenario card — styled differently
                PracticalExampleCard(heading: section.heading, text: section.body)
            } else {
                VStack(alignment: .leading, spacing: WWSpacing.s) {
                    if let heading = section.heading {
                        Text(heading).wwSectionTitle()
                    }
                    Text(section.body)
                        .wwBodyLarge(color: .wwTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(4)
                }
            }

        case .bullet:
            if isKeyTakeaway {
                // Key takeaway bullet — styled with checkmark
                HStack(alignment: .top, spacing: WWSpacing.s) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.wwBlue)
                        .padding(.top, 1)
                    Text(section.body)
                        .wwBody()
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
                .padding(.horizontal, WWSpacing.m)
                .padding(.vertical, WWSpacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.wwBlueDim)
                .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous))
            } else {
                HStack(alignment: .top, spacing: WWSpacing.s) {
                    Circle()
                        .fill(Color.wwBlue)
                        .frame(width: 5, height: 5)
                        .padding(.top, 8)
                    Text(section.body)
                        .wwBody()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

        case .callout:
            CalloutCard(heading: section.heading, text: section.body, necCode: section.necCode, onNECTap: onNECTap)

        case .necCallout:
            CalloutCard(heading: section.heading, text: section.body, necCode: section.necCode, onNECTap: onNECTap, isNEC: true)

        case .examTrap:
            ExamTrapCalloutCard(heading: section.heading, text: section.body)
        }
    }
}

// MARK: - Practical Example Card

private struct PracticalExampleCard: View {
    let heading: String?
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: WWSpacing.s) {
            HStack(spacing: WWSpacing.s) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 13))
                    .foregroundColor(.wwTextSecondary)
                Text(heading ?? "On the Job")
                    .font(WWFont.body(.semibold))
                    .foregroundColor(.wwTextSecondary)
                    .lineLimit(1)
            }
            Text(text)
                .wwBody(color: .wwTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
                .italic()
        }
        .padding(WWSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.wwSurface)
        .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous)
                .strokeBorder(Color.wwDivider, lineWidth: 1)
        )
    }
}

private struct LessonScrollMetrics: Equatable {
    var minY: CGFloat
    var contentHeight: CGFloat
}

private struct LessonScrollMetricsPreferenceKey: PreferenceKey {
    static var defaultValue = LessonScrollMetrics(minY: 0, contentHeight: 0)

    static func reduce(value: inout LessonScrollMetrics, nextValue: () -> LessonScrollMetrics) {
        value = nextValue()
    }
}

// MARK: - Callout Card

private struct CalloutCard: View {
    let heading: String?
    let text: String
    let necCode: String?
    let onNECTap: (String) -> Void
    var isNEC: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Blue left accent bar
            Rectangle()
                .fill(Color.wwBlue.opacity(0.6))
                .frame(width: 2.5)

            VStack(alignment: .leading, spacing: WWSpacing.s) {
                if let heading {
                    Text(heading)
                        .font(WWFont.body(.semibold))
                        .foregroundColor(.wwBlue)
                }
                Text(text)
                    .wwBody()
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)

                if let necCode {
                    Button {
                        onNECTap(necCode)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "book.pages")
                                .font(.system(size: 12))
                            Text("NEC \(necCode)")
                                .font(WWFont.caption(.semibold))
                        }
                        .foregroundColor(.wwBlue)
                    }
                }
            }
            .padding(WWSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.wwBlueDim)
        .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous)
                .strokeBorder(Color.wwBlue.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Exam Trap Callout

private struct ExamTrapCalloutCard: View {
    let heading: String?
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Vivid left accent bar
            Rectangle()
                .fill(Color.wwWarning)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: WWSpacing.s) {
                HStack(spacing: WWSpacing.s) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.wwWarning)
                    Text(heading ?? "Exam Trap")
                        .font(WWFont.body(.semibold))
                        .foregroundColor(.wwWarning)
                }
                Text(text)
                    .wwBody()
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
            .padding(WWSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.wwWarning.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous)
                .strokeBorder(Color.wwWarning.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - NEC Reference Chip

private struct NECReferenceChip: View {
    let reference: NECReference
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WWSpacing.s) {
                Image(systemName: "book.pages")
                    .font(.system(size: 14))
                    .foregroundColor(.wwBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("NEC \(reference.code)")
                        .font(WWFont.caption(.semibold))
                        .foregroundColor(.wwBlue)
                    Text(reference.title)
                        .wwCaption()
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.wwTextMuted)
            }
            .padding(WWSpacing.m)
            .background(Color.wwSurface)
            .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - NEC Reference Sheet (modal)

struct NECReferenceSheet: View {
    let reference: NECReference
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WWSpacing.l) {
                    VStack(alignment: .leading, spacing: WWSpacing.s) {
                        Text("NEC \(reference.code)")
                            .font(WWFont.caption(.semibold))
                            .foregroundColor(.wwBlue)
                        Text(reference.title)
                            .wwHeading()
                        Text(reference.summary)
                            .wwBodyLarge(color: .wwTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let expanded = reference.expanded {
                        WWDivider()
                        VStack(alignment: .leading, spacing: WWSpacing.s) {
                            Text("Detailed Explanation")
                                .wwSectionTitle()
                            Text(expanded)
                                .wwBody()
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(4)
                        }
                    }
                }
                .wwScreenPadding()
                .padding(.vertical, WWSpacing.m)
            }
            .background(Color.wwBackground)
            .navigationTitle("NEC \(reference.code)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(WWFont.body(.medium))
                        .foregroundColor(.wwBlue)
                }
            }
        }
    }
}

// MARK: - Lesson Completion Bar (Duolingo-style sticky bottom bar)

private struct LessonCompletionBar: View {
    let nextLessonTitle: String?
    let onNext: () -> Void
    let onPractice: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: WWSpacing.m) {
                // Left: completion status
                HStack(spacing: WWSpacing.s) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.wwSuccess)
                    Text("Complete")
                        .font(WWFont.caption(.semibold))
                        .foregroundColor(.wwSuccess)
                }

                Spacer()

                // Right: primary next action
                Button(action: onNext) {
                    HStack(spacing: 4) {
                        if let title = nextLessonTitle {
                            Text(title)
                                .font(WWFont.caption(.semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: 140, alignment: .trailing)
                        } else {
                            Text("Browse Modules")
                                .font(WWFont.caption(.semibold))
                        }
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, WWSpacing.m)
                    .padding(.vertical, 10)
                    .background(Color.wwBlue)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, WWSpacing.m)
            .padding(.vertical, WWSpacing.s + 2)
            .background(Color.wwBackground)
        }
    }
}

// MARK: - Tutor Sheet (embedded)

struct TutorSheet: View {
    let context: TutorContext?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TutorView(initialContext: context)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") { dismiss() }
                            .font(WWFont.body(.medium))
                            .foregroundColor(.wwBlue)
                    }
                }
        }
    }
}

#Preview {
    NavigationStack {
        LessonView(lessonId: WattWiseContentRuntimeAdapter.uuid(for: "lesson:ap-les-001"))
            .environment(ServiceContainer())
            .environment(AppViewModel())
    }
}
