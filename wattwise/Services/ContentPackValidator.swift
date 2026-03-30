import Foundation

enum ContentPackValidator {
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

        return issues
    }
}
