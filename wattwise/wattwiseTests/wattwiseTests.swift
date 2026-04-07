//
//  wattwiseTests.swift
//  wattwiseTests
//
//  Created by User on 3/30/26.
//

import Testing
import Foundation
@testable import wattwise

private final class StubContentService: ContentServiceProtocol {
    var lessonToReturn: WWLesson
    var modulesResult: Result<[WWModule], Error>

    init(lessonToReturn: WWLesson, modulesResult: Result<[WWModule], Error>) {
        self.lessonToReturn = lessonToReturn
        self.modulesResult = modulesResult
    }

    func fetchModules() async throws -> [WWModule] {
        try modulesResult.get()
    }

    func fetchLesson(id: UUID) async throws -> WWLesson {
        lessonToReturn
    }

    func saveProgress(lessonId: UUID, completion: Double) async throws {}
}

private final class StubQuizService: QuizServiceProtocol {
    let quizToReturn: WWQuiz

    init(quizToReturn: WWQuiz) {
        self.quizToReturn = quizToReturn
    }

    func generateQuiz(type: QuizType, topicTags: [String], examType: ExamType?) async throws -> WWQuiz {
        quizToReturn
    }

    func submitQuiz(quizId: UUID, answers: [QuizAnswer]) async throws -> QuizResult {
        QuizResult(
            id: UUID(),
            quizId: quizId,
            score: 0,
            correctCount: 0,
            totalCount: 0,
            results: [],
            weakTopics: []
        )
    }
}

private final class RecordingQuizService: QuizServiceProtocol {
    var generatedTopicTags: [String] = []
    var generateError: Error?
    let quizToReturn: WWQuiz

    init(quizToReturn: WWQuiz) {
        self.quizToReturn = quizToReturn
    }

    func generateQuiz(type: QuizType, topicTags: [String], examType: ExamType?) async throws -> WWQuiz {
        generatedTopicTags = topicTags
        if let generateError {
            throw generateError
        }
        return quizToReturn
    }

    func submitQuiz(quizId: UUID, answers: [QuizAnswer]) async throws -> QuizResult {
        QuizResult(
            id: UUID(),
            quizId: quizId,
            score: 0,
            correctCount: 0,
            totalCount: 0,
            results: [],
            weakTopics: []
        )
    }
}

@MainActor
struct wattwiseTests {

