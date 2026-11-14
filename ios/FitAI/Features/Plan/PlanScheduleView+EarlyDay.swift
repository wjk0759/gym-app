import SwiftUI

extension PlanScheduleView {
    var earlyDayCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("首周之前")
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)

            Text(
                todayDay?.skippedAt == nil
                    ? "今天不在 4 周日期板内，已作为额外训练保留。"
                    : "今天不在 4 周日期板内。先取消要移到今天的那天，再选这里。"
            )
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.tertiaryText)
            .fixedSize(horizontal: false, vertical: true)

            if todaySlotVisible {
                Button {
                    toggleToday()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selected.contains(todayKey)
                            ? "checkmark.circle.fill"
                            : "circle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(selected.contains(todayKey)
                                ? Theme.cobalt
                                : Theme.tertiaryText)
                        Text("今天 \(FitnessDate.short(today))")
                            .font(AppType.caption.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        if let todayDay {
                            Text("· \(todayDay.title)")
                                .font(AppType.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        Spacer(minLength: 4)
                        Text(selected.contains(todayKey) ? "已选" : "空闲")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                }
                .buttonStyle(.plain)
            }

            ForEach(earlyDays.filter { !calendar.isDateInToday($0.date ?? .distantPast) }) { day in
                HStack(spacing: 6) {
                    Image(systemName: day.skippedAt == nil
                        ? "checkmark.circle.fill"
                        : "circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(day.skippedAt == nil ? Theme.cobalt : Theme.tertiaryText)
                    Text("\(day.date.map(FitnessDate.short) ?? "--") · \(day.title)")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 4)
                    if day.skippedAt != nil {
                        Text("已跳过")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                }
            }

            Text("想临时加练，直接对教练说「今天我想练背」。")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    var todayDay: PlanDay? {
        guard let plan = store.plan else { return nil }
        return todayPlanDay(in: plan)
    }
}
