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
    var targetDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    var isOnboarded: Bool = false

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
        equipment.union([.bodyweight])
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

    var targetText: String {
        if let weight = weightKG, weight > 0 {
            return "\(sets) 组 × \(reps) · \(weight.formatted())kg"
        }
        return "\(sets) 组 × \(reps)"
    }
}

struct PlanDay: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var weekIndex: Int = 1
    var weekday: Int
    var title: String
    var focus: [MuscleGroup]
    var exercises: [PlanExercise]

    enum CodingKeys: String, CodingKey {
        case id
        case weekIndex = "week_index"
        case weekday
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
    var version: Int = 1
    var weeks: Int = 4
    var days: [PlanDay]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt = "created_at"
        case version
        case weeks
        case days
    }

    var firstWeek: [PlanDay] { weekDays(in: 1) }

    func weekDays(in week: Int) -> [PlanDay] {
        days.filter { $0.weekIndex == week }.sorted { $0.weekday < $1.weekday }
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
    var sets: [SetLog]

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
    let videoURL: URL?

    init(
        slug: String,
        nameZH: String,
        nameEN: String = "",
        muscle: MuscleGroup,
        equipment: Equipment,
        isCompound: Bool,
        instructions: String,
        contraindications: [String] = [],
        videoURL: URL? = nil
    ) {
        self.slug = slug
        self.nameZH = nameZH
        self.nameEN = nameEN
        self.muscle = muscle
        self.equipment = equipment
        self.isCompound = isCompound
        self.instructions = instructions
        self.contraindications = contraindications
        self.videoURL = videoURL
    }
}

struct EquipmentCandidate: Identifiable, Hashable {
    var id: String { exercise.slug }
    let exercise: Exercise
    let confidence: Double
}

// MARK: - 对话

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
}
