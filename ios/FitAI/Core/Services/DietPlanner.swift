import Foundation

struct NutritionTargets: Codable {
    let bmr: Int
    let tdee: Int
    let kcal: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let fiber: Int

    init(
        bmr: Int,
        tdee: Int,
        kcal: Int,
        protein: Int,
        carbs: Int,
        fat: Int,
        fiber: Int
    ) {
        self.bmr = bmr
        self.tdee = tdee
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
    }

    init?(remote: RemoteDietPlan.Targets?, profile: UserProfile) {
        guard let remote,
              let kcal = remote.targetKcal,
              let protein = remote.proteinG,
              let carbs = remote.carbG,
              let fat = remote.fatG else {
            return nil
        }
        let base = DietPlanner.targets(profile: profile)
        self.init(
            bmr: base.bmr,
            tdee: base.tdee,
            kcal: kcal,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: base.fiber
        )
    }
}

struct MealSuggestion: Identifiable {
    let name: String
    let kcal: Int
    let items: [String]
    var meal: MealType = .breakfast
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fiber: Double = 0
    var skipped: Bool = false

    var id: String { meal.rawValue + "|" + name }
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

        let bmi = weight / ((height / 100) * (height / 100))
        let safeFloor = profile.sex == .female ? 1200.0 : 1500.0
        let rawKcal: Double
        if profile.goalType == .loseFat, bmi < 18.5 {
            // Never recommend further fat loss for an underweight profile.
            rawKcal = tdee
        } else {
            rawKcal = tdee * goalFactor
        }
        let kcal = max(safeFloor, rawKcal)
        let protein = weight * proteinPerKg
        let fat = weight * 0.9
        let carbs = max(0, (kcal - protein * 4 - fat * 9) / 4)

        return NutritionTargets(
            bmr: Int(bmr.rounded()),
            tdee: Int(tdee.rounded()),
            kcal: Int(kcal.rounded()),
            protein: Int(protein.rounded()),
            carbs: Int(carbs.rounded()),
            fat: Int(fat.rounded()),
            fiber: max(25, Int((kcal / 1000 * 14).rounded()))
        )
    }

    static func meals(profile: UserProfile) -> [MealSuggestion] {
        let targets = targets(profile: profile)
        let target = targets.kcal
        let templates: [(MealType, String, Double, [String])] = [
            (.breakfast, "早餐", 0.25, ["燕麦 50g", "鸡蛋 2 个", "无糖酸奶 150g", "蓝莓 80g"]),
            (.lunch, "午餐", 0.35, ["糙米饭 150g", "鸡胸肉 150g", "西兰花 200g", "橄榄油 5g"]),
            (.dinner, "晚餐", 0.30, ["红薯 150g", "三文鱼或豆腐 150g", "混合蔬菜 250g"]),
            (.snack, "加餐", 0.10, ["牛奶 200ml", "坚果 15g"])
        ]

        return templates.map { item in
            MealSuggestion(
                name: item.1,
                kcal: Int(Double(target) * item.2),
                items: item.3,
                meal: item.0,
                protein: Double(targets.protein) * item.2,
                carbs: Double(targets.carbs) * item.2,
                fat: Double(targets.fat) * item.2,
                fiber: Double(targets.fiber) * item.2
            )
        }
    }
}
