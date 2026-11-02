import SwiftUI

extension WorkoutHistoryView {
    var header: some View {
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

    func monthCover(_ sessions: [WorkoutSession]) -> some View {
        let volume = sessions.reduce(0) { $0 + $1.volume }
        let minutes = sessions.reduce(0) { $0 + $1.durationMinutes }
        let exerciseCount = Set(sessions.flatMap(\.sets).map(\.slug)).count

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("MONTH / \(monthShort)")
                    .font(AppType.overline)
                    .tracking(1.4)
                    .foregroundStyle(Theme.onMedia.opacity(0.9))

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
                    .foregroundStyle(Theme.onMedia)
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 2) {
                    Text("次训练")
                        .font(AppType.caption.weight(.bold))
                        .foregroundStyle(Theme.onMedia)
                    Text(monthTitle)
                        .font(AppType.micro)
                        .foregroundStyle(Theme.onMedia.opacity(0.72))
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
                            .foregroundStyle(Theme.onMedia)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Theme.onMedia.opacity(0.14), in: Capsule())
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
            .foregroundStyle(Theme.onMedia.opacity(0.88))
            .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(Theme.onMedia.opacity(0.22))
                .frame(height: 1)

            HStack(spacing: 10) {
                historyStat(value: Int(volume).formatted(), unit: "kg", label: "总容量")
                historyStat(value: "\(minutes)", unit: "分钟", label: "总时长")
                historyStat(value: "\(exerciseCount)", unit: "个", label: "动作数")
            }
        }
        .padding(18)
        .background(
            Theme.inkSolid,
            in: RoundedRectangle(cornerRadius: AppLayout.heroCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppLayout.heroCornerRadius, style: .continuous)
                .strokeBorder(Theme.ink, lineWidth: 1.5)
        }
    }

    func monthArrow(
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
                .foregroundStyle(Theme.onMedia)
                .frame(width: 30, height: 30)
                .background(Theme.onMedia.opacity(0.14), in: Circle())
        }
        .buttonStyle(SubtlePressStyle(scale: 0.92))
        .disabled(disabled)
        .opacity(disabled ? 0.3 : 1)
    }

    func historyStat(value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.onMedia)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(unit)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.onMedia.opacity(0.78))
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.onMedia.opacity(0.85))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
