import Foundation

enum ContentPublishStatus: String, Codable, CaseIterable {
    case draft
    case researched
    case autoApproved = "auto_approved"
    case published
}

enum ContentFreshnessStatus: String, Codable, CaseIterable {
    case fresh
    case stale
    case unknown
    case conflicted
}

struct ContentVerificationMetadata: Codable, Equatable {
    var baseCodeCycle: String?
    var jurisdictionScope: String
    var lastVerifiedAt: String?
    var sourceURLs: [String]
    var sourceHashes: [String]
    var verificationConfidence: Double
    var freshnessStatus: ContentFreshnessStatus
    var publishStatus: ContentPublishStatus
    var stalenessReason: String?
    var disclaimer: String?

    static let draft = ContentVerificationMetadata(
        baseCodeCycle: nil,
        jurisdictionScope: "national",
        lastVerifiedAt: nil,
        sourceURLs: [],
        sourceHashes: [],
        verificationConfidence: 0,
        freshnessStatus: .unknown,
        publishStatus: .draft,
        stalenessReason: "Content has not passed the automated verification pipeline yet.",
        disclaimer: nil
    )

    private enum CodingKeys: String, CodingKey {
        case baseCodeCycle = "base_code_cycle"
        case jurisdictionScope = "jurisdiction_scope"
        case lastVerifiedAt = "last_verified_at"
        case sourceURLs = "source_urls"
        case sourceHashes = "source_hashes"
        case verificationConfidence = "verification_confidence"
        case freshnessStatus = "freshness_status"
        case publishStatus = "publish_status"
        case stalenessReason = "staleness_reason"
        case disclaimer
    }

    init(
        baseCodeCycle: String?,
        jurisdictionScope: String,
        lastVerifiedAt: String?,
        sourceURLs: [String],
        sourceHashes: [String],
        verificationConfidence: Double,
        freshnessStatus: ContentFreshnessStatus,
        publishStatus: ContentPublishStatus,
        stalenessReason: String?,
        disclaimer: String?
    ) {
        self.baseCodeCycle = baseCodeCycle
        self.jurisdictionScope = jurisdictionScope
        self.lastVerifiedAt = lastVerifiedAt
        self.sourceURLs = sourceURLs
        self.sourceHashes = sourceHashes
        self.verificationConfidence = verificationConfidence
        self.freshnessStatus = freshnessStatus
        self.publishStatus = publishStatus
        self.stalenessReason = stalenessReason
        self.disclaimer = disclaimer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseCodeCycle = try container.decodeIfPresent(String.self, forKey: .baseCodeCycle)
        jurisdictionScope = (try? container.decode(String.self, forKey: .jurisdictionScope)) ?? "national"
        lastVerifiedAt = try container.decodeIfPresent(String.self, forKey: .lastVerifiedAt)
        sourceURLs = (try? container.decode([String].self, forKey: .sourceURLs)) ?? []
        sourceHashes = (try? container.decode([String].self, forKey: .sourceHashes)) ?? []
        verificationConfidence = (try? container.decode(Double.self, forKey: .verificationConfidence)) ?? 0
        freshnessStatus = (try? container.decode(ContentFreshnessStatus.self, forKey: .freshnessStatus)) ?? .unknown
        publishStatus = (try? container.decode(ContentPublishStatus.self, forKey: .publishStatus)) ?? .draft
        stalenessReason = try container.decodeIfPresent(String.self, forKey: .stalenessReason)
        disclaimer = try container.decodeIfPresent(String.self, forKey: .disclaimer)
    }
}

// MARK: - Content Pack (top-level JSON structure)

struct WattWiseContentPack: Codable {
    var metadata: ContentPackMetadata
    var executiveSummary: ExecutiveSummary
    var fullLessons: [LessonContentRecord]
    var questionBank: [QuestionBankRecord]
    var practiceExams: [PracticeExamBlueprint]
    var jurisdictionProfiles: [JurisdictionProfile]
    var stateSpecificQuestions: [StateSpecificQuestionRecord]
    var flashcards: [FlashcardRecord]
    var quickReferenceGuides: [QuickReferenceGuide]
    var studyPlans: [StudyPlanRecord]
    var glossary: [GlossaryEntryRecord]
    var jurisdictionResearchNotes: [JurisdictionResearchNote]
    var sourceList: [SourceCitation]

