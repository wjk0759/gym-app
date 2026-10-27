import Foundation

// MARK: - 基础枚举

enum Sex: String, Codable, CaseIterable, Identifiable {
    case male
    case female

    var id: String { rawValue }
    var label: String { self == .male ? "男" : "女" }
}

enum Experience: String, Codable, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var label: String {
        switch self {
        case .beginner: return "新手"
        case .intermediate: return "有基础"
        case .advanced: return "进阶"
        }
    }
}

enum GoalType: String, Codable, CaseIterable, Identifiable {
    case loseFat
    case buildMuscle
    case recomp
    case endurance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .loseFat: return "减脂"
        case .buildMuscle: return "增肌"
        case .recomp: return "重塑体型"
        case .endurance: return "提升体能"
        }
    }

    var detail: String {
        switch self {
        case .loseFat: return "控制热量，保留肌肉"
        case .buildMuscle: return "渐进超负荷，稳定增重"
        case .recomp: return "体重变化不大，改善围度"
        case .endurance: return "提高心肺与耐力"
        }
    }
}

enum Equipment: String, Codable, CaseIterable, Identifiable {
    case bodyweight
    case dumbbell
    case barbell
    case machine
    case cable
    case band
    case kettlebell

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bodyweight: return "徒手"
        case .dumbbell: return "哑铃"
        case .barbell: return "杠铃"
        case .machine: return "固定器械"
        case .cable: return "绳索"
        case .band: return "弹力带"
        case .kettlebell: return "壶铃"
        }
    }

    var symbolName: String {
        switch self {
        case .bodyweight: return "figure.strengthtraining.functional"
        case .dumbbell: return "dumbbell"
        case .barbell: return "figure.strengthtraining.traditional"
        case .machine: return "gearshape.fill"
        case .cable: return "point.3.connected.trianglepath.dotted"
        case .band: return "link"
        case .kettlebell: return "figure.cross.training"
        }
    }
}

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest
    case back
    case legs
    case glutes
    case shoulders
    case arms
    case core
    case cardio

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chest: return "胸"
        case .back: return "背"
        case .legs: return "腿"
        case .glutes: return "臀"
        case .shoulders: return "肩"
        case .arms: return "手臂"
        case .core: return "核心"
        case .cardio: return "有氧"
        }
    }
}

enum Weekday {
    static let shortNames = ["一", "二", "三", "四", "五", "六", "日"]

    static func label(_ value: Int) -> String {
        let index = min(max(value - 1, 0), 6)
        return "周" + shortNames[index]
    }

    static var today: Int {
        let component = Calendar.current.component(.weekday, from: Date())
        return component == 1 ? 7 : component - 1
    }
}

// MARK: - 用户