    private func contentPackURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("wattwise/Resources/WattWiseContentPack.json")
    }

    @Test func contentPackDecodes() throws {
        let data = try Data(contentsOf: contentPackURL())
        let pack = try JSONDecoder().decode(WattWiseContentPack.self, from: data)

        #expect(pack.metadata.title.contains("WattWise"))
        #expect(pack.curriculumFramework.count == 3)
        #expect(pack.questionBank.isEmpty == false)
    }

    @Test func contentPackPassesStructuralValidation() throws {
        let data = try Data(contentsOf: contentPackURL())
        let pack = try JSONDecoder().decode(WattWiseContentPack.self, from: data)
        let issues = ContentPackValidator.validate(pack)

        #expect(issues.isEmpty, "Validation issues: \(issues.joined(separator: " | "))")
    }

    @Test func contentPackProvidesFullLessonCoverage() throws {
        let data = try Data(contentsOf: contentPackURL())
        let pack = try JSONDecoder().decode(WattWiseContentPack.self, from: data)

        let plannedLessonIDs = Set(pack.curriculumFramework.flatMap(\.modules).flatMap(\.lessons).map(\.id))
        let authoredLessonIDs = Set(pack.fullLessonContent.map(\.id))

        #expect(plannedLessonIDs.count == 24)
        #expect(authoredLessonIDs == plannedLessonIDs)
    }

    @Test func runtimeAdapterBuildsModulesFromContentPack() throws {
        let data = try Data(contentsOf: contentPackURL())
        let pack = try JSONDecoder().decode(WattWiseContentPack.self, from: data)
        let modules = try WattWiseContentRuntimeAdapter.modules(from: pack)

        #expect(modules.count == 12)
        #expect(modules.flatMap(\.lessons).count == 24)
        #expect(modules.allSatisfy { $0.lessons.isEmpty == false })
        #expect(modules.flatMap(\.lessons).allSatisfy { lesson in
            lesson.sections.contains(where: { $0.body == "Key Takeaways" && $0.type == .heading }) &&
            lesson.sections.contains(where: { $0.body == "Knowledge Check" && $0.type == .heading })
        })
    }

    @Test func runtimeAdapterIncludesSectionNECReferencesInLessonMetadata() throws {
        let lesson = try WattWiseContentRuntimeAdapter.loadLesson(
            id: WattWiseContentRuntimeAdapter.uuid(for: "lesson:ms-les-008")
        )

        #expect(lesson.necReferences.contains(where: { $0.code == "90.4" }))
        #expect(lesson.sections.contains(where: { $0.type == .necCallout }))
    }

    @Test func moduleProgressReflectsPartialCompletion() throws {
        let modules = try WattWiseContentRuntimeAdapter.loadModules()
        let safetyModule = try #require(modules.first(where: { $0.title.contains("Safety") }))

        #expect(safetyModule.progress > 0)
        #expect(safetyModule.progress < 1)
    }

    @Test func quizViewModelTurnsEmptyQuizIntoUserVisibleError() async throws {
        let vm = QuizViewModel()
        let services = ServiceContainer(
            auth: MockAuthService(),
            content: MockContentService(),
            quiz: StubQuizService(quizToReturn: WWQuiz(id: UUID(), type: .quickQuiz, questions: [])),
            tutor: MockTutorService(),
            nec: MockNECService(),
            progress: MockProgressService(),
            subscription: MockSubscriptionService()
        )

        await vm.load(type: .quickQuiz, examType: .apprentice, services: services)

        #expect(vm.quiz == nil)
        #expect(vm.errorMessage?.contains("No quiz questions") == true)
        #expect(vm.shouldShowLoadingState == false)
    }

    @Test func lessonViewModelKeepsLessonWhenFlowContextLookupFails() async throws {
        let lesson = try WattWiseContentRuntimeAdapter.loadLesson(
            id: WattWiseContentRuntimeAdapter.uuid(for: "lesson:ap-les-004")
        )
        let vm = LessonViewModel()
        let services = ServiceContainer(
            auth: MockAuthService(),
            content: StubContentService(
                lessonToReturn: lesson,
                modulesResult: .failure(AppError.networkError("Modules unavailable"))
            ),
            quiz: MockQuizService(),
            tutor: MockTutorService(),
            nec: MockNECService(),
            progress: MockProgressService(),
            subscription: MockSubscriptionService()
        )

        await vm.load(lessonId: lesson.id, services: services)

        #expect(vm.lesson?.id == lesson.id)
        #expect(vm.flowContext == nil)
        #expect(vm.errorMessage == nil)
    }

    @Test func practiceViewModelBlocksWeakAreaReviewWithoutHistory() {
        let vm = PracticeViewModel()

        let resolution = vm.startQuiz(.weakAreaReview, subscription: .preview)

        switch resolution {
        case .unavailable(let title, let message, let suggestedQuiz):
            #expect(title.contains("Weak-area review"))
            #expect(message.contains("scored quiz"))
            #expect(suggestedQuiz == .quickQuiz)
        default:
            Issue.record("Expected weak-area review to be unavailable before any scored quiz.")
        }
    }

    @Test func profileResetProgressClearsAllLocalStores() {
        let keys = [
            "ww_user",
            "ww_profile",
            "ww_access_token",
            "ww_refresh_token",
            "ww_user_data",
            "ww_content_progress_v2",
            "ww_content_study_activity_v1",
            "ww_practice_history_v1"
        ]
        keys.forEach { UserDefaults.standard.set("value", forKey: $0) }
        UserDefaults.standard.set("value", forKey: "ww_tutor_conversation_v1_general")

        let vm = ProfileViewModel()
        let services = ServiceContainer()
        let appVM = AppViewModel()
        appVM.authState = .authenticated(WWUser.guest)

        vm.resetProgress(services: services, appVM: appVM)

        for key in keys {
            #expect(UserDefaults.standard.object(forKey: key) == nil)
        }
        #expect(UserDefaults.standard.object(forKey: "ww_tutor_conversation_v1_general") == nil)
        #expect({
            if case .unauthenticated = appVM.authState { return true }
            return false
        }())
    }

    @Test func tutorContextBuilderCarriesFocusedQuizQuestion() throws {
        let question = QuestionResult(
            id: UUID(),
            questionId: UUID(),
            question: "Why is my grounding answer wrong?",
            userAnswer: "Bond all metal parts to earth",
            correctAnswer: "Bond metal parts together and separately size the grounding path as required",
            explanation: "Bonding and grounding are related, but they are not interchangeable terms.",
            isCorrect: false,
            topics: ["grounding-and-bonding"],
            topicTitles: ["Grounding and Bonding"],
            referenceCode: "250.50"
        )
        let result = QuizResult(
            id: UUID(),
            quizId: UUID(),
            quizAttemptId: UUID(),
            score: 0.6,
            correctCount: 6,
            totalCount: 10,
            results: [question],
            weakTopics: ["Grounding and Bonding"]
        )

        let context = TutorContextBuilder.quizReview(
            result,
            focusedQuestion: question,
            user: WWUser.guest
        )

        #expect(context.type == .quizReview)
        #expect(context.quizReview?.focusedQuestion?.question == question.question)
        #expect(context.quizReview?.focusedQuestion?.referenceCode == "250.50")
        #expect(context.storageKey.contains("quiz-question:"))
        #expect(context.starterPrompts.contains("Why was my answer wrong?"))
    }

    @Test func tutorClearKeepsContextButRemovesConversation() {
        let vm = TutorViewModel()
        let lesson = try? WattWiseContentRuntimeAdapter.loadLesson(
            id: WattWiseContentRuntimeAdapter.uuid(for: "lesson:ap-les-004")
        )
        let context = lesson.map { TutorContextBuilder.lesson($0, user: WWUser.guest) }

        vm.configure(initialContext: context, user: WWUser.guest)
        vm.messages = [
            TutorMessage(id: UUID(), content: "Help me", role: .user, timestamp: Date()),
            TutorMessage(id: UUID(), content: "Sure", role: .assistant, timestamp: Date())
        ]
        vm.sessionID = UUID()

        vm.clear()

        #expect(vm.context.type == .lesson)
        #expect(vm.messages.isEmpty)
        #expect(vm.sessionID == nil)
        #expect(vm.errorState == nil)
    }

    @Test func subscriptionStateTracksSeparateTutorAndNECUsage() {
        var state = SubscriptionState.preview

        state.applyTutorUsage(AIUsageSnapshot(used: 3, limit: 4))
        state.applyNECUsage(AIUsageSnapshot(used: 1, limit: 1))

        #expect(state.tutorMessagesRemaining == 1)
        #expect(state.tutorLimitReached == false)
        #expect(state.necExplanationsRemaining == 0)
        #expect(state.necExplanationLimitReached == true)
    }

    @Test func previewAccessStartsWithOneQuizAndFourTutorQuestions() {
        let state = SubscriptionState.preview

        #expect(state.hasPaidAccess == false)
        #expect(state.previewQuickQuizzesRemaining == 1)
        #expect(state.tutorMessagesRemaining == 4)
        #expect(state.necExplanationsRemaining == 1)
    }

    @Test func fastTrackRemovesPreviewLimits() {
        let state = SubscriptionState.fastTrack

        #expect(state.hasPaidAccess)
        #expect(state.previewQuickQuizLimitReached == false)
        #expect(state.tutorLimitReached == false)
        #expect(state.necExplanationLimitReached == false)
    }

    @Test func fullPrepRemovesPreviewLimits() {
        let state = SubscriptionState.fullPrep

        #expect(state.hasPaidAccess)
        #expect(state.accessTitle == "Full Prep")
        #expect(state.storeProductId == AccessProductID.fullPrep.rawValue)
    }

    @Test func practiceViewModelSendsPreviewUserToPaywallAfterQuizUsed() {
        let vm = PracticeViewModel()
        var preview = SubscriptionState.preview
        preview.markPreviewQuizUsedIfNeeded()

        let resolution = vm.startQuiz(.quickQuiz, subscription: preview)

        switch resolution {
        case .paywall(let context):
            #expect(context == .quizLimit)
        default:
            Issue.record("Expected quick quiz limit to route preview users to the paywall.")
        }
    }

    @Test func practiceViewModelSendsPreviewUserToPracticeExamPaywall() {
        let vm = PracticeViewModel()

        let resolution = vm.startQuiz(.fullPracticeExam, subscription: .preview)

        switch resolution {
        case .paywall(let context):
            #expect(context == .practiceExamLocked)
        default:
            Issue.record("Expected full practice exam to route preview users to the paywall.")
        }
    }

    @Test func mockSubscriptionServiceMapsProductsToAccessTiers() async throws {
        let service = MockSubscriptionService()

        let fastTrack = try await service.purchase(productId: AccessProductID.fastTrack.rawValue)
        #expect(fastTrack.tier == .fastTrack)

        let fullPrep = try await service.purchase(productId: AccessProductID.fullPrep.rawValue)
        #expect(fullPrep.tier == .fullPrep)
    }

    @Test func quizViewModelTurnsForbiddenQuizLoadIntoAccessRestriction() async throws {
        let vm = QuizViewModel()
        let quizService = RecordingQuizService(
            quizToReturn: WWQuiz(id: UUID(), type: .quickQuiz, questions: [])
        )
        quizService.generateError = APIError.forbidden("You've already used your preview quiz. Choose full access to keep practicing.")

        let services = ServiceContainer(
            auth: MockAuthService(),
            content: MockContentService(),
            quiz: quizService,
            tutor: MockTutorService(),
            nec: MockNECService(),
            progress: MockProgressService(),
            subscription: MockSubscriptionService()
        )

        await vm.load(type: .quickQuiz, examType: .apprentice, services: services)

        #expect(vm.accessRestriction?.context == .quizLimit)
        #expect(vm.accessRestriction?.message.contains("preview quiz") == true)
        #expect(vm.errorMessage == nil)
    }

    @Test func weakAreaReviewUsesSuggestedWeakTopicKeys() async throws {
        UserDefaults.standard.removeObject(forKey: "ww_practice_history_v1")

        let quiz = WWQuiz(
            id: UUID(),
            type: .quickQuiz,
            questions: [
                QuizQuestion(
                    id: UUID(),
                    question: "Question",
                    choices: ["A": "One", "B": "Two", "C": "Three", "D": "Four"],
                    correctChoice: "A",
                    explanation: "Explanation",
                    topics: ["grounding"],
                    topicTitles: ["Grounding"]
                )
            ]
        )
        let results = [
            QuestionResult(
                id: UUID(),
                questionId: quiz.questions[0].id,
                question: "Question",
                userAnswer: "Two",
                correctAnswer: "One",
                explanation: "Explanation",
                isCorrect: false,
                topics: ["grounding"],
                topicTitles: ["Grounding"],
                referenceCode: "250.50"
            )
        ]
        PracticeHistoryStore.shared.recordAttempt(
            quiz: quiz,
            results: results,
            score: 0,
            correctCount: 0,
            totalCount: 1
        )

        let vm = QuizViewModel()
        let quizService = RecordingQuizService(
            quizToReturn: WWQuiz(id: UUID(), type: .weakAreaReview, questions: [quiz.questions[0]])
        )
        let services = ServiceContainer(
            auth: MockAuthService(),
            content: MockContentService(),
            quiz: quizService,
            tutor: MockTutorService(),
            nec: MockNECService(),
            progress: MockProgressService(),
            subscription: MockSubscriptionService()
        )

        await vm.load(type: .weakAreaReview, examType: .apprentice, services: services)

        #expect(quizService.generatedTopicTags.contains("grounding"))

        UserDefaults.standard.removeObject(forKey: "ww_practice_history_v1")
    }

    @Test func appViewModelSignOutClearsTutorSnapshots() {
        let appVM = AppViewModel()
        let services = ServiceContainer()
        appVM.authState = .authenticated(.guest)

        UserDefaults.standard.set("value", forKey: "ww_tutor_conversation_v1_general")
        UserDefaults.standard.set("value", forKey: "ww_user_data")

        appVM.signOut(services: services)

        #expect(UserDefaults.standard.object(forKey: "ww_tutor_conversation_v1_general") == nil)
        #expect(UserDefaults.standard.object(forKey: "ww_user_data") == nil)
        #expect({
            if case .unauthenticated = appVM.authState { return true }
            return false
        }())
    }

}
