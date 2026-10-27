#if DEBUG
import Darwin
import Foundation

/// 仅 Debug 使用的压力测试工具：`FITAI_QA_STRESS=1` 启动后会在后台跑一组
/// 大数据编解码、日历分组、训练历史与动作筛选基准，并通过 `STRESS` 前缀写入系统日志。
enum StressHarness {
    private struct StressState: Codable {
        let profile: UserProfile
        let sessions: [WorkoutSession]
        let foodLogs: [FoodLog]
        let bodyMetrics: [BodyMetric]
        let chat: [ChatMessage]
    }

    static func runIfRequested() {
        guard ProcessInfo.processInfo.environment["FITAI_QA_STRESS"] == "1" else { return }
        Task.detached(priority: .userInitiated) {
            try? await Task.sleep(nanoseconds: 800_000_000)
            run()
        }
    }

    private static func run() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        NSLog("STRESS start mem=%.1fMB", residentMB())

        let sessions = (0..<1_200).map { index -> WorkoutSession in
            let date = calendar.date(byAdding: .day, value: -(index % 365), to: now) ?? now
            let sets = (0..<5).map { setIndex in
                SetLog(
                    slug: index % 3 == 0 ? "squat" : "bench-press",
                    setIndex: setIndex + 1,
                    weightKG: 60 + Double(setIndex) * 2.5,
                    reps: 8 + setIndex % 5,
                    rpe: 7.5
                )
            }
            return WorkoutSession(
                date: date,
                dayTitle: index % 2 == 0 ? "下肢力量" : "上肢推",
                durationMinutes: 55,
                feeling: 4,
                sets: sets
            )
        }

        let foodLogs = (0..<2_500).map { index -> FoodLog in
            let date = calendar.date(byAdding: .day, value: -(index % 365), to: now) ?? now
            return FoodLog(
                date: date,
                meal: MealType.allCases[index % MealType.allCases.count],
                foodName: "鸡胸肉饭 \(index)",
                grams: 350,
                kcal: 520,
                protein: 42,
                carbs: 58,
                fat: 12,
                fiber: 5
            )
        }

        let bodyMetrics = (0..<400).map { index -> BodyMetric in
            let date = calendar.date(byAdding: .day, value: -index, to: now) ?? now
            return BodyMetric(
                date: date,
                weightKG: 72 - Double(index) * 0.01,
                bodyFatPCT: 21,
                waistCM: 80,
                armCM: 34,
                thighCM: 56
            )
        }

        let chat = (0..<300).map { index -> ChatMessage in
            ChatMessage(
                role: index % 2 == 0 ? .user : .assistant,
                text: "第 \(index) 条测试消息：这是一段用于压力测试的教练对话内容，包含训练、饮食和恢复建议。"
            )
        }

        let state = StressState(
            profile: UserProfile(),
            sessions: sessions,
            foodLogs: foodLogs,
            bodyMetrics: bodyMetrics,
            chat: chat
        )

        var payload = Data()
        benchmark("encode") {
            payload = (try? JSONEncoder().encode(state)) ?? Data()
        }
        NSLog(
            "STRESS payload %.2fMB sessions=%d food=%d body=%d chat=%d",
            Double(payload.count) / 1_048_576,
            sessions.count,
            foodLogs.count,
            bodyMetrics.count,
            chat.count
        )
        benchmark("decode") {
            _ = try? JSONDecoder().decode(StressState.self, from: payload)
        }

        let days = (0..<42).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 20, to: now)
        }

        benchmark("calendar_old") {
            var total = 0
            for day in days {
                total += sessions.filter {
                    calendar.isDate($0.date, inSameDayAs: day)
                }.count
            }
            NSLog("STRESS calendar_old_count %d", total)
        }

        benchmark("calendar_new") {
            let byDay = Dictionary(grouping: sessions) {
                calendar.startOfDay(for: $0.date)
            }
            var total = 0
            for day in days {
                total += byDay[calendar.startOfDay(for: day)]?.count ?? 0
            }
            NSLog("STRESS calendar_new_count %d", total)
        }

        benchmark("history_old") {
            var total = 0
            for day in days.prefix(31) {
                total += sessions.filter {
                    calendar.isDate($0.date, inSameDayAs: day)
                }.count
            }
            NSLog("STRESS history_old_count %d", total)
        }

        benchmark("history_new") {
            guard let interval = calendar.dateInterval(of: .month, for: now) else { return }
            let month = sessions.filter { interval.contains($0.date) }
            let byDay = Dictionary(grouping: month) {
                calendar.startOfDay(for: $0.date)
            }
            var total = 0
            for day in days.prefix(31) {
                total += byDay[calendar.startOfDay(for: day)]?.count ?? 0
            }
            NSLog("STRESS history_new_count %d", total)
        }

        let exercises = ExerciseLibrary.all
        let savedList = stride(from: 0, to: exercises.count, by: 3)
            .map { exercises[$0].slug }
        let savedSet = Set(savedList)
        NSLog("STRESS exercise_count %d saved=%d", exercises.count, savedList.count)

        benchmark("exercise_old") {
            let filtered = exercises.filter { exercise in
                !savedList.contains(exercise.slug)
            }.sorted { left, right in
                let leftSaved = savedList.contains(left.slug)
                let rightSaved = savedList.contains(right.slug)
                if leftSaved != rightSaved { return leftSaved }
                return left.nameZH < right.nameZH
            }
            NSLog("STRESS exercise_old_count %d", filtered.count)
        }

        benchmark("exercise_new") {
            let filtered = exercises.filter { exercise in
                !savedSet.contains(exercise.slug)
            }.sorted { left, right in
                let leftSaved = savedSet.contains(left.slug)
                let rightSaved = savedSet.contains(right.slug)
                if leftSaved != rightSaved { return leftSaved }
                return left.nameZH < right.nameZH
            }
            NSLog("STRESS exercise_new_count %d", filtered.count)
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("fitai-stress-state.json")
        benchmark("persist_burst_old", iterations: 1) {
            for _ in 0..<20 {
                if let data = try? JSONEncoder().encode(state) {
                    try? data.write(to: tempURL, options: .atomic)
                }
            }
        }
        benchmark("persist_burst_new", iterations: 1) {
            if let data = try? JSONEncoder().encode(state) {
                try? data.write(to: tempURL, options: .atomic)
            }
        }
        try? FileManager.default.removeItem(at: tempURL)

        NSLog("STRESS end mem=%.1fMB", residentMB())
    }

    private static func benchmark(
        _ name: String,
        iterations: Int = 3,
        _ block: () -> Void
    ) {
        var best = Double.greatestFiniteMagnitude
        for _ in 0..<iterations {
            let started = CFAbsoluteTimeGetCurrent()
            block()
            best = min(best, (CFAbsoluteTimeGetCurrent() - started) * 1000)
        }
        NSLog("STRESS %@ best=%.3fms", name, best)
    }

    private static func residentMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else { return -1 }
        return Double(info.resident_size) / 1_048_576
    }
}
#endif
