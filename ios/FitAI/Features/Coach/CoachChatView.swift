import Foundation
import ImageIO
import PhotosUI
import SwiftUI
import UIKit

struct CoachChatView: View {
    @Environment(AppStore.self) var store
    @Environment(\.colorScheme) var colorScheme

    @State var input = ""
    @State var showCamera = false
    @State var cameraTitle = "拍照问教练"
    @State var cameraHint = "尽量拍到完整动作或器械，避免脸和隐私部位。照片只用于本次对话。"
    @State var showEquipmentScan = false
    @State var showBodyAnalysis = false
    @State var showDietLibrary = false
    @State var showVideoReview = false
    @State var draftAttachments: [CoachDraftImage] = []
    @State var draftVideo: CoachVideoAttachment?
    @State var photoItems: [PhotosPickerItem] = []
    @State var videoItem: PhotosPickerItem?
    @State var showPhotoPicker = false
    @State var showVideoPicker = false
    @State var isLoadingAttachments = false
    @State var isLoadingVideo = false
    @State var attachmentError: String?
    @State var selectedDietRecipe: DietRecipeSelection?
    @FocusState var focused: Bool

    var canSend: Bool {
        !store.isReplying
            && !isLoadingVideo
            && !isLoadingAttachments
            && (!input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !draftAttachments.isEmpty
                || draftVideo != nil)
    }

    var canAddImageAttachment: Bool {
        draftVideo == nil
            && !isLoadingAttachments
            && !isLoadingVideo
            && CoachAttachmentPolicy.remainingImageSlots(currentCount: draftAttachments.count) > 0
            && !store.isReplying
    }

    var canAddVideoAttachment: Bool {
        draftAttachments.isEmpty
            && draftVideo == nil
            && !isLoadingAttachments
            && !isLoadingVideo
            && !store.isReplying
    }

    struct StarterPrompt: Identifiable {
        let text: String
        let icon: String
        var id: String { text }
    }

    let starters = [
        StarterPrompt(text: "今天练什么？", icon: "calendar"),
        StarterPrompt(text: "没有器械怎么替代？", icon: "dumbbell"),
        StarterPrompt(text: "减脂怎么吃？", icon: "fork.knife"),
        StarterPrompt(text: "膝盖不舒服还能练吗？", icon: "cross.case")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if store.planAdjustmentStage > 0 {
                    adjustmentBanner
                }

                ScrollViewReader { proxy in
                    AppScrollView {
                        if store.chat.isEmpty {
                            welcome
                                .padding(20)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(store.chat) { message in
                                    bubble(message)
                                        .id(message.id)
                                        .transition(.opacity)
                                }

                                if store.isReplying {
                                    HStack(spacing: 9) {
                                        TypingDots()
                                        Text("教练正在输入…")
                                            .font(AppType.caption)
                                            .foregroundStyle(Theme.secondaryText)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        Theme.paper,
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    )
                                    .padding(.horizontal, 4)
                                    .transition(.opacity.combined(with: .offset(y: 8)))
                                }
                            }
                            .padding(20)
                        }
                    }
                    .onChange(of: store.chat.count) { _, _ in
                        guard let last = store.chat.last else { return }
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                    .onChange(of: store.isReplying) { _, _ in
                        guard let last = store.chat.last else { return }
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }

                if store.planAdjustmentStage > 0 {
                    if store.planAdjustmentStage == 3, let proposal = store.planAdjustmentProposal {
                        proposalCard(proposal)
                    } else {
                        adjustmentQuickBar
                    }
                } else {
                    if let proposal = store.agentProposal {
                        agentProposalCard(proposal)
                    }
                    if !store.agentActions.isEmpty {
                        agentActionsCard
                    }
                    if let week = store.dietWeekPlan {
                        dietWeekCard(week)
                    }
                    if let equipment = store.coachEquipmentResult {
                        coachEquipmentCard(equipment)
                    }
                    if store.agentProposal == nil && store.agentActions.isEmpty && !store.chat.isEmpty {
                        coachQuickActions
                    }
                }

                if store.lastAgentRetryText != nil {
                    agentRetryCard
                }
                if store.pendingUndo != nil {
                    agentUndoCard
                }

                if !draftAttachments.isEmpty
                    || draftVideo != nil
                    || isLoadingAttachments
                    || isLoadingVideo {
                    attachmentDraftBar
                }

                inputBar
            }
            .background(AppBackground())
            .navigationTitle(store.planAdjustmentStage > 0 ? "调整计划" : "AI 私人教练")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: store.planAdjustmentRequested) { _, requested in
                if requested {
                    store.beginPlanAdjustment()
                }
            }
            .onAppear {
                if store.planAdjustmentRequested {
                    store.beginPlanAdjustment()
                }
                consumePendingCoachAttachments()
            }
            .onChange(of: store.pendingCoachAttachmentData.count) { _, _ in
                consumePendingCoachAttachments()
            }
            .onChange(of: store.coachEquipmentScanRequested) { _, requested in
                if requested {
                    showEquipmentScan = true
                    store.coachEquipmentScanRequested = false
                }
            }
            .sheet(isPresented: $showEquipmentScan) {
                EquipmentRecognitionView(
                    onSaved: { item in
                        store.appendCoachNotice("已加入个人动作库：\(item.name)")
                    },
                    onRecognized: { result in
                        store.coachEquipmentResult = result
                    }
                )
            }
            .onChange(of: store.coachBodyAnalysisRequested) { _, requested in
                if requested {
                    if store.requirePro(.bodyPhoto) {
                        showBodyAnalysis = true
                    }
                    store.coachBodyAnalysisRequested = false
                }
            }
            .sheet(isPresented: $showBodyAnalysis) {
                BodyPhotoAnalysisView()
            }
            .sheet(isPresented: $showDietLibrary) {
                DietLibraryView()
            }
            .sheet(isPresented: $showVideoReview) {
                VideoReviewView()
            }
            .sheet(item: $selectedDietRecipe) { selection in
                DietRecipeSheet(selection: selection)
            }
            .fullScreenCover(isPresented: $showCamera) {
                PhotoCaptureView(
                    title: cameraTitle,
                    hint: cameraHint,
                    onImage: { image in
                        stageCameraImage(image)
                        showCamera = false
                    },
                    onCancel: {
                        showCamera = false
                    }
                )
            }
            .toolbar {
                if !store.chat.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("清空") { store.clearChat() }
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("收起") {
                        focused = false
                        KeyboardDismiss.dismiss()
                    }
                }
            }
            .onChange(of: photoItems.map(\.itemIdentifier)) { _, _ in
                guard !photoItems.isEmpty else { return }
                Task { await loadPickedPhotos() }
            }
            .onChange(of: videoItem?.itemIdentifier) { _, _ in
                guard let videoItem else { return }
                Task { await loadVideo(videoItem) }
            }
            .alert(
                "图片没有加入",
                isPresented: Binding(
                    get: { attachmentError != nil },
                    set: { if !$0 { attachmentError = nil } }
                )
            ) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(attachmentError ?? "")
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $photoItems,
                maxSelectionCount: max(
                    1,
                    CoachAttachmentPolicy.remainingImageSlots(currentCount: draftAttachments.count)
                ),
                matching: .images,
                photoLibrary: .shared()
            )
            .photosPicker(
                isPresented: $showVideoPicker,
                selection: $videoItem,
                matching: .videos,
                photoLibrary: .shared()
            )
        }
    }
}
