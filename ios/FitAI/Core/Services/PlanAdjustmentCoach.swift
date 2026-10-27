import Foundation

/// Local, deterministic coach-led plan adjustment for the preview/native build.
/// The conversation is intentionally staged so the plan is never changed before
/// the user explains the problem and confirms the proposal.
struct PlanAdjustmentProposal: Identifiable, Equatable {
    let id = UUID()
    let headline: String
    let summary: String
    let changes: [String]
    let setsDelta: Int
    let weightMultiplier: Double
    let restDelta: Int
    let maxExercises: Int?
    let maxDaysPerWeek: Int?
    let weeklyDays: Int?
    let sessionMinutes: Int?
    let weekdays: [Int]?
    let regeneratePlan: Bool
    let painMuscle: MuscleGroup?
    let avoidSlugs: [String]
}

extension AppStore {
    func requestPlanAdjustment() {
        selectedTab = 2
        if canUseRemoteAI {
            planAdjustmentRequested = false
            planAdjustmentStage = 0
            planAdjustmentProposal = nil
            if chat.isEmpty {
                chat.append(
                    ChatMessage(
                        role: .assistant,
                        text: "直接告诉我你想怎么调整：训练日、频率、时长、动作、伤病或最近执行情况都可以。我会先理解你的意思，再给出可确认的方案。"
                    )
                )
            }
            persist()
            return
        }
        planAdjustmentRequested = true
    }

    func beginPlanAdjustment() {
        planAdjustmentRequested = false
        guard planAdjustmentStage == 0 else { return }
        planAdjustmentStage = 1
        planAdjustmentIssue = ""
        planAdjustmentDetail = ""
        planAdjustmentCategory = ""
        planAdjustmentProposal = nil
        chat.append(
            ChatMessage(
                role: .assistant,
                text: "我们开始调整计划，但我不会先替你拍脑袋改。先说说：最近训练里最困扰你的是什么？是时间、恢复、疼痛、重量卡住，还是计划太满？也可以直接讲一个最近训练里的具体问题。"
            )
        )
        persist()
    }

    var planAdjustmentQuickReplies: [String] {
        guard planAdjustmentStage > 0 else { return [] }
        if planAdjustmentStage == 3 {
            return ["应用调整", "再改一点", "取消"]
        }
        if planAdjustmentStage == 1 {
            return ["时间不够，练不完", "恢复不过来，总是累", "某个动作会疼", "重量卡住不进步", "计划太满，坚持不了"]
        }
        switch planAdjustmentCategory {
        case "pain":
            return ["膝盖，深蹲时明显", "肩膀，推举时疼", "腰，硬拉后不舒服", "肘或腕，撑地时疼"]
        case "time":
            return ["每次 30 分钟，每周 2 天", "每次 45 分钟，每周 3 天", "每次 60 分钟，每周 3 天"]
        case "recovery":
            return ["睡 5–6 小时，总是累", "酸痛 2 天以上", "工作忙，恢复不过来"]
        case "plateau":
            return ["深蹲和卧推卡住", "1 个月没进步", "每次都快力竭但还是不涨"]
        case "tooMuch":
            return ["经常加班，缺练", "每次只能做 3 个动作", "计划太满，想减一天"]
        default:
            return ["训练频率", "动作选择", "组数 / 重量", "恢复或时间"]
        }
    }

