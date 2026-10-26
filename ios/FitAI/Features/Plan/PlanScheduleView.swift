import SwiftUI

struct PlanScheduleView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let weeks = 4
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

    private var complete: Bool {
        counts.allSatisfy { $0 == daysPerWeek }
    }

    private var selectedCount: Int {
        counts.reduce(0, +)
    }

    private var targetCount: Int { daysPerWeek * weeks }

    private var remainingCount: Int {
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
                    Text(complete
                         ? "已选满 \(targetCount) 个训练日"
                         : "还差 \(remainingCount) 个训练日")
                        .font(.caption)
                        .foregroundStyle(complete ? Theme.accent : Theme.tertiaryText)

                    Button("保存训练日期") {
                        save()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!complete)
                    .opacity(complete ? 1 : 0.45)
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
                    .foregroundStyle(.white)
                Text("每周 \(daysPerWeek) 练 · \(store.profile.split.title)")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Text("\(selectedCount)/\(targetCount)")
                .font(.headline.weight(.bold))
                .foregroundStyle(complete ? Theme.accent : Theme.warning)
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
                            .foregroundStyle(.white)
                        Text("\(FitnessDate.short(block.start))–\(FitnessDate.short(block.end))")
                            .font(.system(size: 8))
                            .foregroundStyle(Theme.tertiaryText)
                        Text("\(counts[block.id])/\(daysPerWeek)")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(counts[block.id] == daysPerWeek ? Theme.accent : Theme.warning)
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
                .foregroundStyle(active ? Color.black : (isToday ? Theme.accent : Theme.secondaryText))
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
        let offsets = defaultOffsets[daysPerWeek] ?? defaultOffsets[3]!
        for block in blocks {
            var chosen: [String] = []
            for day in plan.days {
                guard let dayDate = plan.scheduledDate(for: day) else { continue }
                let diff = calendar.dateComponents([.day], from: startDate, to: FitnessDate.startOfDay(dayDate)).day ?? -1
                if diff >= block.id * 7, diff < (block.id + 1) * 7 {
                    chosen.append(FitnessDate.key(dayDate))
                }
            }
            chosen = Array(Set(chosen)).sorted()
            if chosen.count > daysPerWeek {
                chosen = Array(chosen.prefix(daysPerWeek))
            }
            for offset in offsets where chosen.count < daysPerWeek {
                let key = FitnessDate.key(FitnessDate.addingDays(offset, to: block.start))
                if !chosen.contains(key) {
                    chosen.append(key)
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
        guard complete else { return }
        var selection: [Int: [Date]] = [:]
        for block in blocks {
            let dates = block.dates.filter { selected.contains(FitnessDate.key($0)) }
            selection[block.id + 1] = dates
        }
        if store.applyPlanSchedule(selection) {
            dismiss()
        } else {
            message = "保存失败，请确认每周选满 \(daysPerWeek) 天"
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
