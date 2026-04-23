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

    private static let jurisdictionCodes: Set<String> = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", "GA", "HI", "ID", "IL", "IN",
        "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH",
        "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT",
        "VT", "VA", "WA", "WV", "WI", "WY"
    ]

    static func validate(_ pack: WattWiseContentPack) -> [String] {
        var issues: [String] = []

        validateMetadata(pack, issues: &issues)
        validateSources(pack, issues: &issues)
        validateLessons(pack, issues: &issues)
        validateQuestions(pack, issues: &issues)
        validatePracticeExams(pack, issues: &issues)
        validateJurisdictions(pack, issues: &issues)
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

        if pack.sourceList.count < 12 {
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
                if containsBannedPhrase(trimmed) {
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

        if pack.questionBank.count < 1_200 {
            issues.append("Expected at least 1,200 national baseline questions, found \(pack.questionBank.count).")
        }

        let byLevel = Dictionary(grouping: pack.questionBank) { $0.certificationLevel.lowercased() }
        for level in ["apprentice", "journeyman", "master"] {
            let records = byLevel[level] ?? []
            if records.count < 400 {
                issues.append("Expected at least 400 \(level) questions, found \(records.count).")
            }
            validateLevelDistribution(level: level, questions: records, issues: &issues)
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
            if containsBannedPhrase(normalizedText) {
                issues.append("Question \(question.id) contains banned generic text.")
            }

            if question.explanation.trimmingCharacters(in: .whitespacesAndNewlines).count < 40 {
                issues.append("Question \(question.id) needs a richer explanation.")
            }
            if question.necReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("Question \(question.id) is missing a reference code.")
            }
            if question.sourceUrls.isEmpty {
                issues.append("Question \(question.id) is missing sourceUrls metadata.")
            }
            if question.jurisdictionScope.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("Question \(question.id) is missing jurisdictionScope metadata.")
            }
            if question.examBlueprintTags.isEmpty {
                issues.append("Question \(question.id) is missing examBlueprintTags.")
            }
        }
    }

    private static func validatePracticeExams(_ pack: WattWiseContentPack, issues: inout [String]) {
        let practiceExamIDs = Set(pack.practiceExams.map(\.id))
        if practiceExamIDs.count != pack.practiceExams.count {
            issues.append("Duplicate practice exam IDs found.")
        }

        if pack.practiceExams.count != 15 {
            issues.append("Expected exactly 15 practice exams, found \(pack.practiceExams.count).")
        }

        let examsByLevel = Dictionary(grouping: pack.practiceExams) { $0.certificationLevel.lowercased() }
        let expectedCountsByLevel: [String: Int] = [
            "apprentice": 5,
            "journeyman": 5,
            "master": 5
        ]
        let expectedQuestionCountByLevel: [String: Int] = [
            "apprentice": 50,
            "journeyman": 80,
            "master": 80
        ]

        for (level, expectedExamCount) in expectedCountsByLevel {
            let exams = examsByLevel[level] ?? []
            if exams.count != expectedExamCount {
                issues.append("Expected \(expectedExamCount) \(level) practice exams, found \(exams.count).")
            }
            let expectedQuestionCount = expectedQuestionCountByLevel[level] ?? 0
            for exam in exams {
                if exam.questionIds.count != expectedQuestionCount {
                    issues.append("Practice exam \(exam.id) should have \(expectedQuestionCount) questions, found \(exam.questionIds.count).")
                }
                if Set(exam.questionIds).count != exam.questionIds.count {
                    issues.append("Practice exam \(exam.id) has duplicate question IDs.")
                }
                if exam.answerKey.count != exam.questionIds.count {
                    issues.append("Practice exam \(exam.id) answer key count does not match question count.")
                }
            }

            // Pairwise overlap must remain <= 10% of the smaller exam.
            for i in 0..<exams.count {
                for j in (i + 1)..<exams.count {
                    let lhs = Set(exams[i].questionIds)
                    let rhs = Set(exams[j].questionIds)
                    let overlapCount = lhs.intersection(rhs).count
                    let denominator = max(1, min(lhs.count, rhs.count))
                    let overlapRatio = Double(overlapCount) / Double(denominator)
                    if overlapRatio > 0.10 {
                        issues.append("Practice exam overlap exceeds 10% between \(exams[i].id) and \(exams[j].id).")
                    }
                }
            }
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
            if let verification = exam.verification {
                validateVerification(verification, label: "Practice exam \(exam.id)", issues: &issues)
            }
        }
    }

    private static func validateJurisdictions(_ pack: WattWiseContentPack, issues: inout [String]) {
        let profileIDs = Set(pack.jurisdictionProfiles.map(\.id))
        if profileIDs.count != pack.jurisdictionProfiles.count {
            issues.append("Duplicate jurisdiction profile IDs found.")
        }

        if pack.jurisdictionProfiles.count != 51 {
            issues.append("Expected 51 jurisdiction profiles (50 states + DC), found \(pack.jurisdictionProfiles.count).")
        }

        let profileCodes = Set(pack.jurisdictionProfiles.map { $0.stateCode.uppercased() })
        let missingCodes = jurisdictionCodes.subtracting(profileCodes).sorted()
        if !missingCodes.isEmpty {
            issues.append("Missing jurisdiction profiles for: \(missingCodes.joined(separator: ", ")).")
        }

        for profile in pack.jurisdictionProfiles {
            if profile.state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("Jurisdiction profile \(profile.id) is missing state.")
            }
            if profile.examProvider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("Jurisdiction profile \(profile.id) is missing examProvider.")
            }
            if profile.licenseAuthority.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("Jurisdiction profile \(profile.id) is missing licenseAuthority.")
            }
            if profile.adoptedNECCycle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("Jurisdiction profile \(profile.id) is missing adoptedNECCycle.")
            }
            if profile.sourceUrls.isEmpty {
                issues.append("Jurisdiction profile \(profile.id) is missing sourceUrls.")
            }
            if profile.lastVerifiedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("Jurisdiction profile \(profile.id) is missing lastVerifiedAt.")
            }
            if let verification = profile.verification {
                validateVerification(verification, label: "Jurisdiction profile \(profile.id)", issues: &issues)
            }
        }

        let stateQuestionIDs = Set(pack.stateSpecificQuestions.map(\.id))
        if stateQuestionIDs.count != pack.stateSpecificQuestions.count {
            issues.append("Duplicate state-specific question IDs found.")
        }

        if pack.stateSpecificQuestions.count < 1_000 {
            issues.append("Expected at least 1,000 state-specific overlay questions, found \(pack.stateSpecificQuestions.count).")
        }

        let byState = Dictionary(grouping: pack.stateSpecificQuestions) { $0.stateCode.uppercased() }
        for code in jurisdictionCodes {
            let count = (byState[code] ?? []).count
            if count < 15 {
                issues.append("Expected at least 15 state-specific questions for \(code), found \(count).")
            }
        }

        for question in pack.stateSpecificQuestions {
            if question.answerChoices.count != 4 {
                issues.append("State question \(question.id) does not have exactly four answer choices.")
            }
            if question.answerChoices[question.correctAnswer] == nil {
                issues.append("State question \(question.id) has an invalid correct answer key.")
            }
            if question.sourceUrls.isEmpty {
                issues.append("State question \(question.id) is missing sourceUrls.")
            }
            if question.questionType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("State question \(question.id) is missing questionType.")
            }
            validateVerification(question.verification, label: "State question \(question.id)", issues: &issues)
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

    private static func validateLevelDistribution(level: String, questions: [QuestionBankRecord], issues: inout [String]) {
        guard questions.isEmpty == false else { return }
        let total = Double(questions.count)
        let calculations = Double(questions.filter(\.isCalculation).count) / total
        let codeLookup = Double(questions.filter(\.isCodeLookup).count) / total
        let general = Double(questions.filter { $0.topicCategory.lowercased() == "general" }.count) / total

        if calculations < 0.25 {
            issues.append("\(level.capitalized) question bank is below 25% calculation coverage.")
        }
        if codeLookup < 0.25 {
            issues.append("\(level.capitalized) question bank is below 25% code-lookup coverage.")
        }
        if general > 0.15 {
            issues.append("\(level.capitalized) question bank exceeds 15% general-topic coverage.")
        }

        let easyRatio = Double(questions.filter { difficultyBucket($0.difficultyLevel) == .easy }.count) / total
        let moderateRatio = Double(questions.filter { difficultyBucket($0.difficultyLevel) == .moderate }.count) / total
        let difficultRatio = Double(questions.filter { difficultyBucket($0.difficultyLevel) == .difficult }.count) / total

        if easyRatio < 0.30 {
            issues.append("\(level.capitalized) question bank has less than 30% easy questions.")
        }
        if moderateRatio < 0.50 {
            issues.append("\(level.capitalized) question bank has less than 50% moderate questions.")
        }
        if difficultRatio < 0.20 {
            issues.append("\(level.capitalized) question bank has less than 20% difficult questions.")
        }
    }

    private enum DifficultyBucket {
        case easy
        case moderate
        case difficult
    }

    private static func difficultyBucket(_ value: String) -> DifficultyBucket {
        switch value.lowercased() {
        case "easy", "beginner":
            return .easy
        case "hard", "advanced", "difficult":
            return .difficult
        default:
            return .moderate
        }
    }

    private static func containsBannedPhrase(_ text: String) -> Bool {
        let lower = text.lowercased()
        return bannedPhrases.contains(where: lower.contains)
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
            if verification.verificationConfidence < 90 {
                issues.append("\(label) is published with confidence below 90.")
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
