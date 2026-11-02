import SwiftUI
import Charts

extension EquipmentItemDetailView {
func statsContent(for item: EquipmentItem) -> some View {
        let stats = detailStats(for: item)
        let lastValue = stats.points.last.map {
            formattedMetricValue(metricValue($0, metric: statsMetric), metric: statsMetric)
        } ?? "—"
        let volumeValue = stats.sessions > 0 ? Int(stats.volume).formatted() : "—"
        let weightValue = stats.sessions > 0
            ? (stats.maxWeight > 0 ? formattedMetricValue(stats.maxWeight, metric: .maxWeight) : "自重")
            : "—"
        let oneRepMaxValue = stats.sessions > 0 && stats.best1RM > 0
            ? formattedMetricValue(stats.best1RM, metric: .oneRepMax)
            : "—"
        let chartValues = stats.points.map { metricValue($0, metric: statsMetric) }
        let chartCeiling = max(chartValues.max() ?? 0, 1) * 1.12

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                statMetric(volumeValue, label: "容量记录", note: "kg · 累计")
                statMetric(weightValue, label: "重量记录", note: "kg · 单组最重")
                statMetric(oneRepMaxValue, label: "1RM 预测", note: "kg · Epley")
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("记录趋势")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.tertiaryText)
                    Text(statsMetric.rawValue)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }

                Spacer(minLength: 8)

                Text("\(lastValue) \(statsMetric.unit)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.cobalt)
            }
            .padding(.top, 18)

            Text("统计周期")
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.tertiaryText)
                .padding(.top, 16)

            HStack(spacing: 4) {
                ForEach(EquipmentStatsPeriod.allCases) { period in
                    statsOption(period.rawValue, active: statsPeriod == period) {
                        statsPeriod = period
                    }
                }
            }
            .padding(.top, 6)

            if statsPeriod == .custom {
                Button {
                    Haptics.tap()
                    showCustomRange = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.cobalt)

                        Text(customRangeLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Spacer(minLength: 6)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    .padding(.horizontal, 11)
                    .frame(height: 40)
                    .background(
                        Theme.paper,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Theme.stroke, lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .sheet(isPresented: $showCustomRange) {
                    EquipmentStatsRangeSheet(
                        start: customStart,
                        end: customEnd
                    ) { start, end in
                        customStart = start
                        customEnd = end
                    }
                }

                if customRangeInvalid {
                    Text("开始日期不能晚于结束日期。")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.danger)
                        .padding(.top, 6)
                }
            }

            HStack(spacing: 4) {
                ForEach(EquipmentStatsMetric.allCases) { metric in
                    statsOption(metric.rawValue, active: statsMetric == metric) {
                        statsMetric = metric
                    }
                }
            }
            .padding(.top, 10)

            if stats.points.isEmpty {
                VStack(spacing: 5) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(width: 30, height: 30)
                        .background(Theme.ink.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text("这个周期还没有训练记录")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                    Text("换一个周期，或完成一次这个动作的训练。")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.tertiaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
                .background(
                    Theme.paper,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.stroke, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                )
                .padding(.top, 10)
            } else {
                Chart(stats.points) { point in
                    AreaMark(
                        x: .value("日期", point.date),
                        y: .value(statsMetric.rawValue, metricValue(point, metric: statsMetric))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.cobalt.opacity(0.26), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("日期", point.date),
                        y: .value(statsMetric.rawValue, metricValue(point, metric: statsMetric))
                    )
                    .foregroundStyle(Theme.cobalt)
                    .lineStyle(
                        StrokeStyle(
                            lineWidth: 2.3,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("日期", point.date),
                        y: .value(statsMetric.rawValue, metricValue(point, metric: statsMetric))
                    )
                    .foregroundStyle(Theme.cobalt)
                    .symbolSize(24)
                }
                .chartYScale(domain: 0.0...chartCeiling)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                            .foregroundStyle(Theme.stroke.opacity(0.65))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date.formatted(.dateTime.month().day()))
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                            .foregroundStyle(Theme.stroke.opacity(0.65))
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text("\(Int(number.rounded()))")
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(Theme.paper.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .frame(height: 180)
                .padding(.top, 10)
            }

            Text("1RM 为估算值，仅用于趋势对比。")
                .font(.system(size: 9))
                .foregroundStyle(Theme.tertiaryText)
                .lineSpacing(2)
                .padding(.top, 9)
        }
    }

func statMetric(_ value: String, label: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Theme.tertiaryText)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(note)
                .font(.system(size: 8))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            Color.white.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
        )
    }

func statsOption(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(active ? Theme.cobalt : Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    active ? Theme.cobalt.opacity(0.12) : Color.white.opacity(0.035),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(
                            active ? Theme.cobalt.opacity(0.28) : Color.white.opacity(0.07),
                            lineWidth: 0.8
                        )
                )
        }
        .buttonStyle(.plain)
    }

func allChartPoints(for item: EquipmentItem) -> [EquipmentChartPoint] {
        guard let slug = item.slug else { return [] }

        var points: [EquipmentChartPoint] = []
        for session in store.sessions {
            let matching = session.sets.filter { $0.slug == slug && $0.completed }
            guard !matching.isEmpty else { continue }

            let volume = matching.reduce(0.0) { partial, log in
                partial + log.weightKG * Double(log.reps)
            }
            let maxWeight = matching.map(\.weightKG).max() ?? 0
            let estimated1RM = matching.reduce(0.0) { partial, log in
                guard log.weightKG > 0 else { return partial }
                let estimate = log.weightKG * (1 + Double(log.reps) / 30)
                return max(partial, estimate)
            }

            points.append(
                EquipmentChartPoint(
                    date: session.date,
                    volume: volume,
                    sets: matching.count,
                    maxWeight: maxWeight,
                    estimated1RM: estimated1RM
                )
            )
        }

        return points.sorted { $0.date < $1.date }
    }

