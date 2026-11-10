import SwiftUI

extension CoachChatView {
    var adjustmentBanner: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("计划调整 · \(String(format: "%02d", store.planAdjustmentStage))")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.cobalt)
                Spacer()
                Button("结束调整") {
                    store.cancelPlanAdjustment()
                }
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
            }
            Text(
                store.planAdjustmentStage == 1
                    ? "说明问题"
                    : store.planAdjustmentStage == 2
                        ? "补充细节"
                        : "确认方案"
            )
            .font(AppType.headline)
            .foregroundStyle(Theme.ink)
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
                            ) ? Theme.cobalt : Theme.tertiaryText
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .background(
            Theme.cobalt.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.cobalt.opacity(0.18), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Theme.background)
    }

    var adjustmentQuickBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.planAdjustmentQuickReplies, id: \.self) { text in
                    Button {
                        store.sendPlanAdjustmentMessage(text)
                    } label: {
                        Text(text)
                            .font(AppType.caption)
                            .foregroundStyle(Theme.cobalt)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.cobalt.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(SubtlePressStyle(scale: 0.95))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    func proposalCard(_ proposal: PlanAdjustmentProposal) -> some View {
        CoachCard {
            VStack(alignment: .leading, spacing: 9) {
                CoachEyebrow(text: "调整方案 · 根据你的反馈")
                Text(proposal.headline)
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Text(proposal.summary)
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(proposal.changes.prefix(4).enumerated()), id: \.offset) { index, change in
                    HStack(alignment: .top, spacing: 8) {
                        Text(String(format: "%02d", index + 1))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.cobalt)
                            .frame(width: 22, alignment: .leading)
                        Text(change)
                            .font(AppType.caption)
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

    var agentRetryCard: some View {
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
    var agentUndoCard: some View {
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

    var agentActionsCard: some View {
        CoachCard(border: Theme.cobalt.opacity(0.25)) {
            VStack(alignment: .leading, spacing: 10) {
                CoachCardHeader(
                    eyebrow: "AGENT 操作",
                    status: store.agentActions.contains(where: { $0.requiresConfirmation }) ? "待确认" : "可执行"
                )

                ForEach(store.agentActions) { action in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: agentActionIcon(action.type))
                            .font(AppType.callout.weight(.semibold))
                            .foregroundStyle(Theme.cobalt)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(action.title)
                                .font(AppType.callout.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            if !action.summary.isEmpty {
                                Text(action.summary)
                                    .font(AppType.caption)
                                    .foregroundStyle(Theme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }

                Text("这些操作只在叫练内执行，不会跨 App，也不涉及付款。")
                    .font(.system(size: 9.5, weight: .medium))
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

    func agentActionIcon(_ type: String) -> String {
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

    func dietWeekCard(_ week: RemoteDietWeek) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("本周饮食计划", systemImage: "fork.knife")
                    .font(AppType.headline)
                Text(week.generatedBy == "ai" ? "AI" : "模板")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(week.generatedBy == "ai" ? Theme.cobalt : Theme.tertiaryText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        (week.generatedBy == "ai" ? Theme.cobalt : Theme.tertiaryText).opacity(0.10),
                        in: Capsule()
                    )
                Spacer()
                Text(week.strategy?.label ?? "饮食")
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.cobalt)
            }

            if let warning = week.warning, !warning.isEmpty {
                Text(warning)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.warning)
            }

            ForEach(week.days) { day in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(day.meals) { meal in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(meal.name) · \(meal.kcal) kcal")
                                    .font(AppType.caption.weight(.semibold))
                                    .foregroundStyle(Theme.ink)

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
                                        .font(.system(size: 9.5, weight: .medium))
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
                            .font(AppType.callout.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(day.targets.targetKcal ?? 0) kcal")
                            .font(AppType.caption.weight(.semibold))
                            .foregroundStyle(Theme.cobalt)
                    }
                }
                .tint(Theme.cobalt)
                if day.id != week.days.last?.id {
                    Divider().opacity(0.15)
                }
            }

            if let caution = week.strategy?.caution, !caution.isEmpty {
                Text(caution)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    func coachEquipmentCard(_ result: EquipmentScanResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("器械识别", systemImage: "camera.viewfinder")
                    .font(AppType.headline)
                Spacer()
                Button("清除") {
                    store.coachEquipmentResult = nil
                }
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(Theme.tertiaryText)
            }

            if !result.description.isEmpty {
                Text(result.description)
                    .font(AppType.caption)
                    .foregroundStyle(result.notInLibrary ? Theme.ink : Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if result.candidates.isEmpty {
                Text(result.notInLibrary ? "动作库未收录；可在识别页自定义添加。" : "没有匹配到动作库里的器械。")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            } else {
                ForEach(result.candidates) { candidate in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.exercise.nameZH)
                                .font(AppType.callout.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            Text("\(candidate.exercise.muscle.label) · \(candidate.exercise.equipment.label)")
                                .font(.system(size: 9.5, weight: .medium))
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
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(isEquipmentSaved(candidate) ? Theme.tertiaryText : Theme.cobalt)
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

    func isEquipmentSaved(_ candidate: EquipmentCandidate) -> Bool {
        store.personalExerciseSlugs.contains(candidate.exercise.slug)
    }

    func agentProposalCard(_ proposal: AgentPlanProposal) -> some View {
        CoachCard(border: Theme.cobalt.opacity(0.25)) {
            VStack(alignment: .leading, spacing: 9) {
                CoachCardHeader(eyebrow: "AGENT 计划草案", status: "待确认")

                Text(proposal.title)
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if !proposal.changes.isEmpty {
                    ForEach(proposal.changes, id: \.self) { change in
                        HStack(alignment: .top, spacing: 7) {
                            Circle()
                                .fill(Theme.cobalt)
                                .frame(width: 5, height: 5)
                                .padding(.top, 5)
                            Text(change)
                                .font(AppType.caption)
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
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)

                    if let focus = proposed.focus, !focus.isEmpty {
                        HStack(spacing: 5) {
                            Text("重点")
                                .foregroundStyle(Theme.tertiaryText)
                            ForEach(focus.compactMap { BodyFocusArea(rawValue: $0)?.label }, id: \.self) { label in
                                Text(label)
                                    .font(AppType.micro.weight(.bold))
                                    .foregroundStyle(Theme.onPrimary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Theme.primary, in: Capsule(style: .continuous))
                            }
                        }
                        .font(AppType.micro)
                    }
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
}
