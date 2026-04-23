import CryptoKit
import Foundation

private func uniqueLessonReferenceCodes(for record: LessonContentRecord) -> [String] {
    let values = record.lessonContent.flatMap(\.necReferences) + record.references
    var unique: [String] = []
    for value in values where unique.contains(value) == false {
        unique.append(value)
    }
    return unique
}

enum WattWiseContentRuntimeAdapter {
    private static let supportedCertificationLevels: Set<String> = ["apprentice", "journeyman", "master"]

    private struct StoredLessonProgress: Codable {
        var completion: Double
        var lastAccessedAt: Date
        var completedAt: Date?
    }

    private static let seededProgress: [String: Double] = [
        "ap-les-001": 1.0,
        "ap-les-002": 1.0,
        "ap-les-004": 0.55
    ]

    private static let progressStorageKey = "ww_content_progress_v2"
    private static let studyActivityStorageKey = "ww_content_study_activity_v1"
    private static let defaultDailyGoalMinutes = 30

    private static let necCatalog: [String: (title: String, summary: String)] = [
        "90.1": ("Purpose", "Explains the practical purpose of the NEC and its role in safeguarding people and property."),
        "90.3": ("Code Arrangement", "Shows how general rules interact with specific rules and why special chapters can modify the earlier chapters."),
        "90.4": ("Enforcement", "Explains that the authority having jurisdiction interprets, approves, and enforces the adopted code."),
        "110.1": ("Scope", "Introduces the general requirements that apply to electrical installations and equipment."),
        "110.2": ("Approval", "Requires equipment and conductors to be acceptable to the authority having jurisdiction."),
        "110.3(B)": ("Installation and Use", "Requires listed or labeled equipment to be installed and used according to its instructions."),
        "110.4": ("Voltages", "Addresses voltage considerations that affect installation and equipment application."),
        "110.26": ("Spaces About Electrical Equipment", "Covers working-space, access, and dedicated-space rules around electrical equipment."),
        "110.27": ("Guarding of Live Parts", "Requires live parts to be guarded against accidental contact."),
        "210.11": ("Branch Circuits Required", "Identifies required dwelling-unit branch circuits such as small-appliance, laundry, and bathroom circuits."),
        "210.19(A)(1)": ("Branch-Circuit Conductor Sizing", "Sets minimum conductor ampacity for branch circuits and continuous loads."),
        "210.20(A)": ("Overcurrent Protection", "Requires branch-circuit overcurrent devices to be sized for noncontinuous and continuous loads."),
        "210.52": ("Dwelling Receptacle Requirements", "Sets receptacle placement rules for dwelling-unit wall spaces and special areas."),
        "215.2": ("Feeder Conductor Sizing", "Covers minimum ampacity requirements for feeder conductors."),
        "215.3": ("Feeder Overcurrent Protection", "Requires feeder overcurrent devices to be sized for continuous and noncontinuous loads."),
        "220.40": ("General Calculation Methods", "States that branch-circuit, feeder, and service calculations use the rules in Article 220."),
        "220.42": ("Lighting Load Demand Factors", "Provides demand factors for lighting loads used in building calculations."),
        "220.44": ("Receptacle Load Demand Factors", "Allows demand factors for certain receptacle loads in feeder and service calculations."),
        "220.50": ("Motor Loads", "Requires the motor load to be based on the largest motor plus other applicable loads."),
        "220.53": ("Appliance Demand Factors", "Allows demand factors for fastened-in-place appliances when the conditions are met."),
        "220.54": ("Electric Clothes Dryers", "Provides load rules for household electric clothes dryers."),
        "220.60": ("Noncoincident Loads", "Allows only the larger of two loads when it is clear they will not operate at the same time."),
        "220.82": ("Optional Dwelling Calculation", "Provides the optional calculation method for dwelling-unit services and feeders."),
        "230.42": ("Service Conductors", "Covers minimum ampacity requirements for service conductors."),
        "250.24": ("Service Grounding and Bonding", "Explains grounding and bonding rules at the service disconnecting means."),
        "250.32": ("Buildings or Structures Supplied by a Feeder", "Gives grounding and bonding rules for separate buildings or structures."),
        "250.50": ("Grounding Electrode System", "Requires available electrodes to be bonded together into one grounding electrode system."),
        "250.66": ("Grounding Electrode Conductor Sizing", "Provides sizing rules for grounding electrode conductors."),
        "300.11": ("Securing and Supporting", "Requires raceways, cable assemblies, and boxes to be secured and supported correctly."),
        "310.14": ("Ampacity Selection", "Directs users to choose conductor ampacity using the applicable tables and conditions of use."),
        "310.16": ("Ampacity Table", "Lists allowable ampacities for insulated conductors under stated conditions."),
        "314.16": ("Box Fill", "Provides box-volume calculations based on conductors, devices, fittings, and grounds."),
        "430.22": ("Motor Circuit Conductors", "Requires motor branch-circuit conductors to be sized from motor full-load current rules."),
        "430.32": ("Motor Overload Protection", "Covers motor overload protection sizing and settings."),
        "430.52": ("Short-Circuit and Ground-Fault Protection", "Gives maximum ratings for motor branch-circuit short-circuit and ground-fault protection."),
        "500.5": ("Classifications of Hazardous Locations", "Defines how hazardous locations are classified by class, division, and zone."),
        "500.7": ("Protection Techniques", "Lists protection techniques used for equipment in hazardous locations."),
        "501.10": ("Wiring Methods", "Covers permitted wiring methods in Class I locations."),
        "501.15": ("Sealing and Drainage", "Explains sealing fitting rules used to control gases, vapors, and pressure."),
        "501.125": ("Motors", "Provides motor requirements for Class I hazardous locations."),
        "502.10": ("Class II Wiring Methods", "Covers wiring methods in Class II locations where combustible dust is present."),
        "505.9": ("Zone 0, 1, and 2 Equipment", "Addresses equipment permitted in classified zone locations."),
        "Annex D": ("Examples", "Contains informative calculation examples that help users practice NEC problem solving."),
        "Article 100": ("Definitions", "Holds defined terms used throughout the NEC and is a frequent starting point for code lookup.")
    ]

