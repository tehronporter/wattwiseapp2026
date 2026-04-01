//
//  wattwiseTests.swift
//  wattwiseTests
//
//  Created by User on 3/30/26.
//

import Testing
import Foundation
@testable import wattwise

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

}
