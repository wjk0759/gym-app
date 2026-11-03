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
        case .invertedTriangle: return "倒三角"
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

    var shoulder: CGFloat {
        switch self {
        case .apple: return 0.92
        case .pear: return 0.74
        case .invertedTriangle: return 1.12
        case .rectangle: return 0.92
        case .hourglass: return 1.02
        case .oval: return 0.90
        case .trapezoid: return 1.06
        }
    }

    var waist: CGFloat {
        switch self {
        case .apple: return 1.00
        case .pear: return 0.82
        case .invertedTriangle: return 0.78
        case .rectangle: return 0.90
        case .hourglass: return 0.64
        case .oval: return 1.04
        case .trapezoid: return 0.94
        }
    }

    var hip: CGFloat {
        switch self {
        case .apple: return 0.94
        case .pear: return 1.12
        case .invertedTriangle: return 0.80
        case .rectangle: return 0.92
        case .hourglass: return 1.06
        case .oval: return 0.94
        case .trapezoid: return 0.92
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

struct BodySilhouette: View {
    var type: BodyType = .rectangle
    var sex: Sex = .male
    var fullness: CGFloat = 1
    var fill: Color = Theme.ink.opacity(0.12)
    var stroke: Color = Theme.ink.opacity(0.38)
    var lineWidth: CGFloat = 1.2

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let centerX = width * 0.5
            let shoulderY = height * 0.22
            let waistY = height * 0.47
            let hipY = height * 0.60
            let shoulderScale: CGFloat = sex == .female ? 0.94 : 1
            let waistScale: CGFloat = sex == .female ? 0.90 : 1
            let hipScale: CGFloat = sex == .female ? 1.06 : 1
            let shoulder = width * 0.5 * type.shoulder * fullness * shoulderScale
            let waist = width * 0.5 * type.waist * fullness * waistScale
            let hip = width * 0.5 * type.hip * fullness * hipScale

            ZStack {
                Circle()
                    .fill(fill)
                    .overlay(Circle().stroke(stroke, lineWidth: lineWidth))
                    .frame(width: width * 0.17, height: width * 0.17)
                    .position(x: centerX, y: height * 0.10)

                Path { path in
                    path.move(to: CGPoint(x: centerX - shoulder, y: shoulderY))
                    path.addQuadCurve(
                        to: CGPoint(x: centerX - waist, y: waistY),
                        control: CGPoint(x: centerX - shoulder * 0.80, y: (shoulderY + waistY) * 0.5)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: centerX - hip, y: hipY),
                        control: CGPoint(x: centerX - waist * 0.96, y: (waistY + hipY) * 0.5)
                    )
                    path.addLine(to: CGPoint(x: centerX + hip, y: hipY))
                    path.addQuadCurve(
                        to: CGPoint(x: centerX + waist, y: waistY),
                        control: CGPoint(x: centerX + waist * 0.96, y: (waistY + hipY) * 0.5)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: centerX + shoulder, y: shoulderY),
                        control: CGPoint(x: centerX + shoulder * 0.80, y: (shoulderY + waistY) * 0.5)
                    )
                    path.closeSubpath()
                }
                .fill(fill)
                .overlay(
                    Path { path in
                        path.move(to: CGPoint(x: centerX - shoulder, y: shoulderY))
                        path.addQuadCurve(
                            to: CGPoint(x: centerX - waist, y: waistY),
                            control: CGPoint(x: centerX - shoulder * 0.80, y: (shoulderY + waistY) * 0.5)
                        )
                        path.addQuadCurve(
                            to: CGPoint(x: centerX - hip, y: hipY),
                            control: CGPoint(x: centerX - waist * 0.96, y: (waistY + hipY) * 0.5)
                        )
                        path.addLine(to: CGPoint(x: centerX + hip, y: hipY))
                        path.addQuadCurve(
                            to: CGPoint(x: centerX + waist, y: waistY),
                            control: CGPoint(x: centerX + waist * 0.96, y: (waistY + hipY) * 0.5)
                        )
                        path.addQuadCurve(
                            to: CGPoint(x: centerX + shoulder, y: shoulderY),
                            control: CGPoint(x: centerX + shoulder * 0.80, y: (shoulderY + waistY) * 0.5)
                        )
                        path.closeSubpath()
                    }
                    .stroke(stroke, lineWidth: lineWidth)
                )

                arm(width: width, height: height, centerX: centerX, shoulder: shoulder, side: -1, fill: fill, stroke: stroke)
                arm(width: width, height: height, centerX: centerX, shoulder: shoulder, side: 1, fill: fill, stroke: stroke)

                leg(width: width, height: height, centerX: centerX, hip: hip, side: -1, fill: fill, stroke: stroke)
                leg(width: width, height: height, centerX: centerX, hip: hip, side: 1, fill: fill, stroke: stroke)
            }
        }
        .accessibilityHidden(true)
    }

    private func arm(
        width: CGFloat,
        height: CGFloat,
        centerX: CGFloat,
        shoulder: CGFloat,
        side: CGFloat,
        fill: Color,
        stroke: Color
    ) -> some View {
        RoundedRectangle(cornerRadius: width * 0.045, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.045, style: .continuous)
                    .stroke(stroke, lineWidth: lineWidth)
            )
            .frame(width: width * 0.085, height: height * 0.34)
            .rotationEffect(.degrees(side * 8))
            .position(
                x: centerX + side * (shoulder + width * 0.035),
                y: height * 0.38
            )
    }

    private func leg(
        width: CGFloat,
        height: CGFloat,
        centerX: CGFloat,
        hip: CGFloat,
        side: CGFloat,
        fill: Color,
        stroke: Color
    ) -> some View {
        RoundedRectangle(cornerRadius: width * 0.055, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.055, style: .continuous)
                    .stroke(stroke, lineWidth: lineWidth)
            )
            .frame(width: width * 0.115, height: height * 0.43)
            .position(
                x: centerX + side * hip * 0.42,
                y: height * 0.78
            )
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

