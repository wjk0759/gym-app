import Charts
import Foundation
import SwiftUI

/// One place to answer “Am I changing?”. The old app scattered weight, body
/// fat, adherence and weekly review across several cards. This screen keeps
/// the story in one scroll and leaves Today for action.
struct ProgressOverviewView: View {
    @Environment(AppStore.self) private var store

    @State private var metric: MetricChoice = .weight
    @State private var showBodyCheckIn = false

    private enum MetricChoice: String, CaseIterable, Identifiable {
        case weight
        case bodyFat
        case waist

        var id: String { rawValue }

        var title: String {
            switch self {
            case .weight: return "体重"
            case .bodyFat: return "体脂"
            case .waist: return "腰围"
            }
        }

        var unit: String {
            switch self {
            case .weight: return "kg"
            case .bodyFat: return "%"
            case .waist: return "cm"
            }
        }
    }

    private var metrics: [BodyMetric] {
        store.bodyMetrics.sorted { $0.date < $1.date }
    }

    private var latest: BodyMetric? { metrics.last }
    private var first: BodyMetric? { metrics.first }

    private func metricValue(_ item: BodyMetric) -> Double {
        switch metric {
        case .weight: return item.weightKG
        case .bodyFat: return item.bodyFatPCT
        case .waist: return item.waistCM
        }
    }

    private var delta: Double {
        guard let first, let latest else { return 0 }
        return metricValue(latest) - metricValue(first)
    }

    var body: some View {
        AppScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                heroMetrics
                chartCard
                trainingCard
                nutritionCard
                goalCard(store.profile.goalType)
                reviewLink
                disclaimer
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .background(AppBackground())
        .navigationTitle("变化")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $showBodyCheckIn) {
            BodyCheckInSheet(manual: true)
                .presentationDetents([.medium, .large])
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showBodyCheckIn = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("记录身体数据")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THE LONG VIEW")
                .font(AppType.overline)
                .tracking(1.8)
                .foregroundStyle(Theme.cobalt)
            Text("变化")
                .font(AppType.display)
                .tracking(-0.8)
                .foregroundStyle(Theme.ink)
            Text("不是每天都要变，但一个月后应该看得出方向。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private var heroMetrics: some View {
        HStack(spacing: 10) {
            startMetric(
                title: "起点",
                value: first.map { String(format: "%.1f", metricValue($0)) } ?? "—",
                unit: metric.unit
            )
            startMetric(
                title: "现在",
                value: latest.map { String(format: "%.1f", metricValue($0)) } ?? "—",
                unit: metric.unit
            )
            startMetric(
                title: "变化",
                value: metrics.count > 1 ? String(format: "%+.1f", delta) : "—",
                unit: metric.unit,
                accent: delta <= 0 ? Theme.cobalt : Theme.coral
            )
        }
    }

    private func startMetric(
        title: String,
        value: String,
        unit: String,
        accent: Color = Theme.cobalt
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(AppType.micro)
                .foregroundStyle(Theme.tertiaryText)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(AppType.numberSmall)
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                Text(unit)
                    .font(AppType.micro)
                    .foregroundStyle(Theme.secondaryText)
            }
            Rectangle()
                .fill(accent)
                .frame(width: 22, height: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "趋势", subtitle: "最近 \(metrics.count) 次记录")
                Spacer()
                Picker("指标", selection: $metric) {
                    ForEach(MetricChoice.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
            }

            if metrics.isEmpty {
                EmptyStateView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "还没有身体数据",
                    message: "先记录一次体重，之后这里会显示趋势。"
                )
            } else {
                Chart(metrics) { item in
                    LineMark(
                        x: .value("日期", item.date),
                        y: .value(metric.title, metricValue(item))
                    )
                    .foregroundStyle(Theme.cobalt)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("日期", item.date),
                        y: .value(metric.title, metricValue(item))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.cobalt.opacity(0.18), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("日期", item.date),
                        y: .value(metric.title, metricValue(item))
                    )
                    .foregroundStyle(Theme.ink)
                    .symbolSize(22)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4))
                }
                .frame(height: 210)
            }
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private var trainingCard: some View {
        let recent = store.sessions.filter {
            $0.date >= Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
        }
        let weeks = max(1.0, 4.0)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "训练执行", subtitle: "最近 4 周")
                Spacer()
                Text("\(recent.count) 次")
                    .font(AppType.numberSmall)
                    .foregroundStyle(Theme.ink)
            }

            HStack(spacing: 8) {
                EditorialMetric(title: "总训练", value: "\(recent.count)", unit: "次")
                EditorialMetric(
                    title: "周均",
                    value: String(format: "%.1f", Double(recent.count) / weeks),
                    unit: "次"
                )
                EditorialMetric(
                    title: "总容量",
                    value: "\(Int(recent.reduce(0) { $0 + $1.volume }))",
                    unit: "kg"
                )
            }

            Text(recent.isEmpty ? "先完成一次训练，趋势会从这里开始。" : "稳定比一次练狠更重要。")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private var nutritionCard: some View {
        let days = Set(
            store.foodLogs
                .filter {
                    $0.date >= Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
                }
                .map { FitnessDate.key($0.date) }
        ).count
        let progress = min(1, Double(days) / 28)
        return HStack(spacing: 14) {
            ProgressRing(progress: progress, lineWidth: 7, color: Theme.lime)
                .frame(width: 58, height: 58)
                .overlay {
                    Text("\(Int(progress * 100))%")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.ink)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text("饮食记录")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Text("最近 28 天记录了 \(days) 天")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                Text(days == 0 ? "不用完美，先记一天。" : "记录本身就是反馈。")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.tertiaryText)
            }
            Spacer()
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private func goalCard(_ goal: GoalType) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.cobalt)
                .frame(width: 36, height: 36)
                .background(Theme.cobalt.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("当前目标 · \(goal.label)")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Text(goal.detail)
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private var reviewLink: some View {
        NavigationLink {
            PlanReviewView()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("训练复盘")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text("看动作、容量和 RPE 的详细变化")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.cobalt)
            }
            .padding(14)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
    }

    private var disclaimer: some View {
        Text("趋势比单次数字更重要。体重会受水分、盐分和生理期影响；不要用一天的数字否定自己。")
            .font(AppType.micro)
            .foregroundStyle(Theme.tertiaryText)
            .lineSpacing(2)
    }
}