    // JSON uses "practiceQuestions" key
    private enum CodingKeys: String, CodingKey {
        case metadata
        case executiveSummary
        case fullLessons
        case questionBank = "practiceQuestions"
        case practiceExams
        case jurisdictionProfiles
        case stateSpecificQuestions
        case flashcards
        case quickReferenceGuides
        case studyPlans
        case glossary
        case jurisdictionResearchNotes
        case sourceList = "sources"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metadata = try container.decode(ContentPackMetadata.self, forKey: .metadata)
        executiveSummary = try container.decode(ExecutiveSummary.self, forKey: .executiveSummary)
        fullLessons = try container.decode([LessonContentRecord].self, forKey: .fullLessons)
        questionBank = (try? container.decode([QuestionBankRecord].self, forKey: .questionBank)) ?? []
        practiceExams = (try? container.decode([PracticeExamBlueprint].self, forKey: .practiceExams)) ?? []
        jurisdictionProfiles = (try? container.decode([JurisdictionProfile].self, forKey: .jurisdictionProfiles)) ?? []
        stateSpecificQuestions = (try? container.decode([StateSpecificQuestionRecord].self, forKey: .stateSpecificQuestions)) ?? []
        flashcards = (try? container.decode([FlashcardRecord].self, forKey: .flashcards)) ?? []
        quickReferenceGuides = (try? container.decode([QuickReferenceGuide].self, forKey: .quickReferenceGuides)) ?? []
        studyPlans = (try? container.decode([StudyPlanRecord].self, forKey: .studyPlans)) ?? []
        glossary = (try? container.decode([GlossaryEntryRecord].self, forKey: .glossary)) ?? []
        jurisdictionResearchNotes = (try? container.decode([JurisdictionResearchNote].self, forKey: .jurisdictionResearchNotes)) ?? []
        sourceList = (try? container.decode([SourceCitation].self, forKey: .sourceList)) ?? []
    }

    // Synthesized encode
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(executiveSummary, forKey: .executiveSummary)
        try container.encode(fullLessons, forKey: .fullLessons)
        try container.encode(questionBank, forKey: .questionBank)
        try container.encode(practiceExams, forKey: .practiceExams)
        try container.encode(jurisdictionProfiles, forKey: .jurisdictionProfiles)
        try container.encode(stateSpecificQuestions, forKey: .stateSpecificQuestions)
        try container.encode(flashcards, forKey: .flashcards)
        try container.encode(quickReferenceGuides, forKey: .quickReferenceGuides)
        try container.encode(studyPlans, forKey: .studyPlans)
        try container.encode(glossary, forKey: .glossary)
        try container.encode(jurisdictionResearchNotes, forKey: .jurisdictionResearchNotes)
        try container.encode(sourceList, forKey: .sourceList)
    }

    var publishedLessons: [LessonContentRecord] {
        fullLessons.filter { $0.verification.publishStatus == .published }
    }

    var publishedQuestionBank: [QuestionBankRecord] {
        questionBank.filter { $0.verification.publishStatus == .published }
    }

    // Backwards-compat accessor used by WattWiseContentRuntimeAdapter
    var fullLessonContent: [LessonContentRecord] { fullLessons }
    var curriculumFramework: [CourseBlueprint] { synthesizedCurriculumFramework() }

    private func synthesizedCurriculumFramework() -> [CourseBlueprint] {
        let groupedByCourse = Dictionary(grouping: fullLessons) { "\($0.certificationLevel)|\($0.courseTitle)" }

        return groupedByCourse.values
            .sorted {
                courseRank(for: $0.first?.certificationLevel ?? "") < courseRank(for: $1.first?.certificationLevel ?? "")
            }
            .map { lessonRecords in
                let first = lessonRecords[0]
                let modules = Dictionary(grouping: lessonRecords) { $0.moduleName }
                    .values
                    .sorted { lhs, rhs in
                        moduleSortOrder(for: lhs[0].moduleName) < moduleSortOrder(for: rhs[0].moduleName)
                    }
                    .map { moduleLessons in
                        let sample = moduleLessons[0]
                        let lessonBlueprints = moduleLessons
                            .sorted { lhs, rhs in lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending }
                            .map { lesson in
                                LessonBlueprint(
                                    id: lesson.id,
                                    lessonTitle: lesson.lessonTitle,
                                    necReferences: lesson.references,
                                    estimatedMinutes: lesson.estimatedMinutes
                                )
                            }

                        return ModuleBlueprint(
                            id: "module:\(sample.certificationLevel.lowercased())-\(sample.moduleName)",
                            moduleName: sample.moduleName,
                            learningObjectives: sample.learningObjectives,
                            lessons: lessonBlueprints
                        )
                    }

                return CourseBlueprint(
                    id: "course:\(first.certificationLevel.lowercased())",
                    courseTitle: first.courseTitle,
                    certificationLevel: first.certificationLevel,
                    courseDescription: first.learningObjectives.first ?? first.courseTitle,
                    modules: modules
                )
            }
    }

    private func courseRank(for certificationLevel: String) -> Int {
        switch certificationLevel.lowercased() {
        case "apprentice": return 1
        case "journeyman": return 2
        case "master": return 3
        default: return 99
        }
    }

    private func moduleSortOrder(for moduleName: String) -> Int {
        fullLessons.firstIndex(where: { $0.moduleName == moduleName }) ?? .max
    }
}

