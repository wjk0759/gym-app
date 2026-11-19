import SwiftUI
import PhotosUI
import UIKit

/// 教练输入区动作：发送文本/图片/视频、加载相册、处理控制面请求打开 sheet。
/// 本文件只做输入校验和路由，真正的网络请求和会话状态由 AppStore 处理。
extension CoachChatView {
    func consumeCoachEntryPrompt() {
        guard let prompt = store.coachEntryPrompt else { return }
        store.coachEntryPrompt = nil
        input = prompt
        focused = true
    }

    /// 发送当前输入。
    /// 视频、图片、纯文本三条互斥路径；图片区分“饮食记录”和普通教练视觉，
    /// 饮食图片只允许一张且走食物识别，不直接写库。
    func sendCurrent() {
        guard !store.isReplying, !isLoadingVideo, !isLoadingAttachments else { return }
        let caption = String(input.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))

        if let video = draftVideo {
            guard store.requirePro(.videoReview) else { return }
            guard draftAttachments.isEmpty else {
                attachmentError = "图片和视频不能同时发送，请先清空其中一种。"
                return
            }
            let thumbnailData = video.thumbnail.jpegData(compressionQuality: 0.72)
                ?? video.frames.first
            let question = caption.isEmpty
                ? video.analysisPrompt
                : video.analysisPrompt + "\n用户补充：\(caption)"

            Haptics.impact(.light)
            input = ""
            focused = false
            KeyboardDismiss.dismiss()
            draftVideo = nil
            store.sendCoachPhotos(
                video.frames,
                caption: caption,
                question: question,
                videoThumbnailData: thumbnailData,
                videoDurationSeconds: video.durationSeconds,
                proFeature: .videoReview
            )
            return
        }

        if draftAttachments.isEmpty {
            send(input)
            return
        }

        let images = draftAttachments.map(\.data)
        guard !images.isEmpty else { return }

        if imagePurpose == .food {
            guard images.count == 1 else {
                attachmentError = "饮食记录一次一张，请先移除多余图片。"
                return
            }
            guard store.requirePro(.foodPhoto) else { return }
            Haptics.impact(.light)
            input = ""
            focused = false
            KeyboardDismiss.dismiss()
            draftAttachments = []
            imagePurpose = .review
            store.sendCoachFoodPhotos(images[0], caption: caption)
            return
        }

        guard store.requirePro(.coachVision) else { return }