/// Renders the 3D body figure for a type and, when available, a body-fat band.
/// Falls back to the vector silhouette if an asset is ever removed.
struct BodyFigure: View {
    let type: BodyType
    var sex: Sex = .male
    var fatOptionID: String? = nil

    var body: some View {
        if let name = BodyFigureAsset.comboName(type: type, sex: sex, fatOptionID: fatOptionID),
           UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        } else {
            BodySilhouette(
                type: type,
                sex: sex,
                fullness: fallbackFullness,
                fill: Theme.ink.opacity(0.055),
                stroke: Theme.ink.opacity(0.28),
                lineWidth: 1
            )
        }
    }

    private var fallbackFullness: CGFloat {
        guard let fatOptionID,
              let option = BodyFatOption.options(for: sex).first(where: { $0.id == fatOptionID }) else {
            return 1
        }
        return option.fullness
    }
}

// MARK: - Body type picker

struct BodyTypeCard: View {
    let type: BodyType
    var sex: Sex = .male
    let selected: Bool
    var recommended: Bool = false
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    BodyFigure(
                        type: type,
                        sex: sex
                    )
                    .frame(height: 136)
                    .padding(.horizontal, 8)

                    if recommended {
                        RecommendationBadge(text: "建议")
                    }
                }

                Text(type.label)
                    .font(AppType.callout.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text(type.detail)
                    .font(AppType.micro)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(selected ? Theme.cobalt.opacity(0.06) : Theme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Theme.cobalt : Theme.stroke, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
        .accessibilityLabel("\(type.label)，\(type.detail)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Body fat reference

struct BodyFatOption: Identifiable, Equatable {
    let id: String
    let label: String
    let range: ClosedRange<Double>
    let fullness: CGFloat
    let note: String
    let assetToken: String

    var midpoint: Double { (range.lowerBound + range.upperBound) / 2 }

    static let male: [BodyFatOption] = [
        .init(id: "male_under_12", label: "< 12%", range: 8...11, fullness: 0.84, note: "很精瘦", assetToken: "Under12"),
        .init(id: "male_12_15", label: "12–15%", range: 12...15, fullness: 0.90, note: "偏瘦有线条", assetToken: "12To15"),
        .init(id: "male_16_20", label: "16–20%", range: 16...20, fullness: 0.98, note: "匀称", assetToken: "16To20"),
        .init(id: "male_21_24", label: "21–24%", range: 21...24, fullness: 1.06, note: "常见范围", assetToken: "21To24"),
        .init(id: "male_25_29", label: "25–29%", range: 25...29, fullness: 1.14, note: "偏丰满", assetToken: "25To29"),
        .init(id: "male_over_29", label: "> 29%", range: 30...40, fullness: 1.22, note: "体脂偏高", assetToken: "Over29")
    ]

    static let female: [BodyFatOption] = [
        .init(id: "female_under_15", label: "< 15%", range: 10...14, fullness: 0.86, note: "很精瘦", assetToken: "Under15"),
        .init(id: "female_15_18", label: "15–18%", range: 15...18, fullness: 0.92, note: "偏瘦有线条", assetToken: "15To18"),
        .init(id: "female_19_22", label: "19–22%", range: 19...22, fullness: 0.98, note: "匀称", assetToken: "19To22"),
        .init(id: "female_23_28", label: "23–28%", range: 23...28, fullness: 1.06, note: "常见范围", assetToken: "23To28"),
        .init(id: "female_29_34", label: "29–34%", range: 29...34, fullness: 1.14, note: "偏丰满", assetToken: "29To34"),
        .init(id: "female_over_34", label: "> 34%", range: 35...45, fullness: 1.22, note: "体脂偏高", assetToken: "Over34")
    ]

    static func options(for sex: Sex) -> [BodyFatOption] {
        sex == .female ? female : male
    }
}

struct BodyFatCard: View {
    let option: BodyFatOption
    var type: BodyType = .rectangle
    var sex: Sex = .male
    let selected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            VStack(spacing: 6) {
                BodyFigure(
                    type: type,
                    sex: sex,
                    fatOptionID: option.id
                )
                .frame(height: 104)
                .padding(.horizontal, 6)

                Text(option.label)
                    .font(AppType.caption.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(option.note)
                    .font(AppType.micro)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .padding(.horizontal, 6)
            .background(selected ? Theme.lime.opacity(0.18) : Theme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? Theme.ink : Theme.stroke, lineWidth: selected ? 1.6 : 1)
            }
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
        .accessibilityLabel("\(type.label)，体脂 \(option.label)，\(option.note)")
        .accessibilityAddTraits(selected ? .isSelected : [])
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

    var position: UnitPoint {
        switch self {
        case .shoulders: return UnitPoint(x: 0.50, y: 0.20)
        case .chest: return UnitPoint(x: 0.50, y: 0.31)
        case .arms: return UnitPoint(x: 0.18, y: 0.38)
        case .core: return UnitPoint(x: 0.50, y: 0.47)
        case .glutes: return UnitPoint(x: 0.50, y: 0.60)
        case .legs: return UnitPoint(x: 0.50, y: 0.78)
        case .back: return UnitPoint(x: 0.82, y: 0.32)
        }
    }
}

struct BodyFocusMap: View {
    @Binding var selected: Set<BodyFocusArea>
    var sex: Sex = .male
    var recommended: Set<BodyFocusArea> = []
    var maxSelection: Int = 2

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Theme.ink.opacity(0.035))
                    BodySilhouette(
                        type: .rectangle,
                        sex: sex,
                        fill: Theme.ink.opacity(0.08),
                        stroke: Theme.ink.opacity(0.22),
                        lineWidth: 1
                    )
                    .padding(16)

                    ForEach(BodyFocusArea.allCases) { area in
                        focusDot(area)
                            .position(
                                x: geo.size.width * area.position.x,
                                y: geo.size.height * area.position.y
                            )
                    }
                }
            }
            .frame(height: 310)

            Text("最多选 \(maxSelection) 个，计划会优先安排这些部位")
                .font(AppType.micro)
                .foregroundStyle(Theme.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func focusDot(_ area: BodyFocusArea) -> some View {
        let isSelected = selected.contains(area)
        let isRecommended = recommended.contains(area) && !isSelected
        return Button {
            if isSelected {
                Haptics.select()
                selected.remove(area)
            } else if selected.count < maxSelection {
                Haptics.select()
                selected.insert(area)
            } else {
                Haptics.warning()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isSelected ? "checkmark" : area.symbol)
                    .font(.system(size: 9, weight: .bold))
                Text(area.label)
                    .font(AppType.micro)
            }
            .foregroundStyle(isSelected ? Theme.onAccent : Theme.ink.opacity(0.72))
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                isSelected ? Theme.lime : (isRecommended ? Theme.lime.opacity(0.30) : Theme.paper),
                in: Capsule(style: .continuous)
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        isSelected ? Theme.ink : Theme.ink.opacity(isRecommended ? 0.28 : 0.18),
                        lineWidth: isSelected ? 1.2 : 0.8
                    )
            }
        }
        .buttonStyle(SubtlePressStyle(scale: 0.94))
        .accessibilityLabel(area.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
