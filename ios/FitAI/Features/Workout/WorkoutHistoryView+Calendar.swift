import SwiftUI

extension WorkoutHistoryView {
    func calendarCard(_ sessions: [WorkoutSession]) -> some View {
        let sessionsByDay = Dictionary(grouping: sessions) {
            calendar.startOfDay(for: $0.date)
        }
        let days = calendarDays

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
                ForEach(days, id: \.self) { date in
                    dayCell(date, sessionsByDay: sessionsByDay)
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

    func dayCell(
        _ date: Date,
        sessionsByDay: [Date: [WorkoutSession]]
    ) -> some View {
        let day = calendar.component(.day, from: date)
        let sessions = sessionsByDay[calendar.startOfDay(for: date)] ?? []
        let volume = sessions.reduce(0) { $0 + $1.volume }
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)
        let inMonth = calendar.isDate(date, equalTo: monthStart, toGranularity: .month)

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
                    .foregroundStyle(isSelected ? Theme.onPrimary : Theme.ink)

                Text(volume > 0 ? compactVolume(volume) : " ")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(
                        isSelected
                            ? Theme.onPrimary.opacity(0.72)
                            : (volume > 0 ? Theme.ink : Color.clear)
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
                            ? Theme.primary
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
            .opacity(inMonth ? 1 : 0.3)
            .animation(Motion.quick, value: isSelected)
        }
        .buttonStyle(SubtlePressStyle(scale: 0.94))
        .accessibilityLabel(dayAccessibilityLabel(date, volume: volume, selected: isSelected))
    }
}