func detailStats(for item: EquipmentItem) -> EquipmentDetailStats {
        let all = allChartPoints(for: item)
        let now = Date()
        let calendar = Calendar.current
        let start: Date?
        let end: Date?

        switch statsPeriod {
        case .week:
            start = calendar.date(byAdding: .day, value: -7, to: now)
            end = now
        case .month:
            start = calendar.date(byAdding: .day, value: -30, to: now)
            end = now
        case .ninetyDays:
            start = calendar.date(byAdding: .day, value: -90, to: now)
            end = now
        case .all:
            start = nil
            end = nil
        case .custom:
            if customRangeInvalid { return EquipmentDetailStats() }
            start = calendar.startOfDay(for: customStart)
            end = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: customEnd)
            )
        }

        let points = all.filter { point in
            if let start, point.date < start { return false }
            if let end, point.date >= end { return false }
            return true
        }

        return EquipmentDetailStats(
            points: points,
            sessions: points.count,
            sets: points.reduce(0) { $0 + $1.sets },
            volume: points.reduce(0) { $0 + $1.volume },
            maxWeight: points.reduce(0) { max($0, $1.maxWeight) },
            best1RM: points.reduce(0) { max($0, $1.estimated1RM) },
            last: points.last?.date
        )
    }

func statsLead(for item: EquipmentItem) -> String {
        if customRangeInvalid {
            return "开始日期不能晚于结束日期。"
        }
        let stats = detailStats(for: item)
        guard stats.sessions > 0 else {
            return "所选周期还没有这个动作的训练记录。"
        }
        let last = stats.last?.formatted(.dateTime.month().day().hour().minute()) ?? ""
        return "\(statsPeriod.rawValue) · \(stats.sessions) 次训练 / \(stats.sets) 组\(last.isEmpty ? "" : "，最近一次 \(last)")。"
    }

func metricValue(_ point: EquipmentChartPoint, metric: EquipmentStatsMetric) -> Double {
        switch metric {
        case .volume:
            return point.volume
        case .sets:
            return Double(point.sets)
        case .maxWeight:
            return point.maxWeight
        case .oneRepMax:
            return point.estimated1RM
        }
    }

func formattedMetricValue(_ value: Double, metric: EquipmentStatsMetric) -> String {
        if metric == .sets {
            return "\(Int(value.rounded()))"
        }
        guard value > 0 else { return "—" }
        return value.rounded() == value
            ? Int(value).formatted()
            : String(format: "%.1f", value)
    }
}

enum EquipmentStatsPeriod: String, CaseIterable, Identifiable, Equatable {
    case week = "7天"
    case month = "30天"
    case ninetyDays = "90天"
    case all = "全部"
    case custom = "自定义"

    var id: String { rawValue }
}

enum EquipmentStatsMetric: String, CaseIterable, Identifiable, Equatable {
    case volume = "容量"
    case sets = "组数"
    case maxWeight = "最大重量"
    case oneRepMax = "1RM 估算"

    var id: String { rawValue }

    var unit: String {
        switch self {
        case .sets:
            return "组"
        default:
            return "kg"
        }
    }
}

struct EquipmentChartPoint: Identifiable {
    let id: UUID
    let date: Date
    let volume: Double
    let sets: Int
    let maxWeight: Double
    let estimated1RM: Double

    init(date: Date, volume: Double, sets: Int, maxWeight: Double, estimated1RM: Double) {
        self.id = UUID()
        self.date = date
        self.volume = volume
        self.sets = sets
        self.maxWeight = maxWeight
        self.estimated1RM = estimated1RM
    }
}

struct EquipmentDetailStats {
    var points: [EquipmentChartPoint] = []
    var sessions: Int = 0
    var sets: Int = 0
    var volume: Double = 0
    var maxWeight: Double = 0
    var best1RM: Double = 0
    var last: Date?
}

struct EquipmentStatsRangeSheet: View {
    @Environment(\.dismiss) var dismiss

    @State var start: Date
    @State var end: Date
    let onApply: (Date, Date) -> Void

    init(start: Date, end: Date, onApply: @escaping (Date, Date) -> Void) {
        _start = State(initialValue: start)
        _end = State(initialValue: end)
        self.onApply = onApply
    }

    var invalid: Bool {
        start > end
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(spacing: 8) {
                        dateRow("开始日期", selection: $start)
                        dateRow("结束日期", selection: $end)
                    }

                    if invalid {
                        Label("开始日期不能晚于结束日期", systemImage: "exclamationmark.circle.fill")
                            .font(AppType.caption)
                            .foregroundStyle(Theme.danger)
                    }

                    Text("只影响下方的趋势和汇总，不会修改训练记录。")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                        .padding(.top, 2)
                }
                .padding(20)
            }
            .background(AppBackground())
            .navigationTitle("自定义统计周期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        onApply(start, end)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(invalid)
                }
            }
        }
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.background)
    }

    func dateRow(_ title: String, selection: Binding<Date>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(AppType.callout)
                .foregroundStyle(Theme.ink)

            Spacer(minLength: 8)

            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .fixedSize()
                .tint(Theme.cobalt)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 0.8)
        )
    }
}
