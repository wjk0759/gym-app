import SwiftUI

extension HomeV2View {
    var quickActions: some View {
        HStack(spacing: 12) {
            quickTile(title: "记录身体", symbol: "figure.stand") {
                bodyCheckInManual = true
                showBodyCheckIn = true
            }

            NavigationLink(value: TabRoute.progressOverview) {
                quickTileLabel(title: "变化", symbol: "chart.line.uptrend.xyaxis")
            }
            .buttonStyle(.plain)

            quickTile(title: "拍照识别", symbol: "camera") {
                showCaptureHub = true
            }
        }
    }

    func quickTile(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            quickTileLabel(title: title, symbol: symbol)
        }
        .buttonStyle(.plain)
    }

    func quickTileLabel(title: String, symbol: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Theme.ink)
            Text(title)
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
