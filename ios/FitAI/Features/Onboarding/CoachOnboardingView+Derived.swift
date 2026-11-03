import SwiftUI

extension CoachOnboardingView {
    // MARK: - Derived values

    var bmr: Int {
        let base = 10 * draft.weightKG + 6.25 * draft.heightCM - 5 * Double(draft.age)
        return Int((base + (draft.sex == .male ? 5 : -161)).rounded())
    }

    var recommendedGoal: GoalType {
        if draft.bmi >= 27 || draft.bodyFatPCT >= 30 { return .loseFat }
        if draft.bmi < 20 { return .buildMuscle }
        if bodyType == .invertedTriangle || bodyType == .rectangle || bodyType == .trapezoid {
            return .buildMuscle
        }
        return .recomp
    }

    var selectedBodyFatOption: BodyFatOption? {
        guard let bodyFatID else { return nil }
        return BodyFatOption.options(for: draft.sex).first { $0.id == bodyFatID }
    }

    var recommendedBodyType: BodyType {
        if let bodyType, bodyType.isAvailable(for: draft.sex) { return bodyType }
        if draft.bmi >= 27 || draft.bodyFatPCT >= (draft.sex == .female ? 32 : 25) {
            return draft.sex == .female ? .apple : .oval
        }
        if draft.bmi < 20 { return .rectangle }
        return .rectangle
    }

    var recommendedFocus: Set<BodyFocusArea> {
        switch bodyType ?? .rectangle {
        case .apple: return [.core, .legs]
        case .pear: return [.glutes, .legs]
        case .invertedTriangle: return [.back, .shoulders]
        case .rectangle: return [.shoulders, .glutes]
        case .hourglass: return [.core, .glutes]
        case .oval: return [.core, .legs]
        case .trapezoid: return [.shoulders, .back]
        }
    }

    var injuryOptions: [String] {
        ["心脏病", "高血压", "腰部疼痛", "肩颈疼痛", "膝盖疼痛", "孕期/术后"]
    }

    func experienceDetail(_ item: Experience) -> String {
        switch item {
        case .beginner: return "还在学动作，先建立习惯"
        case .intermediate: return "练过一段时间，动作基本稳定"
        case .advanced: return "训练多年，能自己安排强度"
        }
    }

    func experienceSymbol(_ item: Experience) -> String {
        switch item {
        case .beginner: return "leaf.fill"
        case .intermediate: return "chart.line.uptrend.xyaxis"
        case .advanced: return "bolt.fill"
        }
    }

    func goalSymbol(_ goal: GoalType) -> String {
        switch goal {
        case .loseFat: return "flame.fill"
        case .buildMuscle: return "dumbbell.fill"
        case .recomp: return "arrow.triangle.2.circlepath"
        case .endurance: return "figure.run"
        }
    }
}
