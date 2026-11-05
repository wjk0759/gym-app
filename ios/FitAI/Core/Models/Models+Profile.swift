import Foundation

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

    var stageLabel: String {
        switch self {
        case .beginner: return "小白"
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
    /// Server-owned progression tier derived from completed training days.
    var trainingStage: Experience = .beginner
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
        trainingStage = try container.decodeIfPresent(Experience.self, forKey: .trainingStage) ?? .beginner
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
        case trainingStage = "training_stage"
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
