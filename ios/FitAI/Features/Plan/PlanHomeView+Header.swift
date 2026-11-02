import SwiftUI

extension PlanHomeView {
    // MARK: - Header

    var topBar: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.tap()
                withAnimation(Motion.smooth) {
                    goToToday()
                }
            } label: {
                Label("回到今天", systemImage: "arrow.uturn.backward")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(Theme.paper, in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    }
            }
            .buttonStyle(SubtlePressStyle(scale: 0.96))

            Spacer(minLength: 0)

            Menu {
                Button {
                    showHistory = true
                } label: {
                    Label("计划版本历史", systemImage: "clock.arrow.circlepath")
                }
                if store.plan != nil {
                    Button(role: .destructive) {
                        showRegenerate = true
                    } label: {
                        Label("重新生成计划", systemImage: "arrow.clockwise")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 34, height: 34)
                    .background(Theme.paper, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    }
            }
            .accessibilityLabel("更多计划操作")
        }
    }

    var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text("TRAINING LOG / 记录")
                    .font(AppType.overline)
                    .tracking(1.5)
                    .foregroundStyle(Theme.cobalt)

                Text("训练手账")
                    .font(AppType.display)
                    .tracking(-0.9)
                    .foregroundStyle(Theme.ink)

                Text("翻回去看，才知道自己走了多远。")
                    .font(AppType.body)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            monthStamp
        }
        .padding(.top, 2)
    }

    var monthStamp: some View {
        let components = calendar.dateComponents([.year, .month], from: visibleMonth)
        let month = components.month ?? 1
        let year = components.year ?? calendar.component(.year, from: Date())

        return VStack(spacing: 0) {
            Text("\(month)")
                .font(.system(size: 26, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Text("月")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.cobalt)
            Rectangle()
                .fill(Theme.stroke)
                .frame(width: 22, height: 1)
                .padding(.vertical, 3)
            Text(String(year))
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(width: 54, height: 64)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Theme.ink, lineWidth: 1.2)
        }
        .rotationEffect(.degrees(-3))
        .accessibilityHidden(true)
    }
}
