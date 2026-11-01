import SwiftUI

struct PeriodScheduleView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                        unavailableCard
                    } else {
                        header
                        modePicker
                        calendarCard
                        rangeStatus
                        Button("保存经期区间") {
                            save()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(startKey == nil)
                        .opacity(startKey == nil ? 0.45 : 1)

                        Text("经期只影响这几天在计划和今日页的强度提示；训练计划本身不会被删除。")
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

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("CYCLE / 经期")
                .font(AppType.overline)
                .tracking(1.5)
                .foregroundStyle(Theme.cycle)

            Text("标记经期")
                .font(AppType.display)
                .tracking(-0.9)
                .foregroundStyle(Theme.ink)

            Text("经期会显示在计划日历上；训练计划保留，只调整这几天的强度。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("仅适用于女性用户")
                .font(AppType.headline)
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorialCard(accent: Theme.cycle)
    }

    // MARK: - Mode

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("这几天怎么练")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Text("计划保留，只调整强度")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            HStack(spacing: 8) {
                ForEach(PeriodTrainingMode.allCases) { item in
                    Button {
                        guard mode != item else { return }
                        Haptics.select()
                        withAnimation(Motion.resolved(Motion.quick, reduceMotion: reduceMotion)) {
                            mode = item
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                Image(systemName: item == .light ? "figure.walk" : "bed.double.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text(item.title)
                                    .font(AppType.caption.weight(.bold))
                            }
                            Text(item.detail)
                                .font(.system(size: 9, weight: .medium))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(
                            mode == item
                                ? Theme.onAccent
                                : Theme.secondaryText
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(11)
                        .background(
                            mode == item ? Theme.cycle : Theme.paper,
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(
                                    mode == item ? Theme.cycle : Theme.stroke,
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(SubtlePressStyle(scale: 0.97))
                }
            }
        }
        .card()
    }

    // MARK: - Calendar

    private var calendarCard: some View {
        let monthNumber = calendar.component(.month, from: month)
        let year = calendar.component(.year, from: month)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("经期日历")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text(startKey == nil ? "点开始日期，再点结束日期" : "点日期可重新选择区间")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }

                Spacer(minLength: 4)

                monthButton(systemName: "chevron.left") {
                    moveMonth(-1)
                }

                VStack(spacing: 1) {
                    Text("\(monthNumber)月")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(String(year))
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .frame(width: 62)

                monthButton(systemName: "chevron.right") {
                    moveMonth(1)
                }
            }

            HStack(spacing: 4) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 2)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                spacing: 4
            ) {
                ForEach(calendarDays, id: \.self) { date in
                    dayCell(date)
                }
            }

            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    Circle()
                        .stroke(Theme.cobalt, lineWidth: 1.2)
                        .frame(width: 7, height: 7)
                    Text("今天")
                }
                HStack(spacing: 5) {
                    Circle()
                        .fill(Theme.cycle)
                        .frame(width: 6, height: 6)
                    Text("经期区间")
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    private func monthButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            withAnimation(Motion.smooth) {
                action()
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 34, height: 34)
                .background(
                    Theme.ink.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                }
        }
        .buttonStyle(SubtlePressStyle())
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
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(
                        .system(
                            size: 11.5,
                            weight: boundary ? .bold : .semibold,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(
                        boundary
                            ? Theme.onAccent
                            : (active ? Theme.cycle : (inMonth ? Theme.ink : Theme.tertiaryText))
                    )
                    .frame(maxWidth: .infinity)

                if active {
                    Circle()
                        .fill(boundary ? Theme.onAccent : Theme.cycle)
                        .frame(width: 3.5, height: 3.5)
                } else if isToday {
                    Circle()
                        .stroke(Theme.cobalt, lineWidth: 1)
                        .frame(width: 3.5, height: 3.5)
                } else {
                    Color.clear.frame(width: 3.5, height: 3.5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        boundary
                            ? Theme.cycle
                            : (active
                                ? Theme.cycle.opacity(0.13)
                                : (isToday ? Theme.cobalt.opacity(0.04) : Color.clear))
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isToday && !active ? Theme.cobalt : Color.clear,
                        lineWidth: 1.4
                    )
            }
            .opacity(inMonth ? 1 : 0.3)
            .scaleEffect(boundary ? 1.03 : 1)
            .animation(Motion.quick, value: active)
        }
        .buttonStyle(SubtlePressStyle(scale: 0.95))
        .accessibilityLabel(accessibilityText(date, key: key, active: active))
    }

    // MARK: - Status

    @ViewBuilder
    private var rangeStatus: some View {
        if let startKey {
            let end = endKey ?? startKey
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.cycle)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(endKey == nil ? "再选择一个结束日期" : "\(displayDate(startKey)) – \(displayDate(end))")
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(
                        endKey == nil
                            ? "还没有选择结束日期"
                            : "\(rangeDays) 天 · \(mode.title)"
                    )
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                }

                Spacer(minLength: 0)
            }
            .padding(11)
            .background(
                Theme.cycle.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(Theme.cycle.opacity(0.22), lineWidth: 1)
            }
        }
    }

    // MARK: - Data

    private func isSelected(_ key: String) -> Bool {
        guard let rangeStart, let rangeEnd else { return false }
        return key >= rangeStart && key <= rangeEnd
    }

    private func select(_ key: String) {
        Haptics.select()
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
            Haptics.success()
            dismiss()
        }
    }

    private func displayDate(_ key: String) -> String {
        guard let date = FitnessDate.date(from: key) else { return key }
        return "\(calendar.component(.month, from: date))月\(calendar.component(.day, from: date))日"
    }

    private func accessibilityText(_ date: Date, key: String, active: Bool) -> String {
        var parts = [displayDate(key)]
        if let rangeStart, let rangeEnd, key >= rangeStart, key <= rangeEnd {
            parts.append("经期区间")
        }
        if active {
            parts.append("已选中")
        }
        if calendar.isDateInToday(date) {
            parts.append("今天")
        }
        return parts.joined(separator: "，")
    }
}
