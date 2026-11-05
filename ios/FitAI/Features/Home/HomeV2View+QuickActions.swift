import SwiftUI

extension HomeV2View {
    // MARK: - Quick actions

    var quickActions: some View {
        HStack(spacing: 8) {
            quickTile(title: "记录身体", symbol: "figure.stand", accent: Theme.primary) {
                bodyCheckInManual = true
                showBodyCheckIn = true
            }
            NavigationLink(value: TabRoute.progressOverview) {
                quickTileLabel(title: "变化", symbol: "chart.line.uptrend.xyaxis", accent: Theme.ink, foreground: Theme.onAccent)
            }
            .buttonStyle(CardPressStyle(scale: 0.985))

            quickTile(title: "问教练", symbol: "bubble.left.and.bubble.right", accent: Theme.primary) {
                store.selectedTab = 2
            }
        }
    }

    func quickTile(
        title: String,
        symbol: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            quickTileLabel(title: title, symbol: symbol, accent: accent, foreground: Theme.onPrimary)
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
    }

    func quickTileLabel(title: String, symbol: String, accent: Color, foreground: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: 32, height: 32)
                .background(accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title)
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }
}
