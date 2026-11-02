import SwiftUI

extension PlanHomeView {
    // MARK: - Training data

    private var recentTrainingSessions: [WorkoutSession] {
        let end = Date()
        let start = calendar.date(
            byAdding: .day,
            value: -29,
            to: calendar.startOfDay(for: end)
        ) ?? end
        return store.sessions.filter { $0.date >= start && $0.date <= end }
    }

    private var trainingDataCard: some View {
        let recent = recentTrainingSessions
        let volume = recent.reduce(0) { $0 + $1.volume }
        let sets = recent.reduce(0) { $0 + $1.sets.filter(\.completed).count }
        let minutes = recent.reduce(0) { $0 + $1.durationMinutes }
        let bars = trainingWeekBars
        let recentSessions = recent.sorted { $0.date > $1.date }
        let averageMinutes = recent.isEmpty ? 0 : minutes / recent.count

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("训练数据")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text("最近 30 天 · 按实际训练日期统计")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }

                Spacer(minLength: 4)

                NavigationLink {
                    WorkoutHistoryView()
                } label: {
                    Text("全部记录 ›")
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.cobalt)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                dataMetric(value: "\(recent.count)", unit: "次", label: "训练")
                dataMetric(value: Int(volume).formatted(), unit: "kg", label: "容量")
                dataMetric(value: "\(sets)", unit: "组", label: "组数")
                dataMetric(value: "\(averageMinutes)", unit: "分钟", label: "平均")
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(bars.enumerated()), id: \.offset) { index, bar in
                    VStack(spacing: 5) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(index == bars.count - 1 ? Theme.lime : Theme.cobalt)
                            .frame(
                                height: CGFloat(
                                    max(
                                        4,
                                        64 * bar.value / max(bars.map { $0.value }.max() ?? 1, 1)
                                    )
                                )
                            )
                        Text(bar.label)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 88)

            if !recentSessions.isEmpty {
                InkDivider()

                Text("最近训练")
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)

                ForEach(recentSessions.prefix(3)) { session in
                    Button {
                        sessionSheet = SessionSheet(session: session, isNew: false)
                    } label: {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(session.dayTitle.prefix(40)))
                                    .font(AppType.callout)
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Theme.tertiaryText)
                            }

                            Spacer(minLength: 4)

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int(session.volume)) kg")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Theme.cobalt)
                                Text("\(session.durationMinutes) 分钟")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Theme.tertiaryText)
                            }

                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Theme.tertiaryText)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    private func dataMetric(value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(unit)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(
            Theme.ink.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    private var trainingWeekBars: [(label: String, value: Double)] {
        let monday = mondayOfWeek(Date())
        let labels = ["-3周", "-2周", "上周", "本周"]
        return (0..<4).map { index -> (label: String, value: Double) in
            let weekStart = calendar.date(
                byAdding: .day,
                value: -7 * (3 - index),
                to: monday
            ) ?? monday
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            let value = store.sessions
                .filter { $0.date >= weekStart && $0.date < weekEnd }
                .reduce(0) { $0 + $1.volume }
            return (label: labels[index], value: value)
        }
    }
}