struct UserProfile: Codable, Equatable {
    var nickname: String = ""
    var sex: Sex = .male
    var age: Int = 30
    var heightCM: Double = 175
    var weightKG: Double = 72
    var waistCM: Double = 80
    var chestCM: Double = 95
    var hipCM: Double = 95
    var experience: Experience = .beginner
    var equipment: Set<Equipment> = [.bodyweight, .dumbbell]
    var injuries: String = ""
    var weeklyDays: Int = 3
    var sessionMinutes: Int = 45
    var goalType: GoalType = .buildMuscle
    var targetWeightKG: Double = 75
    var targetWaistCM: Double? = nil
    var targetBodyFatPCT: Double? = nil
    var targetDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    var bodyFatPCT: Double = 21
    var armCM: Double = 34
    var thighCM: Double = 56
    var split: SplitType = .one
    var goalStartWeight: Double? = nil
    var goalStartDate: Date? = nil
    var periodRangeStart: String? = nil
    var periodRangeEnd: String? = nil
    var periodDates: [String] = []
    var periodTrainingMode: PeriodTrainingMode = .light
    var isOnboarded: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        sex = try container.decodeIfPresent(Sex.self, forKey: .sex) ?? .male
        age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 30
        heightCM = try container.decodeIfPresent(Double.self, forKey: .heightCM) ?? 175
        weightKG = try container.decodeIfPresent(Double.self, forKey: .weightKG) ?? 72
        bodyFatPCT = try container.decodeIfPresent(Double.self, forKey: .bodyFatPCT) ?? 21
        waistCM = try container.decodeIfPresent(Double.self, forKey: .waistCM) ?? 80
        armCM = try container.decodeIfPresent(Double.self, forKey: .armCM) ?? 34
        thighCM = try container.decodeIfPresent(Double.self, forKey: .thighCM) ?? 56
        chestCM = try container.decodeIfPresent(Double.self, forKey: .chestCM) ?? 95
        hipCM = try container.decodeIfPresent(Double.self, forKey: .hipCM) ?? 95
        experience = try container.decodeIfPresent(Experience.self, forKey: .experience) ?? .beginner
        equipment = try container.decodeIfPresent(Set<Equipment>.self, forKey: .equipment)
            ?? [.bodyweight, .dumbbell]
        injuries = try container.decodeIfPresent(String.self, forKey: .injuries) ?? ""
        weeklyDays = try container.decodeIfPresent(Int.self, forKey: .weeklyDays) ?? 3
        sessionMinutes = try container.decodeIfPresent(Int.self, forKey: .sessionMinutes) ?? 45
        split = try container.decodeIfPresent(SplitType.self, forKey: .split) ?? .one
        goalType = try container.decodeIfPresent(GoalType.self, forKey: .goalType) ?? .buildMuscle
        targetWeightKG = try container.decodeIfPresent(Double.self, forKey: .targetWeightKG) ?? 75
        targetWaistCM = try container.decodeIfPresent(Double.self, forKey: .targetWaistCM)
        targetBodyFatPCT = try container.decodeIfPresent(Double.self, forKey: .targetBodyFatPCT)
        targetDate = try container.decodeIfPresent(Date.self, forKey: .targetDate)
            ?? Calendar.current.date(byAdding: .month, value: 3, to: Date())
            ?? Date()
        goalStartWeight = try container.decodeIfPresent(Double.self, forKey: .goalStartWeight)
        goalStartDate = try container.decodeIfPresent(Date.self, forKey: .goalStartDate)
        periodRangeStart = try container.decodeIfPresent(String.self, forKey: .periodRangeStart)
        periodRangeEnd = try container.decodeIfPresent(String.self, forKey: .periodRangeEnd)
        periodDates = try container.decodeIfPresent([String].self, forKey: .periodDates) ?? []
        periodTrainingMode = try container.decodeIfPresent(PeriodTrainingMode.self, forKey: .periodTrainingMode) ?? .light
        isOnboarded = try container.decodeIfPresent(Bool.self, forKey: .isOnboarded) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case nickname
        case sex
        case age
        case heightCM
        case weightKG
        case bodyFatPCT
        case waistCM
        case armCM
        case thighCM
        case chestCM
        case hipCM
        case experience
        case equipment
        case injuries
        case weeklyDays
        case sessionMinutes
        case split
        case goalType
        case targetWeightKG
        case targetWaistCM
        case targetBodyFatPCT
        case targetDate
        case goalStartWeight
        case goalStartDate
        case periodRangeStart
        case periodRangeEnd
        case periodDates
        case periodTrainingMode
        case isOnboarded
    }

    var bmi: Double {
        guard heightCM > 0 else { return 0 }
        let meters = heightCM / 100
        return (weightKG / (meters * meters) * 10).rounded() / 10
    }

    var bmiLabel: String {
        switch bmi {
        case ..<18.5: return "偏瘦"
        case 18.5..<24: return "正常"
        case 24..<28: return "偏高"
        default: return "肥胖"
        }
    }

    var availableEquipment: Set<Equipment> {
        equipment
    }
}

// MARK: - 计划

struct PlanExercise: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var slug: String
    var sets: Int
    var reps: String
    var weightKG: Double?
    var restSec: Int
    var rpe: Double

    enum CodingKeys: String, CodingKey {
        case id
        case slug
        case sets
        case reps
        case weightKG = "weight_kg"
        case restSec = "rest_sec"
        case rpe
    }

    var exercise: Exercise? {
        ExerciseLibrary.exercise(slug: slug)
    }

    var displayName: String {
        exercise?.nameZH ?? slug
    }

    var displayReps: String {
        let first = reps.components(separatedBy: "-").first ?? reps
        let digits = first.filter(\.isNumber)
        return digits.isEmpty ? "10" : String(digits.prefix(2))
    }

    var targetText: String {
        if let weight = weightKG, weight > 0 {
            return "\(sets) 组 × \(displayReps) · \(weight.formatted())kg"
        }
        return "\(sets) 组 × \(displayReps)"
    }
}

struct PlanDay: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var weekIndex: Int = 1
    var weekday: Int
    var date: Date? = nil
    /// 用户明确跳过这次训练；跳过的训练不再出现在今日卡、错期提醒和通知里。
    var skippedAt: Date? = nil
    var title: String
    var focus: [MuscleGroup]
    var exercises: [PlanExercise]

    enum CodingKeys: String, CodingKey {
        case id
        case weekIndex = "week_index"
        case weekday
        case date
        case skippedAt = "skipped_at"
        case title
        case focus
        case exercises
    }

    var focusText: String {
        focus.map(\.label).joined(separator: " · ")
    }

    var estimatedMinutes: Int {
        let work = exercises.reduce(0) { partial, item in
            partial + item.sets * max(1, item.restSec) / 60
        }
        return max(20, work + exercises.count * 3)
    }
}