    func sendPlanAdjustmentMessage(_ message: String) {
        let text = String(message.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !text.isEmpty, planAdjustmentStage > 0 else { return }
        chat.append(ChatMessage(role: .user, text: text))

        if ["取消", "算了", "不改", "先不改", "不改了", "结束调整"].contains(text) {
            cancelPlanAdjustment()
            return
        }

        if planAdjustmentStage == 1 {
            planAdjustmentIssue = text
            planAdjustmentCategory = classifyAdjustmentIssue(text)
            planAdjustmentDetail = text
            let hasSchedule = !scheduleWeekdays(in: text).isEmpty
                || firstNumber(in: text, pattern: "每周[^0-9]{0,5}(\\d)\\s*(?:练|次|天)") != nil
                || firstNumber(in: text, pattern: "(\\d{2,3})\\s*分钟") != nil
            if hasSchedule {
                let proposal = makePlanAdjustmentProposal()
                planAdjustmentProposal = proposal
                planAdjustmentStage = 3
                if text.contains("直接") || text.contains("就按") || text.contains("生成") || text.contains("不用确认") {
                    applyPlanAdjustment()
                    return
                }
                chat.append(
                    ChatMessage(
                        role: .assistant,
                        text: "我理解你的安排是\(scheduleSummary(for: proposal))。确认后我会直接按这个频率、日期和时长生成一版新计划，不再只改组数。"
                    )
                )
            } else {
                planAdjustmentStage = 2
                chat.append(
                    ChatMessage(
                        role: .assistant,
                        text: adjustmentDetailPrompt(for: planAdjustmentCategory)
                    )
                )
            }
        } else if planAdjustmentStage == 2 {
            planAdjustmentDetail = text
            if planAdjustmentCategory.isEmpty || planAdjustmentCategory == "generic" {
                planAdjustmentCategory = classifyAdjustmentIssue("\(planAdjustmentIssue) \(text)")
            }
            planAdjustmentProposal = makePlanAdjustmentProposal()
            planAdjustmentStage = 3
            chat.append(
                ChatMessage(
                    role: .assistant,
                    text: "我按你说的把方案重新算了一遍。先看下面的调整方案是否更贴近你的真实情况；如果不合适，我们可以继续改。"
                )
            )
        } else if planAdjustmentStage == 3 {
            if ["应用", "应用调整", "确认", "可以", "执行"].contains(text) {
                applyPlanAdjustment()
                return
            }
            if ["再改一点", "不合适", "重来"].contains(text) {
                revisePlanAdjustment()
                return
            }
            planAdjustmentDetail = "\(planAdjustmentDetail)；补充：\(text)"
            planAdjustmentProposal = makePlanAdjustmentProposal()
            chat.append(
                ChatMessage(
                    role: .assistant,
                    text: "收到，我把你的补充也放进去了，重新给你一版。"
                )
            )
        }
        persist()
    }

    func applyPlanAdjustment() {
        guard let proposal = planAdjustmentProposal else { return }
        if proposal.regeneratePlan {
            var updated = profile
            if let weeklyDays = proposal.weeklyDays {
                updated.weeklyDays = max(1, min(7, weeklyDays))
            }
            if let sessionMinutes = proposal.sessionMinutes {
                updated.sessionMinutes = max(15, min(180, sessionMinutes))
            }
            profile = updated
            planAdjustmentStage = 0
            planAdjustmentProposal = nil
            planAdjustmentRequested = false
            chat.append(
                ChatMessage(
                    role: .assistant,
                    text: "收到，我会按\(scheduleSummary(for: proposal))重新生成 4 周计划。训练日和时长会直接写进计划。"
                )
            )
            persist()
            generatePlan(force: true, weeklyWeekdays: proposal.weekdays)
            return
        }
        guard var current = plan else { return }
        current.version += 1
        current.updatedAt = Date()

        for index in current.days.indices {
            var exercises = current.days[index].exercises
                .filter { !proposal.avoidSlugs.contains($0.slug) }
                .map { exercise -> PlanExercise in
                    var item = exercise
                    item.sets = max(2, min(6, item.sets + proposal.setsDelta))
                    item.restSec = max(30, min(180, item.restSec + proposal.restDelta))
                    if let weight = item.weightKG, weight > 0, proposal.weightMultiplier != 1 {
                        item.weightKG = (weight * proposal.weightMultiplier * 2).rounded() / 2
                    }
                    if let painMuscle = proposal.painMuscle,
                       item.exercise?.muscle == painMuscle {
                        item.sets = min(item.sets, 2)
                        if let weight = item.weightKG, weight > 0 {
                            item.weightKG = (weight * 0.9 * 2).rounded() / 2
                        }
                    }
                    return item
                }
            if let maxExercises = proposal.maxExercises {
                exercises = Array(exercises.prefix(max(2, maxExercises)))
            }
            current.days[index].exercises = exercises
            current.days[index].focus = Array(Set(exercises.compactMap { $0.exercise?.muscle }))
        }

        if let maxDays = proposal.maxDaysPerWeek {
            let sortedDays = current.days.sorted {
                $0.weekIndex == $1.weekIndex
                    ? $0.weekday < $1.weekday
                    : $0.weekIndex < $1.weekIndex
            }
            var keptByWeek: [Int: Int] = [:]
            var keptIDs: Set<UUID> = []
            for day in sortedDays {
                let count = keptByWeek[day.weekIndex, default: 0]
                if count < maxDays {
                    keptByWeek[day.weekIndex] = count + 1
                    keptIDs.insert(day.id)
                }
            }
            current.days = current.days.filter { keptIDs.contains($0.id) }
            profile.weeklyDays = maxDays
            if current.title.range(of: "每周\\s*\\d+\\s*练", options: .regularExpression) != nil {
                current.title = current.title.replacingOccurrences(
                    of: "每周\\s*\\d+\\s*练",
                    with: "每周 \(maxDays) 练",
                    options: .regularExpression
                )
            }
        }

        plan = current
        chat.append(
            ChatMessage(
                role: .assistant,
                text: "计划已按你的诉求更新到第 \(current.version) 版。\n\n" + proposal.changes.joined(separator: "\n")
            )
        )
        planAdjustmentStage = 0
        planAdjustmentProposal = nil
        planAdjustmentRequested = false
        persist()
    }

    func revisePlanAdjustment() {
        guard planAdjustmentStage == 3 else { return }
        planAdjustmentStage = 2
        planAdjustmentProposal = nil
        chat.append(
            ChatMessage(
                role: .assistant,
                text: "可以。你最想先改哪一块：动作数量、重量、动作选择，还是训练频率？直接说具体一点，我按你的要求重算。"
            )
        )
        persist()
    }

    func cancelPlanAdjustment() {
        chat.append(
            ChatMessage(
                role: .assistant,
                text: "好，这次先不改计划。你现在的问题已经记在对话里；下次想调整时直接告诉我。"
            )
        )
        planAdjustmentStage = 0
        planAdjustmentProposal = nil
        planAdjustmentRequested = false
        persist()
    }

    /// Used by the normal coach input to route explicit schedule requests into
    /// the plan-adjustment flow instead of giving a generic chat answer.
    func isPlanScheduleRequest(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.contains("周") || value.contains("星期") || value.contains("礼拜") else {
            return false
        }
        return value.contains("练") || value.contains("训练") || value.contains("计划") || value.contains("安排")
    }

    private func scheduleSummary(for proposal: PlanAdjustmentProposal) -> String {
        var parts: [String] = []
        if let weekdays = proposal.weekdays, !weekdays.isEmpty {
            parts.append("每周" + weekdays.map { Weekday.shortNames[max(0, min(6, $0 - 1))] }.joined(separator: "、"))
        } else if let weeklyDays = proposal.weeklyDays {
            parts.append("每周 \(weeklyDays) 练")
        }
        if let minutes = proposal.sessionMinutes {
            parts.append("每次 \(minutes) 分钟")
        }
        return parts.isEmpty ? "你描述的频率和训练时长" : parts.joined(separator: "，")
    }

    private func classifyAdjustmentIssue(_ text: String) -> String {
        if text.contains("疼") || text.contains("痛") || text.contains("膝") || text.contains("肩")
            || text.contains("腰") || text.contains("肘") || text.contains("腕")
            || text.contains("麻") || text.contains("肿") || text.contains("伤") {
            return "pain"
        }
        if text.contains("时间") || text.contains("忙") || text.contains("没空")
            || text.contains("分钟") || text.contains("小时") || text.contains("练不完") {
            return "time"
        }
        if text.contains("恢复") || text.contains("累") || text.contains("疲劳")
            || text.contains("睡") || text.contains("酸") {
            return "recovery"
        }
        if text.contains("重量") || text.contains("卡") || text.contains("瓶颈")
            || text.contains("不涨") || text.contains("进步") {
            return "plateau"
        }
        if text.contains("太满") || text.contains("太多") || text.contains("坚持")
            || text.contains("缺练") || text.contains("放弃") {
            return "tooMuch"
        }
        if text.contains("不想") || text.contains("懒") || text.contains("动力") {
            return "motivation"
        }
        return "generic"
    }

    private func adjustmentDetailPrompt(for category: String) -> String {
        switch category {
        case "pain":
            return "收到，安全优先。先别急着硬练。具体是哪个位置不舒服：膝、肩、腰、肘还是手腕？是哪个动作最明显，疼到几分（1–10）？有没有刺痛、麻木或肿胀？如果出现这些信号，我会建议你先停止相关动作并做专业评估。"
        case "time":
            return "明白，时间是最现实的约束。你现在每次实际能练多久、每周最多几天？我宁愿把计划压缩到你真的能完成，也不想给你排一个看起来很满、实际坚持不了的计划。"
        case "recovery":
            return "收到。最近睡眠大概几小时？训练后酸痛会持续几天？是全身都累，还是某个部位恢复特别慢？我会先调容量和休息，不继续加量。"
        case "plateau":
            return "收到。是哪几个动作卡住了？大概多久没进步？每组是做到力竭，还是还留有余力？我会先改负荷进阶和次数，不会只让你再拼一点。"
        case "tooMuch":
            return "明白，计划需要匹配真实生活。最近一周哪几天最容易缺练？每次能完成几个动作？我会把计划压缩到你能稳定执行的版本。"
        case "motivation":
            return "收到。先不评判自己，能坚持比一次练狠更重要。你更希望计划更短、更有趣，还是固定一个更容易执行的时间？"
        default:
            return "收到。我想再确认一下：最想先解决的是训练频率、动作选择、组数 / 重量、恢复，还是时间？最好举一个最近训练里的具体例子。"
        }
    }

    private func scheduleWeekdays(in text: String) -> [Int] {
        let mapping: [Character: Int] = [
            "一": 1, "二": 2, "三": 3, "四": 4,
            "五": 5, "六": 6, "日": 7, "天": 7
        ]
        let patterns = [
            "(?:周|星期|礼拜)([一二三四五六日天])",
            "每\\s*(?:周|星期|礼拜)\\s*([一二三四五六日天、,，和及\\s]+)"
        ]
        var found = Set<Int>()
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in regex.matches(in: text, range: range) {
                guard match.numberOfRanges > 1,
                      let valueRange = Range(match.range(at: 1), in: text) else { continue }
                let suffix = text[valueRange.upperBound...].first
                if let suffix, "次天练个".contains(suffix) {
                    continue
                }
                for character in text[valueRange] {
                    if let day = mapping[character] {
                        found.insert(day)
                    }
                }
            }
        }
        return found.sorted()
    }

