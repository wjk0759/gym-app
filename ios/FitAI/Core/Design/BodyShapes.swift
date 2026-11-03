import SwiftUI
import UIKit

// MARK: - Body type

enum BodyType: String, CaseIterable, Identifiable {
    case apple
    case pear
    case invertedTriangle
    case rectangle
    case hourglass
    case oval
    case trapezoid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .apple: return "苹果型"
        case .pear: return "梨型"
        case .invertedTriangle: return "倒三角型"
        case .rectangle: return "直筒型"
        case .hourglass: return "沙漏型"
        case .oval: return "椭圆型"
        case .trapezoid: return "梯形"
        }
    }

    var detail: String {
        switch self {
        case .apple: return "腰腹更集中，四肢相对细"
        case .pear: return "臀腿更丰满，肩背偏窄"
        case .invertedTriangle: return "肩背更宽，臀腿偏窄"
        case .rectangle: return "肩腰臀接近，线条偏直"
        case .hourglass: return "肩臀同宽，腰部相对纤细"
        case .oval: return "腰腹更集中，肩背相对窄"
        case .trapezoid: return "肩宽腰粗，整体厚实"
        }
    }

    var recommendedGoal: GoalType {
        switch self {
        case .apple: return .recomp
        case .pear: return .recomp
        case .invertedTriangle: return .buildMuscle
        case .rectangle: return .buildMuscle
        case .hourglass: return .recomp
        case .oval: return .recomp
        case .trapezoid: return .buildMuscle
        }
    }

    /// Male and female body-shape vocabularies are intentionally different.
    /// Female users get apple/pear/hourglass; male users get oval/trapezoid
    /// instead of the female-coded shapes. Inverted triangle and rectangle are
    /// shared because both reference sets include them.
    static func options(for sex: Sex) -> [BodyType] {
        switch sex {
        case .female:
            return [.apple, .pear, .invertedTriangle, .hourglass, .rectangle]
        case .male:
            return [.invertedTriangle, .rectangle, .oval, .trapezoid]
        }
    }

    func isAvailable(for sex: Sex) -> Bool {
        Self.options(for: sex).contains(self)
    }
}

// MARK: - Body figure assets

enum BodyFigureAsset {
    /// The type picker uses a representative mid-range figure so the pose and
    /// clothing stay consistent with the fat picker/report images.
    static func representativeFatID(for sex: Sex) -> String {
        sex == .female ? "female_19_22" : "male_16_20"
    }

    static func comboName(
        type: BodyType,
        sex: Sex,
        fatOptionID: String?
    ) -> String? {
        guard type.isAvailable(for: sex) else { return nil }
        let fatID = fatOptionID ?? representativeFatID(for: sex)
        guard let option = BodyFatOption.options(for: sex).first(where: { $0.id == fatID }) else {
            return nil
        }
        let token = type.rawValue.prefix(1).uppercased() + String(type.rawValue.dropFirst())
        let sexToken = sex == .female ? "Female" : "Male"
        return "BodyFigure\(sexToken)\(token)Fat\(option.assetToken)"
    }
}

/// Selects how much of the shared 400×667 figure canvas is shown.
enum BodyFigureCrop {
    case fullBody
    case torso

    /// Normalized rect inside the shared figure canvas. Kept in sync with the
    /// asset pipeline: every combo figure is 400×667 with the same pose.
    var normalizedRect: CGRect {
        switch self {
        case .fullBody:
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        case .torso:
            return CGRect(x: 0.215, y: 0.142, width: 0.570, height: 0.398)
        }
    }
}

/// Renders the 3D body figure for a type and, when available, a body-fat band.
/// Falls back to a neutral SF Symbol if an asset is ever removed.
struct BodyFigure: View {
    let type: BodyType
    var sex: Sex = .male
    var fatOptionID: String? = nil
    var crop: BodyFigureCrop = .fullBody

