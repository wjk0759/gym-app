import SwiftUI

/// 训记式的训练日历：按月看训练容量，点日期看当天记录。
struct WorkoutHistoryView: View {
    @Environment(AppStore.self) private var store

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

    private func visibleSessions(in sessions: [WorkoutSession]) -> [WorkoutSession] {
        let list = selectedDate.map { date in
            sessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
        } ?? sessions
        return list.sorted { $0.date > $1.date }
    }

    var body: some View {
        let sessions = monthSessions

        AppScrollView {
            VStack(spacing: 16) {
                statsCard(sessions)
                monthCard
                calendarCard(sessions)
                sessionsCard(sessions)
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .background(AppBackground())
        .navigationTitle("训练记录")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSession) { session in
            WorkoutDetailView(session: session)
        }
    }

    private func statsCard(_ sessions: [WorkoutSession]) -> some View {
        let volume = sessions.reduce(0) { $0 + $1.volume }
        let minutes = sessions.reduce(0) { $0 + $1.durationMinutes }
        let exerciseCount = Set(sessions.flatMap(\.sets).map(\.slug)).count

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("本月训练")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text(sessions.isEmpty ? "还没有记录" : "\(sessions.count) 次训练")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                }
                Spacer()
                Image(systemName: "calendar")
                    .foregroundStyle(Theme.accent)
            }

            HStack(spacing: 8) {
                metric("\(Int(volume))", "容量 kg")
                metric("\(minutes)", "总分钟")
                metric("\(exerciseCount)", "动作数")
            }
        }
        .card()
    }

    private var monthCard: some View {
        HStack(spacing: 14) {
            Button {
                Haptics.tap()
                changeMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 34, height: 34)
                    .background(Theme.surfaceStrong, in: Circle())
            }
            .buttonStyle(SubtlePressStyle(scale: 0.92))
            .foregroundStyle(Theme.secondaryText)

            Spacer()

            VStack(spacing: 2) {
                Text(monthStart.formatted(.dateTime.year().month(.wide)))
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                Button("回到本月") {
                    Haptics.tap()
                    month = Date()
                    selectedDate = nil
                }
                .font(.caption2)
                .foregroundStyle(Theme.accent)
                .buttonStyle(SubtlePressStyle(scale: 0.96))
            }

            Spacer()

            Button {
                Haptics.tap()
                changeMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 34, height: 34)
                    .background(Theme.surfaceStrong, in: Circle())
            }
            .buttonStyle(SubtlePressStyle(scale: 0.92))
            .foregroundStyle(Theme.secondaryText)
            .disabled(calendar.isDate(monthStart, equalTo: Date(), toGranularity: .month))
            .opacity(calendar.isDate(monthStart, equalTo: Date(), toGranularity: .month) ? 0.35 : 1)
        }
        .card(padding: 12)
    }

    private func calendarCard(_ sessions: [WorkoutSession]) -> some View {
        let sessionsByDay = Dictionary(grouping: sessions) {
            calendar.startOfDay(for: $0.date)
        }

        return VStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                spacing: 6
            ) {
                ForEach(0..<leadingBlankCount, id: \.self) { _ in
                    Color.clear.frame(height: 44)
                }

                ForEach(1...daysInMonth, id: \.self) { day in
                    dayCell(day, sessionsByDay: sessionsByDay)
                }
            }
        }
        .card()
    }

    private func sessionsCard(_ sessions: [WorkoutSession]) -> some View {
        let visible = visibleSessions(in: sessions)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDate.map { $0.formatted(.dateTime.month().day()) } ?? "本月记录")
                        .font(.headline)
                    Text(selectedDate == nil ? "点日历上的日期查看当天记录" : "当天训练")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                }
                Spacer()
                if selectedDate != nil {
                    Button("看全月") {
                        Haptics.tap()
                        withAnimation(Motion.quick) {
                            selectedDate = nil
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                    .buttonStyle(SubtlePressStyle(scale: 0.95))
                }
            }

            if visible.isEmpty {
                Text("这一天没有训练记录。")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.vertical, 8)
            } else {
                ForEach(visible) { session in
                    Button {
                        Haptics.tap()
                        selectedSession = session
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(session.dayTitle)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Theme.primaryText)
                                Text(session.date.formatted(.dateTime.month().day().weekday(.abbreviated)))
                                    .font(.caption2)
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("\(Int(session.volume)) kg")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                                Text("\(session.durationMinutes) 分钟")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.tertiaryText)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(SubtlePressStyle(scale: 0.985))
                    if session.id != visible.last?.id {
                        Divider().overlay(Theme.stroke)
                    }
                }
            }
        }
        .card()
    }

    private func dayCell(_ day: Int, sessionsByDay: [Date: [WorkoutSession]]) -> some View {
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
                    .font(.caption.weight(isToday ? .bold : .regular))
                    .foregroundStyle(volume > 0 || isToday ? Theme.accent : Theme.secondaryText)
                Text(volume > 0 ? compactVolume(volume) : " ")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        isSelected
                            ? Theme.accent.opacity(0.22)
                            : (volume > 0 ? Theme.accent.opacity(0.07) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isSelected ? Theme.accent.opacity(0.6) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.03 : 1)
            .animation(Motion.quick, value: isSelected)
        }
        .buttonStyle(SubtlePressStyle(scale: 0.94))
    }

    private var leadingBlankCount: Int {
        (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    }

    private func changeMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: monthStart) else { return }
        month = next
        selectedDate = nil
    }

    private func compactVolume(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return "\(Int(value))"
    }

    private func metric(_ value: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primaryText)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(
            Theme.surfaceStrong,
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
    }
}
