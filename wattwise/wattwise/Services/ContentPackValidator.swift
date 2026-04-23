import Foundation

enum ContentPackValidator {
    private static let requiredLessonHeadings: [String] = [
        "Learning objective",
        "Why this matters",
        "Core explanation",
        "Key concepts",
        "NEC / code relevance",
        "Practical example",
        "Common mistakes",
        "Exam insight"
    ]

    private static let bannedPhrases: [String] = [
        "todo",
        "tbd",
        "placeholder",
        "coming soon",
        "lorem ipsum",
        "the fundamental principle behind",
        "in real-world applications,",
        "many apprentices and journeymen misunderstand",
        "real electricians must master this concept",
        "in what real-world scenario would you apply",
        "this question tests",
        "the correct answer is"
    ]

    static func validate(_ pack: WattWiseContentPack) -> [String] {
        var issues: [String] = []

        validateMetadata(pack, issues: &issues)
        validateSources(pack, issues: &issues)
        validateLessons(pack, issues: &issues)
        validateQuestions(pack, issues: &issues)
        validatePracticeExams(pack, issues: &issues)
        validateSecondaryAssets(pack, issues: &issues)

        return issues
    }

    private static func validateMetadata(_ pack: WattWiseContentPack, issues: inout [String]) {
        if pack.metadata.contentStatus.contains("production_ready") {
            issues.append("Metadata still claims production-ready status.")
        }
    }

    private static func validateSources(_ pack: WattWiseContentPack, issues: inout [String]) {
        let sourceIDs = Set(pack.sourceList.map(\.id))
        if sourceIDs.count != pack.sourceList.count {
            issues.append("Duplicate source citation IDs found.")
        }

        if pack.sourceList.count < 10 {
            issues.append("Source coverage is too thin for a customer-ready curriculum.")
        }
    }