// MARK: - Metadata

struct ContentPackMetadata: Codable {
    var title: String
    var version: String
    var createdOn: String
    var contentStatus: String
    var validationStatus: String
    var limitations: [String]
}

// MARK: - Executive Summary

struct ExecutiveSummary: Codable {
    var overview: String
    // JSON has curriculumStats / contentApproach — we only need overview
}

// MARK: - NEC Changes (may not exist in JSON — kept for compat)

struct NECChangeSummary: Codable, Identifiable {
    var id: String
    var title: String
    var summary: String
    var examImpact: String
    var sources: [String]
}

// MARK: - Curriculum (synthesized from lesson records; not a JSON top-level key)

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

// MARK: - Lesson Content

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
    var verification: ContentVerificationMetadata
    var estimatedMinutes: Int {
        let bodyWords = lessonContent.reduce(0) { $0 + $1.body.split(separator: " ").count }
        return min(max(bodyWords / 180, 10), 45)
    }

    private enum CodingKeys: String, CodingKey {
        case id, courseTitle, moduleName, lessonTitle, certificationLevel, learningObjectives, lessonContent, keyTakeaways, practiceQuestions, references
        case verification
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        courseTitle = try container.decode(String.self, forKey: .courseTitle)
        moduleName = try container.decode(String.self, forKey: .moduleName)
        lessonTitle = try container.decode(String.self, forKey: .lessonTitle)
        certificationLevel = try container.decode(String.self, forKey: .certificationLevel)
        learningObjectives = (try? container.decode([String].self, forKey: .learningObjectives)) ?? []
        lessonContent = (try? container.decode([LessonParagraph].self, forKey: .lessonContent)) ?? []
        keyTakeaways = (try? container.decode([String].self, forKey: .keyTakeaways)) ?? []
        practiceQuestions = (try? container.decode([String].self, forKey: .practiceQuestions)) ?? []
        references = (try? container.decode([String].self, forKey: .references)) ?? []
        verification = (try? container.decode(ContentVerificationMetadata.self, forKey: .verification)) ?? .draft
    }
}

struct LessonParagraph: Codable, Identifiable {
    var id: String
    var heading: String
    var body: String
    var necReferences: [String]
}