struct TrainingPlan: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var createdAt: Date = Date()
    var updatedAt: Date?
    var version: Int = 1
    var weeks: Int = 4
    var split: SplitType? = nil
    var weeklyDays: Int? = nil
    var days: [PlanDay]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case version
        case weeks
        case split
        case weeklyDays
        case days
    }

    var displayDate: Date { updatedAt ?? createdAt }

    func date(week: Int, weekday: Int) -> Date? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: createdAt)
        let startWeekday = calendar.component(.weekday, from: start)
        let mondayOffset = startWeekday == 1 ? -6 : 2 - startWeekday
        guard let monday = calendar.date(byAdding: .day, value: mondayOffset, to: start) else {
            return nil
        }
        let safeWeek = max(1, week)
        let safeWeekday = min(max(1, weekday), 7)
        return calendar.date(
            byAdding: .day,
            value: (safeWeek - 1) * 7 + safeWeekday - 1,
            to: monday
        )
    }

    func scheduledDate(for day: PlanDay) -> Date? {
        day.date ?? date(week: day.weekIndex, weekday: day.weekday)
    }

    func day(on date: Date) -> PlanDay? {
        days.first { day in
            guard day.skippedAt == nil,
                  let value = scheduledDate(for: day) else { return false }
            return Calendar.current.isDate(value, inSameDayAs: date)
        }
    }

    var firstWeek: [PlanDay] { weekDays(in: 1) }

    func weekDays(in week: Int) -> [PlanDay] {
        days.filter { $0.weekIndex == week && $0.skippedAt == nil }.sorted {
            let left = scheduledDate(for: $0) ?? .distantFuture
            let right = scheduledDate(for: $1) ?? .distantFuture
            return left == right ? $0.weekday < $1.weekday : left < right
        }
    }
}

// MARK: - 训练记录

struct SetLog: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var slug: String
    var setIndex: Int
    var weightKG: Double
    var reps: Int
    var rpe: Double
    var completed: Bool = true
}

struct WorkoutSession: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date()
    var dayTitle: String
    var durationMinutes: Int
    var feeling: Int
    var notes: String? = nil
    var sets: [SetLog]
    /// 关联的计划训练日，用于跨设备恢复训练日标题与 Agent 上下文。
    var programDayID: String? = nil
    /// 已同步到服务端的远端记录 ID；旧本地记录为空。
    var remoteID: String? = nil
    var syncedAt: Date? = nil
    /// 已同步记录的本地修改尚未成功 PATCH 时置为 true，供前台重试。
    var pendingRemoteUpdate: Bool? = nil

    var volume: Double {
        sets.filter(\.completed).reduce(0) { partial, item in
            partial + item.weightKG * Double(item.reps)
        }
    }

    var exerciseCount: Int {
        Set(sets.map(\.slug)).count
    }
}

// MARK: - 动作

struct Exercise: Identifiable, Hashable {
    var id: String { slug }
    let slug: String
    let nameZH: String
    let nameEN: String
    let muscle: MuscleGroup
    let equipment: Equipment
    let isCompound: Bool
    let instructions: String
    let contraindications: [String]

    var videoURL: URL? {
        VideoCatalog.url(for: slug)
    }

    init(
        slug: String,
        nameZH: String,
        nameEN: String = "",
        muscle: MuscleGroup,
        equipment: Equipment,
        isCompound: Bool,
        instructions: String,
        contraindications: [String] = []
    ) {
        self.slug = slug
        self.nameZH = nameZH
        self.nameEN = nameEN
        self.muscle = muscle
        self.equipment = equipment
        self.isCompound = isCompound
        self.instructions = instructions
        self.contraindications = contraindications
    }
}

struct EquipmentCandidate: Identifiable, Hashable {
    var id: String { exercise.slug }
    let exercise: Exercise
    let confidence: Double
}

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
        case .trainer: return "训练安排、动作替代和负荷调整"
        case .rehab: return "疼痛分级、恢复期活动和就医提示"
        case .nutrition: return "热量、蛋白质和膳食结构建议"
        }
    }

    var placeholder: String {
        switch self {
        case .trainer: return "问问训练、动作或计划…"
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
}

// MARK: - 器械库与体型分析

struct EquipmentItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var slug: String?
    var muscle: MuscleGroup?
    var equipment: Equipment?
    var videoURL: String?
    var notes: String = ""
    var photoData: Data?
    var createdAt: Date = Date()
    var syncedAt: Date? = nil

    var exercise: Exercise? {
        slug.flatMap { ExerciseLibrary.exercise(slug: $0) }
    }
}

struct BodyAnalysis: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var summary: String
    var focusAreas: [MuscleGroup]
    var recommendations: [String]
    var confidence: Double
    var disclaimer: String
    var appliedToPlan: Bool = false
}
