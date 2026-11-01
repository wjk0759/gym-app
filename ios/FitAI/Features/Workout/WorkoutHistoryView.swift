import SwiftUI

/// A month-by-month training ledger.
///
/// The record tab answers “what is this month?”. This screen answers “what did
/// I actually lift?”: one month cover, one date grid, and the sessions that
/// belong to the selected day. It reads like the next page of the same journal.
struct WorkoutHistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var month = Date()
    @State private var selectedDate: Date?
    @State private var selectedSession: WorkoutSession?

    init() {}

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "zh_CN")
        value.firstWeekday = 2
        return value
    }

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
    }

    private var monthSessions: [WorkoutSession] {
        guard let interval = calendar.dateInterval(of: .month, for: monthStart) else {
            return []
        }
        return store.sessions.filter { interval.contains($0.date) }
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(monthStart, equalTo: Date(), toGranularity: .month)
    }

    private func visibleSessions(in sessions: [WorkoutSession]) -> [WorkoutSession] {
        let list = selectedDate.map { date in
            sessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
        } ?? sessions
        return list.sorted { $0.date > $1.date }
    }

    var body: some View {
        let sessions = monthSessions

        AppScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                monthCover(sessions)
                calendarCard(sessions)
                sessionsCard(sessions)
                footer
            }
            .appPagePadding()
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AppBackground())
        .navigationTitle("训练记录")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSession) { session in
            WorkoutDetailView(session: session)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("WORKOUT LOG / 训练记录")
                .font(AppType.overline)
                .tracking(1.5)
                .foregroundStyle(Theme.cobalt)

            Text("训练账本")
                .font(AppType.display)
                .tracking(-0.9)
                .foregroundStyle(Theme.ink)

            Text("练过的每一组，都算数。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private func monthCover(_ sessions: [WorkoutSession]) -> some View {
        let volume = sessions.reduce(0) { $0 + $1.volume }
        let minutes = sessions.reduce(0) { $0 + $1.durationMinutes }
        let exerciseCount = Set(sessions.flatMap(\.sets).map(\.slug)).count

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("MONTH / \(monthShort)")
                    .font(AppType.overline)
                    .tracking(1.4)
                    .foregroundStyle(Theme.onAccent.opacity(0.9))

                Spacer(minLength: 4)

                monthArrow(systemName: "chevron.left", disabled: false) {
                    changeMonth(-1)
                }
                monthArrow(systemName: "chevron.right", disabled: isCurrentMonth) {
                    changeMonth(1)
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text("\(sessions.count)")
                    .font(.system(size: 48, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.onAccent)
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 2) {
                    Text("次训练")
                        .font(AppType.caption.weight(.bold))
                        .foregroundStyle(Theme.onAccent)
                    Text(monthTitle)
                        .font(AppType.micro)
                        .foregroundStyle(Theme.onAccent.opacity(0.72))
                }
                .padding(.bottom, 5)

                Spacer(minLength: 4)

                if !isCurrentMonth {
                    Button {
                        Haptics.tap()
                        withAnimation(Motion.smooth) {
                            month = Date()
                            selectedDate = nil
                        }
                    } label: {
                        Text("回到本月")
                            .font(AppType.micro)
                            .foregroundStyle(Theme.onAccent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Theme.onAccent.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(SubtlePressStyle(scale: 0.95))
                    .padding(.bottom, 4)
                }
            }

            Text(
                sessions.isEmpty
                    ? "这个月还没有训练记录。"
                    : "容量和时长只统计本机已保存的训练。"
            )
            .font(AppType.caption)
            .foregroundStyle(Theme.onAccent.opacity(0.88))
            .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(Theme.onAccent.opacity(0.22))
                .frame(height: 1)

            HStack(spacing: 10) {
                historyStat(value: Int(volume).formatted(), unit: "kg", label: "总容量")
                historyStat(value: "\(minutes)", unit: "分钟", label: "总时长")
                historyStat(value: "\(exerciseCount)", unit: "个", label: "动作数")
            }
        }
        .padding(18)
        .background(Theme.cobalt, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Theme.ink, lineWidth: 1.5)
        }
        .shadow(color: Theme.ink.opacity(0.14), radius: 0, x: 5, y: 5)
    }

    private func monthArrow(
        systemName: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            withAnimation(Motion.smooth) {
                action()
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 30, height: 30)
                .background(Theme.onAccent.opacity(0.14), in: Circle())
        }
        .buttonStyle(SubtlePressStyle(scale: 0.92))
        .disabled(disabled)
        .opacity(disabled ? 0.3 : 1)
    }

    private func historyStat(value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.onAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(unit)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.onAccent.opacity(0.78))
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.onAccent.opacity(0.85))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func calendarCard(_ sessions: [WorkoutSession]) -> some View {
        let sessionsByDay = Dictionary(grouping: sessions) {
            calendar.startOfDay(for: $0.date)
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("日历")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text(
                        selectedDate.map { "正在看 \(dayTitle($0))" }
                            ?? "点一天，筛出当天记录"
                    )
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                }

                Spacer(minLength: 4)

                if selectedDate != nil {
                    Button("看全月") {
                        Haptics.tap()
                        withAnimation(Motion.quick) {
                            selectedDate = nil
                        }
                    }
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.cobalt)
                    .buttonStyle(SubtlePressStyle(scale: 0.95))
                }
            }

            HStack(spacing: 0) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { weekday in
                    Text(weekday)
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
                ForEach(0..<leadingBlankCount, id: \.self) { _ in
                    Color.clear.frame(height: 44)
                }

                ForEach(1...daysInMonth, id: \.self) { day in
                    dayCell(day, sessionsByDay: sessionsByDay)
                }
            }

            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Theme.cobalt, lineWidth: 1.2)
                        .frame(width: 7, height: 7)
                    Text("今天")
                }
                Text("数字为当日训练容量")
                Spacer(minLength: 0)
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    private func dayCell(
        _ day: Int,
        sessionsByDay: [Date: [WorkoutSession]]
    ) -> some View {
        let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart
        let sessions = sessionsByDay[calendar.startOfDay(for: date)] ?? []
        let volume = sessions.reduce(0) { $0 + $1.volume }
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)

        return Button {
            Haptics.select()
            withAnimation(Motion.quick) {
                selectedDate = date
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(
                        .system(
                            size: 11.5,
                            weight: isToday ? .bold : .semibold,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(isSelected ? Theme.paper : Theme.ink)

                Text(volume > 0 ? compactVolume(volume) : " ")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(
                        isSelected
                            ? Theme.paper.opacity(0.78)
                            : (volume > 0 ? Theme.cobalt : Color.clear)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? Theme.ink
                            : (volume > 0 ? Theme.ink.opacity(0.035) : Color.clear)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isToday && !isSelected ? Theme.cobalt : Color.clear,
                        lineWidth: 1.4
                    )
            }
            .scaleEffect(isSelected ? 1.03 : 1)
            .animation(Motion.quick, value: isSelected)
        }
        .buttonStyle(SubtlePressStyle(scale: 0.94))
        .accessibilityLabel(dayAccessibilityLabel(date, volume: volume, selected: isSelected))
    }

    private func sessionsCard(_ sessions: [WorkoutSession]) -> some View {
        let visible = visibleSessions(in: sessions)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDate.map { dayTitle($0) } ?? "本月记录")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text(
                        selectedDate == nil
                            ? "\(visible.count) 次训练 · 点日历筛选"
                            : "\(visible.count) 次训练"
                    )
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                }

                Spacer(minLength: 4)

                if selectedDate != nil {
                    Button("看全月") {
                        Haptics.tap()
                        withAnimation(Motion.quick) {
                            selectedDate = nil
                        }
                    }
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.cobalt)
                    .buttonStyle(SubtlePressStyle(scale: 0.95))
                }
            }

            if visible.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedDate == nil ? "这个月还没有训练记录" : "这一天没有训练记录")
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("练完一次，这里就会多一页。")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.tertiaryText)
                    if selectedDate == nil {
                        Button("回训练手账补记") {
                            store.selectedTab = 1
                            dismiss()
                        }
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.cobalt)
                        .buttonStyle(SubtlePressStyle())
                        .padding(.top, 2)
                    }
                }
                .padding(.vertical, 8)
            } else {
                ForEach(visible) { session in
                    Button {
                        Haptics.tap()
                        selectedSession = session
                    } label: {
                        sessionRow(session)
                    }
                    .buttonStyle(.plain)

                    if session.id != visible.last?.id {
                        InkDivider()
                    }
                }
            }
        }
        .card()
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        HStack(spacing: 10) {
            VStack(spacing: 0) {
                Text("\(calendar.component(.day, from: session.date))")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                Text(weekdayShort(session.date))
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .frame(width: 38, height: 42)
            .background(Theme.ink.opacity(0.045), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(String(session.dayTitle.prefix(40)))
                    .font(AppType.callout.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text("\(session.sets.filter(\.completed).count) 组 · \(session.exerciseCount) 个动作")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(Int(session.volume)) kg")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.cobalt)
                Text("\(session.durationMinutes) 分钟")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    private var footer: some View {
        Text("训练记录只保存在本机。编辑或删除后，训练容量和 AI 复盘数据会同步更新。")
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(Theme.tertiaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var leadingBlankCount: Int {
        (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    }

    private func changeMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: monthStart) else {
            return
        }
        month = next
        selectedDate = nil
    }

    private var monthShort: String {
        "\(calendar.component(.month, from: monthStart))月"
    }

    private var monthTitle: String {
        let components = calendar.dateComponents([.year, .month], from: monthStart)
        return "\(components.year ?? 0)年\(components.month ?? 0)月"
    }

    private func compactVolume(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return "\(Int(value))"
    }

    private func dayTitle(_ date: Date) -> String {
        "\(calendar.component(.month, from: date))月\(calendar.component(.day, from: date))日"
    }

    private func weekdayShort(_ date: Date) -> String {
        let index = (calendar.component(.weekday, from: date) + 5) % 7
        let labels = ["一", "二", "三", "四", "五", "六", "日"]
        return labels[max(0, min(labels.count - 1, index))]
    }

    private func dayAccessibilityLabel(
        _ date: Date,
        volume: Double,
        selected: Bool
    ) -> String {
        var parts = [dayTitle(date), "周\(weekdayShort(date))"]
        if volume > 0 {
            parts.append("训练容量 \(Int(volume)) 公斤")
        } else {
            parts.append("没有训练记录")
        }
        if selected {
            parts.append("已选中")
        }
        return parts.joined(separator: "，")
    }
}