// MARK: - Question Bank

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
    var jurisdictionScope: String
    var examProvider: String?
    var licenseType: String?
    var codeCycle: String?
    var sourceUrls: [String]
    var sourceAccessedOn: String?
    var examBlueprintTags: [String]
    var isCalculation: Bool
    var isCodeLookup: Bool
    var verification: ContentVerificationMetadata

    private enum CodingKeys: String, CodingKey {
        case id
        case certificationLevel
        case topicCategory = "topic"
        case questionText = "question"
        case optionA, optionB, optionC, optionD
        case correctAnswer
        case explanation
        case necReference
        case difficultyLevel = "difficulty"
        case jurisdictionScope
        case examProvider
        case licenseType
        case codeCycle
        case sourceUrls
        case sourceAccessedOn
        case examBlueprintTags
        case isCalculation
        case isCodeLookup
        case verification
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        certificationLevel = try container.decode(String.self, forKey: .certificationLevel)
        topicCategory = (try? container.decode(String.self, forKey: .topicCategory)) ?? ""
        questionText = try container.decode(String.self, forKey: .questionText)
        correctAnswer = try container.decode(String.self, forKey: .correctAnswer)
        explanation = (try? container.decode(String.self, forKey: .explanation)) ?? ""
        necReference = (try? container.decode(String.self, forKey: .necReference)) ?? ""
        difficultyLevel = (try? container.decode(String.self, forKey: .difficultyLevel)) ?? "intermediate"
        verification = (try? container.decode(ContentVerificationMetadata.self, forKey: .verification)) ?? .draft
        jurisdictionScope = (try? container.decode(String.self, forKey: .jurisdictionScope))
            ?? verification.jurisdictionScope
        examProvider = try container.decodeIfPresent(String.self, forKey: .examProvider)
        licenseType = try container.decodeIfPresent(String.self, forKey: .licenseType)
        codeCycle = try container.decodeIfPresent(String.self, forKey: .codeCycle)
        sourceUrls = (try? container.decode([String].self, forKey: .sourceUrls)) ?? verification.sourceURLs
        sourceAccessedOn = try container.decodeIfPresent(String.self, forKey: .sourceAccessedOn)
        examBlueprintTags = (try? container.decode([String].self, forKey: .examBlueprintTags)) ?? []
        isCalculation = (try? container.decode(Bool.self, forKey: .isCalculation)) ?? false
        isCodeLookup = (try? container.decode(Bool.self, forKey: .isCodeLookup)) ?? false

        // Build answerChoices dict from individual optionA/B/C/D fields
        var choices: [String: String] = [:]
        if let a = try? container.decode(String.self, forKey: .optionA) { choices["A"] = a }
        if let b = try? container.decode(String.self, forKey: .optionB) { choices["B"] = b }
        if let c = try? container.decode(String.self, forKey: .optionC) { choices["C"] = c }
        if let d = try? container.decode(String.self, forKey: .optionD) { choices["D"] = d }
        answerChoices = choices
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(certificationLevel, forKey: .certificationLevel)
        try container.encode(topicCategory, forKey: .topicCategory)
        try container.encode(questionText, forKey: .questionText)
        try container.encode(correctAnswer, forKey: .correctAnswer)
        try container.encode(explanation, forKey: .explanation)
        try container.encode(necReference, forKey: .necReference)
        try container.encode(difficultyLevel, forKey: .difficultyLevel)
        try container.encode(jurisdictionScope, forKey: .jurisdictionScope)
        try container.encodeIfPresent(examProvider, forKey: .examProvider)
        try container.encodeIfPresent(licenseType, forKey: .licenseType)
        try container.encodeIfPresent(codeCycle, forKey: .codeCycle)
        try container.encode(sourceUrls, forKey: .sourceUrls)
        try container.encodeIfPresent(sourceAccessedOn, forKey: .sourceAccessedOn)
        try container.encode(examBlueprintTags, forKey: .examBlueprintTags)
        try container.encode(isCalculation, forKey: .isCalculation)
        try container.encode(isCodeLookup, forKey: .isCodeLookup)
        try container.encode(verification, forKey: .verification)
        try container.encodeIfPresent(answerChoices["A"], forKey: .optionA)
        try container.encodeIfPresent(answerChoices["B"], forKey: .optionB)
        try container.encodeIfPresent(answerChoices["C"], forKey: .optionC)
        try container.encodeIfPresent(answerChoices["D"], forKey: .optionD)
    }
}

// MARK: - Practice Exams

