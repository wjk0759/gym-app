import SwiftUI

struct PlanScheduleView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var weeks: Int {
        max(4, store.plan?.weeks ?? 4)
    }
    private let weekLabels = ["一", "二", "三", "四", "五", "六", "日"]

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
        selectedCount > 0
    }

    private var selectedCount: Int {
        counts.reduce(0, +)
    }

    /// 比基准每周天数少选的日期，会在保存时标记为跳过。
    private var skippedCount: Int {
        counts.reduce(0) { $0 + max(0, daysPerWeek - $1) }
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    overview
                    board
                    if !message.isEmpty {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(Theme.warning)
                    }
                    Text(selectedCount == 0
                         ? "至少选择一个训练日"
                         : "已选 \(selectedCount) 天 · 每周最多 \(daysPerWeek) 天")
                        .font(.caption)
                        .foregroundStyle(selectedCount == 0 ? Theme.warning : Theme.accent)

                    if skippedCount > 0 {
                        Text("有 \(skippedCount) 个原训练日会被标记为跳过，不会算作未完成。")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button("保存训练日期") {
                        save()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.45)

                    Text("每周可以少于基准天数；少选会跳过对应训练。临时没空时，也可以在今日页点「今天没空」只顺延单次训练。")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
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

    private var overview: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("未来 \(weeks) 周")
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                Text("每周最多 \(daysPerWeek) 练 · 可少选 · \(store.profile.split.title)")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Text("已选 \(selectedCount)")
                .font(.headline.weight(.bold))
                .foregroundStyle(selectedCount > 0 ? Theme.accent : Theme.warning)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Theme.surfaceStrong, in: Capsule())
        }
        .card()
    }

    private var board: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text("周")
                    .frame(width: 42, alignment: .leading)
                ForEach(weekLabels, id: \.self) { label in
                    Text(label)
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Theme.tertiaryText)
            .padding(.horizontal, 4)

            ForEach(blocks) { block in
                HStack(spacing: 4) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("第\(block.id + 1)周")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.primaryText)
                        Text("\(FitnessDate.short(block.start))–\(FitnessDate.short(block.end))")
                            .font(.system(size: 8))
                            .foregroundStyle(Theme.tertiaryText)
                        Text("\(counts[block.id])/\(daysPerWeek)")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(counts[block.id] == 0 ? Theme.warning : Theme.accent)
                    }
                    .frame(width: 52, alignment: .leading)

                    ForEach(block.dates, id: \.self) { date in
                        dayButton(date, block: block.id)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .card(padding: 12)
    }

    private func dayButton(_ date: Date, block: Int) -> some View {
        let key = FitnessDate.key(date)
        let active = selected.contains(key)
        let isToday = calendar.isDateInToday(date)
        return Button {
            toggle(date, block: block)
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 12, weight: active ? .bold : .medium, design: .rounded))
                .foregroundStyle(active ? Theme.onAccent : (isToday ? Theme.accent : Theme.secondaryText))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(active ? Theme.accent : (isToday ? Theme.accent.opacity(0.10) : Theme.surfaceStrong))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(isToday && !active ? Theme.accent.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(key)
    }

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
}
