import Foundation
import ImageIO
import PhotosUI
import SwiftUI
import UIKit

struct CoachChatView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var input = ""
    @State private var showPaywall = false
    @State private var showCamera = false
    @State private var cameraTitle = "拍照问教练"
    @State private var cameraHint = "尽量拍到完整动作或器械，避免脸和隐私部位。照片只用于本次对话。"
    @State private var showEquipmentScan = false
    @State private var showBodyAnalysis = false
    @State private var showDietLibrary = false
    @State private var showVideoReview = false
    @State private var draftAttachments: [CoachDraftImage] = []
    @State private var draftVideo: CoachVideoAttachment?
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var videoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var showVideoPicker = false
    @State private var isLoadingAttachments = false
    @State private var isLoadingVideo = false
    @State private var attachmentError: String?
    @State private var selectedDietRecipe: DietRecipeSelection?
    @FocusState private var focused: Bool


    private var canSend: Bool {
        !store.isReplying
            && !isLoadingVideo
            && !isLoadingAttachments
            && (!input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !draftAttachments.isEmpty
                || draftVideo != nil)
    }

    private var canAddImageAttachment: Bool {
        draftVideo == nil
            && !isLoadingAttachments
            && !isLoadingVideo
            && CoachAttachmentPolicy.remainingImageSlots(currentCount: draftAttachments.count) > 0
            && !store.isReplying
    }

    private var canAddVideoAttachment: Bool {
        draftAttachments.isEmpty
            && draftVideo == nil
            && !isLoadingAttachments
            && !isLoadingVideo
            && !store.isReplying
    }

    private struct StarterPrompt: Identifiable {
        let text: String
        let icon: String
        var id: String { text }
    }

    private let starters = [
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
                                            .font(.caption)
                                            .foregroundStyle(Theme.secondaryText)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        Theme.surface,
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
                    showBodyAnalysis = true
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
            .sheet(isPresented: $showPaywall) {
                PaywallView()
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

    private var adjustmentBanner: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("计划调整 · \(String(format: "%02d", store.planAdjustmentStage))")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.accent)
                Spacer()
                Button("结束调整") {
                    store.cancelPlanAdjustment()
                }
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
            }
            Text(
                store.planAdjustmentStage == 1
                    ? "说明问题"
                    : store.planAdjustmentStage == 2
                        ? "补充细节"
                        : "确认方案"
            )
            .font(.headline)
            .foregroundStyle(Theme.primaryText)
            HStack(spacing: 6) {
                ForEach(["说明问题", "补充细节", "确认方案"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(
                            label == (
                                store.planAdjustmentStage == 1
                                    ? "说明问题"
                                    : store.planAdjustmentStage == 2
                                        ? "补充细节"
                                        : "确认方案"
                            ) ? Theme.accent : Theme.tertiaryText
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .background(
            Theme.accent.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.accent.opacity(0.18), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Theme.background)
    }

    private var adjustmentQuickBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.planAdjustmentQuickReplies, id: \.self) { text in
                    Button {
                        store.sendPlanAdjustmentMessage(text)
                    } label: {
                        Text(text)
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.accent.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(SubtlePressStyle(scale: 0.95))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func proposalCard(_ proposal: PlanAdjustmentProposal) -> some View {
        CoachCard {
            VStack(alignment: .leading, spacing: 9) {
                CoachEyebrow(text: "调整方案 · 根据你的反馈")
                Text(proposal.headline)
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                Text(proposal.summary)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(proposal.changes.prefix(4).enumerated()), id: \.offset) { index, change in
                    HStack(alignment: .top, spacing: 8) {
                        Text(String(format: "%02d", index + 1))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 22, alignment: .leading)
                        Text(change)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack(spacing: 8) {
                    Button(proposal.regeneratePlan ? "生成新计划" : "应用调整") {
                        store.applyPlanAdjustment()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Button("再改一点") {
                        store.revisePlanAdjustment()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    private var agentRetryCard: some View {
        CoachInlineBanner(
            icon: "arrow.clockwise.circle.fill",
            tint: Theme.warning,
            title: "这次远程请求没有完成",
            message: "你的输入已保留，可以重试；不会重复生成计划。",
            actionTitle: "重试",
            isBusy: store.isReplying,
            action: { store.retryAgentChat() }
        )
    }

    @ViewBuilder
    private var agentUndoCard: some View {
        if let undo = store.pendingUndo {
            CoachInlineBanner(
                icon: "arrow.uturn.backward.circle.fill",
                title: "已执行：\(undo.title)",
                message: "5 分钟内可以撤销这次操作",
                actionTitle: "撤销",
                action: { store.undoLastAgentAction() }
            )
        }
    }

    private var agentActionsCard: some View {
        CoachCard(border: Theme.accent.opacity(0.25)) {
            VStack(alignment: .leading, spacing: 10) {
                CoachCardHeader(
                    eyebrow: "AGENT 操作",
                    status: store.agentActions.contains(where: { $0.requiresConfirmation }) ? "待确认" : "可执行"
                )

                ForEach(store.agentActions) { action in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: agentActionIcon(action.type))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(action.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.primaryText)
                            if !action.summary.isEmpty {
                                Text(action.summary)
                                    .font(.caption)
                                    .foregroundStyle(Theme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }

                Text("这些操作只在 FitAI 内执行，不会跨 App，也不涉及付款。")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)

                HStack(spacing: 8) {
                    Button {
                        store.executeAgentActions()
                    } label: {
                        CoachLoadingLabel(
                            title: "确认并执行",
                            isLoading: store.isExecutingAgentActions
                        )
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(store.isExecutingAgentActions)

                    Button("忽略") {
                        store.dismissAgentActions()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(store.isExecutingAgentActions)
                }
            }
        }
    }

    private func agentActionIcon(_ type: String) -> String {
        switch type {
        case "reschedule_training": return "calendar.badge.clock"
        case "skip_training": return "forward.end"
        case "start_training": return "play.circle"
        case "open_screen": return "rectangle.portrait.and.arrow.right"
        case "update_goal": return "target"
        case "log_body_metric": return "scalemass"
        case "create_diet_plan": return "fork.knife"
        case "recognize_equipment": return "camera.viewfinder"
        case "analyze_body": return "figure.stand"
        default: return "bolt"
        }
    }

    private func dietWeekCard(_ week: RemoteDietWeek) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("本周饮食计划", systemImage: "fork.knife")
                    .font(.headline)
                Text(week.generatedBy == "ai" ? "AI" : "模板")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(week.generatedBy == "ai" ? Theme.accent : Theme.tertiaryText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        (week.generatedBy == "ai" ? Theme.accent : Theme.tertiaryText).opacity(0.10),
                        in: Capsule()
                    )
                Spacer()
                Text(week.strategy?.label ?? "饮食")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }

            Text("点开每天看餐单，点菜名查看家常做法。")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)

            if let warning = week.warning, !warning.isEmpty {
                Text(warning)
                    .font(.caption2)
                    .foregroundStyle(Theme.warning)
            }

            ForEach(week.days) { day in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(day.meals) { meal in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(meal.name) · \(meal.kcal) kcal")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.primaryText)

                                if let dishes = meal.dishes, !dishes.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        ForEach(Array(dishes.enumerated()), id: \.offset) { pair in
                                            let dish = pair.element
                                            DietDishRow(dish: dish) {
                                                selectedDietRecipe = DietRecipeSelection(
                                                    dayTitle: day.title,
                                                    mealName: meal.name,
                                                    dish: dish
                                                )
                                            }
                                        }
                                    }
                                } else {
                                    Text(meal.items.joined(separator: "、"))
                                        .font(.caption2)
                                        .foregroundStyle(Theme.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    HStack {
                        Text(day.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                        Spacer()
                        Text("\(day.targets.targetKcal ?? 0) kcal")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
                .tint(Theme.accent)
                if day.id != week.days.last?.id {
                    Divider().opacity(0.15)
                }
            }

            if let caution = week.strategy?.caution, !caution.isEmpty {
                Text(caution)
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func coachEquipmentCard(_ result: EquipmentScanResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("器械识别", systemImage: "camera.viewfinder")
                    .font(.headline)
                Spacer()
                Button("清除") {
                    store.coachEquipmentResult = nil
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.tertiaryText)
            }

            if !result.description.isEmpty {
                Text(result.description)
                    .font(.caption)
                    .foregroundStyle(result.notInLibrary ? Color.orange : Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if result.candidates.isEmpty {
                Text(result.notInLibrary ? "动作库未收录；可在识别页自定义添加。" : "没有匹配到动作库里的器械。")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            } else {
                ForEach(result.candidates) { candidate in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.exercise.nameZH)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.primaryText)
                            Text("\(candidate.exercise.muscle.label) · \(candidate.exercise.equipment.label)")
                                .font(.caption2)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        Spacer()
                        Button(isEquipmentSaved(candidate) ? "已加入" : "加入") {
                            guard !isEquipmentSaved(candidate) else { return }
                            store.addEquipment(
                                EquipmentItem(
                                    name: candidate.exercise.nameZH,
                                    slug: candidate.exercise.slug,
                                    muscle: candidate.exercise.muscle,
                                    equipment: candidate.exercise.equipment,
                                    videoURL: candidate.exercise.videoURL?.absoluteString,
                                    notes: "来自拍照识别",
                                    source: "recognition"
                                )
                            )
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isEquipmentSaved(candidate) ? Theme.tertiaryText : Theme.accent)
                        .disabled(isEquipmentSaved(candidate))
                    }
                    if candidate.id != result.candidates.last?.id {
                        Divider().opacity(0.15)
                    }
                }
            }
        }
        .card()
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func isEquipmentSaved(_ candidate: EquipmentCandidate) -> Bool {
        store.equipmentLibrary.contains { $0.slug == candidate.exercise.slug }
    }

    private func agentProposalCard(_ proposal: AgentPlanProposal) -> some View {
        CoachCard(border: Theme.accent.opacity(0.25)) {
            VStack(alignment: .leading, spacing: 9) {
                CoachCardHeader(eyebrow: "AGENT 计划草案", status: "待确认")

                Text(proposal.title)
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if !proposal.changes.isEmpty {
                    ForEach(proposal.changes, id: \.self) { change in
                        HStack(alignment: .top, spacing: 7) {
                            Circle()
                                .fill(Theme.accent)
                                .frame(width: 5, height: 5)
                                .padding(.top, 5)
                            Text(change)
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if let proposed = proposal.proposed {
                    HStack(spacing: 12) {
                        if let weeklyDays = proposed.weeklyDays {
                            Text("每周 \(weeklyDays) 练")
                        }
                        if let minutes = proposed.sessionMinutes {
                            Text("\(minutes) 分钟/次")
                        }
                        if let weeks = proposed.weeks {
                            Text("\(weeks) 周")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                }

                HStack(spacing: 8) {
                    Button {
                        store.applyAgentProposal()
                    } label: {
                        CoachLoadingLabel(
                            title: "应用到正式计划",
                            isLoading: store.isAgentWorking
                        )
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(store.isAgentWorking)

                    Button("忽略") {
                        store.dismissAgentProposal()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(store.isAgentWorking)
                }
            }
        }
    }

    private var inputPlaceholder: String {
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

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 11) {
                    HeroGlyph(
                        symbol: "bubble.left.and.bubble.right.fill",
                        size: 76,
                        tint: Theme.accent
                    )
                    .offset(x: -4, y: 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI 私人健身教练")
                            .font(.headline)
                            .foregroundStyle(Theme.primaryText)
                        Text("训练、饮食、恢复、计划都能问")
                            .font(.caption2)
                            .foregroundStyle(Theme.tertiaryText)
                        Text(store.canUseRemoteAI ? "DeepSeek 远程 AI · 读取训练上下文" : "本地规则建议 · 未调用模型")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(store.canUseRemoteAI ? Theme.accent : Theme.tertiaryText)
                    }
                }

                Text("涉及疼痛、孕期、术后等情况，我会建议你就医，而不是继续加练。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .staggerIn(0)

            if !store.canUseRemoteAI {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("解锁 DeepSeek AI 教练")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.primaryText)
                            Text("当前使用本地规则建议；Pro 会员可使用完整 AI 教练。")
                                .font(.caption2)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 14)
                }
                .buttonStyle(CardPressStyle(scale: 0.985))
                .staggerIn(1)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("快速开始")
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(starters) { item in
                        Button {
                            send(item.text)
                        } label: {
                            VStack(alignment: .leading, spacing: 9) {
                                Image(systemName: item.icon)
                                    .font(.headline)
                                    .foregroundStyle(Theme.accent)
                                Text(item.text)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.primaryText)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
                            .padding(12)
                            .background(
                                Theme.surfaceStrong,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                        }
                        .buttonStyle(CardPressStyle(scale: 0.98))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .staggerIn(2)

            weeklyRecap
                .staggerIn(3)
        }
    }

    private var weeklyRecap: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("本周状态")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text("第 \(store.currentPlanWeek) 周")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }

            Text("\(store.currentWeekCompletedCount)/\(store.currentWeekPlannedCount) 练 · 完成率 \(Int(store.weeklyCompletion * 100))%")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)

            Button {
                send("帮我复盘一下本周训练，接下来应该怎么调整？")
            } label: {
                Label("让教练复盘本周", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }

    private func bubble(_ message: ChatMessage) -> some View {
        CoachChatBubble(isUser: message.role == .user, isSafety: message.isSafety) {
            VStack(alignment: .leading, spacing: 6) {
                if message.isSafety {
                    Label("安全提醒", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
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
                        .font(.subheadline)
                        .foregroundStyle(message.role == .user ? Theme.onAccent : Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var attachmentUploadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.28)
            ProgressView()
                .tint(.white)
                .scaleEffect(1.05)
        }
        .allowsHitTesting(false)
    }

    private var coachQuickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CoachQuickActionButton(title: "训练计划", icon: "calendar") {
                    send("帮我安排今天的训练")
                }
                CoachQuickActionButton(title: "饮食方案", icon: "fork.knife") {
                    showDietLibrary = true
                }
                CoachQuickActionButton(title: "动作点评", icon: "camera.viewfinder") {
                    cameraTitle = "动作点评"
                    cameraHint = "拍全身侧面，光线清楚，尽量包含器械和完整动作。照片只用于本次点评。"
                    showCamera = true
                }
                CoachQuickActionButton(title: "视频点评", icon: "video.fill") {
                    showVideoReview = true
                }
                CoachQuickActionButton(title: "器械识别", icon: "dumbbell") {
                    showEquipmentScan = true
                }
                CoachQuickActionButton(title: "记录", icon: "list.bullet.rectangle") {
                    store.selectedTab = 1
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            Menu {
                Button {
                    Haptics.tap()
                    cameraTitle = "拍照问教练"
                    cameraHint = "尽量拍到完整动作或器械，避免脸和隐私部位。照片只用于本次对话。"
                    focused = false
                    KeyboardDismiss.dismiss()
                    showCamera = true
                } label: {
                    Label("拍照", systemImage: "camera.fill")
                }
                .disabled(!canAddImageAttachment)

                Button {
                    Haptics.tap()
                    focused = false
                    KeyboardDismiss.dismiss()
                    showPhotoPicker = true
                } label: {
                    Label("从相册选照片", systemImage: "photo.on.rectangle")
                }
                .disabled(!canAddImageAttachment)

                Button {
                    Haptics.tap()
                    focused = false
                    KeyboardDismiss.dismiss()
                    showVideoPicker = true
                } label: {
                    Label("选择视频", systemImage: "video.fill")
                }
                .disabled(!canAddVideoAttachment)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 40, height: 42)
                    .background(Theme.surfaceStrong, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(SubtlePressStyle())
            .disabled(!canAddImageAttachment && !canAddVideoAttachment)
            .accessibilityLabel("添加图片或视频")

            TextField(inputPlaceholder, text: $input, axis: .vertical)
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
                        .fill(
                            Color.white.opacity(colorScheme == .dark ? 0.075 : 0.46)
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            Color.white.opacity(colorScheme == .dark ? 0.10 : 0.42),
                            lineWidth: 0.8
                        )
                }

            if store.isReplying {
                Button {
                    Haptics.impact(.light)
                    KeyboardDismiss.dismiss()
                    store.cancelAgentChat()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Theme.warning))
                }
                .buttonStyle(SubtlePressStyle())
                .accessibilityLabel("停止本次回复")
            } else {
                Button {
                    sendCurrent()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle().fill(canSend ? Theme.accent : Theme.secondaryText.opacity(0.35))
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
            GlassSurface(cornerRadius: 26, material: true)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(
                    focused
                        ? Theme.accent.opacity(0.55)
                        : Theme.stroke,
                    lineWidth: focused ? 1.1 : 0.8
                )
                .animation(Motion.quick, value: focused)
        }
        .shadow(
            color: Theme.shadow.opacity(colorScheme == .dark ? 0.42 : 0.20),
            radius: 18,
            y: 8
        )
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    private func sendCurrent() {
        guard !store.isReplying, !isLoadingVideo, !isLoadingAttachments else { return }
        let caption = String(input.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))

        if let video = draftVideo {
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
                videoDurationSeconds: video.durationSeconds
            )
            return
        }

        if draftAttachments.isEmpty {
            send(input)
            return
        }

        let images = draftAttachments.map(\.data)
        guard !images.isEmpty else { return }

        Haptics.impact(.light)
        input = ""
        focused = false
        KeyboardDismiss.dismiss()
        draftAttachments = []
        store.sendCoachPhotos(images, caption: caption)
    }

    private func stageCameraImage(_ image: UIImage) {
        let prepared = image.fitWithin(maxDimension: 1600)
        guard let data = prepared.jpegData(compressionQuality: 0.75) else {
            attachmentError = "照片处理失败，换一张试试。"
            return
        }
        appendDraft(image: prepared, data: data)
    }

    @MainActor
    private func loadPickedPhotos() async {
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
    private func consumePendingCoachAttachments() {
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
    private func loadVideo(_ item: PhotosPickerItem) async {
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

    private func appendDraft(image: UIImage, data: Data) {
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

    private var attachmentDraftBar: some View {
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

    private func send(_ text: String) {
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !trimmed.isEmpty, !store.isReplying else { return }
        Haptics.impact(.light)
        // 先结束编辑，再发请求：避免消息插入、键盘收起和列表滚动同时发生。
        input = ""
        focused = false
        KeyboardDismiss.dismiss()
        if store.canUseRemoteAI {
            // 所有 Skill、所有自然语言都先交给 Agent 理解；不再由本地关键词决定意图。
            store.sendAgentChat(trimmed)
        } else if store.planAdjustmentStage > 0 {
            store.sendPlanAdjustmentMessage(trimmed)
        } else if store.isPlanScheduleRequest(trimmed) {
            store.beginPlanAdjustment()
            store.sendPlanAdjustmentMessage(trimmed)
        } else {
            store.sendChat(trimmed)
        }
    }
}
