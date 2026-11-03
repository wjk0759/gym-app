import XCTest
import UIKit
@testable import FitAI

final class BrandAssetTests: XCTestCase {
    func testBrandLogoExistsAndIsSquare() {
        guard let image = UIImage(named: "BrandLogo") else {
            XCTFail("BrandLogo is missing from the asset catalog")
            return
        }
        XCTAssertEqual(image.size.width, image.size.height, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(image.size.width, 256)
    }
}
