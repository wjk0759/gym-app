import Foundation

struct NutritionTargets {
    let bmr: Int
    let tdee: Int
    let kcal: Int
    let protein: Int
    let carbs: Int
    let fat: Int
}

struct MealSuggestion: Identifiable {
    let name: String
    let kcal: Int
    let items: [String]

    var id: String { name }
}

enum DietPlanner {
    static func targets(profile: UserProfile) -> NutritionTargets {
        let weight = max(30, profile.weightKG)
        let height = max(120, profile.heightCM)
        let age = Double(max(14, profile.age))

        let bmr: Double
        if profile.sex == .female {
            bmr = 10 * weight + 6.25 * height - 5 * age - 161
        } else {
            bmr = 10 * weight + 6.25 * height - 5 * age + 5
        }

        let activity: Double
        switch profile.weeklyDays {
        case ...2: activity = 1.375
        case 3...4: activity = 1.55
        default: activity = 1.725
        }
        let tdee = bmr * activity

        let goalFactor: Double
        let proteinPerKg: Double
        switch profile.goalType {
        case .loseFat:
            goalFactor = 0.85
            proteinPerKg = 1.8
        case .buildMuscle:
            goalFactor = 1.10
            proteinPerKg = 2.0
        default:
            goalFactor = 1.0
            proteinPerKg = 1.6
        }

        let kcal = tdee * goalFactor
        let protein = weight * proteinPerKg
        let fat = weight * 0.9
        let carbs = max(0, (kcal - protein * 4 - fat * 9) / 4)

        return NutritionTargets(
            bmr: Int(bmr.rounded()),
            tdee: Int(tdee.rounded()),
            kcal: Int(kcal.rounded()),
            protein: Int(protein.rounded()),
            carbs: Int(carbs.rounded()),
            fat: Int(fat.rounded())
        )
    }

    static func meals(profile: UserProfile) -> [MealSuggestion] {
        let target = targets(profile: profile).kcal
        let templates: [(String, Double, [String])] = [
            ("早餐", 0.25, ["燕麦 50g", "鸡蛋 2 个", "无糖酸奶 150g", "蓝莓 80g"]),
            ("午餐", 0.35, ["糙米饭 150g", "鸡胸肉 150g", "西兰花 200g", "橄榄油 5g"]),
            ("晚餐", 0.30, ["红薯 150g", "三文鱼或豆腐 150g", "混合蔬菜 250g"]),
            ("加餐", 0.10, ["牛奶 200ml", "坚果 15g"])
        ]

        return templates.map { item in
            MealSuggestion(
                name: item.0,
                kcal: Int(Double(target) * item.1),
                items: item.2
            )
        }
    }
}