    static func loadModules(includeDraftContent: Bool = false) throws -> [WWModule] {
        try modules(from: WattWiseContentCatalog.loadFromBundle(), includeDraftContent: includeDraftContent)
    }

    static func loadLesson(id: UUID, includeDraftContent: Bool = false) throws -> WWLesson {
        let pack = try WattWiseContentCatalog.loadFromBundle()
        let lessons = lessonMap(from: pack, includeDraftContent: includeDraftContent)
        guard let lesson = lessons[id] else {
            throw AppError.notFound("Lesson not found in the content pack.")
        }
        return lesson
    }

    static func previewLessonID(includeDraftContent: Bool = false) throws -> UUID? {
        try loadModules(includeDraftContent: includeDraftContent)
            .flatMap(\.lessons)
            .first(where: { $0.isPreviewIncluded == true })?
            .id
    }

    static func modules(from pack: WattWiseContentPack, includeDraftContent: Bool = false) throws -> [WWModule] {
        // Build module structure directly from lesson records (JSON has no curriculumFramework)
        let supportedRecords = pack.fullLessonContent.filter {
            supportedCertificationLevels.contains($0.certificationLevel.lowercased()) &&
                (includeDraftContent || $0.verification.publishStatus == .published)
        }

        // Group lessons by (certificationLevel + moduleName), preserving insertion order
        var moduleOrder: [String] = []
        var recordsByModule: [String: [LessonContentRecord]] = [:]
        for record in supportedRecords {
            let key = "\(record.certificationLevel.lowercased())|\(record.moduleName)"
            if recordsByModule[key] == nil {
                moduleOrder.append(key)
                recordsByModule[key] = []
            }
            recordsByModule[key]!.append(record)
        }

        return try moduleOrder.compactMap { key -> WWModule? in
            guard let records = recordsByModule[key], !records.isEmpty else { return nil }
            let first = records[0]
            let moduleId = "module:\(first.certificationLevel.lowercased())-\(first.moduleName.lowercased().replacingOccurrences(of: " ", with: "-"))"

            let lessonModels = try records.flatMap { record -> [WWLesson] in
                let totalParts = partCountForLesson(record)
                return try (1...totalParts).map { partNumber in
                    try makeLessonFromRecord(record: record, moduleId: moduleId, partNumber: partNumber, totalParts: totalParts)
                }
            }

            let estimatedMinutes = lessonModels.reduce(0) { $0 + $1.estimatedMinutes }
            let progress = lessonModels.isEmpty
                ? 0.0
                : lessonModels.reduce(0.0) { $0 + $1.completionPercentage } / Double(lessonModels.count)

            let certLevel = first.certificationLevel.lowercased()
            let moduleSlug = first.moduleName
                .lowercased()
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .replacingOccurrences(of: " and ", with: "-")
                .replacingOccurrences(of: " ", with: "-")
            let tags = [certLevel, moduleSlug].filter { !$0.isEmpty }

            return WWModule(
                id: uuid(for: moduleId),
                title: first.moduleName,
                description: first.learningObjectives.first ?? first.moduleName,
                lessonCount: lessonModels.count,
                estimatedMinutes: estimatedMinutes,
                topicTags: tags,
                progress: progress,
                lessons: lessonModels,
                examType: ExamType(rawValue: certLevel),
                publishStatus: includeDraftContent ? nil : .published,
                freshnessStatus: aggregateFreshness(for: records),
                jurisdictionScope: records.map(\.verification.jurisdictionScope).first(where: { !$0.isEmpty }) ?? "national",
                lastVerifiedAt: records.compactMap(\.verification.lastVerifiedAt).max()
            )
        }
    }

