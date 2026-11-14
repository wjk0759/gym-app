import SwiftUI

extension CoachChatView {
    @ViewBuilder
    var coachInboxSection: some View {
        let unread = store.coachInbox.filter { $0.status == "unread" }
        if !unread.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("教练动态")
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Button("全部已读") {
                        store.markAllCoachInboxRead()
                    }
                    .font(AppType.micro.weight(.semibold))
                    .foregroundStyle(Theme.cobalt)
                    .buttonStyle(.plain)
                }
                ForEach(unread.prefix(3)) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(AppType.caption.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text(item.body)
                            .font(AppType.micro)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        if item.capabilityID == "review.weekly" {
                            Button("看复盘") {
                                Task {
                                    try? await APIClient.shared.markCoachInboxRead(id: item.id)
                                }
                                store.sendCoachControlTurn("复盘本周")
                            }
                            .font(AppType.micro.weight(.semibold))
                            .foregroundStyle(Theme.cobalt)
                            .buttonStyle(.plain)
                        } else if let prompt = item.payload?.prompt, !prompt.isEmpty {
                            Button("问教练") {
                                Task {
                                    try? await APIClient.shared.markCoachInboxRead(id: item.id)
                                }
                                send(prompt)
                            }
                            .font(AppType.micro.weight(.semibold))
                            .foregroundStyle(Theme.cobalt)
                            .buttonStyle(.plain)
                        } else if item.kind == "plan" {
                            Button("打开训练手账") {
                                Task {
                                    try? await APIClient.shared.markCoachInboxRead(id: item.id)
                                }
                                store.selectedTab = 1
                                store.refreshCoachInbox()
                            }
                            .font(AppType.micro.weight(.semibold))
                            .foregroundStyle(Theme.cobalt)
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Theme.ink.opacity(0.035),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
            }
            .card(padding: 14)
        }
    }

    @ViewBuilder
    var coachControlCards: some View {
        if let pending = store.coachPending {
            coachPendingCard(pending)
        }
        if let receipt = store.coachReceipt {
            coachReceiptCard(receipt)
        }
    }

    func coachPendingCard(_ pending: CoachPendingState) -> some View {
        CoachCard(border: Theme.cobalt.opacity(0.25)) {
            VStack(alignment: .leading, spacing: 10) {
                CoachCardHeader(
                    eyebrow: pending.kind == "insight"
                        ? "COACH / 洞察"
                        : "COACH / 待确认",
                    status: pending.kind == "draft"
                        ? "待补充"
                        : (pending.kind == "insight" ? "只读" : "待执行")
                )

                if pending.kind == "draft" {
                    Text("还需要补充一点信息，直接在输入框回复即可。")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                } else if pending.capabilityID == "training.preview_next" {
                    trainingPreviewPendingContent(pending)
                } else if pending.capabilityID == "review.weekly"
                            || pending.capabilityID == "diet.review_day"
                            || pending.capabilityID == "body.review_trend" {
                    reviewPendingContent(pending)
                } else if pending.capabilityID == "training.generate_plan",
                          let plan = pending.payload?.plan {
                    planPendingContent(plan)
                } else if pending.capabilityID == "diet.log_food" {
                    dietPendingContent(pending)
                } else if pending.capabilityID == "training.reschedule" {
                    trainingPendingContent(pending)
                } else if pending.capabilityID == "training.log_cardio" {
                    cardioPendingContent(pending)
                } else if pending.capabilityID == "training.skip" {
                    Text("\(pending.payload?.date ?? "") · \(pending.payload?.title ?? "训练")")
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                } else if pending.capabilityID == "training.log_strength" {
                    strengthPendingContent(pending)
                } else if pending.capabilityID.hasPrefix("diet.") {
                    mealPendingContent(pending)
                } else if pending.capabilityID == "body.log_weight" {
                    Text("体重 \(pending.payload?.weightKG.map { String(format: "%.1f", $0) } ?? "—") kg")
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                } else if pending.capabilityID == "profile.update_goal" {
                    goalPendingContent(pending)
                } else {
                    Text("准备执行一项操作。")
                        .font(AppType.callout)
                        .foregroundStyle(Theme.ink)
                }

                if pending.kind == "card" || pending.kind == "proposal" {
                    HStack(spacing: 8) {
                        Button {
                            store.confirmCoachPending()
                        } label: {
                            CoachLoadingLabel(
                                title: "确认并执行",
                                isLoading: store.isCoachControlWorking
                            )
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(store.isCoachControlWorking)

                        Button("忽略") {
                            store.cancelCoachPending()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(store.isCoachControlWorking)
                    }
                } else if pending.kind == "insight" {
                    Button("知道了") {
                        store.cancelCoachPending()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    private func dietPendingContent(_ pending: CoachPendingState) -> some View {
        let items = pending.payload?.items ?? []
        let total = items.reduce(0) { $0 + $1.kcal }
        return VStack(alignment: .leading, spacing: 7) {
            Text("记录 \(pending.payload?.date ?? "") · \(mealLabel(pending.payload?.meal))")
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 6) {
                    Text(item.name)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if let portion = item.portion, !portion.isEmpty {
                        Text(portion)
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    Spacer(minLength: 0)
                    Text("\(Int(item.kcal)) kcal")
                        .foregroundStyle(Theme.cobalt)
                }
                .font(AppType.caption)
            }
            HStack {
                Text("合计")
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text("\(Int(total)) kcal")
                    .foregroundStyle(Theme.cobalt)
                    .fontWeight(.semibold)
            }
            .font(AppType.caption)
        }
    }

    private func planPendingContent(_ plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(plan.title)
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("\(plan.weeks) 周 · \(plan.days.count) 个训练日")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
            if let first = plan.days.first {
                Text("\(first.title) · \(first.exercises.count) 个动作")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
    }

    private func goalPendingContent(_ pending: CoachPendingState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let goal = pending.payload?.goalType {
                Text("目标：\(goal)")
                    .font(AppType.callout.weight(.semibold))
                    .foregroundStyle(Theme.ink)
            }
            if let weight = pending.payload?.targetWeightKG {
                Text("目标体重：\(String(format: "%.1f", weight)) kg")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            if let date = pending.payload?.targetDate {
                Text("目标日期：\(date)")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private func trainingPreviewPendingContent(_ pending: CoachPendingState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pending.payload?.summary ?? "下一练")
                .font(AppType.callout)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let lines = pending.payload?.wins, !lines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(lines, id: \.self) { line in
                        Text("· \(line)")
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if let watchouts = pending.payload?.watchouts, !watchouts.isEmpty {
                Text("留意：\(watchouts.joined(separator: "；"))")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func reviewPendingContent(_ pending: CoachPendingState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pending.payload?.summary ?? "本周复盘")
                .font(AppType.callout)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let wins = pending.payload?.wins, !wins.isEmpty {
                Text("做得好：\(wins.joined(separator: "；"))")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.cobalt)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let watchouts = pending.payload?.watchouts, !watchouts.isEmpty {
                Text("留意：\(watchouts.joined(separator: "；"))")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let action = pending.payload?.actions?.first {
                Text("下一步：\(action)")
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func strengthPendingContent(_ pending: CoachPendingState) -> some View {
        let sets = pending.payload?.sets ?? []
        let first = sets.first
        return VStack(alignment: .leading, spacing: 6) {
            Text(pending.payload?.title ?? "力量训练")
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(
                "\(pending.payload?.date ?? "") · \(sets.count) 组 × "
                + "\(first?.reps ?? 0) 次"
                + (first.map { " · \(String(format: "%.1f", $0.weightKG ?? 0)) kg" } ?? "")
            )
            .font(AppType.caption)
            .foregroundStyle(Theme.secondaryText)
        }
    }

    private func cardioPendingContent(_ pending: CoachPendingState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(pending.payload?.title ?? "有氧训练")
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("\(pending.payload?.date ?? "") · \(pending.payload?.durationMinutes ?? 0) 分钟")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private func mealPendingContent(_ pending: CoachPendingState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(pending.payload?.date ?? "") · \(mealLabel(pending.payload?.meal))")
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(actionLabel(pending.capabilityID))
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private func actionLabel(_ capability: String) -> String {
        switch capability {
        case "diet.log_planned_meal": return "按当天计划记录整餐"
        case "diet.skip_planned_meal": return "把这一餐标记为主动跳过"
        case "diet.restore_planned_meal": return "恢复被跳过的计划餐"
        case "diet.swap_meal": return "从本周计划换一餐"
        default: return "记录饮食"
        }
    }

    private func trainingPendingContent(_ pending: CoachPendingState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(pending.payload?.title ?? "训练")
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("\(pending.payload?.fromDate ?? "原日期") → \(pending.payload?.toDate ?? "新日期")")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private func coachReceiptCard(_ receipt: CoachReceipt) -> some View {
        CoachCard(border: Theme.primary.opacity(0.3)) {
            VStack(alignment: .leading, spacing: 9) {
                CoachCardHeader(eyebrow: "COACH / 已完成", status: "可撤销")
                Text(receipt.summary ?? "操作已完成")
                    .font(AppType.callout)
                    .foregroundStyle(Theme.ink)
                if let from = receipt.fromDate, let to = receipt.toDate {
                    Text("\(from) → \(to)")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                if store.coachUndoActionID != nil {
                    Button("撤销这次操作") {
                        store.undoCoachReceipt()
                    }
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.coral)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func mealLabel(_ value: String?) -> String {
        switch value {
        case "breakfast": return "早餐"
        case "lunch": return "午餐"
        case "dinner": return "晚餐"
        case "snack": return "加餐"
        default: return value ?? "餐次"
        }
    }
}
