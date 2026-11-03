import Foundation

/// Server-authoritative Pro/trial snapshot. The client only renders this;
/// it must never be used as the sole gate for paid AI endpoints.
struct AccessSnapshot: Decodable, Equatable {
    struct Feature: Decodable, Equatable {
        let trialUsed: Bool?
        let trialAvailable: Bool?
        let trialSource: String?
        let trialUsedAt: Date?
        let canGenerate: Bool?
        let requiresPro: Bool?
        let weeklyLimit: Int?
        let used: Int?
        let remaining: Int?
        let resetAt: Date?
        let canSend: Bool?

        enum CodingKeys: String, CodingKey {
            case trialUsed = "trial_used"
            case trialAvailable = "trial_available"
            case trialSource = "trial_source"
            case trialUsedAt = "trial_used_at"
            case canGenerate = "can_generate"
            case requiresPro = "requires_pro"
            case weeklyLimit = "weekly_limit"
            case used
            case remaining
            case resetAt = "reset_at"
            case canSend = "can_send"
        }
    }

    let isPro: Bool
    let proExpiresAt: Date?
    let proSources: [String]
    let features: [String: Feature]

    enum CodingKeys: String, CodingKey {
        case isPro = "is_pro"
        case proExpiresAt = "pro_expires_at"
        case proSources = "pro_sources"
        case features
    }

    var trainingPlan: Feature? { features[ProFeature.trainingPlan.rawValue] }
    var mealPlan: Feature? { features[ProFeature.mealPlan.rawValue] }
    var coachAI: Feature? { features[ProFeature.coachAI.rawValue] }

    var mealPlanTrialAvailable: Bool {
        mealPlan?.trialAvailable == true
    }

    var coachRemaining: Int? {
        coachAI?.remaining
    }
}

enum ProFeature: String, Identifiable, CaseIterable {
    case trainingPlan = "training_plan"
    case mealPlan = "meal_plan"
    case coachAI = "coach_ai"
    case foodPhoto = "food_photo"
    case bodyPhoto = "body_photo"
    case videoReview = "video_review"
    case advancedReview = "advanced_review"
    case equipmentScan = "equipment_scan"
    case general = "general"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trainingPlan: return "训练计划"
        case .mealPlan: return "本周饮食计划"
        case .coachAI: return "AI 教练"
        case .foodPhoto: return "饮食拍照分析"
        case .bodyPhoto: return "身材拍照分析"
        case .videoReview: return "视频动作点评"
        case .advancedReview: return "数据复盘"
        case .equipmentScan: return "器械 AI 识别"
        case .general: return "叫练 Pro"
        }
    }

    var subtitle: String {
        switch self {
        case .trainingPlan: return "Pro 解锁重新生成、调整和下周期计划。"
        case .mealPlan: return "Pro 解锁每周重新生成和下周计划。"
        case .coachAI: return "Pro 解锁不限条数的 AI 教练对话。"
        case .foodPhoto: return "Pro 解锁饮食拍照识别和营养估算。"
        case .bodyPhoto: return "Pro 解锁身材拍照分析和训练重点建议。"
        case .videoReview: return "Pro 解锁视频动作点评和姿态分析。"
        case .advancedReview: return "Pro 解锁周/月/年复盘和高级趋势。"
        case .equipmentScan: return "Pro 解锁器械拍照识别。"
        case .general: return "Pro 解锁 App 内全部功能。"
        }
    }

    var icon: String {
        switch self {
        case .trainingPlan: return "calendar.badge.clock"
        case .mealPlan: return "fork.knife"
        case .coachAI: return "bubble.left.and.bubble.right.fill"
        case .foodPhoto: return "camera.fill"
        case .bodyPhoto: return "figure.arms.open"
        case .videoReview: return "play.rectangle.fill"
        case .advancedReview: return "chart.xyaxis.line"
        case .equipmentScan: return "viewfinder"
        case .general: return "crown.fill"
        }
    }
}
