import Foundation

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
    /// 本地排期变更时间；用于跨设备最后写入优先。
    var scheduleUpdatedAt: Date? = nil
    var title: String
    var focus: [MuscleGroup]
    var exercises: [PlanExercise]

    enum CodingKeys: String, CodingKey {
        case id
        case weekIndex = "week_index"
        case weekday
        case date
        case skippedAt = "skipped_at"
        case scheduleUpdatedAt = "schedule_updated_at"
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
    var generatedBy: String? = nil
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
        case generatedBy = "generated_by"
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
    /// 这次训练实际计划的组数；用于区分“练了一半”和“完成整个训练日”。
    /// 旧记录为空时回退到计划动作的组数。
    var plannedSets: Int? = nil
    /// 训练入口：phone / watch。旧记录为空时按 phone 处理。
    var source: String? = nil
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

/// 训练中的本地草稿：暂停、切后台或中途退出时保存，再次进入同一训练日时恢复。
/// 草稿不会生成正式训练记录；用户点“结束并保存”后才写入 sessions。
struct WorkoutDraft: Codable, Identifiable, Hashable {
    var id: UUID { dayID }
    var dayID: UUID
    var dayTitle: String
    var logs: [SetLog]
    var currentIndex: Int
    var plannedSets: Int
    var elapsedSeconds: Double
    var feeling: Int
    var notes: String
    var adjustedExercises: [PlanExercise]
    /// 本次训练实际使用的动作列表；计划日被自定义调整后，恢复时必须沿用这份顺序。
    var exercises: [PlanExercise]? = nil
    var updatedAt: Date = Date()

    var completedSets: Int {
        logs.filter(\.completed).count
    }

    var progress: Double {
        guard plannedSets > 0 else { return 0 }
        return min(1, Double(completedSets) / Double(plannedSets))
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
    let motionStartURL: URL?
    let motionEndURL: URL?
    let aliases: [String]
    let slugAliases: [String]
    /// Two-level category for library browsing (e.g. 胸/上胸, 背/背阔肌).
    let categoryL1: String?
    let categoryL2: String?
    /// Whether this action may enter the AI plan pool (common actions + the
    /// user's self-selected library). Excluded: yoga/stretch/cardio/"other".
    let planEligible: Bool
    /// Lowercased bag of everything a user might type to find this action.
    /// Precomputed once so search never re-allocates strings per keystroke.
    let searchKey: String

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
        contraindications: [String] = [],
        motionStartURL: URL? = nil,
        motionEndURL: URL? = nil,
        aliases: [String] = [],
        slugAliases: [String] = [],
        categoryL1: String? = nil,
        categoryL2: String? = nil,
        planEligible: Bool = true
    ) {
        self.slug = slug
        self.nameZH = nameZH
        self.nameEN = nameEN
        self.muscle = muscle
        self.equipment = equipment
        self.isCompound = isCompound
        self.instructions = instructions
        self.contraindications = contraindications
        self.motionStartURL = motionStartURL
        self.motionEndURL = motionEndURL
        self.aliases = aliases
        self.slugAliases = slugAliases
        self.categoryL1 = categoryL1
        self.categoryL2 = categoryL2
        self.planEligible = planEligible
        self.searchKey = ([nameZH, nameEN] + aliases + [muscle.label, equipment.label])
            .joined(separator: " ")
            .lowercased()
    }
}

struct EquipmentCandidate: Identifiable, Hashable {
    var id: String { exercise.slug }
    let exercise: Exercise
    let confidence: Double
}

struct EquipmentMatchOption: Identifiable, Equatable {
    let slug: String
    let name: String
    let confidence: Double
    let candidates: [EquipmentCandidate]

    var id: String { slug }
}

struct EquipmentScanResult {
    var candidates: [EquipmentCandidate]
    var description: String
    var name: String
    var notInLibrary: Bool
    var warning: String? = nil
    var status: String = "ok"
    var equipmentName: String? = nil
    var confidence: Double? = nil
    var equipmentOptions: [EquipmentMatchOption] = []
}
