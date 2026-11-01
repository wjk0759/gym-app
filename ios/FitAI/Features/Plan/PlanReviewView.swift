import SwiftUI

struct PlanReviewView: View {
    @Environment(AppStore.self) private var store

    @State private var period: ReviewPeriod = .month
    @State private var review: ReviewData?

    var body: some View {
        AppScrollView {
            LazyVStack(spacing: 16) {
                if let review {
                    header(review)
                    periodPicker
                    trendSummary(review)
                    kpiGrid(review)
                    trainingCard(review)
                    nutritionCard(review)
                    recentCard(review)
                } else {
                    reviewHeaderPlaceholder
                    periodPicker
                    reviewLoadingCard
                }
            }
            .appPagePadding()
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AppBackground())
        .navigationTitle("数据复盘")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task(id: period) {
            await loadReview()
        }
    }

    private var reviewHeaderPlaceholder: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("REVIEW / 数据复盘")
                .font(AppType.overline)
                .tracking(1.5)
                .foregroundStyle(Theme.cobalt)
            Text("\(period.title)复盘")
                .font(AppType.display)
                .tracking(-0.9)
                .foregroundStyle(Theme.ink)
            Text("正在整理本期数据…")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reviewLoadingCard: some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(Theme.cobalt)
            Text("正在计算训练与饮食数据")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .card()
    }

    private func loadReview() async {
        review = nil
        let input = ReviewInput(store: store)
        let targetPeriod = period
        let data = await Task.detached(priority: .userInitiated) {
            PlanReviewEngine.make(input: input, period: targetPeriod)
        }.value
        guard !Task.isCancelled else { return }
        review = data
    }

    private func header(_ review: ReviewData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("REVIEW / 数据复盘")
                .font(AppType.overline)
                .tracking(1.5)
                .foregroundStyle(Theme.cobalt)
            Text("\(review.period.title)复盘")
                .font(AppType.display)
                .tracking(-0.9)
                .foregroundStyle(Theme.ink)
            Text("\(review.rangeLabel) · 对比\(review.period.previousTitle)")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var periodPicker: some View {
        AnimatedSegmentedControl(
            items: ReviewPeriod.allCases,
            selection: $period
        ) { $0.title }
    }

    private func trendSummary(_ review: ReviewData) -> some View {
        HStack(spacing: 12) {
            trendLegend(color: Theme.primary, text: "优于上期 \(review.goodCount)")
            trendLegend(color: Theme.secondary, text: "低于上期 \(review.badCount)")
            trendLegend(color: Theme.tertiaryText, text: "数据不足 \(review.insufficientCount)")
            Spacer(minLength: 0)
        }
        .font(.system(size: 9.5, weight: .medium))
    }

    private func trendLegend(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(text)
                .foregroundStyle(Theme.tertiaryText)
        }
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
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                Spacer()
                Text(kpi.trend.direction == .up ? "↑" : kpi.trend.direction == .down ? "↓" : "→")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(toneColor(kpi.trend.tone))
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(kpi.display)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(toneColor(kpi.trend.tone))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(kpi.unit)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
            }
            Text(kpi.trend.text)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(toneColor(kpi.trend.tone))
                .lineLimit(1)
            Text("上期 \(kpi.previousDisplay) · \(kpi.note)")
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(toneColor(kpi.trend.tone).opacity(0.18), lineWidth: 1)
        }
    }

    private func trainingCard(_ review: ReviewData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("训练明细")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(review.current.trainingDays) 个训练日")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }
            HStack(spacing: 6) {
                detailMetric("\(Int(review.current.volume))", "总容量 kg")
                detailMetric("\(review.current.sets)", "总组数")
                detailMetric(formatMinutes(review.current.averageSessionMinutes), "单次分钟")
                detailMetric("\(review.current.sessions.count)", "完成训练")
            }
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
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(current.hasNutrition
                     ? "有记录日均 · \(current.loggedFoodDays)/\(review.periodDays) 天"
                     : "\(review.periodDays) 天暂无记录")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }
            HStack(spacing: 6) {
                macroMetric("热量", current.averageIntake.map { "\(Int($0))" } ?? "—", "目标 \(targets.kcal)")
                macroMetric("蛋白质", current.hasNutrition ? "\(Int(current.totalProtein / Double(max(1, current.loggedFoodDays))))g" : "—", "目标 \(targets.protein)g")
                macroMetric("碳水", current.hasNutrition ? "\(Int(current.totalCarbs / Double(max(1, current.loggedFoodDays))))g" : "—", "目标 \(targets.carbs)g")
                macroMetric("脂肪", current.hasNutrition ? "\(Int(current.totalFat / Double(max(1, current.loggedFoodDays))))g" : "—", "目标 \(targets.fat)g")
            }
            Text("膳食纤维 \(fiberValue)g / 目标 \(targets.fiber)g")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
            Text("日均值只按有记录的天计算；未记录的天不当作 0 摄入。")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    private func recentCard(_ review: ReviewData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(review.period.title)训练记录")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                NavigationLink {
                    WorkoutHistoryView()
                } label: {
                    Text("全部训练 ›")
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.cobalt)
                }
                .buttonStyle(.plain)
            }
            if review.current.sessions.isEmpty {
                Text("这个周期还没有训练记录，可以在日历中补录。")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.tertiaryText)
            } else {
                ForEach(review.current.sessions.prefix(3)) { session in
                    NavigationLink {
                        WorkoutDetailView(session: session)
                    } label: {
                        HStack(spacing: 7) {
                            Text(session.date.formatted(.dateTime.month().day()))
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Theme.cobalt)
                                .frame(width: 42, alignment: .leading)
                            Text(session.dayTitle)
                                .font(AppType.caption.weight(.medium))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Spacer()
                            Text("\(session.durationMinutes) 分钟 · \(Int(session.volume)) kg")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Theme.tertiaryText)
                        }
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    if let last = review.current.sessions.prefix(3).last, session.id != last.id {
                        InkDivider()
                    }
                }
            }
        }
        .card()
    }

    private func detailMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            Theme.ink.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    private func macroMetric(_ label: String, _ value: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(note)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            Theme.ink.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    private func toneColor(_ tone: ReviewTrend.Tone) -> Color {
        switch tone {
        case .good: return Theme.ink
        case .bad: return Theme.secondary
        case .flat: return Theme.secondaryText
        case .muted: return Theme.tertiaryText
        }
    }

    private func formatMinutes(_ value: Double) -> String {
        value > 0 ? String(format: "%.0f", value) : "—"
    }
}
