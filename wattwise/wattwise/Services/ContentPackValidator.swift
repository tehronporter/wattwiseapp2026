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

    static func validate(_ pack: WattWiseContentPack) -> [String] {
        var issues: [String] = []

        let sourceIDs = Set(pack.sourceList.map(\.id))
        if sourceIDs.count != pack.sourceList.count {
            issues.append("Duplicate source citation IDs found.")
        }

        let changeIDs = Set(pack.nec2026Changes.map(\.id))
        if changeIDs.count != pack.nec2026Changes.count {
            issues.append("Duplicate NEC change IDs found.")
        }

        for change in pack.nec2026Changes {
            if change.sources.isEmpty {
                issues.append("NEC change \(change.id) is missing source citations.")
            }

            for source in change.sources where !sourceIDs.contains(source) {
                issues.append("NEC change \(change.id) references unknown source \(source).")
            }
        }

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
        }

        let practiceExamIDs = Set(pack.practiceExams.map(\.id))
        if practiceExamIDs.count != pack.practiceExams.count {
            issues.append("Duplicate practice exam IDs found.")
        }

        let questionIDSet = Set(questionIDs)
        for exam in pack.practiceExams {
            for questionID in exam.questionIds where !questionIDSet.contains(questionID) {
                issues.append("Practice exam \(exam.id) references unknown question \(questionID).")
            }

            for (questionID, answer) in exam.answerKey where exam.questionIds.contains(questionID) == false || ["A", "B", "C", "D"].contains(answer) == false {
                issues.append("Practice exam \(exam.id) has an invalid answer-key entry for \(questionID).")
            }
        }

        let glossaryIDs = Set(pack.glossary.map(\.id))
        if glossaryIDs.count != pack.glossary.count {
            issues.append("Duplicate glossary IDs found.")
        }

        let flashcardIDs = Set(pack.flashcards.map(\.id))
        if flashcardIDs.count != pack.flashcards.count {
            issues.append("Duplicate flashcard IDs found.")
        }

        let lessonIDs = Set(pack.fullLessonContent.map(\.id))
        if lessonIDs.count != pack.fullLessonContent.count {
            issues.append("Duplicate lesson content IDs found.")
        }

        let blueprintLessons = pack.curriculumFramework
            .flatMap(\.modules)
            .flatMap(\.lessons)
        let blueprintLessonIDs = Set(blueprintLessons.map(\.id))

        if lessonIDs != blueprintLessonIDs {
            let missing = blueprintLessonIDs.subtracting(lessonIDs).sorted()
            let unexpected = lessonIDs.subtracting(blueprintLessonIDs).sorted()

            if missing.isEmpty == false {
                issues.append("Missing lesson content for: \(missing.joined(separator: ", ")).")
            }
            if unexpected.isEmpty == false {
                issues.append("Lesson content has unexpected IDs: \(unexpected.joined(separator: ", ")).")
            }
        }

        for lesson in pack.fullLessonContent {
            let headings = lesson.lessonContent.map(\.heading)
            let headingSet = Set(headings)
            let missingHeadings = Set(requiredLessonHeadings).subtracting(headingSet).sorted()
            if missingHeadings.isEmpty == false {
                issues.append("Lesson \(lesson.id) is missing required sections: \(missingHeadings.joined(separator: ", ")).")
            }

            if headings != requiredLessonHeadings {
                issues.append("Lesson \(lesson.id) does not follow the required section order.")
            }

            if lesson.lessonContent.count < requiredLessonHeadings.count {
                issues.append("Lesson \(lesson.id) has too few content sections.")
            }

            for paragraph in lesson.lessonContent {
                let trimmed = paragraph.body.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    issues.append("Lesson \(lesson.id) has an empty body in section \(paragraph.id).")
                }

                if trimmed.count < 40 {
                    issues.append("Lesson \(lesson.id) section \(paragraph.id) is too thin for production use.")
                }

                let lower = trimmed.lowercased()
                if ["todo", "tbd", "placeholder", "coming soon", "lorem ipsum"].contains(where: lower.contains) {
                    issues.append("Lesson \(lesson.id) contains placeholder text in section \(paragraph.id).")
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
            if sectionReferenceSet.isSubset(of: Set(lesson.references)) == false {
                issues.append("Lesson \(lesson.id) contains section NEC references that are not listed in references.")
            }

            if lesson.keyTakeaways.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).count < 20 }) {
                issues.append("Lesson \(lesson.id) has a takeaway that is too short to be useful.")
            }

            if lesson.practiceQuestions.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?") == false }) {
                issues.append("Lesson \(lesson.id) has a practice question that is not phrased like a question.")
            }
        }

        return issues
    }
}