    private func firstNumber(in text: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Int(text[valueRange])
    }

    private func namedSlugs(in text: String) -> [String] {
        let known: [(String, String)] = [
            ("深蹲", "goblet_squat"),
            ("箭步蹲", "lunge"),
            ("卧推", "dumbbell_press"),
            ("推举", "shoulder_press"),
            ("硬拉", "romanian_deadlift"),
            ("划船", "seated_row"),
            ("下拉", "lat_pulldown"),
            ("臀推", "hip_thrust"),
            ("腿举", "leg_press"),
            ("俯卧撑", "pushup")
        ]
        return known.filter { text.contains($0.0) }.map { $0.1 }
    }

    private func makePlanAdjustmentProposal() -> PlanAdjustmentProposal {
        let category = planAdjustmentCategory
        let recent = sessions.filter { $0.date >= Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date() }
        let averageMinutes = recent.isEmpty
            ? 0
            : recent.reduce(0) { $0 + $1.durationMinutes } / recent.count
        let evidence = recent.isEmpty
            ? "目前训练记录还不多，我会用更保守的调整，先确保你能稳定执行。"
            : "最近 30 天完成 \(recent.count) 次训练，本周 \(currentWeekSessions.count) 次，平均 \(averageMinutes) 分钟。"
        let quote = String("\(planAdjustmentIssue) \(planAdjustmentDetail)".prefix(80))
        let scheduleText = "\(planAdjustmentIssue) \(planAdjustmentDetail)"
        let parsedWeekdays = scheduleWeekdays(in: scheduleText)
        let parsedWeeklyDays = firstNumber(
            in: scheduleText,
            pattern: "每周[^0-9]{0,5}(\\d)\\s*(?:练|次|天)"
        )
        let parsedSessionMinutes = firstNumber(
            in: scheduleText,
            pattern: "(\\d{2,3})\\s*分钟"
        )
        var weeklyDays: Int? = parsedWeekdays.isEmpty ? parsedWeeklyDays : parsedWeekdays.count
        if let value = weeklyDays {
            weeklyDays = max(1, min(7, value))
        }
        var sessionMinutes = parsedSessionMinutes
        if let value = sessionMinutes {
            sessionMinutes = max(15, min(180, value))
        }
        var weekdays = parsedWeekdays.isEmpty ? nil : parsedWeekdays
        var regeneratePlan = weekdays != nil || weeklyDays != nil || sessionMinutes != nil
        var setsDelta = 0
        var weightMultiplier = 1.0
        var restDelta = 0
        var maxExercises: Int?
        var maxDaysPerWeek: Int?
        var painMuscle: MuscleGroup?
        var avoidSlugs: [String] = []
        var headline = "先把计划调到你能稳定执行"
        var analysis = ""
        var changes: [String] = []

        if category == "pain" {
            if planAdjustmentDetail.contains("膝") || planAdjustmentDetail.contains("腿") {
                painMuscle = .legs
            } else if planAdjustmentDetail.contains("肩") {
                painMuscle = .shoulders
            } else if planAdjustmentDetail.contains("肘") || planAdjustmentDetail.contains("腕") {
                painMuscle = .arms
            } else {
                setsDelta = -1
                weightMultiplier = 0.9
            }
            avoidSlugs = namedSlugs(in: "\(planAdjustmentIssue) \(planAdjustmentDetail)")
            restDelta = 15
            headline = "先避开疼痛，再谈进步"
            analysis = "先降低可能诱发疼痛的动作负荷，并增加组间休息。"
            changes = [
                painMuscle?.label == nil ? "所有可能诱发疼痛的动作降到 2 组、负重 -10%" : "\(painMuscle?.label ?? "")相关动作降到 2 组、负重 -10%",
                avoidSlugs.isEmpty ? "先避开会诱发疼痛的动作，不硬顶" : "先把\(avoidSlugs.compactMap { ExerciseLibrary.exercise(slug: $0)?.nameZH }.joined(separator: "、"))移出计划",
                "组间休息增加 15 秒，训练前先做 5 分钟动态热身",
                "出现刺痛、麻木或肿胀时停止训练，并进行专业评估"
            ]
        } else if category == "time" {
            let minutes = firstNumber(in: planAdjustmentDetail, pattern: "每次[^0-9]{0,5}(\\d{2,3})\\s*分钟")
                ?? firstNumber(in: planAdjustmentDetail, pattern: "(\\d{2,3})\\s*分钟")
            maxDaysPerWeek = firstNumber(in: planAdjustmentDetail, pattern: "每周[^0-9]{0,5}(\\d)\\s*(?:天|练)")
                ?? firstNumber(in: planAdjustmentIssue, pattern: "每周[^0-9]{0,5}(\\d)\\s*(?:天|练)")
            maxExercises = (minutes ?? 60) <= 30 ? 3 : 4
            restDelta = (minutes ?? 60) <= 30 ? -15 : 0
            headline = "把计划压缩到真实可完成的长度"
            analysis = "时间有限时，优先保留主项，而不是继续往计划里塞动作。"
            changes = [
                "每个训练日最多保留 \(maxExercises ?? 4) 个动作，主项优先",
                maxDaysPerWeek == nil ? "保留最容易坚持的训练频率" : "每周只保留 \(maxDaysPerWeek ?? 2) 个训练日，其余安排恢复",
                "去掉低优先级的孤立动作",
                "先连续两周完成，再考虑增加动作或训练量"
            ]
        } else if category == "recovery" {
            setsDelta = -1
            weightMultiplier = 0.95
            restDelta = 30
            headline = "先把恢复拉回来，不继续加量"
            analysis = "恢复慢或疲劳时，当前更需要降容量和负荷。"
            changes = ["每个动作减少 1 组", "负重下调 5%", "组间休息增加 30 秒"]
        } else if category == "plateau" {
            weightMultiplier = 1.025
            restDelta = 15
            maxExercises = 4
            headline = "换进阶方式，不靠每次拼到力竭"
            analysis = "先减少无效容量，把主项做得更重、更干净。"
            changes = ["主项负重 +2.5%，保留 1–2 次余力", "每个训练日最多 4 个动作", "组间休息增加 15 秒，连续两周记录同一动作"]
        } else if category == "tooMuch" {
            setsDelta = -1
            weightMultiplier = 0.95
            maxExercises = 4
            restDelta = 15
            headline = "先把完成率做回来"
            analysis = "完成率比单次强度更重要，这版先减量。"
            changes = ["每个训练日最多 4 个动作", "每个动作减少 1 组，负重下调 5%", "先稳定完成两周，再逐周加量"]
        } else if category == "motivation" {
            setsDelta = -1
            maxExercises = 3
            restDelta = 15
            headline = "先把启动难度降到最低"
            analysis = "先把训练缩短到容易开始，再靠连续完成建立节奏。"
            changes = ["每个训练日压缩到 3 个动作", "每个动作减少 1 组", "连续完成两周后再加量"]
        } else {
            setsDelta = -1
            weightMultiplier = 0.95
            maxExercises = 4
            restDelta = 15
            headline = "先做一版更稳的计划"
            analysis = "信息还不够具体，这版先保守减量。"
            changes = ["每个训练日最多 4 个动作", "每个动作减少 1 组，负重下调 5%", "两周后根据完成率再决定"]
        }

        if regeneratePlan {
            headline = "按你的真实时间重新生成计划"
            analysis = "这次会直接按你提供的训练日、频率和时长重排 4 周计划，而不是只在旧计划上改动作。"
            changes = []
            if let weekdays, !weekdays.isEmpty {
                let labels = weekdays.map { Weekday.shortNames[max(0, min(6, $0 - 1))] }.joined(separator: "、")
                changes.append("每周\(labels)训练")
            } else if let weeklyDays {
                changes.append("每周安排 \(weeklyDays) 个训练日")
            }
            if let sessionMinutes {
                changes.append("每次控制在 \(sessionMinutes) 分钟")
            }
            changes.append("重新生成 4 周训练日与动作安排")
        }

        return PlanAdjustmentProposal(
            headline: headline,
            summary: "\(evidence)你提到“\(quote)”。\(analysis)",
            changes: changes,
            setsDelta: setsDelta,
            weightMultiplier: weightMultiplier,
            restDelta: restDelta,
            maxExercises: maxExercises,
            maxDaysPerWeek: maxDaysPerWeek,
            weeklyDays: weeklyDays,
            sessionMinutes: sessionMinutes,
            weekdays: weekdays,
            regeneratePlan: regeneratePlan,
            painMuscle: painMuscle,
            avoidSlugs: avoidSlugs
        )
    }
}
