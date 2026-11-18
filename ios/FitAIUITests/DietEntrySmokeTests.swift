import XCTest

final class DietEntrySmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testDietEntryScreensOpenWithoutCrash() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FITAI_QA_BYPASS_AUTH"] = "1"
        app.launch()

        let dietEntry = app.staticTexts["今日饮食"].firstMatch
        XCTAssertTrue(dietEntry.waitForExistence(timeout: 10))
        dietEntry.tap()

        XCTAssertTrue(app.navigationBars["今日饮食"].waitForExistence(timeout: 5))

        let weekPlan = app.staticTexts["本周计划"].firstMatch
        XCTAssertTrue(weekPlan.waitForExistence(timeout: 5))
        weekPlan.tap()
        XCTAssertTrue(app.navigationBars["本周饮食计划"].waitForExistence(timeout: 5))
        app.buttons["关闭"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["今日饮食"].waitForExistence(timeout: 5))

        let addFood = app.staticTexts["记一笔"].firstMatch
        XCTAssertTrue(addFood.waitForExistence(timeout: 5))
        addFood.tap()
        XCTAssertTrue(app.navigationBars["记录食物"].waitForExistence(timeout: 5))
        app.buttons["取消"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["今日饮食"].waitForExistence(timeout: 5))

        let backButton = app.navigationBars["今日饮食"].buttons.firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()

        XCTAssertTrue(app.tabBars.buttons["发现"].waitForExistence(timeout: 5))
        app.tabBars.buttons["发现"].tap()
        let dietLibrary = app.staticTexts["饮食方案"].firstMatch
        XCTAssertTrue(dietLibrary.waitForExistence(timeout: 5))
        dietLibrary.tap()
        XCTAssertTrue(app.navigationBars["饮食方案"].waitForExistence(timeout: 5))
        app.buttons["关闭"].firstMatch.tap()
    }
}
