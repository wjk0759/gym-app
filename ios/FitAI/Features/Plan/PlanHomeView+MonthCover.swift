import SwiftUI

extension PlanHomeView {
    // MARK: - Month cover

    var visibleMonthStats: MonthStats {
        guard let interval = calendar.dateInterval(of: .month, for: visibleMonth) else {
            return MonthStats()
        }

        var stats = MonthStats()
        let monthSessions = store.sessions.filter { interval.contains($0.date) }
        stats.sessions = monthSessions.count
        stats.volume = monthSessions.reduce(0) { $0 + $1.volume }
        stats.minutes = monthSessions.reduce(0) { $0 + $1.durationMinutes }
        stats.foodDays = Set(
            store.foodLogs
                .filter { interval.contains($0.date) }
                .map { FitnessDate.key($0.date) }
        ).count

        if let plan = store.plan {
            for day in plan.days {
                guard day.skippedAt == nil,
                      let date = plan.scheduledDate(for: day),
                      interval.contains(date) else { continue }
                stats.plannedDays += 1
                if store.isPlanDayCompleted(day) {
                    stats.completedPlanDays += 1
                }
            }
        }

        return stats
    }

    var monthCover: some View {
        let stats = visibleMonthStats
        let year = calendar.component(.year, from: visibleMonth)
        let completionText = stats.plannedDays == 0
            ? "—"
            : "\(Int(stats.completion * 100))%"

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("MONTH / \(monthLabel)")
                    .font(AppType.overline)
                    .tracking(1.4)
                    .foregroundStyle(Theme.onMedia.opacity(0.9))
                Spacer()
                Text(String(year))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.onMedia.opacity(0.78))
            }

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text("\(stats.sessions)")
                    .font(.system(size: 52, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.onMedia)
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 2) {
                    Text("次训练")
                        .font(AppType.caption.weight(.bold))
                        .foregroundStyle(Theme.onMedia)
                    Text(isCurrentVisibleMonth ? "本月" : "当月")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.onMedia.opacity(0.72))
                }
                .padding(.bottom, 5)

                Spacer(minLength: 6)

                ProgressRing(
                    progress: stats.completion,
                    lineWidth: 5,
                    color: Theme.onMedia,
                    track: Theme.onMedia.opacity(0.22)
                )
                .frame(width: 46, height: 46)
                .overlay {
                    Text(completionText)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.onMedia)
                }
                .padding(.bottom, 2)
            }

            Text(monthCoverNote(stats))
                .font(AppType.caption)
                .foregroundStyle(Theme.onMedia.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(Theme.onMedia.opacity(0.22))
                .frame(height: 1)

            HStack(spacing: 10) {
                monthStat(
                    value: Int(stats.volume).formatted(),
                    unit: "kg",
                    label: "训练容量"
                )
                monthStat(
                    value: "\(stats.minutes)",
                    unit: "分钟",
                    label: "累计时长"
                )
                monthStat(
                    value: stats.plannedDays == 0
                        ? "—"
                        : "\(stats.completedPlanDays)/\(stats.plannedDays)",
                    unit: "",
                    label: "计划完成"
                )
            }
        }
        .padding(18)
        .background(
            Theme.inkSolid,
            in: RoundedRectangle(cornerRadius: AppLayout.heroCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppLayout.heroCornerRadius, style: .continuous)
                .strokeBorder(Theme.ink, lineWidth: 1.5)
        }
    }

    func monthStat(value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.onMedia)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.onMedia.opacity(0.78))
                }
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.onMedia.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func monthCoverNote(_ stats: MonthStats) -> String {
        if isFutureVisibleMonth {
            return "\(monthLabel)还没开始。先把计划排好，到时候按页练。"
        }
        if stats.sessions == 0 {
            if isCurrentVisibleMonth {
                return "这个月还没有训练记录。今天写下第一笔，就有得翻了。"
            }
            return "这个月没有训练记录。空页也是记录的一部分。"
        }
        if isCurrentVisibleMonth {
            let remaining = max(
                0,
                store.currentWeekPlannedCount - store.currentWeekCompletedCount
            )
            if remaining > 0 {
                return "本周还差 \(remaining) 次训练，日历上已经留好位置。"
            }
            return "本周计划已经完成。剩下的时间留给恢复。"
        }
        return "这是 \(monthLabel) 的记录，训练和饮食都留在这本账里。"
    }

    var isCurrentVisibleMonth: Bool {
        calendar.isDate(visibleMonth, equalTo: Date(), toGranularity: .month)
    }

    var isFutureVisibleMonth: Bool {
        startOfMonth(visibleMonth) > startOfMonth(Date())
    }

    var monthLabel: String {
        "\(calendar.component(.month, from: visibleMonth))月"
    }
}
