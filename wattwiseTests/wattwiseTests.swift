//
//  wattwiseTests.swift
//  wattwiseTests
//
//  Created by User on 3/30/26.
//

import Testing
import Foundation
@testable import wattwise

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

}
