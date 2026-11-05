import SwiftUI

extension PlanHomeView {
    // MARK: - Quick actions

    var quickActions: some View {
        HStack(spacing: 8) {
            quickAction(title: "训练日期", symbol: "calendar.badge.clock", accent: Theme.primary) {
                showSchedule = true
            }

            NavigationLink(value: TabRoute.workoutHistory) {
                quickActionLabel(
                    title: "训练记录",
                    symbol: "clock.arrow.circlepath",
                    accent: Theme.ink,
                    foreground: Theme.onAccent
                )
            }
            .buttonStyle(CardPressStyle(scale: 0.97))

            NavigationLink(value: TabRoute.progressOverview) {
                quickActionLabel(
                    title: "变化",
                    symbol: "chart.xyaxis.line",
                    accent: Theme.primary
                )
            }
            .buttonStyle(CardPressStyle(scale: 0.97))

            if store.profile.sex == .female {
                SheetPresentingButton {
                    quickActionLabel(
                        title: "经期",
                        symbol: "drop.fill",
                        accent: Theme.secondary,
                        foreground: Theme.onAccent
                    )
                } sheet: {
                    PeriodScheduleView()
                }
            }
        }
    }

    func quickAction(
        title: String,
        symbol: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            quickActionLabel(title: title, symbol: symbol, accent: accent)
        }
        .buttonStyle(CardPressStyle(scale: 0.97))
    }

    func quickActionLabel(
        title: String,
        symbol: String,
        accent: Color,
        foreground: Color = Theme.onPrimary
    ) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: 28, height: 28)
                .background(accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }
}