    var body: some View {
        if let name = BodyFigureAsset.comboName(type: type, sex: sex, fatOptionID: fatOptionID),
           UIImage(named: name) != nil {
            switch crop {
            case .fullBody:
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .accessibilityHidden(true)
            case .torso:
                BodyFigureTorso(name: name)
                    .accessibilityHidden(true)
            }
        } else {
            Image(systemName: "figure.stand")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(Theme.tertiaryText)
        }
    }
}

/// Crops the shared 400×667 canvas to the shoulders-to-hips torso.
private struct BodyFigureTorso: View {
    let name: String

    var body: some View {
        let rect = BodyFigureCrop.torso.normalizedRect
        Color.clear
            .aspectRatio(
                rect.width * 400 / (rect.height * 667),
                contentMode: .fit
            )
            .overlay {
                GeometryReader { geo in
                    let renderedWidth = geo.size.width / rect.width
                    let renderedHeight = renderedWidth * 667 / 400
                    Image(name)
                        .resizable()
                        .frame(width: renderedWidth, height: renderedHeight)
                        .offset(
                            x: -rect.minX * renderedWidth,
                            y: -rect.minY * renderedHeight
                        )
                }
            }
            .clipped()
    }
}

// MARK: - Body fat reference

struct BodyFatOption: Identifiable, Equatable {
    let id: String
    let label: String
    let range: ClosedRange<Double>
    let note: String
    let assetToken: String

    var midpoint: Double { (range.lowerBound + range.upperBound) / 2 }

    static let male: [BodyFatOption] = [
        .init(id: "male_under_12", label: "< 12%", range: 8...11, note: "很精瘦", assetToken: "Under12"),
        .init(id: "male_12_15", label: "12–15%", range: 12...15, note: "偏瘦有线条", assetToken: "12To15"),
        .init(id: "male_16_20", label: "16–20%", range: 16...20, note: "匀称", assetToken: "16To20"),
        .init(id: "male_21_24", label: "21–24%", range: 21...24, note: "常见范围", assetToken: "21To24"),
        .init(id: "male_25_29", label: "25–29%", range: 25...29, note: "偏丰满", assetToken: "25To29"),
        .init(id: "male_over_29", label: "> 29%", range: 30...40, note: "体脂偏高", assetToken: "Over29")
    ]

    static let female: [BodyFatOption] = [
        .init(id: "female_under_15", label: "< 15%", range: 10...14, note: "很精瘦", assetToken: "Under15"),
        .init(id: "female_15_18", label: "15–18%", range: 15...18, note: "偏瘦有线条", assetToken: "15To18"),
        .init(id: "female_19_22", label: "19–22%", range: 19...22, note: "匀称", assetToken: "19To22"),
        .init(id: "female_23_28", label: "23–28%", range: 23...28, note: "常见范围", assetToken: "23To28"),
        .init(id: "female_29_34", label: "29–34%", range: 29...34, note: "偏丰满", assetToken: "29To34"),
        .init(id: "female_over_34", label: "> 34%", range: 35...45, note: "体脂偏高", assetToken: "Over34")
    ]

    static func options(for sex: Sex) -> [BodyFatOption] {
        sex == .female ? female : male
    }
}

// MARK: - Focus map

enum BodyFocusArea: String, CaseIterable, Identifiable {
    case shoulders
    case chest
    case arms
    case core
    case glutes
    case legs
    case back

    var id: String { rawValue }

    static let displayOrder: [BodyFocusArea] = [
        .shoulders, .chest, .back, .arms, .core, .glutes, .legs
    ]

    var label: String {
        switch self {
        case .shoulders: return "肩部"
        case .chest: return "胸部"
        case .arms: return "手臂"
        case .core: return "腰腹"
        case .glutes: return "臀腿"
        case .legs: return "腿部"
        case .back: return "背部"
        }
    }

    var symbol: String {
        switch self {
        case .shoulders: return "figure.strengthtraining.functional"
        case .chest: return "heart.fill"
        case .arms: return "dumbbell.fill"
        case .core: return "circle.grid.cross"
        case .glutes: return "figure.walk"
        case .legs: return "figure.run"
        case .back: return "arrow.up.and.down"
        }
    }

}
