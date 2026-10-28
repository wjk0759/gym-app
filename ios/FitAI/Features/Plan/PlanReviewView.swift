import SwiftUI

struct PlanReviewView: View {
    @Environment(AppStore.self) private var store

    @State private var period: ReviewPeriod = .month

    var body: some View {
        let review = PlanReviewEngine.make(store: store, period: period)

        return AppScrollView {
            VStack(spacing: 16) {
                header(review)
                periodPicker
                trendSummary(review)
                kpiGrid(review)
                trainingCard(review)
                nutritionCard(review)
                recentCard(review)
            }
            .appPagePadding()
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AppBackground())
        .navigationTitle("数据复盘")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ review: ReviewData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(review.period.title)复盘")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
            Text("\(review.rangeLabel) · 对比\(review.period.previousTitle)")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var periodPicker: some View {
        HStack(spacing: 6) {
            ForEach(ReviewPeriod.allCases) { item in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        period = item
                    }
                } label: {
                    Text(item.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(period == item ? Theme.onAccent : Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            Capsule().fill(period == item ? Theme.accent : Theme.surfaceStrong)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .card(padding: 6)
    }

    private func trendSummary(_ review: ReviewData) -> some View {
        HStack(spacing: 12) {
            Text("↑ 优于上期 \(review.goodCount)")
                .foregroundStyle(Theme.accent)
            Text("↓ 低于上期 \(review.badCount)")
                .foregroundStyle(Theme.danger)
            Text("· 数据不足 \(review.insufficientCount)")
                .foregroundStyle(Theme.tertiaryText)
            Spacer()
        }
        .font(.caption2)
    }

    private func kpiGrid(_ review: ReviewData) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            spacing: 8
        ) {
            ForEach(review.kpis) { kpi in
                kpiCard(kpi)
            }
        }
    }

    private func kpiCard(_ kpi: ReviewKPI) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(kpi.label)
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                Spacer()
                Text(kpi.trend.direction == .up ? "↑" : kpi.trend.direction == .down ? "↓" : "→")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(toneColor(kpi.trend.tone))
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(kpi.display)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(toneColor(kpi.trend.tone))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(kpi.unit)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
            }
            Text(kpi.trend.text)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(toneColor(kpi.trend.tone))
                .lineLimit(1)
            Text("上期 \(kpi.previousDisplay) · \(kpi.note)")
                .font(.system(size: 8.5))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(toneColor(kpi.trend.tone).opacity(0.18), lineWidth: 1)
        )
    }

    private func trainingCard(_ review: ReviewData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("训练明细")
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text("\(review.current.trainingDays) 个训练日")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }
            HStack(spacing: 6) {
                detailMetric("\(Int(review.current.volume))", "总容量 kg")
                detailMetric("\(review.current.sets)", "总组数")
                detailMetric(formatMinutes(review.current.averageSessionMinutes), "单次分钟")
                detailMetric("\(review.current.sessions.count)", "完成训练")
            }
            Text("平均每日时长 = 周期内训练总分钟 ÷ 周期天数。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    private func nutritionCard(_ review: ReviewData) -> some View {
        let current = review.current
        let targets = DietPlanner.targets(profile: store.profile)
        let fiberValue = current.hasNutrition
            ? "\(Int(current.totalFiber / Double(max(1, current.loggedFoodDays))))"
            : "—"
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("饮食营养")
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text(current.hasNutrition
                     ? "有记录日均 · \(current.loggedFoodDays)/\(review.periodDays) 天"
                     : "\(review.periodDays) 天暂无记录")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }
            HStack(spacing: 6) {
                macroMetric("热量", current.averageIntake.map { "\(Int($0))" } ?? "—", "目标 \(targets.kcal)")
                macroMetric("蛋白质", current.hasNutrition ? "\(Int(current.totalProtein / Double(max(1, current.loggedFoodDays))))g" : "—", "目标 \(targets.protein)g")
                macroMetric("碳水", current.hasNutrition ? "\(Int(current.totalCarbs / Double(max(1, current.loggedFoodDays))))g" : "—", "目标 \(targets.carbs)g")
                macroMetric("脂肪", current.hasNutrition ? "\(Int(current.totalFat / Double(max(1, current.loggedFoodDays))))g" : "—", "目标 \(targets.fat)g")
            }
            Text("膳食纤维 \(fiberValue)g / 目标 \(targets.fiber)g")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
            Text("日均值只按有记录的天计算；未记录的天不当作 0 摄入。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    private func recentCard(_ review: ReviewData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(review.period.title)训练记录")
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                NavigationLink {
                    WorkoutHistoryView()
                } label: {
                    Text("全部训练 ›")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
            if review.current.sessions.isEmpty {
                Text("这个周期还没有训练记录，可以在日历中补录。")
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)
            } else {
                ForEach(review.current.sessions.prefix(3)) { session in
                    NavigationLink {
                        WorkoutDetailView(session: session)
                    } label: {
                        HStack(spacing: 7) {
                            Text(session.date.formatted(.dateTime.month().day()))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(Theme.accent)
                                .frame(width: 42, alignment: .leading)
                            Text(session.dayTitle)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.primaryText)
                                .lineLimit(1)
                            Spacer()
                            Text("\(session.durationMinutes) 分钟 · \(Int(session.volume)) kg")
                                .font(.system(size: 9.5))
                                .foregroundStyle(Theme.tertiaryText)
                        }
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    if let last = review.current.sessions.prefix(3).last, session.id != last.id {
                        Divider().overlay(Theme.stroke)
                    }                }
            }
        }
        .card()
    }

    private func detailMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 8.5))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func macroMetric(_ label: String, _ value: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8.5))
                .foregroundStyle(Theme.tertiaryText)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(note)
                .font(.system(size: 8))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func toneColor(_ tone: ReviewTrend.Tone) -> Color {
        switch tone {
        case .good: return Theme.accent
        case .bad: return Theme.danger
        case .flat: return Theme.secondaryText
        case .muted: return Theme.tertiaryText
        }
    }

    private func formatMinutes(_ value: Double) -> String {
        value > 0 ? String(format: "%.0f", value) : "—"
    }
}