        Haptics.impact(.light)
        input = ""
        focused = false
        KeyboardDismiss.dismiss()
        draftAttachments = []
        store.sendCoachPhotos(images, caption: caption)
    }

    func stageCameraImage(_ image: UIImage) {
        let prepared = image.fitWithin(maxDimension: 1600)
        guard let data = prepared.jpegData(compressionQuality: 0.75) else {
            attachmentError = "照片处理失败，换一张试试。"
            return
        }
        appendDraft(image: prepared, data: data)
    }

    /// 控制面 UI action 请求打开 sheet。
    /// `onChange` 只在 view 已挂载时触发，所以新进入教练 Tab 时也要在 onAppear 调一次。
    func presentCoachSheetIfNeeded() {
        if store.coachEquipmentScanRequested {
            if store.requirePro(.equipmentScan) {
                showEquipmentScan = true
            }
            store.coachEquipmentScanRequested = false
        }
        if store.coachBodyAnalysisRequested {
            if store.requirePro(.bodyPhoto) {
                showBodyAnalysis = true
            }
            store.coachBodyAnalysisRequested = false
        }
    }

    /// 相册多选加载：按剩余槽位、单张大小和总大小校验；
    /// 校验失败的图片不会进入草稿，只设置 attachmentError。
    @MainActor
    func loadPickedPhotos() async {
        guard !isLoadingAttachments else { return }
        isLoadingAttachments = true
        defer {
            isLoadingAttachments = false
            photoItems = []
        }

        guard draftVideo == nil else {
            attachmentError = "请先移除已选视频，图片和视频不能同时发送。"
            return
        }
        let remaining = CoachAttachmentPolicy.remainingImageSlots(currentCount: draftAttachments.count)
        guard remaining > 0 else {
            attachmentError = "最多只能添加 \(CoachAttachmentPolicy.maxImages) 张照片。"
            return
        }

        let selected = photoItems
        var accepted: [CoachDraftImage] = []
        for item in selected.prefix(remaining) {
            do {
                let loaded = try await PhotoLibraryLoader.load(
                    item,
                    maxDimension: 1600,
                    compressionQuality: 0.75,
                    maxBytes: CoachAttachmentPolicy.maxImageBytes
                )
                accepted.append(
                    CoachDraftImage(image: loaded.image, data: loaded.jpegData)
                )
            } catch {
                attachmentError = error.localizedDescription
            }
        }

        for attachment in accepted {
            if let error = CoachAttachmentPolicy.validationError(
                appending: attachment.data,
                to: draftAttachments.map(\.data)
            ) {
                attachmentError = error
                break
            }
            draftAttachments.append(attachment)
        }
        if selected.count > remaining {
            attachmentError = "最多只能添加 \(CoachAttachmentPolicy.maxImages) 张照片。"
        }
    }

    @MainActor
    func consumePendingCoachAttachments() {
        guard !store.pendingCoachAttachmentData.isEmpty else { return }
        guard draftVideo == nil else {
            store.pendingCoachAttachmentData = []
            attachmentError = "请先移除已选视频，图片和视频不能同时发送。"
            return
        }
        let incoming = store.pendingCoachAttachmentData
        store.pendingCoachAttachmentData = []
        for data in incoming {
            guard let image = UIImage(data: data) else {
                attachmentError = "有一张照片无法读取，请重新选择。"
                continue
            }
            appendDraft(image: image, data: data)
        }
    }

    @MainActor
    func loadVideo(_ item: PhotosPickerItem) async {
        guard !isLoadingVideo else { return }
        guard draftAttachments.isEmpty else {
            videoItem = nil
            attachmentError = "请先清空已选图片，图片和视频不能同时发送。"
            return
        }
        isLoadingVideo = true
        defer {
            isLoadingVideo = false
            videoItem = nil
        }
        do {
            let video = try await VideoAttachmentProcessor.prepare(item)
            draftVideo = video
            attachmentError = nil
        } catch {
            attachmentError = error.localizedDescription
        }
    }

    func appendDraft(image: UIImage, data: Data) {
        guard draftVideo == nil else {
            attachmentError = "请先移除已选视频，图片和视频不能同时发送。"
            return
        }
        if let error = CoachAttachmentPolicy.validationError(
            appending: data,
            to: draftAttachments.map(\.data)
        ) {
            attachmentError = error
            return
        }
        draftAttachments.append(CoachDraftImage(image: image, data: data))
        attachmentError = nil
    }

    /// 纯文本发送入口：有远程 AI 或未开通 Pro 时走控制面；
    /// 否则按“计划调整 / 排期 / 普通教练”分流。
    func send(_ text: String) {
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !trimmed.isEmpty, !store.isReplying else { return }
        Haptics.impact(.light)
        // 先结束编辑，再发请求：避免消息插入、键盘收起和列表滚动同时发生。
        input = ""
        focused = false
        KeyboardDismiss.dismiss()
        if store.canUseRemoteAI || !store.hasProAccess {
            store.sendCoachControlTurn(trimmed)
            return
        }
        if store.planAdjustmentStage > 0 {
            guard store.requirePro(.trainingPlan) else { return }
            store.sendPlanAdjustmentMessage(trimmed)
        } else if store.isPlanScheduleRequest(trimmed) {
            guard store.requirePro(.trainingPlan) else { return }
            store.beginPlanAdjustment()
            store.sendPlanAdjustmentMessage(trimmed)
        } else {
            store.sendChat(trimmed)
        }
    }
}
