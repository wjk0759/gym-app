import SwiftUI

extension WorkoutHistoryView {
    var footer: some View {
        Text("训练记录只保存在本机。编辑或删除后，训练容量和 AI 复盘数据会同步更新。")
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(Theme.tertiaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    var calendarDays: [Date] {
        let weekday = calendar.component(.weekday, from: monthStart)
        let mondayOffset = (weekday + 5) % 7
        guard let gridStart = calendar.date(
            byAdding: .day,
            value: -mondayOffset,
            to: monthStart
        ) else {
            return []
        }
        return (0..<42).compactMap {
            calendar.date(byAdding: .day, value: $0, to: gridStart)
        }
    }

    func changeMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: monthStart) else {
            return
        }
        month = next
        selectedDate = nil
    }

    var monthShort: String {
        "\(calendar.component(.month, from: monthStart))月"
    }

    var monthTitle: String {
        let components = calendar.dateComponents([.year, .month], from: monthStart)
        return "\(components.year ?? 0)年\(components.month ?? 0)月"
    }

    func compactVolume(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return "\(Int(value))"
    }

    func dayTitle(_ date: Date) -> String {
        "\(calendar.component(.month, from: date))月\(calendar.component(.day, from: date))日"
    }

    func weekdayShort(_ date: Date) -> String {
        let index = (calendar.component(.weekday, from: date) + 5) % 7
        let labels = ["一", "二", "三", "四", "五", "六", "日"]
        return labels[max(0, min(labels.count - 1, index))]
    }

    func dayAccessibilityLabel(
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
