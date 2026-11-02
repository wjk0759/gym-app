import Foundation

// MARK: - 对话

enum CoachSkill: String, Codable, CaseIterable, Identifiable {
    case trainer
    case rehab
    case nutrition

    var id: String { rawValue }

    var label: String {
        switch self {
        case .trainer: return "健身教练"
        case .rehab: return "康复师"
        case .nutrition: return "营养师"
        }
    }

    var icon: String {
        switch self {
        case .trainer: return "figure.strengthtraining.traditional"
        case .rehab: return "cross.case"
        case .nutrition: return "leaf"
        }
    }

    var detail: String {
        switch self {
        case .trainer: return "训练、饮食、恢复和计划都能问"
        case .rehab: return "疼痛分级、恢复期活动和就医提示"
        case .nutrition: return "热量、蛋白质和膳食结构建议"
        }
    }

    var placeholder: String {
        switch self {
        case .trainer: return "训练、饮食、恢复、计划都能问…"
        case .rehab: return "描述疼痛位置、时间和程度…"
        case .nutrition: return "问问热量、蛋白质或饮食安排…"
        }
    }
}

struct ChatMessage: Codable, Identifiable, Hashable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    var id: UUID = UUID()
    var role: Role
    var text: String
    var date: Date = Date()
    var isSafety: Bool = false
    var imageData: Data? = nil
    /// 一条消息可以带多张待发送的图片；`imageData` 保留用于旧数据。
    var imageDataList: [Data]? = nil
    /// 视频只保存预览缩略图和时长；原始视频不会上传或持久化。
    var videoThumbnailData: Data? = nil
    var videoDurationSeconds: Int? = nil

    var allImageData: [Data] {
        if let imageDataList, !imageDataList.isEmpty {
            return imageDataList
        }
        return imageData.map { [$0] } ?? []
    }
}

// MARK: - 饮食记录

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var label: String {
        switch self {
        case .breakfast: return "早餐"
        case .lunch: return "午餐"
        case .dinner: return "晚餐"
        case .snack: return "加餐"
        }
    }
}

struct FoodLog: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date()
    var meal: MealType
    var foodName: String
    var grams: Double
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    /// 旧数据没有该字段；0 表示未记录，不阻塞解码。
    var fiber: Double? = nil
    var syncedAt: Date? = nil
}

struct NutritionTotals {
    var kcal: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fiber: Double = 0
}

/// 饮食照片识别出的单个食物。营养值按每 100g 保存，修改克数后可实时重算。
struct FoodRecognitionItem: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var grams: Double
    var kcalPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var fiberPer100g: Double? = nil
    var confidence: Double
    var selected: Bool = true

    var kcal: Double { kcalPer100g * grams / 100 }
    var protein: Double { proteinPer100g * grams / 100 }
    var carbs: Double { carbsPer100g * grams / 100 }
    var fat: Double { fatPer100g * grams / 100 }
    var fiber: Double { (fiberPer100g ?? max(0, carbsPer100g * 0.05)) * grams / 100 }
}

struct FoodRecognitionResult: Hashable {
    var items: [FoodRecognitionItem]
    var confidence: Double
    var disclaimer: String
    var model: String
    var summary: String = ""
    var isFood: Bool = true
}

struct CoachVisionResult: Decodable {
    /// training / nutrition / equipment / body / general
    let mode: String?
    let isTraining: Bool
    let summary: String
    let observations: [String]
    let nextCue: String?
    let safetyFlag: String?
    let warning: String?
    let sessionID: UUID?

    enum CodingKeys: String, CodingKey {
        case mode
        case isTraining = "is_training"
        case summary
        case observations
        case nextCue = "next_cue"
        case safetyFlag = "safety_flag"
        case warning
        case sessionID = "session_id"
    }
}

struct RemoteDietPlan: Decodable {
    struct Meal: Decodable {
        let meal: String
        let name: String
        let kcal: Int
        let items: [String]
    }

    let meals: [Meal]
    let tips: [String]?
    let note: String?
    let generatedBy: String?
    let warning: String?

    enum CodingKeys: String, CodingKey {
        case meals
        case tips
        case note
        case warning
        case generatedBy = "generated_by"
    }
}

struct RemoteDietRecipe: Decodable {
    let title: String
    let ingredients: [String]
    let steps: [String]
    let tip: String?
}

struct RemoteDietDish: Decodable, Identifiable {
    let name: String
    let items: [String]
    let recipe: RemoteDietRecipe?

    var id: String {
        name + "|" + items.joined(separator: "|")
    }
}

struct DietRecipeSelection: Identifiable {
    let id = UUID()
    let dayTitle: String
    let mealName: String
    let dish: RemoteDietDish
}

struct RemoteDietWeek: Decodable {
    struct Strategy: Decodable {
        let id: String
        let label: String
        let description: String?
        let caution: String?
    }

    struct Targets: Decodable {
        let targetKcal: Int?
        let proteinG: Int?
        let carbG: Int?
        let fatG: Int?

        enum CodingKeys: String, CodingKey {
            case targetKcal = "target_kcal"
            case proteinG = "protein_g"
            case carbG = "carb_g"
            case fatG = "fat_g"
        }
    }

    struct Meal: Decodable, Identifiable {
        let meal: String
        let name: String
        let kcal: Int
        let items: [String]
        let dishes: [RemoteDietDish]?

        var id: String { meal }
    }

    struct Day: Decodable, Identifiable {
        let date: String
        let weekday: Int
        let dayType: String
        let dayTypeLabel: String
        let title: String
        let targets: Targets
        let meals: [Meal]

        var id: String { date }

        enum CodingKeys: String, CodingKey {
            case date
            case weekday
            case dayType = "day_type"
            case dayTypeLabel = "day_type_label"
            case title
            case targets
            case meals
        }
    }

    let weekStart: String
    let strategy: Strategy?
    let days: [Day]
    let generatedBy: String?
    let warning: String?

    enum CodingKeys: String, CodingKey {
        case weekStart = "week_start"
        case strategy
        case days
        case generatedBy = "generated_by"
        case warning
    }
}
