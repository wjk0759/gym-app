import SwiftUI

// 教学视频入口由 AppConfig.exerciseVideosEnabled 控制；素材上线前保持隐藏。
// 这里保留播放器和占位实现，不要删除。
extension EquipmentItemDetailView {
@ViewBuilder
func videoContent(for item: EquipmentItem) -> some View {
        if let url = videoURL {
            LoopingVideoPlayer(url: url)
                .frame(height: 245)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) {
                    detailBadge("官方教学视频", accent: true)
                        .padding(10)
                }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.inkSolid, Theme.inkSolid.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let data = item.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .opacity(0.32)
                } else {
                    Image(systemName: equipmentSymbol(item))
                        .font(.system(size: 66, weight: .light))
                        .foregroundStyle(Theme.primary.opacity(0.40))
                }

                VStack(spacing: 7) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(width: 54, height: 54)
                        .background(Color.black.opacity(0.42), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.30), lineWidth: 1))

                    Text("教学视频准备中")
                        .font(AppType.callout.weight(.bold))
                        .foregroundStyle(Theme.onMedia)

                    Text(isPreview ? "这个动作的官方示范视频还在准备中。" : "这件器械的官方示范视频还在准备中。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.onMedia.opacity(0.70))
                }
            }
            .frame(height: 245)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
            .overlay(alignment: .topTrailing) {
                detailBadge("视频待上线")
                    .padding(10)
            }
        }
    }

@ViewBuilder
func motionBoard(for item: EquipmentItem) -> some View {
        if let exercise = item.exercise, let videoURL = exercise.demoVideoURL {
            ZStack(alignment: .topLeading) {
                LoopingVideoPlayer(url: videoURL)
                detailBadge("动作轨迹", accent: true)
                    .padding(10)
            }
            .frame(height: 232)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
        } else {
            placeholderMotionBoard(for: item)
        }
    }

func placeholderMotionBoard(for item: EquipmentItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.primary.opacity(0.10), Theme.paper],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            ForEach(0..<3, id: \.self) { index in
                Ellipse()
                    .stroke(
                        Theme.primary.opacity(0.20),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 5])
                    )
                    .frame(
                        width: 250 - CGFloat(index) * 48,
                        height: 105 - CGFloat(index) * 22
                    )
                    .rotationEffect(.degrees(-16))
            }

            Image(systemName: equipmentSymbol(item))
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Theme.ink)
                .shadow(color: Color.black.opacity(0.12), radius: 10, y: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text("保持轨迹稳定")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 28, height: 28)
                .background(Theme.cobalt, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .padding(10)
        }
    }

func angleGrid(for item: EquipmentItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(Array(["正面", "侧面", "发力", "细节"].enumerated()), id: \.offset) { index, label in
                    VStack(spacing: 4) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Theme.ink.opacity(0.035).opacity(index < 2 ? 1 : 0.65))
                            Image(systemName: index < 2 ? equipmentSymbol(item) : "ellipsis")
                                .font(.system(size: 21, weight: .light))
                                .foregroundStyle(
                                    index < 2 ? Theme.cobalt.opacity(0.70) : Theme.tertiaryText
                                )
                        }
                        .frame(height: 58)

                        Text(label)
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(5)
                    .background(
                        Theme.paper,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.stroke, lineWidth: 0.8)
                    )
                }
            }

            Text("示范素材准备中；先用下面的动作要点确认起始位置和发力顺序。")
                .font(.system(size: 10))
                .foregroundStyle(Theme.tertiaryText)
                .lineSpacing(1.5)
        }
    }

}
