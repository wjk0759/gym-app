import XCTest
import UIKit
@testable import FitAI

final class BodyFigureAssetTests: XCTestCase {
    func testEveryAvailableTypeHasRepresentativeFigure() {
        for sex in [Sex.female, Sex.male] {
            for type in BodyType.options(for: sex) {
                XCTAssertNotNil(
                    BodyFigureAsset.comboName(
                        type: type,
                        sex: sex,
                        fatOptionID: nil
                    ),
                    "\(sex) \(type) is missing a representative figure"
                )
            }
        }
    }

    func testEveryTypeAndFatOptionHasACombinedFigure() {
        for sex in [Sex.female, Sex.male] {
            for type in BodyType.options(for: sex) {
                for option in BodyFatOption.options(for: sex) {
                    let name = BodyFigureAsset.comboName(
                        type: type,
                        sex: sex,
                        fatOptionID: option.id
                    )
                    XCTAssertNotNil(
                        name,
                        "\(sex) \(type) \(option.id) is missing a figure"
                    )
                    if let name {
                        XCTAssertNotNil(
                            UIImage(named: name),
                            "\(name) is missing from the asset catalog"
                        )
                    }
                }
            }
        }
    }

    func testGenderAssetsExist() {
        for name in [
            "GenderMale",
            "GenderFemale",
            "GenderMalePortrait",
            "GenderFemalePortrait"
        ] {
            XCTAssertNotNil(
                UIImage(named: name),
                "\(name) is missing from the asset catalog"
            )
        }
    }

    func testCombinedAssetNameUsesTypeAndFatTokens() {
        XCTAssertEqual(
            BodyFigureAsset.comboName(
                type: .pear,
                sex: .female,
                fatOptionID: "female_23_28"
            ),
            "BodyFigureFemalePearFat23To28"
        )
        XCTAssertEqual(
            BodyFigureAsset.comboName(
                type: .invertedTriangle,
                sex: .male,
                fatOptionID: "male_16_20"
            ),
            "BodyFigureMaleInvertedTriangleFat16To20"
        )
    }

    func testBodyFatRangesMatchReferenceImages() {
        XCTAssertEqual(
            BodyFatOption.female.map(\.label),
            ["< 15%", "15–18%", "19–22%", "23–28%", "29–34%", "> 34%"]
        )
        XCTAssertEqual(
            BodyFatOption.male.map(\.label),
            ["< 12%", "12–15%", "16–20%", "21–24%", "25–29%", "> 29%"]
        )
        XCTAssertEqual(BodyFatOption.female[3].midpoint, 25.5, accuracy: 0.01)
        XCTAssertEqual(BodyFatOption.male[3].midpoint, 22.5, accuracy: 0.01)
    }

    func testFocusDisplayOrderCoversEveryArea() {
        XCTAssertEqual(
            Set(BodyFocusArea.displayOrder),
            Set(BodyFocusArea.allCases)
        )
        XCTAssertEqual(
            BodyFocusArea.displayOrder.count,
            BodyFocusArea.allCases.count
        )
    }
}
