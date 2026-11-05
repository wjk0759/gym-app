import XCTest

@testable import FitAI

final class AppConfigTests: XCTestCase {
    func testResolveAbsoluteMediaURL() {
        let url = AppConfig.resolveMediaURL("https://cdn.example.com/avatar.jpg")

        XCTAssertEqual(url?.absoluteString, "https://cdn.example.com/avatar.jpg")
    }

    func testResolveRelativeMediaURLAgainstAPIBase() {
        let url = AppConfig.resolveMediaURL("/media/avatars/a.jpg")

        XCTAssertEqual(url?.path, "/media/avatars/a.jpg")
        XCTAssertEqual(url?.host, AppConfig.apiBaseURL.host)
        XCTAssertEqual(url?.scheme, AppConfig.apiBaseURL.scheme)
    }

    func testResolveEmptyMediaURL() {
        XCTAssertNil(AppConfig.resolveMediaURL(nil))
        XCTAssertNil(AppConfig.resolveMediaURL("   "))
    }
}
