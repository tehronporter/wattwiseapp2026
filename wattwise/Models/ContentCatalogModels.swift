import Foundation

struct WattWiseContentPack: Codable {
    var metadata: ContentPackMetadata
    var executiveSummary: ExecutiveSummary
    var nec2026Changes: [NECChangeSummary]
    var curriculumFramework: [CourseBlueprint]
    var fullLessonContent: [LessonContentRecord]
    var questionBank: [QuestionBankRecord]
    var practiceExams: [PracticeExamBlueprint]
    var flashcards: [FlashcardRecord]
    var quickReferenceGuides: [QuickReferenceGuide]
    var studyPlans: [StudyPlanRecord]
    var glossary: [GlossaryEntryRecord]
    var jurisdictionResearchNotes: [JurisdictionResearchNote]
    var sourceList: [SourceCitation]
}

struct ContentPackMetadata: Codable {
    var title: String
    var version: String
    var createdOn: String
    var contentStatus: String
    var validationStatus: String
    var limitations: [String]
}

struct ExecutiveSummary: Codable {
    var overview: String
    var examPrepImpact: [String]
    var instructionalUseNotes: [String]
}

struct NECChangeSummary: Codable, Identifiable {
    var id: String
    var title: String
    var summary: String
    var examImpact: String
    var sources: [String]
}

struct CourseBlueprint: Codable, Identifiable {
    var id: String
    var courseTitle: String
    var certificationLevel: String
    var courseDescription: String
    var modules: [ModuleBlueprint]
}

struct ModuleBlueprint: Codable, Identifiable {
    var id: String
    var moduleName: String
    var learningObjectives: [String]
    var lessons: [LessonBlueprint]
}

struct LessonBlueprint: Codable, Identifiable {
    var id: String
    var lessonTitle: String
    var necReferences: [String]
    var estimatedMinutes: Int
}

struct LessonContentRecord: Codable, Identifiable {
    var id: String
    var courseTitle: String
    var moduleName: String
    var lessonTitle: String
    var certificationLevel: String
    var learningObjectives: [String]
    var lessonContent: [LessonParagraph]
    var keyTakeaways: [String]
    var practiceQuestions: [String]
    var references: [String]
}

struct LessonParagraph: Codable, Identifiable {
    var id: String
    var heading: String
    var body: String
    var necReferences: [String]
}

struct QuestionBankRecord: Codable, Identifiable {
    var id: String
    var certificationLevel: String
    var topicCategory: String
    var questionText: String
    var answerChoices: [String: String]
    var correctAnswer: String
    var explanation: String
    var necReference: String
    var difficultyLevel: String
}

struct PracticeExamBlueprint: Codable, Identifiable {
    var id: String
    var title: String
    var certificationLevel: String
    var structureNotes: String
    var timingMinutes: Int
    var questionIds: [String]
    var answerKey: [String: String]
}

struct FlashcardRecord: Codable, Identifiable {
    var id: String
    var front: String
    var back: String
    var necReference: String
    var certificationLevel: String
}

struct QuickReferenceGuide: Codable, Identifiable {
    var id: String
    var title: String
    var certificationLevel: String
    var bullets: [String]
    var references: [String]
}

struct StudyPlanRecord: Codable, Identifiable {
    var id: String
    var title: String
    var certificationLevel: String
    var durationWeeks: Int
    var weeklyFocus: [String]
}

struct GlossaryEntryRecord: Codable, Identifiable {
    var id: String
    var term: String
    var definition: String
    var necReference: String
    var certificationLevel: String
}

struct JurisdictionResearchNote: Codable, Identifiable {
    var id: String
    var jurisdiction: String
    var summary: String
    var officialSource: String
}

struct SourceCitation: Codable, Identifiable {
    var id: String
    var title: String
    var publisher: String
    var url: String
    var sourceType: String
    var accessedOn: String
    var notes: String
}