struct PracticeExamBlueprint: Codable, Identifiable {
    var id: String
    var title: String
    var certificationLevel: String
    var structureNotes: String
    var timingMinutes: Int
    var questionCount: Int?
    var examProvider: String?
    var licenseType: String?
    var jurisdictionCode: String?
    var codeCycle: String?
    var passingScore: Int?
    var blueprintTags: [String]
    var questionIds: [String]
    var answerKey: [String: String]
    var verification: ContentVerificationMetadata?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case certificationLevel
        case structureNotes
        case timingMinutes
        case questionCount
        case examProvider
        case licenseType
        case jurisdictionCode
        case codeCycle
        case passingScore
        case blueprintTags
        case questionIds
        case answerKey
        case verification
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        certificationLevel = try container.decode(String.self, forKey: .certificationLevel)
        structureNotes = (try? container.decode(String.self, forKey: .structureNotes)) ?? ""
        timingMinutes = (try? container.decode(Int.self, forKey: .timingMinutes)) ?? 0
        questionCount = try container.decodeIfPresent(Int.self, forKey: .questionCount)
        examProvider = try container.decodeIfPresent(String.self, forKey: .examProvider)
        licenseType = try container.decodeIfPresent(String.self, forKey: .licenseType)
        jurisdictionCode = try container.decodeIfPresent(String.self, forKey: .jurisdictionCode)
        codeCycle = try container.decodeIfPresent(String.self, forKey: .codeCycle)
        passingScore = try container.decodeIfPresent(Int.self, forKey: .passingScore)
        blueprintTags = (try? container.decode([String].self, forKey: .blueprintTags)) ?? []
        questionIds = (try? container.decode([String].self, forKey: .questionIds)) ?? []
        answerKey = (try? container.decode([String: String].self, forKey: .answerKey)) ?? [:]
        verification = try container.decodeIfPresent(ContentVerificationMetadata.self, forKey: .verification)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(certificationLevel, forKey: .certificationLevel)
        try container.encode(structureNotes, forKey: .structureNotes)
        try container.encode(timingMinutes, forKey: .timingMinutes)
        try container.encodeIfPresent(questionCount, forKey: .questionCount)
        try container.encodeIfPresent(examProvider, forKey: .examProvider)
        try container.encodeIfPresent(licenseType, forKey: .licenseType)
        try container.encodeIfPresent(jurisdictionCode, forKey: .jurisdictionCode)
        try container.encodeIfPresent(codeCycle, forKey: .codeCycle)
        try container.encodeIfPresent(passingScore, forKey: .passingScore)
        try container.encode(blueprintTags, forKey: .blueprintTags)
        try container.encode(questionIds, forKey: .questionIds)
        try container.encode(answerKey, forKey: .answerKey)
        try container.encodeIfPresent(verification, forKey: .verification)
    }
}

// MARK: - Flashcards

struct FlashcardRecord: Codable, Identifiable {
    var id: String
    var front: String
    var back: String
    var necReference: String
    var certificationLevel: String
    var verification: ContentVerificationMetadata?

    private enum CodingKeys: String, CodingKey {
        case id, front, back, certificationLevel, verification
        case necReference = "topic"
    }
}

// MARK: - Quick Reference / Study Plans / Glossary

struct QuickReferenceGuide: Codable, Identifiable {
    var id: String
    var title: String
    var certificationLevel: String
    var bullets: [String]
    var references: [String]
    var verification: ContentVerificationMetadata?
}

struct StudyPlanRecord: Codable, Identifiable {
    var id: String
    var title: String
    var certificationLevel: String
    var durationWeeks: Int
    var weeklyFocus: [String]
    var verification: ContentVerificationMetadata?
}

struct GlossaryEntryRecord: Codable, Identifiable {
    var id: String
    var term: String
    var definition: String
    var necReference: String
    var certificationLevel: String
    var verification: ContentVerificationMetadata?
}

// MARK: - Jurisdiction Notes

struct JurisdictionResearchNote: Codable, Identifiable {
    var id: String
    var jurisdiction: String
    var summary: String
    var officialSource: String
}

struct JurisdictionProfile: Codable, Identifiable {
    var id: String
    var state: String
    var stateCode: String
    var examProvider: String
    var licenseAuthority: String
    var adoptedNECCycle: String
    var stateAmendments: [String]
    var examFormat: JurisdictionExamFormat
    var licenseTypeMap: [String: String]
    var referencesAllowed: String
    var reciprocityNotes: String
    var sourceUrls: [String]
    var sourceAccessedOn: String
    var lastVerifiedAt: String
    var verification: ContentVerificationMetadata?
}

struct JurisdictionExamFormat: Codable {
    var questionCount: Int
    var timeLimitMinutes: Int
    var passingScore: Int
    var openBook: Bool
}

struct StateSpecificQuestionRecord: Codable, Identifiable {
    var id: String
    var stateCode: String
    var state: String
    var certificationLevel: String
    var questionText: String
    var answerChoices: [String: String]
    var correctAnswer: String
    var explanation: String
    var questionType: String
    var topicCategory: String
    var examProvider: String?
    var licenseType: String?
    var codeCycle: String?
    var sourceUrls: [String]
    var sourceAccessedOn: String?
    var verification: ContentVerificationMetadata

