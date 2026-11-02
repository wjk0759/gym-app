import SwiftUI
import Charts

extension ProgressOverviewView {
    var header: some View {
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

    var heroMetrics: some View {
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
                accent: delta <= 0 ? Theme.primary : Theme.secondary
            )
        }
    }

    func startMetric(
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

    var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    chartTitle
                    Spacer()
                    chartMetricPicker
                }
                VStack(alignment: .leading, spacing: 8) {
                    chartTitle
                    chartMetricPicker
                }
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

    var chartTitle: some View {
        SectionTitle(title: "趋势", subtitle: "最近 \(metrics.count) 次记录")
    }

    var chartMetricPicker: some View {
        Picker("指标", selection: $metric) {
            ForEach(MetricChoice.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 210)
    }

    var disclaimer: some View {
        Text("体重会受水分、盐分和生理期影响，看趋势即可。")
            .font(AppType.micro)
            .foregroundStyle(Theme.tertiaryText)
            .lineSpacing(2)
    }
}
