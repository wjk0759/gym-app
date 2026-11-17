import XCTest

final class TabBarClearanceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FITAI_QA_BYPASS_AUTH"] = "1"
        app.launch()
        return app
    }

    /// The floating tab bar must not cover the first-screen quick actions.
    func testTodayQuickActionsStayAboveTabBar() throws {
        let app = launchApp()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        let quickAction = app.buttons["记录身体"].firstMatch
        XCTAssertTrue(quickAction.waitForExistence(timeout: 8))
        XCTAssertTrue(quickAction.isHittable)
        XCTAssertLessThanOrEqual(
            quickAction.frame.maxY,
            tabBar.frame.minY + 0.5,
            "quick action must end above the tab bar"
        )
    }

    /// Pushed pages hide the tab bar instead of relying on bottom padding.
    func testPushedEquipmentLibraryHidesTabBar() throws {
        let app = launchApp()
        let discover = app.tabBars.buttons["发现"]
        XCTAssertTrue(discover.waitForExistence(timeout: 10))
        discover.tap()

        let openLibrary = app.buttons["打开我的器械库"].firstMatch
        XCTAssertTrue(openLibrary.waitForExistence(timeout: 8))
        openLibrary.tap()

        XCTAssertTrue(
            app.navigationBars["器械库"].waitForExistence(timeout: 8)
        )
        XCTAssertFalse(app.tabBars.firstMatch.exists)
    }
}
