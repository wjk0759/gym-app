import XCTest

final class NavigationPerformanceTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSwitchingTabsReturnsToSectionRoot() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FITAI_QA_BYPASS_AUTH"] = "1"
        app.launch()

        let recordTab = app.tabBars.buttons["记录"]
        XCTAssertTrue(recordTab.waitForExistence(timeout: 10))
        recordTab.tap()

        // 训练记录 is a pushed page that keeps the tab bar visible, so the
        // cross-tab reset behavior can still be exercised. Settings now hides
        // the tab bar by design, so it can no longer be used here.
        let historyButton = app.buttons["训练记录"].firstMatch
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5))
        historyButton.tap()

        let historyBar = app.navigationBars["训练记录"]
        XCTAssertTrue(historyBar.waitForExistence(timeout: 5))

        app.tabBars.buttons["今日"].tap()
        recordTab.tap()

        XCTAssertTrue(app.staticTexts["训练手账"].waitForExistence(timeout: 5))
        XCTAssertFalse(historyBar.exists)
    }

    func testTappingCurrentTabReturnsToSectionRoot() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FITAI_QA_BYPASS_AUTH"] = "1"
        app.launch()

        let recordTab = app.tabBars.buttons["记录"]
        XCTAssertTrue(recordTab.waitForExistence(timeout: 10))
        recordTab.tap()

        let historyButton = app.buttons["训练记录"].firstMatch
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5))
        historyButton.tap()

        let historyBar = app.navigationBars["训练记录"]
        XCTAssertTrue(historyBar.waitForExistence(timeout: 5))

        recordTab.tap()

        XCTAssertTrue(app.staticTexts["训练手账"].waitForExistence(timeout: 5))
        XCTAssertFalse(historyBar.exists)
    }

    func testProgressNavigationPerformance() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FITAI_QA_BYPASS_AUTH"] = "1"
        app.launchEnvironment["FITAI_QA_FRAME_LOG"] = "1"
        app.launch()

        let recordTab = app.tabBars.buttons["记录"]
        XCTAssertTrue(recordTab.waitForExistence(timeout: 10))
        recordTab.tap()

        let progressTile = app.buttons["变化"]
        XCTAssertTrue(progressTile.waitForExistence(timeout: 10))

        measure(
            metrics: [
                XCTClockMetric(),
                XCTCPUMetric(application: app),
                XCTMemoryMetric(application: app),
                XCTOSSignpostMetric.navigationTransitionMetric
            ]
        ) {
            progressTile.tap()

            let progressBar = app.navigationBars["变化"]
            XCTAssertTrue(progressBar.waitForExistence(timeout: 5))

            let backButton = progressBar.buttons.firstMatch
            XCTAssertTrue(backButton.waitForExistence(timeout: 2))
            backButton.tap()
            XCTAssertTrue(recordTab.waitForExistence(timeout: 5))
        }
    }
}
