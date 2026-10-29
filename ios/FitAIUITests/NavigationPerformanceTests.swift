import XCTest

final class NavigationPerformanceTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testReviewNavigationPerformance() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FITAI_QA_BYPASS_AUTH"] = "1"
        app.launchEnvironment["FITAI_QA_FRAME_LOG"] = "1"
        app.launch()

        let recordTab = app.tabBars.buttons["记录"]
        XCTAssertTrue(recordTab.waitForExistence(timeout: 10))
        recordTab.tap()

        let reviewTile = app.buttons
            .matching(NSPredicate(format: "label CONTAINS '数据复盘'"))
            .firstMatch
        XCTAssertTrue(reviewTile.waitForExistence(timeout: 10))

        measure(
            metrics: [
                XCTClockMetric(),
                XCTCPUMetric(application: app),
                XCTMemoryMetric(application: app),
                XCTOSSignpostMetric.navigationTransitionMetric
            ]
        ) {
            reviewTile.tap()

            let reviewBar = app.navigationBars["数据复盘"]
            XCTAssertTrue(reviewBar.waitForExistence(timeout: 5))

            let backButton = reviewBar.buttons.firstMatch
            XCTAssertTrue(backButton.waitForExistence(timeout: 2))
            backButton.tap()
            XCTAssertTrue(recordTab.waitForExistence(timeout: 5))
        }
    }
}
