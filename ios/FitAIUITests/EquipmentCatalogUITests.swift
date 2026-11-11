import XCTest

final class EquipmentCatalogUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCatalogBrowserAndDetail() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FITAI_QA_BYPASS_AUTH"] = "1"
        app.launchArguments += [
            "-fitai_api_base_url",
            "https://hk-api.jiaolianfit.cn/api/v1",
        ]
        app.launch()

        app.tabBars.buttons["发现"].tap()
        app.buttons["打开我的器械库"].tap()

        XCTAssertTrue(app.navigationBars["器械库"].waitForExistence(timeout: 8))

        let catalogButton = app.buttons["从器械库添加"].firstMatch
        if catalogButton.waitForExistence(timeout: 3) {
            catalogButton.tap()
        } else {
            app.buttons["添加器械"].tap()
            app.buttons["从器械库添加"].firstMatch.tap()
        }

        XCTAssertTrue(app.navigationBars["器械库"].waitForExistence(timeout: 8))
        let machine = app.staticTexts["坐姿推胸机"].firstMatch
        XCTAssertTrue(machine.waitForExistence(timeout: 8))
        attachScreenshot(named: "equipment-browser")
        machine.tap()

        XCTAssertTrue(app.navigationBars["坐姿推胸机"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["动作步骤"].firstMatch.waitForExistence(timeout: 8))
        attachScreenshot(named: "equipment-detail")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
