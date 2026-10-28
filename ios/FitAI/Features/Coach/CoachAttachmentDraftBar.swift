import SwiftUI

/// Presentation for staged coach attachments.
///
/// Staging/validation lives in `CoachChatView`; this view only renders the
/// draft and forwards user intents, so the same bar can be reused by another
/// coach entry point without copying attachment UI.
struct CoachAttachmentDraftBar: View {
    let images: [CoachDraftImage]
    let video: CoachVideoAttachment?
    let isLoadingImages: Bool
    let isLoadingVideo: Bool
    let onClear: () -> Void
    let onRemoveImage: (UUID) -> Void
    let onRemoveVideo: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(
                    !(video != nil || isLoadingVideo)
                        ? "待发送图片 \(images.count)/\(CoachAttachmentPolicy.maxImages)"
                        : "待发送视频",
                    systemImage: !(video != nil || isLoadingVideo) ? "paperclip" : "video.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)

                if isLoadingImages || isLoadingVideo {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()

                Button("清空") {
                    onClear()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.tertiaryText)
            }

            if isLoadingVideo, video == nil {
                HStack(spacing: 10) {
                    VStack(spacing: 5) {
                        ProgressView()
                            .tint(Theme.accent)
                        Text("读取中")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .frame(width: 150, height: 84)
                    .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("正在分析视频画面…")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                        Text("本地抽取关键帧并识别姿态，请稍等")
                            .font(.caption2)
                            .foregroundStyle(Theme.tertiaryText)
                    }

                    Spacer(minLength: 0)
                }
            } else if let video {
                HStack(spacing: 10) {
                    ZStack {
                        Image(uiImage: video.thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 150, height: 84)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.94))
                            .shadow(radius: 2)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("视频已就绪")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                        Text("\(video.durationSeconds)s · 发送时上传最多 6 个关键帧")
                            .font(.caption2)
                            .foregroundStyle(Theme.tertiaryText)
                    }

                    Spacer(minLength: 0)

                    Button {
                        onRemoveVideo()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.secondaryText)
                            .frame(width: 26, height: 26)
                            .background(Theme.surfaceStrong, in: Circle())
                    }
                    .accessibilityLabel("移除视频")
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if isLoadingImages {
                            VStack(spacing: 4) {
                                ProgressView()
                                    .tint(Theme.accent)
                                Text("读取中")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                            .frame(width: 68, height: 68)
                            .background(
                                Theme.surfaceStrong,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                        }

                        ForEach(images) { attachment in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: attachment.image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 68, height: 68)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                Button {
                                    onRemoveImage(attachment.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 18, height: 18)
                                        .background(.black.opacity(0.66), in: Circle())
                                }
                                .offset(x: 5, y: -5)
                                .accessibilityLabel("移除图片")
                            }
                        }
                    }
                    .padding(.trailing, 8)
                    .padding(.vertical, 2)
                }
            }

            Text(
                !(video != nil || isLoadingVideo)
                    ? "图片和视频只能二选一；可以先添加多张图片，写完说明后再发送。"
                    : "视频一次只能发送一个；发送时最多上传 6 个关键帧和本机姿态摘要，不上传原视频。"
            )
            .font(.caption2)
            .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            GlassSurface(cornerRadius: 0, material: false)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.48))
                .frame(height: 0.8)
        }
    }
}
