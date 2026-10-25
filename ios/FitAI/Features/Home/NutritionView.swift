import SwiftUI
import UIKit

struct NutritionView: View {
    @Environment(AppStore.self) private var store

    @State private var showAlert = false
    @State private var message = ""
    @State private var isOpening = false

    private var targets: NutritionTargets {
        DietPlanner.targets(profile: store.profile)
    }

    private var meals: [MealSuggestion] {
        DietPlanner.meals(profile: store.profile)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                macroCard

                ForEach(meals) { meal in
                    mealCard(meal)
                }

                meituanCard
                disclaimer
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("饮食计划")
        .navigationBarTitleDisplayMode(.inline)
        .alert("美团外卖", isPresented: $showAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(message)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日热量目标")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(targets.kcal)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                Text("kcal")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }

            Text("按 \(store.profile.goalType.label) 目标与每周 \(store.profile.weeklyDays) 练估算。结果是一个区间，不需要精确到个位数。")
                .font(.caption)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var macroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("宏量营养素")
                .font(.headline)

            HStack(spacing: 10) {
                macro("蛋白质", "\(targets.protein)g", color: Theme.accent)
                macro("碳水", "\(targets.carbs)g", color: Theme.warning)
                macro("脂肪", "\(targets.fat)g", color: Color(red: 0.55, green: 0.70, blue: 0.98))
            }

            Text("BMR \(targets.bmr) kcal · 维持热量约 \(targets.tdee) kcal")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    private func macro(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func mealCard(_ meal: MealSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(meal.name)
                    .font(.headline)
                Spacer()
                Text("约 \(meal.kcal) kcal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }

            ForEach(meal.items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Theme.accent.opacity(0.8))
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var meituanCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "takeoutbag.and.cup.and.straw")
                    .foregroundStyle(Theme.accent)
                Text("附近外卖")
                    .font(.headline)
            }

            Text("美团联盟只提供活动/搜索跳转，不提供菜品营养数据。点开后请按商家页面为准。")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                openMeituan()
            } label: {
                Label(isOpening ? "正在打开…" : "在美团找轻食", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(isOpening)

            Text(store.useRemoteAI
                 ? "当前为远程模式：需要后端配置美团联盟链接。"
                 : "当前为本地模式：先在「我的 → AI 服务」打开远程模式，并配置联盟链接。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    private var disclaimer: some View {
        Text("饮食建议为估算，不构成医疗或疾病饮食处方。孕期、术后、糖尿病、肾病等特殊情况请咨询医生或营养师。")
            .font(.caption2)
            .foregroundStyle(Theme.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 14)
    }

    private func openMeituan() {
        guard store.useRemoteAI else {
            message = "美团入口依赖后端联盟链接。请先在「我的 → AI 服务」打开远程模式，并在后端 .env 里配置 MEITUAN_DEEPLINK_BASE。"
            showAlert = true
            return
        }

        isOpening = true
        Task { @MainActor in
            do {
                if let url = try await APIClient.shared.meituanLink(keyword: "轻食") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                } else {
                    message = "后端没有返回可用的美团链接。"
                    showAlert = true
                }
            } catch {
                message = "美团联盟未配置或后端不可用。上线前需要企业资质并申请 CPS 权限。"
                showAlert = true
            }
            isOpening = false
        }
    }
}
