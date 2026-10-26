import SwiftUI

struct PeriodScheduleView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var month = FitnessDate.startOfMonth(Date())
    @State private var startKey: String?
    @State private var endKey: String?
    @State private var mode: PeriodTrainingMode = .light
    @State private var didLoad = false

    private var calendar: Calendar { FitnessDate.calendar }

    private var rangeStart: String? {
        guard let startKey else { return nil }
        return min(startKey, endKey ?? startKey)
    }

    private var rangeEnd: String? {
        guard let startKey else { return nil }
        return max(startKey, endKey ?? startKey)
    }

    private var rangeDays: Int {
        guard let rangeStart, let rangeEnd,
              let start = FitnessDate.date(from: rangeStart),
              let end = FitnessDate.date(from: rangeEnd) else { return 0 }
        return (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
    }

    private var monthTitle: String {
        let components = calendar.dateComponents([.year, .month], from: month)
        return "\(components.year ?? 0)年\(components.month ?? 0)月"
    }

    private var calendarDays: [Date] {
        let first = FitnessDate.startOfMonth(month)
        let weekday = calendar.component(.weekday, from: first)
        let offset = (weekday + 5) % 7
        let start = FitnessDate.addingDays(-offset, to: first)
        return (0..<42).map { FitnessDate.addingDays($0, to: start) }
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if store.profile.sex != .female {
                        EmptyStateView(
                            icon: "calendar.badge.exclamationmark",
                            title: "仅适用于女性用户",
                            message: "经期安排只会在女性用户的计划页中出现。"
                        )
                    } else {
                        header
                        modePicker
                        calendarCard
                        if let rangeStart, let rangeEnd {
                            Text("\(rangeStart) 至 \(rangeEnd) · \(rangeDays) 天")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                        } else if startKey != nil {
                            Text("再选择一个结束日期")
                                .font(.caption)
                                .foregroundStyle(Theme.warning)
                        } else {
                            Text("先点开始日期，再点结束日期")
                                .font(.caption)
                                .foregroundStyle(Theme.tertiaryText)
                        }
                        Button("保存经期区间") {
                            save()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(startKey == nil)
                        .opacity(startKey == nil ? 0.45 : 1)
                    }
                }
                .appPagePadding()
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(AppBackground())
            .navigationTitle("经期安排")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear(perform: load)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("选择经期区间")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("经期会显示在计划日历上；可设置为轻重量训练或直接休息。训练计划本身会保留。")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("经期训练安排")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.tertiaryText)
            HStack(spacing: 8) {
                ForEach(PeriodTrainingMode.allCases) { item in
                    Button {
                        mode = item
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(mode == item ? Color.black : .white)
                            Text(item.detail)
                                .font(.caption2)
                                .foregroundStyle(mode == item ? Color.black.opacity(0.7) : Theme.tertiaryText)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(11)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(mode == item ? Theme.accent : Theme.surfaceStrong)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    private var calendarCard: some View {
        VStack(spacing: 10) {
            HStack {
                Button { moveMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 34, height: 34)
                        .background(Theme.surfaceStrong, in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.secondaryText)

                Spacer()
                VStack(spacing: 2) {
                    Text(monthTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("点选经期区间")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                }
                Spacer()

                Button { moveMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 34, height: 34)
                        .background(Theme.surfaceStrong, in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.secondaryText)
            }

            HStack(spacing: 4) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(calendarDays, id: \.self) { date in
                    dayCell(date)
                }
            }
        }
        .card()
    }

    private func dayCell(_ date: Date) -> some View {
        let key = FitnessDate.key(date)
        let inMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
        let active = isSelected(key)
        let boundary = key == (rangeStart ?? "") || key == (rangeEnd ?? "")
        let isToday = calendar.isDateInToday(date)
        return Button {
            select(key)
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 12, weight: active ? .bold : .medium, design: .rounded))
                .foregroundStyle(active ? Color.white : (isToday ? Theme.accent : Theme.secondaryText))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(active ? Theme.danger.opacity(0.72) : Color.white.opacity(0.025))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(boundary ? Theme.danger : (isToday ? Theme.accent.opacity(0.5) : Color.clear), lineWidth: 1)
                )
                .opacity(inMonth ? 1 : 0.28)
        }
        .buttonStyle(.plain)
    }

    private func isSelected(_ key: String) -> Bool {
        guard let rangeStart, let rangeEnd else { return false }
        return key >= rangeStart && key <= rangeEnd
    }

    private func select(_ key: String) {
        if startKey == nil || (startKey != nil && endKey != nil) {
            startKey = key
            endKey = nil
        } else if let startKey, key < startKey {
            self.endKey = startKey
            self.startKey = key
        } else {
            endKey = key
        }
    }

    private func moveMonth(_ amount: Int) {
        month = calendar.date(byAdding: .month, value: amount, to: month) ?? month
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        startKey = store.profile.periodRangeStart
        endKey = store.profile.periodRangeEnd
        mode = store.profile.periodTrainingMode
        if let startKey, let start = FitnessDate.date(from: startKey) {
            month = FitnessDate.startOfMonth(start)
        }
    }

    private func save() {
        guard let startKey else { return }
        let end = endKey ?? startKey
        if store.savePeriodRange(startKey: startKey, endKey: end, mode: mode) {
            dismiss()
        }
    }
}
