import Foundation

struct RemoteMe: Decodable {
    let profile: RemoteMeProfile?
    let goal: RemoteMeGoal?
}

struct RemoteMeProfile: Decodable {
    let nickname: String?
    let sex: String?
    let birthDate: String?
    let age: Int?
    let heightCM: Double?
    let weightKG: Double?
    let bodyFatPCT: Double?
    let chestCM: Double?
    let waistCM: Double?
    let hipCM: Double?
    let experience: String?
    let trainingStage: String?
    let injuries: [String]?
    let equipment: [String]?
    let weeklyDays: Int?
    let sessionMinutes: Int?
    let onboarded: Bool?

    enum CodingKeys: String, CodingKey {
        case nickname
        case sex
        case birthDate = "birth_date"
        case age
        case heightCM = "height_cm"
        case weightKG = "weight_kg"
        case bodyFatPCT = "body_fat_pct"
        case chestCM = "chest_cm"
        case waistCM = "waist_cm"
        case hipCM = "hip_cm"
        case experience
        case trainingStage = "training_stage"
        case injuries
        case equipment
        case weeklyDays = "weekly_days"
        case sessionMinutes = "session_minutes"
        case onboarded
    }
}

struct RemoteMeGoal: Decodable {
    let type: String?
    let targetWeightKG: Double?
    let targetBodyFatPCT: Double?
    let targetWaistCM: Double?
    let targetDate: String?

    enum CodingKeys: String, CodingKey {
        case type
        case targetWeightKG = "target_weight_kg"
        case targetBodyFatPCT = "target_body_fat_pct"
        case targetWaistCM = "target_waist_cm"
        case targetDate = "target_date"
    }
}

struct RemoteCloudSync: Decodable {
    let serverTime: String?
    let preferences: RemoteCloudPreferences?
    let customFoods: [RemoteCloudFood]
    let favorites: [RemoteCloudFavorite]
    let dislikedExercises: [RemoteCloudDislike]

    enum CodingKeys: String, CodingKey {
        case serverTime = "server_time"
        case preferences
        case customFoods = "custom_foods"
        case favorites
        case dislikedExercises = "disliked_exercises"
    }
}

struct RemoteCloudPreferences: Codable, Equatable {
    let strictEquipmentMode: Bool?
    let useRemoteAI: Bool?
    let reminderHour: Int?
    let reminderMinute: Int?
    let notificationsEnabled: Bool?
    let bodyCheckinFrequency: String?
    let bodyCheckinWeekday: Int?
    let bodyCheckinDay: Int?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case strictEquipmentMode = "strict_equipment_mode"
        case useRemoteAI = "use_remote_ai"
        case reminderHour = "reminder_hour"
        case reminderMinute = "reminder_minute"
        case notificationsEnabled = "notifications_enabled"
        case bodyCheckinFrequency = "body_checkin_frequency"
        case bodyCheckinWeekday = "body_checkin_weekday"
        case bodyCheckinDay = "body_checkin_day"
        case updatedAt = "updated_at"
    }
}

struct RemoteCloudFood: Decodable {
    let clientID: String
    let name: String
    let category: String?
    let kcal: Double?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let fiber: Double?
    let defaultGrams: Double?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case name
        case category
        case kcal
        case protein
        case carbs
        case fat
        case fiber
        case defaultGrams = "default_grams"
        case updatedAt = "updated_at"
    }
}

struct RemoteCloudFavorite: Decodable {
    let foodKey: String
    let name: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case foodKey = "food_key"
        case name
        case updatedAt = "updated_at"
    }
}

struct RemoteCloudDislike: Decodable {
    let slug: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case slug
        case updatedAt = "updated_at"
    }
}

struct PlanHistoryResponse: Decodable {
    let items: [TrainingPlan]
}

