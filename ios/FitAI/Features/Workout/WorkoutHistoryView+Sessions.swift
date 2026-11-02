import SwiftUI

extension WorkoutHistoryView {
    func sessionsCard(_ sessions: [WorkoutSession]) -> some View {
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

    func sessionRow(_ session: WorkoutSession) -> some View {
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
}
