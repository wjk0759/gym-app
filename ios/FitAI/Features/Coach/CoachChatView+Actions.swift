import SwiftUI
import PhotosUI
import UIKit

extension CoachChatView {
    func consumeCoachEntryPrompt() {
        guard let prompt = store.coachEntryPrompt else { return }
        store.coachEntryPrompt = nil
        input = prompt
        focused = true
    }

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

        guard store.requirePro(.coachVision) else { return }
        let images = draftAttachments.map(\.data)
        guard !images.isEmpty else { return }

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

    func send(_ text: String) {
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !trimmed.isEmpty, !store.isReplying else { return }
        Haptics.impact(.light)
        // 先结束编辑，再发请求：避免消息插入、键盘收起和列表滚动同时发生。
        input = ""
        focused = false
        KeyboardDismiss.dismiss()
        if store.canRouteToCoachControl(trimmed) {
            store.sendCoachControlTurn(trimmed)
            return
        }
        if store.canUseRemoteAI || !store.hasProAccess {
            // 免费用户一律先交给 Agent：文字教练只受每日额度约束，
            // 不能因为“像计划调整”就在发送前弹订阅。
            store.sendChat(trimmed)
        } else if store.planAdjustmentStage > 0 {
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
