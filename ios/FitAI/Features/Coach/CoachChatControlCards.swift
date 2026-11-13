import SwiftUI

extension CoachChatView {
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
                    eyebrow: "COACH / 待确认",
                    status: pending.kind == "draft" ? "待补充" : "待执行"
                )

                if pending.kind == "draft" {
                    Text("还需要补充一点信息，直接在输入框回复即可。")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
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
                } else if pending.capabilityID.hasPrefix("diet.") {
                    mealPendingContent(pending)
                } else if pending.capabilityID == "body.log_weight" {
                    Text("体重 \(pending.payload?.weightKG.map { String(format: "%.1f", $0) } ?? "—") kg")
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                } else {
                    Text("准备执行一项操作。")
                        .font(AppType.callout)
                        .foregroundStyle(Theme.ink)
                }

                if pending.kind == "card" {
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
