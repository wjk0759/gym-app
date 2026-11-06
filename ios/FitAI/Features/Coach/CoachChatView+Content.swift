import SwiftUI
import PhotosUI
import UIKit

extension CoachChatView {
    var inputPlaceholder: String {
        if store.shouldShowCoachQuotaCard {
            return "今天的免费额度已用完，升级 Pro 继续聊"
        }
        if store.planAdjustmentStage == 1 {
            return "说说最近训练最困扰你的地方…"
        }
        if store.planAdjustmentStage == 2 {
            return "补充具体情况，越具体越好…"
        }
        if store.planAdjustmentStage == 3 {
            return "需要再改可以继续说…"
        }
        return "训练、饮食、恢复、计划都能问…"
    }

    var coachBadgeText: String {
        if store.hasProAccess {
            return store.useRemoteAI ? "远程 AI 已连接" : "本地建议"
        }
        guard store.accessSnapshot != nil else { return "正在确认权益" }
        return store.shouldShowCoachQuotaCard ? "今日额度已用完" : "免费 AI 额度"
    }

    var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    CoachMark(size: 58)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("我是你的教练")
                            .font(AppType.title)
                            .foregroundStyle(Theme.ink)
                    }
                }

                Text(store.hasProAccess
                     ? "把今天的情况、限制或照片发给我，我来判断下一步。"
                     : "把今天的情况或限制发给我，我来判断下一步。")
                    .font(AppType.body)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    RecommendationBadge(text: coachBadgeText)
                    Spacer()
                    Text("疼痛 / 孕期 / 术后会先拦")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .editorialCard(accent: Theme.lime)
            .staggerIn(0)

            VStack(alignment: .leading, spacing: 10) {
                Text("快速开始")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 180), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(starters) { item in
                        Button {
                            send(item.text)
                        } label: {
                            VStack(alignment: .leading, spacing: 9) {
                                Image(systemName: item.icon)
                                    .font(AppType.headline)
                                    .foregroundStyle(Theme.cobalt)
                                Text(item.text)
                                    .font(AppType.callout.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
                            .padding(12)
                            .background(
                                Theme.ink.opacity(0.035),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                        }
                        .buttonStyle(CardPressStyle(scale: 0.98))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .staggerIn(1)

            weeklyRecap
                .staggerIn(2)
        }
    }

    var weeklyRecap: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("本周状态")
                    .font(AppType.callout.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("第 \(store.currentPlanWeek) 周")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Text("\(store.currentWeekCompletedCount)/\(store.currentWeekPlannedCount) 练 · 完成率 \(Int(store.weeklyCompletion * 100))%")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)

            Button {
                send("帮我复盘一下本周训练，接下来应该怎么调整？")
            } label: {
                Label("让教练复盘本周", systemImage: "sparkles")
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.cobalt)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }

    func bubble(_ message: ChatMessage) -> some View {
        CoachChatBubble(isUser: message.role == .user, isSafety: message.isSafety) {
            VStack(alignment: .leading, spacing: 6) {
                if message.isSafety {
                    Label("安全提醒", systemImage: "exclamationmark.triangle.fill")
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.warning)
                }

                let isUploading = store.isReplying
                    && message.role == .user
                    && store.chat.last?.id == message.id
                if let videoData = message.videoThumbnailData,
                   let duration = message.videoDurationSeconds {
                    ChatVideoThumbnail(
                        messageID: message.id,
                        data: videoData,
                        duration: duration
                    )
                    .overlay {
                        if isUploading {
                            attachmentUploadingOverlay
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                } else if !message.allImageData.isEmpty {
                    ChatMessageImageGrid(
                        messageID: message.id,
                        images: message.allImageData
                    )
                    .overlay {
                        if isUploading {
                            attachmentUploadingOverlay
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }

                if !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(message.text)
                        .font(AppType.callout)
                        .foregroundStyle(message.role == .user ? Theme.onAccent : Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    var attachmentUploadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.28)
            ProgressView()
                .tint(.white)
                .scaleEffect(1.05)
        }
        .allowsHitTesting(false)
    }

    var coachQuickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CoachQuickActionButton(title: "训练计划", icon: "calendar") {
                    send("帮我安排今天的训练")
                }
                CoachQuickActionButton(title: "饮食方案", icon: "fork.knife") {
                    showDietLibrary = true
                }
                CoachQuickActionButton(
                    title: store.hasProAccess ? "动作点评" : "动作点评 · Pro",
                    icon: "camera.viewfinder"
                ) {
                    guard store.requirePro(.coachVision) else { return }
                    cameraTitle = "动作点评"
                    cameraHint = "拍全身侧面，光线清楚，尽量包含器械和完整动作。照片只用于本次点评。"
                    showCamera = true
                }
                CoachQuickActionButton(
                    title: store.hasProAccess ? "视频点评" : "视频点评 · Pro",
                    icon: "video.fill"
                ) {
                    if store.requirePro(.videoReview) {
                        showVideoReview = true
                    }
                }
                CoachQuickActionButton(
                    title: store.hasProAccess ? "器械识别" : "器械识别 · Pro",
                    icon: "dumbbell"
                ) {
                    if store.requirePro(.equipmentScan) {
                        showEquipmentScan = true
                    }
                }
                CoachQuickActionButton(title: "记录", icon: "list.bullet.rectangle") {
                    store.selectedTab = 1
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    var inputBar: some View {
        VStack(spacing: 0) {
            if let remaining = store.access.policy.coachRemaining,
               let limit = store.access.policy.coachLimit {
                HStack(spacing: 8) {
                    Text(remaining == 0
                         ? "今天的免费 AI 教练额度已用完"
                         : "今日免费 AI 教练剩余 \(remaining)/\(limit) 条")
                        .font(AppType.micro)
                        .foregroundStyle(remaining > 0 ? Theme.secondaryText : Theme.coral)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 4)
            }
            HStack(spacing: 8) {
            Menu {
                Button {
                    guard store.requirePro(.coachVision) else { return }
                    Haptics.tap()
                    cameraTitle = "拍照问教练"
                    cameraHint = "尽量拍到完整动作或器械，避免脸和隐私部位。照片只用于本次对话。"
                    focused = false
                    KeyboardDismiss.dismiss()
                    showCamera = true
                } label: {
                    Label(store.hasProAccess ? "拍照" : "拍照 · Pro", systemImage: "camera.fill")
                }
                .disabled(!canAddImageAttachment)

                Button {
                    guard store.requirePro(.coachVision) else { return }
                    Haptics.tap()
                    focused = false
                    KeyboardDismiss.dismiss()
                    showPhotoPicker = true
                } label: {
                    Label(store.hasProAccess ? "从相册选照片" : "从相册选照片 · Pro", systemImage: "photo.on.rectangle")
                }
                .disabled(!canAddImageAttachment)

                Button {
                    guard store.requirePro(.videoReview) else { return }
                    Haptics.tap()
                    focused = false
                    KeyboardDismiss.dismiss()
                    showVideoPicker = true
                } label: {
                    Label(store.hasProAccess ? "选择视频" : "选择视频 · Pro", systemImage: "video.fill")
                }
                .disabled(!canAddVideoAttachment)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.cobalt)
                    .frame(width: 40, height: 42)
                    .background(Theme.ink.opacity(0.035), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(SubtlePressStyle())
            .disabled(!canAddImageAttachment && !canAddVideoAttachment)
            .accessibilityLabel("添加图片或视频")

            TextField(inputPlaceholder, text: $input, axis: .vertical)
                .font(AppType.callout)
                .lineLimit(1...4)
                .focused($focused)
                .onChange(of: input) { _, value in
                    if value.count > 500 {
                        input = String(value.prefix(500))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.ink.opacity(0.035))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                }

            if store.isReplying {
                Button {
                    Haptics.impact(.light)
                    KeyboardDismiss.dismiss()
                    store.cancelAgentChat()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(AppType.callout.weight(.bold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Theme.coral))
                }
                .buttonStyle(SubtlePressStyle())
                .accessibilityLabel("停止本次回复")
            } else {
                Button {
                    sendCurrent()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle().fill(canSend ? Theme.cobalt : Theme.secondaryText.opacity(0.35))
                        )
                        .scaleEffect(canSend ? 1 : 0.94)
                        .animation(Motion.quick, value: canSend)
                }
                .buttonStyle(SubtlePressStyle())
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Theme.paper)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(
                    focused
                        ? Theme.cobalt.opacity(0.38)
                        : Theme.stroke,
                    lineWidth: focused ? 1.4 : 1
                )
                .animation(Motion.quick, value: focused)
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 6)
        }
    }
    var attachmentDraftBar: some View {
        CoachAttachmentDraftBar(
            images: draftAttachments,
            video: draftVideo,
            isLoadingImages: isLoadingAttachments,
            isLoadingVideo: isLoadingVideo,
            onClear: {
                draftAttachments = []
                draftVideo = nil
            },
            onRemoveImage: { id in
                draftAttachments.removeAll { $0.id == id }
            },
            onRemoveVideo: {
                draftVideo = nil
            }
        )
    }
}
