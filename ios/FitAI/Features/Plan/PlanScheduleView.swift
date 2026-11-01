import SwiftUI

struct PlanScheduleView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var weeks: Int {
        max(4, store.plan?.weeks ?? 4)
    }

    @State private var startDate = FitnessDate.startOfDay(Date())
    @State private var daysPerWeek = 3
    @State private var selected = Set<String>()
    @State private var didLoad = false
    @State private var message = ""

    private var calendar: Calendar { FitnessDate.calendar }

    private struct ScheduleBlock: Identifiable {
        let id: Int
        let start: Date
        let end: Date
        let dates: [Date]
    }

    private var blocks: [ScheduleBlock] {
        (0..<weeks).map { index in
            let start = FitnessDate.addingDays(index * 7, to: startDate)
            let dates = (0..<7).map { FitnessDate.addingDays($0, to: start) }
            return ScheduleBlock(
                id: index,
                start: start,
                end: FitnessDate.addingDays(6, to: start),
                dates: dates
            )
        }
    }

    private var counts: [Int] {
        blocks.map { block in
            block.dates.filter { selected.contains(FitnessDate.key($0)) }.count
        }
    }

    private var canSave: Bool {
        selectedCount > 0 && store.plan != nil
    }

    private var selectedCount: Int {
        counts.reduce(0, +)
    }

    /// 比基准每周天数少选的日期，会在保存时标记为跳过。
    private var skippedCount: Int {
        counts.reduce(0) { $0 + max(0, daysPerWeek - $1) }
    }

    /// The board starts from today, so columns follow today's weekday rather
    /// than an assumed Monday-first week. Every block advances by seven days,
    /// which keeps the same weekday in each column.
    private var weekdayHeaders: [String] {
        guard let first = blocks.first else { return [] }
        return first.dates.map(weekdayShort)
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if store.plan == nil {
                        noPlanCard
                    } else {
                        overview
                        board
                        feedback

                        Button("保存训练日期") {
                            save()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.45)

                        Text("每周可以少于基准天数；少选会跳过对应训练。临时没空时，也可以回到训练手账，只顺延单次训练。")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.tertiaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .appPagePadding()
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(AppBackground())
            .navigationTitle("训练日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear(perform: load)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("SCHEDULE / 训练日期")
                .font(AppType.overline)
                .tracking(1.5)
                .foregroundStyle(Theme.cobalt)

            Text("排好这 \(weeks) 周")
                .font(AppType.display)
                .tracking(-0.9)
                .foregroundStyle(Theme.ink)

            Text("选训练日。少选会跳过对应训练，不算未完成。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var noPlanCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("还没有训练计划")
                .font(AppType.headline)
                .foregroundStyle(Theme.ink)
            Text("先生成一份 4 周计划，再回来调整每周训练日期。")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button("回训练手账") {
                store.selectedTab = 1
                dismiss()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .editorialCard(accent: Theme.lime)
    }

    private var overview: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("未来 \(weeks) 周")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Text("每周最多 \(daysPerWeek) 练 · \(store.profile.split.title)")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(selectedCount)")
                    .font(.system(size: 30, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                Text("已选天数")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .card()
    }

    // MARK: - Board

    private var board: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("训练日")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text("按周选择，点一下切换")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }

                Spacer(minLength: 4)

                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Theme.cobalt, lineWidth: 1.2)
                        .frame(width: 7, height: 7)
                    Text("今天")
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
            }

            HStack(spacing: 4) {
                ForEach(weekdayHeaders, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 2)

            VStack(spacing: 0) {
                ForEach(blocks) { block in
                    weekRow(block)

                    if block.id != blocks.last?.id {
                        InkDivider()
                    }
                }
            }
        }
        .card()
    }

    private func weekRow(_ block: ScheduleBlock) -> some View {
        let count = counts[block.id]
        let isFull = count >= daysPerWeek

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("第 \(block.id + 1) 周")
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)

                Text("\(FitnessDate.short(block.start))–\(FitnessDate.short(block.end))")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                Text("\(count)/\(daysPerWeek)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(count == 0 ? Theme.ink : Theme.secondary)
            }

            HStack(spacing: 4) {
                ForEach(block.dates, id: \.self) { date in
                    dayButton(date, block: block.id, weekFull: isFull)
                }
            }
        }
        .padding(.vertical, 7)
    }

    private func dayButton(
        _ date: Date,
        block: Int,
        weekFull: Bool
    ) -> some View {
        let key = FitnessDate.key(date)
        let active = selected.contains(key)
        let isToday = calendar.isDateInToday(date)

        return Button {
            Haptics.select()
            withAnimation(Motion.quick) {
                toggle(date, block: block)
            }
        } label: {
            VStack(spacing: 1) {
                Text("\(calendar.component(.day, from: date))")
                    .font(
                        .system(
                            size: 12,
                            weight: active ? .bold : .semibold,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(active ? Theme.paper : Theme.ink)

                if active {
                    Circle()
                        .fill(Theme.lime)
                        .frame(width: 3, height: 3)
                } else if isToday {
                    Circle()
                        .stroke(Theme.cobalt, lineWidth: 1)
                        .frame(width: 3, height: 3)
                } else {
                    Color.clear.frame(width: 3, height: 3)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        active
                            ? Theme.ink
                            : (isToday ? Theme.cobalt.opacity(0.06) : Theme.paper)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(
                        isToday && !active
                            ? Theme.cobalt
                            : (active ? Theme.ink : Theme.stroke),
                        lineWidth: isToday && !active ? 1.4 : 1
                    )
            }
            .opacity(!active && weekFull ? 0.45 : 1)
        }
        .buttonStyle(SubtlePressStyle(scale: 0.94))
        .accessibilityLabel(
            "\(FitnessDate.short(date))，\(active ? "已选训练日" : "未选")"
        )
    }

    // MARK: - Feedback

    private var feedback: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Circle()
                    .fill(selectedCount == 0 ? Theme.primary : Theme.secondary)
                    .frame(width: 5, height: 5)
                Text(
                    selectedCount == 0
                        ? "至少选择一个训练日"
                        : "已选 \(selectedCount) 天 · 每周最多 \(daysPerWeek) 天"
                )
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(
                    selectedCount == 0 ? Theme.ink : Theme.secondaryText
                )
            }

            if skippedCount > 0 {
                Text("有 \(skippedCount) 个原训练日会被标记为跳过，不会算作未完成。")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.coral)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Data

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let plan = store.plan, !plan.days.isEmpty else {
            message = "当前计划没有可调整的训练日期"
            return
        }
        daysPerWeek = min(7, max(1, plan.weeklyDays ?? max(1, plan.days.count / max(1, plan.weeks))))
        startDate = FitnessDate.startOfDay(Date())
        let offsets = defaultOffsets[daysPerWeek] ?? [0]
        for block in blocks {
            let blockDays = plan.days.filter { day in
                guard let dayDate = plan.scheduledDate(for: day) else { return false }
                let diff = calendar.dateComponents(
                    [.day],
                    from: startDate,
                    to: FitnessDate.startOfDay(dayDate)
                ).day ?? -1
                return diff >= block.id * 7 && diff < (block.id + 1) * 7
            }
            var chosen = Array(Set(
                blockDays
                    .filter { $0.date != nil && $0.skippedAt == nil }
                    .compactMap { plan.scheduledDate(for: $0) }
                    .map { FitnessDate.key($0) }
            )).sorted()
            if chosen.count > daysPerWeek {
                chosen = Array(chosen.prefix(daysPerWeek))
            }
            // 老计划没有具体日期时，才填充默认训练日；已有日期的周不强制补满。
            let hasExplicitDate = blockDays.contains { $0.date != nil }
            if chosen.isEmpty && !hasExplicitDate {
                for offset in offsets where chosen.count < daysPerWeek {
                    let key = FitnessDate.key(FitnessDate.addingDays(offset, to: block.start))
                    if !chosen.contains(key) {
                        chosen.append(key)
                    }
                }
            }
            chosen.sorted().forEach { selected.insert($0) }
        }
    }

    private func toggle(_ date: Date, block: Int) {
        let key = FitnessDate.key(date)
        if selected.contains(key) {
            selected.remove(key)
            message = ""
            return
        }
        guard counts[block] < daysPerWeek else {
            message = "这周已选满 \(daysPerWeek) 天，先取消一个日期"
            return
        }
        selected.insert(key)
        message = ""
    }

    private func save() {
        guard canSave else { return }
        var selection: [Int: [Date]] = [:]
        for block in blocks {
            let dates = block.dates.filter { selected.contains(FitnessDate.key($0)) }
            selection[block.id + 1] = dates
        }
        if store.applyPlanSchedule(selection) {
            dismiss()
        } else {
            message = "保存失败，请检查所选日期后重试"
        }
    }

    private var defaultOffsets: [Int: [Int]] {
        [
            1: [0],
            2: [0, 3],
            3: [0, 2, 4],
            4: [0, 1, 3, 5],
            5: [0, 1, 2, 4, 5],
            6: [0, 1, 2, 3, 4, 5],
            7: [0, 1, 2, 3, 4, 5, 6]
        ]
    }

    private func weekdayShort(_ date: Date) -> String {
        let index = (calendar.component(.weekday, from: date) + 5) % 7
        let labels = ["一", "二", "三", "四", "五", "六", "日"]
        return labels[max(0, min(labels.count - 1, index))]
    }
}
