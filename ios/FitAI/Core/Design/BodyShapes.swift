import SwiftUI

// MARK: - Body type

enum BodyType: String, CaseIterable, Identifiable {
    case apple
    case pear
    case invertedTriangle
    case rectangle
    case hourglass

    var id: String { rawValue }

    var label: String {
        switch self {
        case .apple: return "苹果型"
        case .pear: return "梨型"
        case .invertedTriangle: return "倒三角"
        case .rectangle: return "直筒型"
        case .hourglass: return "沙漏型"
        }
    }

    var detail: String {
        switch self {
        case .apple: return "腰腹更集中，四肢相对细"
        case .pear: return "臀腿更丰满，肩背偏窄"
        case .invertedTriangle: return "肩背更宽，臀腿偏窄"
        case .rectangle: return "肩腰臀接近，线条偏直"
        case .hourglass: return "肩臀同宽，腰部相对纤细"
        }
    }

    var shoulder: CGFloat {
        switch self {
        case .apple: return 0.92
        case .pear: return 0.74
        case .invertedTriangle: return 1.12
        case .rectangle: return 0.92
        case .hourglass: return 1.02
        }
    }

    var waist: CGFloat {
        switch self {
        case .apple: return 1.00
        case .pear: return 0.82
        case .invertedTriangle: return 0.78
        case .rectangle: return 0.90
        case .hourglass: return 0.64
        }
    }

    var hip: CGFloat {
        switch self {
        case .apple: return 0.94
        case .pear: return 1.12
        case .invertedTriangle: return 0.80
        case .rectangle: return 0.92
        case .hourglass: return 1.06
        }
    }

    var recommendedGoal: GoalType {
        switch self {
        case .apple: return .recomp
        case .pear: return .recomp
        case .invertedTriangle: return .buildMuscle
        case .rectangle: return .buildMuscle
        case .hourglass: return .recomp
        }
    }
}

struct BodySilhouette: View {
    var type: BodyType = .rectangle
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
            let shoulder = width * 0.5 * type.shoulder * fullness
            let waist = width * 0.5 * type.waist * fullness
            let hip = width * 0.5 * type.hip * fullness

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

// MARK: - Body type picker

struct BodyTypeCard: View {
    let type: BodyType
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
                    BodySilhouette(
                        type: type,
                        fill: selected ? Theme.cobalt.opacity(0.16) : Theme.ink.opacity(0.055),
                        stroke: selected ? Theme.cobalt : Theme.ink.opacity(0.32),
                        lineWidth: selected ? 2 : 1
                    )
                    .frame(height: 118)
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

    var midpoint: Double { (range.lowerBound + range.upperBound) / 2 }

    static let all: [BodyFatOption] = [
        .init(id: "very_low", label: "< 15%", range: 10...15, fullness: 0.86, note: "很精瘦"),
        .init(id: "low", label: "15–18%", range: 15...18, fullness: 0.92, note: "偏瘦有线条"),
        .init(id: "athletic", label: "19–22%", range: 19...22, fullness: 0.98, note: "匀称"),
        .init(id: "average", label: "23–28%", range: 23...28, fullness: 1.06, note: "常见范围"),
        .init(id: "higher", label: "29–34%", range: 29...34, fullness: 1.14, note: "偏丰满"),
        .init(id: "high", label: "> 34%", range: 34...40, fullness: 1.22, note: "体脂偏高")
    ]
}

struct BodyFatCard: View {
    let option: BodyFatOption
    let selected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            VStack(spacing: 6) {
                BodySilhouette(
                    type: .rectangle,
                    fullness: option.fullness,
                    fill: selected ? Theme.lime.opacity(0.55) : Theme.ink.opacity(0.055),
                    stroke: selected ? Theme.ink : Theme.ink.opacity(0.28),
                    lineWidth: selected ? 1.6 : 1
                )
                .frame(height: 92)
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
        .accessibilityLabel("体脂 \(option.label)，\(option.note)")
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
    var recommended: Set<BodyFocusArea> = []

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Theme.ink.opacity(0.035))
                    BodySilhouette(
                        type: .rectangle,
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

            Text("选中的部位会记录在报告里，方便你和教练沟通")
                .font(AppType.micro)
                .foregroundStyle(Theme.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func focusDot(_ area: BodyFocusArea) -> some View {
        let isSelected = selected.contains(area)
        let isRecommended = recommended.contains(area) && !isSelected
        return Button {
            Haptics.select()
            if isSelected {
                selected.remove(area)
            } else {
                selected.insert(area)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isSelected ? "checkmark" : area.symbol)
                    .font(.system(size: 9, weight: .bold))
                Text(area.label)
                    .font(AppType.micro)
            }
            .foregroundStyle(isSelected ? Theme.ink : Theme.ink.opacity(0.72))
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