    static func saveProgress(lessonId: UUID, completion: Double) throws {
        let pack = try WattWiseContentCatalog.loadFromBundle()
        guard let record = pack.fullLessonContent.first(where: { uuid(for: "lesson:\($0.id)") == lessonId }) else {
            throw AppError.notFound("Lesson progress could not be saved because the lesson was not found.")
        }

        var progressByLesson = storedProgressByLesson()
        let now = Date()
        let normalizedCompletion = max(0, min(1, completion))
        let existing = progressByLesson[record.id] ?? defaultStoredProgress(for: record.id, now: now)
        let effectiveCompletion = max(existing.completion, normalizedCompletion)

        progressByLesson[record.id] = StoredLessonProgress(
            completion: effectiveCompletion,
            lastAccessedAt: now,
            completedAt: effectiveCompletion >= 1.0 ? (existing.completedAt ?? now) : existing.completedAt
        )
        persistProgress(progressByLesson)

        let estimatedMinutes = estimateMinutes(for: record)
        let gainedMinutes = max(
            0,
            Int(round((effectiveCompletion - existing.completion) * Double(max(estimatedMinutes, 1))))
        )
        if gainedMinutes > 0 {
            var studyActivity = storedStudyActivity()
            let today = isoDate(now)
            studyActivity[today, default: 0] += gainedMinutes
            persistStudyActivity(studyActivity)
        }
    }