    private static func validateLessons(_ pack: WattWiseContentPack, issues: inout [String]) {
        let lessonIDs = Set(pack.fullLessonContent.map(\.id))
        if lessonIDs.count != pack.fullLessonContent.count {
            issues.append("Duplicate lesson content IDs found.")
        }

        if pack.fullLessonContent.count != 92 {
            issues.append("Expected 92 lessons in the content pack, found \(pack.fullLessonContent.count).")
        }

        let curriculumLessonIDs = Set(
            pack.curriculumFramework
                .flatMap(\.modules)
                .flatMap(\.lessons)
                .map(\.id)
        )

        if curriculumLessonIDs != lessonIDs {
            let missing = curriculumLessonIDs.subtracting(lessonIDs).sorted()
            let unexpected = lessonIDs.subtracting(curriculumLessonIDs).sorted()

            if !missing.isEmpty {
                issues.append("Missing lesson content for: \(missing.joined(separator: ", ")).")
            }
            if !unexpected.isEmpty {
                issues.append("Lesson content has unexpected IDs: \(unexpected.joined(separator: ", ")).")
            }
        }

        for lesson in pack.fullLessonContent {
            let headings = lesson.lessonContent.map(\.heading)
            let headingSet = Set(headings)
            let missingHeadings = Set(requiredLessonHeadings).subtracting(headingSet).sorted()
            if !missingHeadings.isEmpty {
                issues.append("Lesson \(lesson.id) is missing required sections: \(missingHeadings.joined(separator: ", ")).")
            }

            if headings != requiredLessonHeadings {
                issues.append("Lesson \(lesson.id) does not follow the required section order.")
            }

            validateVerification(lesson.verification, label: "Lesson \(lesson.id)", issues: &issues)

            for paragraph in lesson.lessonContent {
                let trimmed = paragraph.body.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    issues.append("Lesson \(lesson.id) has an empty body in section \(paragraph.id).")
                }

                if trimmed.count < 40 {
                    issues.append("Lesson \(lesson.id) section \(paragraph.id) is too thin for production use.")
                }

                let lower = trimmed.lowercased()
                if bannedPhrases.contains(where: lower.contains) {
                    issues.append("Lesson \(lesson.id) contains banned generic text in section \(paragraph.id).")
                }
            }

            if lesson.keyTakeaways.count < 4 {
                issues.append("Lesson \(lesson.id) needs at least four key takeaways.")
            }

            if lesson.practiceQuestions.count < 3 {
                issues.append("Lesson \(lesson.id) needs at least three practice questions.")
            }

            if lesson.references.isEmpty {
                issues.append("Lesson \(lesson.id) is missing NEC/code references.")
            }

            let sectionReferenceSet = Set(lesson.lessonContent.flatMap(\.necReferences))
            if !sectionReferenceSet.isSubset(of: Set(lesson.references)) {
                issues.append("Lesson \(lesson.id) contains section NEC references that are not listed in references.")
            }

            if lesson.keyTakeaways.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).count < 20 }) {
                issues.append("Lesson \(lesson.id) has a takeaway that is too short to be useful.")
            }

            if lesson.practiceQuestions.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?") == false }) {
                issues.append("Lesson \(lesson.id) has a practice question that is not phrased like a question.")
            }
        }
    }

    private static func validateQuestions(_ pack: WattWiseContentPack, issues: inout [String]) {
        let questionIDs = pack.questionBank.map(\.id)
        if Set(questionIDs).count != questionIDs.count {
            issues.append("Duplicate question IDs found.")
        }

        for question in pack.questionBank {
            if question.answerChoices.count != 4 {
                issues.append("Question \(question.id) does not have exactly four answer choices.")
            }

            if question.answerChoices[question.correctAnswer] == nil {
                issues.append("Question \(question.id) has an invalid correct answer key.")
            }

            validateVerification(question.verification, label: "Question \(question.id)", issues: &issues)

            let normalizedText = "\(question.questionText) \(question.explanation)".lowercased()
            if bannedPhrases.contains(where: normalizedText.contains) {
                issues.append("Question \(question.id) contains banned generic text.")
            }

            if question.explanation.trimmingCharacters(in: .whitespacesAndNewlines).count < 40 {
                issues.append("Question \(question.id) needs a richer explanation.")
            }

            if question.necReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("Question \(question.id) is missing a reference code.")
            }

            if question.verification.publishStatus == .published && question.verification.sourceURLs.isEmpty {
                issues.append("Question \(question.id) is published without source URLs.")
            }
        }
    }

    private static func validatePracticeExams(_ pack: WattWiseContentPack, issues: inout [String]) {
        let practiceExamIDs = Set(pack.practiceExams.map(\.id))
        if practiceExamIDs.count != pack.practiceExams.count {
            issues.append("Duplicate practice exam IDs found.")
        }

        let publishedQuestionIDs = Set(
            pack.questionBank
                .filter { $0.verification.publishStatus == .published }
                .map(\.id)
        )

        for exam in pack.practiceExams {
            for questionID in exam.questionIds where !publishedQuestionIDs.contains(questionID) {
                issues.append("Practice exam \(exam.id) references unpublished or unknown question \(questionID).")
            }

            for (questionID, answer) in exam.answerKey where !exam.questionIds.contains(questionID) || !["A", "B", "C", "D"].contains(answer) {
                issues.append("Practice exam \(exam.id) has an invalid answer-key entry for \(questionID).")
            }
        }
    }

    private static func validateSecondaryAssets(_ pack: WattWiseContentPack, issues: inout [String]) {
        if pack.glossary.isEmpty {
            issues.append("Glossary is missing.")
        }

        if pack.quickReferenceGuides.isEmpty {
            issues.append("Quick-reference guides are missing.")
        }

        if pack.studyPlans.isEmpty {
            issues.append("Study plans are missing.")
        }

        let glossaryIDs = Set(pack.glossary.map(\.id))
        if glossaryIDs.count != pack.glossary.count {
            issues.append("Duplicate glossary IDs found.")
        }

        let flashcardIDs = Set(pack.flashcards.map(\.id))
        if flashcardIDs.count != pack.flashcards.count {
            issues.append("Duplicate flashcard IDs found.")
        }
    }

    private static func validateVerification(
        _ verification: ContentVerificationMetadata,
        label: String,
        issues: inout [String]
    ) {
        if verification.publishStatus == .published {
            if verification.sourceURLs.isEmpty {
                issues.append("\(label) is published without source URLs.")
            }

            if verification.lastVerifiedAt == nil {
                issues.append("\(label) is published without last_verified_at.")
            }

            if verification.verificationConfidence < 80 {
                issues.append("\(label) is published with confidence below 80.")
            }

            if verification.freshnessStatus != .fresh {
                issues.append("\(label) is published but freshness_status is \(verification.freshnessStatus.rawValue).")
            }
        }

        if verification.freshnessStatus == .stale && (verification.stalenessReason?.isEmpty != false) {
            issues.append("\(label) is stale without a staleness reason.")
        }

        if verification.jurisdictionScope.isEmpty {
            issues.append("\(label) is missing a jurisdiction scope.")
        }
    }
}
