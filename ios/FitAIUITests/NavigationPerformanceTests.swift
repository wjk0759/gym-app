import XCTest

final class NavigationPerformanceTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
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