    static func loadProgressSummary() throws -> ProgressSummary {
        let modules = try loadModules(includeDraftContent: true)
        let lessons = modules.flatMap(\.lessons)
        let progressByLesson = storedProgressByLesson()
        let moduleTitleByLessonID = Dictionary(
            uniqueKeysWithValues: modules.flatMap { module in
                module.lessons.map { ($0.id, module.title) }
            }
        )

        let continueLearning = lessons
            .filter { $0.completionPercentage > 0 && $0.completionPercentage < 1 }
            .sorted { lhs, rhs in
                let lhsDate = canonicalLessonID(for: lhs.id)
                    .flatMap { progressByLesson[$0]?.lastAccessedAt } ?? .distantPast
                let rhsDate = canonicalLessonID(for: rhs.id)
                    .flatMap { progressByLesson[$0]?.lastAccessedAt } ?? .distantPast
                return lhsDate > rhsDate
            }
            .first
            .map {
                ProgressSummary.ContinueLearning(
                    lessonId: $0.id,
                    lessonTitle: $0.title,
                    progress: $0.completionPercentage,
                    moduleTitle: moduleTitleByLessonID[$0.id] ?? $0.topic
                )
            }
            ?? lessons.first(where: { $0.completionPercentage == 0 }).map {
                ProgressSummary.ContinueLearning(
                    lessonId: $0.id,
                    lessonTitle: $0.title,
                    progress: 0,
                    moduleTitle: moduleTitleByLessonID[$0.id] ?? $0.topic
                )
            }

        let activity = storedStudyActivity()
        let today = isoDate(Date())
        let minutesCompleted = activity[today, default: 0]
        let startedLessons = lessons.filter { $0.completionPercentage > 0 }
        let lastActivityAt = progressByLesson.values
            .map(\.lastAccessedAt)
            .max()

        var streak = 0
        var cursor = Calendar.current.startOfDay(for: Date())
        while activity[isoDate(cursor), default: 0] > 0 {
            streak += 1
            guard let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }

        let recommendation: String
        if let continueLearning, continueLearning.progress > 0 {
            recommendation = "Resume \(continueLearning.lessonTitle)"
        } else if let continueLearning {
            recommendation = "Start \(continueLearning.lessonTitle)"
        } else {
            recommendation = "Browse the next lesson in Learn"
        }

        return ProgressSummary(
            continueLearning: continueLearning,
            dailyGoal: .init(
                minutesCompleted: minutesCompleted,
                targetMinutes: defaultDailyGoalMinutes
            ),
            streakDays: streak,
            recommendedAction: recommendation,
            hasStartedContent: startedLessons.isEmpty == false,
            lastActivityAt: lastActivityAt
        )
    }

    static func searchNEC(query: String) throws -> [NECSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return [] }