    private enum CodingKeys: String, CodingKey {
        case id
        case stateCode
        case state
        case certificationLevel
        case questionText = "question"
        case optionA, optionB, optionC, optionD
        case correctAnswer
        case explanation
        case questionType
        case topicCategory = "topic"
        case examProvider
        case licenseType
        case codeCycle
        case sourceUrls
        case sourceAccessedOn
        case verification
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        stateCode = try container.decode(String.self, forKey: .stateCode)
        state = try container.decode(String.self, forKey: .state)
        certificationLevel = try container.decode(String.self, forKey: .certificationLevel)
        questionText = try container.decode(String.self, forKey: .questionText)
        correctAnswer = try container.decode(String.self, forKey: .correctAnswer)
        explanation = try container.decode(String.self, forKey: .explanation)
        questionType = try container.decode(String.self, forKey: .questionType)
        topicCategory = try container.decode(String.self, forKey: .topicCategory)
        examProvider = try container.decodeIfPresent(String.self, forKey: .examProvider)
        licenseType = try container.decodeIfPresent(String.self, forKey: .licenseType)
        codeCycle = try container.decodeIfPresent(String.self, forKey: .codeCycle)
        sourceUrls = (try? container.decode([String].self, forKey: .sourceUrls)) ?? []
        sourceAccessedOn = try container.decodeIfPresent(String.self, forKey: .sourceAccessedOn)
        verification = (try? container.decode(ContentVerificationMetadata.self, forKey: .verification)) ?? .draft

        var choices: [String: String] = [:]
        if let a = try? container.decode(String.self, forKey: .optionA) { choices["A"] = a }
        if let b = try? container.decode(String.self, forKey: .optionB) { choices["B"] = b }
        if let c = try? container.decode(String.self, forKey: .optionC) { choices["C"] = c }
        if let d = try? container.decode(String.self, forKey: .optionD) { choices["D"] = d }
        answerChoices = choices
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(stateCode, forKey: .stateCode)
        try container.encode(state, forKey: .state)
        try container.encode(certificationLevel, forKey: .certificationLevel)
        try container.encode(questionText, forKey: .questionText)
        try container.encode(correctAnswer, forKey: .correctAnswer)
        try container.encode(explanation, forKey: .explanation)
        try container.encode(questionType, forKey: .questionType)
        try container.encode(topicCategory, forKey: .topicCategory)
        try container.encodeIfPresent(examProvider, forKey: .examProvider)
        try container.encodeIfPresent(licenseType, forKey: .licenseType)
        try container.encodeIfPresent(codeCycle, forKey: .codeCycle)
        try container.encode(sourceUrls, forKey: .sourceUrls)
        try container.encodeIfPresent(sourceAccessedOn, forKey: .sourceAccessedOn)
        try container.encode(verification, forKey: .verification)
        try container.encodeIfPresent(answerChoices["A"], forKey: .optionA)
        try container.encodeIfPresent(answerChoices["B"], forKey: .optionB)
        try container.encodeIfPresent(answerChoices["C"], forKey: .optionC)
        try container.encodeIfPresent(answerChoices["D"], forKey: .optionD)
    }
}

// MARK: - Sources

struct SourceCitation: Codable, Identifiable {
    var id: String
    var title: String
    var publisher: String
    var url: String
    var sourceType: String
    var accessedOn: String
    var notes: String

    private enum CodingKeys: String, CodingKey {
        case id, title, publisher, url, sourceType, accessedOn, notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        publisher = (try? container.decode(String.self, forKey: .publisher)) ?? ""
        url = (try? container.decode(String.self, forKey: .url)) ?? ""
        sourceType = (try? container.decode(String.self, forKey: .sourceType)) ?? ""
        accessedOn = (try? container.decode(String.self, forKey: .accessedOn)) ?? ""
        notes = (try? container.decode(String.self, forKey: .notes)) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(publisher, forKey: .publisher)
        try container.encode(url, forKey: .url)
        try container.encode(sourceType, forKey: .sourceType)
        try container.encode(accessedOn, forKey: .accessedOn)
        try container.encode(notes, forKey: .notes)
    }
}
