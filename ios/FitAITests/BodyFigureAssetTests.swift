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

    func testCombinedFiguresShareTheCropCanvas() {
        for sex in [Sex.female, Sex.male] {
            for type in BodyType.options(for: sex) {
                for option in BodyFatOption.options(for: sex) {
                    let name = BodyFigureAsset.comboName(
                        type: type,
                        sex: sex,
                        fatOptionID: option.id
                    )
                    guard let name, let image = UIImage(named: name)?.cgImage else {
                        XCTFail("\(sex) \(type) \(option.id) is missing a figure")
                        continue
                    }
                    XCTAssertEqual(image.width, 400, "\(name) width changed")
                    XCTAssertEqual(image.height, 667, "\(name) height changed")
                }
            }
        }
    }

    func testTorsoCropStaysInsideTheCanvas() {
        let rect = BodyFigureCrop.torso.normalizedRect
        XCTAssertGreaterThan(rect.width, 0)
        XCTAssertGreaterThan(rect.height, 0)
        XCTAssertGreaterThanOrEqual(rect.minX, 0)
        XCTAssertGreaterThanOrEqual(rect.minY, 0)
        XCTAssertLessThanOrEqual(rect.maxX, 1)
        XCTAssertLessThanOrEqual(rect.maxY, 1)
        XCTAssertGreaterThan(
            rect.width * 400 / (rect.height * 667),
            0.75,
            "The torso crop should not collapse into a narrow sliver"
        )
    }

    func testTorsoCropKeepsTheBodyOpaque() {
        for name in [
            "BodyFigureMaleInvertedTriangleFat16To20",
            "BodyFigureFemaleHourglassFat19To22"
        ] {
            guard let image = UIImage(named: name),
                  let map = alphaChannel(of: image) else {
                XCTFail("\(name) is missing or could not be decoded")
                continue
            }
            let rect = BodyFigureCrop.torso.normalizedRect
            let x = Int(Double(map.width) * Double(rect.midX))
            let y = Int(Double(map.height) * Double(rect.midY))
            XCTAssertGreaterThan(
                map.alpha[y * map.width + x],
                200,
                "\(name) torso crop landed on a transparent pixel"
            )
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

    func testGenderAssetsHaveTransparentBackground() {
        // Arm/torso gaps stay transparent instead of showing the source white.
        let fullFigures: [String: (x: Double, y: Double)] = [
            "GenderMale": (0.25, 0.633),
            "GenderFemale": (0.69, 0.633)
        ]

        for name in [
            "GenderMale",
            "GenderFemale",
            "GenderMalePortrait",
            "GenderFemalePortrait"
        ] {
            guard let image = UIImage(named: name),
                  let map = alphaChannel(of: image) else {
                XCTFail("\(name) is missing or could not be decoded")
                continue
            }

            let corners = [
                (2, 2),
                (map.width - 3, 2),
                (2, map.height - 3),
                (map.width - 3, map.height - 3)
            ]
            for (x, y) in corners {
                XCTAssertEqual(
                    map.alpha[y * map.width + x],
                    0,
                    "\(name) has an opaque corner at \(x),\(y)"
                )
            }

            guard let gap = fullFigures[name] else { continue }
            let gapX = Int(Double(map.width) * gap.x)
            let gapY = Int(Double(map.height) * gap.y)
            XCTAssertEqual(
                map.alpha[gapY * map.width + gapX],
                0,
                "\(name) still has an opaque background in the arm gap"
            )
            XCTAssertGreaterThan(
                map.alpha[gapY * map.width + map.width / 2],
                200,
                "\(name) lost the torso while removing the background"
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

    /// Renders the image into an RGBA buffer so tests can inspect alpha values.
    private func alphaChannel(
        of image: UIImage
    ) -> (width: Int, height: Int, alpha: [UInt8])? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        var rendered = false

        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }

            // Flip so row 0 is the top of the image, matching asset coordinates.
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.draw(
                cgImage,
                in: CGRect(x: 0, y: 0, width: width, height: height)
            )
            rendered = true
        }

        guard rendered else { return nil }

        var alpha = [UInt8](repeating: 0, count: width * height)
        for index in 0..<(width * height) {
            alpha[index] = pixels[index * 4 + 3]
        }
        return (width, height, alpha)
    }
}