        return try uniqueNECReferences(from: WattWiseContentCatalog.loadFromBundle())
            .filter {
                $0.code.localizedCaseInsensitiveContains(trimmed) ||
                $0.title.localizedCaseInsensitiveContains(trimmed) ||
                $0.summary.localizedCaseInsensitiveContains(trimmed)
            }
            .sorted { $0.code.localizedStandardCompare($1.code) == .orderedAscending }
    }

    /// Returns flashcards, optionally filtered to a certification level.
    /// Includes supplemental NEC Table flashcards from MockData.
    static func flashcards(certificationLevel: String? = nil) throws -> [FlashcardRecord] {
        let pack = try WattWiseContentCatalog.loadFromBundle()
        var all = pack.flashcards
        // Inject supplemental NEC Table flashcards (deduplicate by id)
        let existingIDs = Set(all.map(\.id))
        let supplemental = MockData.necTableFlashcards.filter { !existingIDs.contains($0.id) }
        all.append(contentsOf: supplemental)

        guard let level = certificationLevel, !level.isEmpty else { return all }
        let certRank = certLevel(level)
        let filtered = all.filter { certLevel($0.certificationLevel) <= certRank }
        return filtered.isEmpty ? all : filtered
    }

    private static func certLevel(_ level: String) -> Int {
        switch level.lowercased() {
        case "apprentice": return 1
        case "journeyman": return 2
        case "master": return 3
        default: return 2
        }
    }

    static func necReference(id: UUID) throws -> NECReference {
        guard let reference = try allNECReferences(from: WattWiseContentCatalog.loadFromBundle())
            .first(where: { $0.id == id }) else {
            throw AppError.notFound("NEC reference not found in the content pack.")
        }
        return reference
    }

    static func loadQuestionBank(includeDraftContent: Bool = false) -> [QuizQuestion] {
        guard let pack = try? WattWiseContentCatalog.loadFromBundle() else { return [] }
        return pack.questionBank
            .filter { includeDraftContent || $0.verification.publishStatus == .published }
            .map { record in
            let topicTag = record.topicCategory
                .lowercased()
                .replacingOccurrences(of: " and ", with: "-")
                .replacingOccurrences(of: " ", with: "-")
            return QuizQuestion(
                id: uuid(for: "question:\(record.id)"),
                question: record.questionText,
                choices: record.answerChoices,
                correctChoice: record.correctAnswer,
                explanation: record.explanation,
                topics: [topicTag],
                topicTitles: [record.topicCategory],
                difficultyLevel: record.difficultyLevel,
                referenceCode: record.necReference,
                certificationLevel: record.certificationLevel
            )
        }
    }

    static func uuid(for key: String) -> UUID {
        let digest = SHA256.hash(data: Data(key.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        let uuidString = bytes.enumerated().map { index, byte -> String in
            let prefix = [4, 6, 8, 10].contains(index) ? "-" : ""
            return "\(prefix)\(String(format: "%02x", byte))"
        }.joined()

        return UUID(uuidString: uuidString) ?? UUID()
    }

    private static func lessonMap(from pack: WattWiseContentPack, includeDraftContent: Bool) -> [UUID: WWLesson] {
        let lessons: [WWLesson] = pack.fullLessonContent.flatMap { record in
            guard includeDraftContent || record.verification.publishStatus == .published else { return [WWLesson]() }
            let moduleId = "module:\(record.certificationLevel.lowercased())-\(record.moduleName.lowercased().replacingOccurrences(of: " ", with: "-"))"
            let totalParts = partCountForLesson(record)
            return (1...totalParts).compactMap { partNumber in
                try? makeLessonFromRecord(record: record, moduleId: moduleId, partNumber: partNumber, totalParts: totalParts)
            }
        }
        return Dictionary(uniqueKeysWithValues: lessons.map { ($0.id, $0) })
    }

    // Determine how many parts to split a lesson into (1 = no split, 2-3 = mini-lessons)
    private static func partCountForLesson(_ record: LessonContentRecord) -> Int {
        let contentParagraphs = record.lessonContent.count
        // Split into 2-3 parts based on content length: <5 paragraphs = 1 part, 5-10 = 2 parts, >10 = 3 parts
        if contentParagraphs <= 4 {
            return 1
        } else if contentParagraphs <= 10 {
            return 2
        } else {
            return 3
        }
    }

    // Split lesson content into parts for mini-lessons
    private static func partitionContent(from record: LessonContentRecord, partNumber: Int, totalParts: Int) -> [LessonParagraph] {
        guard totalParts > 1 else { return record.lessonContent }

        let contentCount = record.lessonContent.count
        let itemsPerPart = max(1, contentCount / totalParts)
        let startIndex = (partNumber - 1) * itemsPerPart
        let endIndex = partNumber == totalParts ? contentCount : min(partNumber * itemsPerPart, contentCount)

        return Array(record.lessonContent[startIndex..<endIndex])
    }

    // Primary lesson builder — derives all info directly from the lesson record.
    // If totalParts > 1, creates a mini-lesson for the specified partNumber.
    private static func makeLessonFromRecord(record: LessonContentRecord, moduleId: String, partNumber: Int = 1, totalParts: Int = 1) throws -> WWLesson {
        let moduleUUID = uuid(for: moduleId)
        let lessonId = totalParts > 1
            ? uuid(for: "lesson:\(record.id):part-\(partNumber)")
            : uuid(for: "lesson:\(record.id)")
        let progress = progressState(for: record.id)

        let partitionedContent = partitionContent(from: record, partNumber: partNumber, totalParts: totalParts)
        let displayTitle = totalParts > 1 ? "\(record.lessonTitle) — Part \(partNumber) of \(totalParts)" : record.lessonTitle

        var sections = partitionedContent.enumerated().map { index, paragraph in
            LessonSection(
                id: uuid(for: "section:\(record.id):core:\(index)"),
                heading: paragraph.heading,
                body: paragraph.body,
                type: inferredSectionType(for: paragraph.heading),
                necCode: paragraph.necReferences.first
            )
        }

        sections.append(LessonSection(
            id: uuid(for: "section:\(record.id):takeaways-heading"),
            heading: nil,
            body: "Key Takeaways",
            type: .heading,
            necCode: nil
        ))

        sections.append(contentsOf: record.keyTakeaways.enumerated().map { index, takeaway in
            LessonSection(
                id: uuid(for: "section:\(record.id):takeaway:\(index)"),
                heading: nil,
                body: takeaway,
                type: .bullet,
                necCode: nil
            )
        })

        sections.append(LessonSection(
            id: uuid(for: "section:\(record.id):knowledge-heading"),
            heading: nil,
            body: "Knowledge Check",
            type: .heading,
            necCode: nil
        ))

        sections.append(contentsOf: record.practiceQuestions.enumerated().map { index, question in
            LessonSection(
                id: uuid(for: "section:\(record.id):question:\(index)"),
                heading: "Question \(index + 1)",
                body: question,
                type: .callout,
                necCode: nil
            )
        })

        let necReferences = uniqueLessonReferenceCodes(for: record).map { code in
            let entry = necCatalog[code] ?? (
                "NEC \(code)",
                "Simplified explanation for NEC \(code). Verify your jurisdiction's adopted code cycle and official wording."
            )
            return NECReference(
                id: uuid(for: "nec:\(code)"),
                code: code,
                title: entry.title,
                summary: entry.summary,
                expanded: MockData.necExpandedText[code],
                edition: record.verification.baseCodeCycle
            )
        }

        return WWLesson(
            id: lessonId,
            moduleId: moduleUUID,
            title: displayTitle,
            topic: record.moduleName,
            estimatedMinutes: totalParts > 1 ? max(5, estimateMinutes(for: record) / totalParts) : estimateMinutes(for: record),
            status: progress.status,
            completionPercentage: progress.completion,
            sections: sections,
            necReferences: necReferences,
            publishStatus: record.verification.publishStatus,
            freshnessStatus: record.verification.freshnessStatus,
            baseCodeCycle: record.verification.baseCodeCycle,
            jurisdictionScope: record.verification.jurisdictionScope,
            lastVerifiedAt: record.verification.lastVerifiedAt,
            disclaimer: record.verification.disclaimer,
            isLocked: nil,
            isPreviewIncluded: record.verification.publishStatus == .published && record.id == "ap-les-001",
            requiresPaidAccess: record.verification.publishStatus == .published && record.id != "ap-les-001",
            partNumber: totalParts > 1 ? partNumber : nil,
            totalParts: totalParts > 1 ? totalParts : nil,
            canonicalLessonID: totalParts > 1 ? record.id : nil
        )
    }

    private static func estimateMinutes(for record: LessonContentRecord) -> Int {
        record.estimatedMinutes
    }

    private static func allNECReferences(from pack: WattWiseContentPack) throws -> [NECReference] {
        Array(
            NSOrderedSet(array: pack.fullLessonContent.flatMap(uniqueLessonReferenceCodes(for:)))
        ).compactMap { $0 as? String }.map { code in
            let entry = necCatalog[code] ?? (
                "NEC \(code)",
                "Simplified explanation for NEC \(code). Verify your jurisdiction's adopted code cycle and official wording."
            )
            return NECReference(
                id: uuid(for: "nec:\(code)"),
                code: code,
                title: entry.title,
                summary: entry.summary,
                expanded: MockData.necExpandedText[code],
                edition: pack.fullLessonContent.first(where: { uniqueLessonReferenceCodes(for: $0).contains(code) })?.verification.baseCodeCycle
            )
        }
    }

    private static func uniqueNECReferences(from pack: WattWiseContentPack) throws -> [NECSearchResult] {
        try allNECReferences(from: pack).map {
            NECSearchResult(id: $0.id, code: $0.code, title: $0.title, summary: $0.summary, edition: $0.edition)
        }
    }

    private static func aggregateFreshness(for records: [LessonContentRecord]) -> ContentFreshnessStatus {
        let statuses = Set(records.map(\.verification.freshnessStatus))
        if statuses.contains(.conflicted) { return .conflicted }
        if statuses.contains(.stale) { return .stale }
        if statuses == [.fresh] { return .fresh }
        return .unknown
    }

    private static func inferredSectionType(for heading: String) -> LessonSection.SectionType {
        switch heading {
        case "Learning objective", "Practical example", "Exam insight":
            return .callout
        case "NEC / code relevance":
            return .necCallout
        case "Exam trap", "Common exam trap", "Exam traps", "Common exam traps",
             "Watch out", "Trap to avoid":
            return .examTrap
        default:
            return .paragraph
        }
    }

    private static func progressState(for canonicalLessonID: String) -> (status: WWLesson.LessonStatus, completion: Double) {
        let stored = storedProgressByLesson()[canonicalLessonID] ?? defaultStoredProgress(for: canonicalLessonID, now: Date())
        let completion = max(0, min(1, stored.completion))

        let status: WWLesson.LessonStatus
        if completion >= 1.0 {
            status = .completed
        } else if completion > 0 {
            status = .inProgress
        } else {
            status = .notStarted
        }

        return (status, completion)
    }

    private static func storedProgressByLesson() -> [String: StoredLessonProgress] {
        guard let data = UserDefaults.standard.data(forKey: progressStorageKey),
              let decoded = try? JSONDecoder().decode([String: StoredLessonProgress].self, from: data) else {
            let now = Date()
            return Dictionary(uniqueKeysWithValues: seededProgress.map {
                ($0.key, defaultStoredProgress(for: $0.key, completion: $0.value, now: now))
            })
        }

        var merged = decoded
        let now = Date()
        for (lessonID, completion) in seededProgress where merged[lessonID] == nil {
            merged[lessonID] = defaultStoredProgress(for: lessonID, completion: completion, now: now)
        }
        return merged
    }

    private static func persistProgress(_ progressByLesson: [String: StoredLessonProgress]) {
        guard let data = try? JSONEncoder().encode(progressByLesson) else { return }
        UserDefaults.standard.set(data, forKey: progressStorageKey)
    }

    /// Returns a dictionary of ISO-8601 date strings ("YYYY-MM-DD") to minutes studied.
    /// Used by ProfileView to render the study activity calendar.
    static func studyActivityByDate() -> [String: Int] {
        storedStudyActivity()
    }

    private static func storedStudyActivity() -> [String: Int] {
        guard let data = UserDefaults.standard.data(forKey: studyActivityStorageKey),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func persistStudyActivity(_ activity: [String: Int]) {
        guard let data = try? JSONEncoder().encode(activity) else { return }
        UserDefaults.standard.set(data, forKey: studyActivityStorageKey)
    }

    private static func defaultStoredProgress(for canonicalLessonID: String, completion: Double? = nil, now: Date) -> StoredLessonProgress {
        let value = max(0, min(1, completion ?? seededProgress[canonicalLessonID] ?? 0))
        return StoredLessonProgress(
            completion: value,
            lastAccessedAt: now,
            completedAt: value >= 1.0 ? now : nil
        )
    }

    private static func canonicalLessonID(for lessonUUID: UUID) -> String? {
        do {
            let pack = try WattWiseContentCatalog.loadFromBundle()
            return pack.fullLessonContent.first(where: { uuid(for: "lesson:\($0.id)") == lessonUUID })?.id
        } catch {
            return nil
        }
    }

    private static func isoDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }
}
