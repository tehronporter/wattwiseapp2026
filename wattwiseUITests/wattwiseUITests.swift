//
//  wattwiseUITests.swift
//  wattwiseUITests
//
//  Created by User on 3/30/26.
//

import XCTest

final class wattwiseUITests: XCTestCase {

    private func launchAuthenticatedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_RESET_STATE", "UITEST_AUTHENTICATED"]
        app.launch()
        return app
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testHomeQuickQuizFromTodaysFocusLoadsQuizFlow() throws {
        let app = launchAuthenticatedApp()

        XCTAssertTrue(app.buttons["Start Quick Quiz"].waitForExistence(timeout: 5))
        app.buttons["Start Quick Quiz"].tap()

        let quizTitle = app.navigationBars["Quick Quiz"]
        XCTAssertTrue(quizTitle.waitForExistence(timeout: 5))

        let loading = app.staticTexts["Preparing your quiz…"]
        let nextButton = app.buttons["Next"]
        let submitButton = app.buttons["Submit"]
        XCTAssertTrue(
            loading.waitForExistence(timeout: 2) ||
            nextButton.waitForExistence(timeout: 5) ||
            submitButton.waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testResumeLessonOpensLessonContent() throws {
        let app = launchAuthenticatedApp()

        XCTAssertTrue(app.buttons["Resume Lesson"].waitForExistence(timeout: 5))
        app.buttons["Resume Lesson"].tap()

        XCTAssertTrue(app.buttons["Ask Tutor"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Reading Progress"].exists)
    }

    @MainActor
    func testLockedFullPracticeExamShowsPaywall() throws {
        let app = launchAuthenticatedApp()

        app.tabBars.buttons["Practice"].tap()
        XCTAssertTrue(app.staticTexts["Practice"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.staticTexts["Full Practice Exam"].waitForExistence(timeout: 5))
        app.staticTexts["Full Practice Exam"].tap()

        XCTAssertTrue(app.staticTexts["Study with more confidence"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Start Full Prep"].exists)
        XCTAssertFalse(app.buttons["Subscribe"].exists)
    }

    @MainActor
    func testPreviewAccessCardAppearsOnHome() throws {
        let app = launchAuthenticatedApp()

        XCTAssertTrue(app.staticTexts["Preview Access"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["See Full Access Options"].exists)
    }
}
