import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var manager

    @State private var selectedProductID: String?

    private var effectiveProduct: Product? {
        manager.products.first { $0.id == selectedProductID }
            ?? manager.products.first { $0.id == SubscriptionManager.ProductID.yearly }
            ?? manager.products.first
    }

    private var annualSaving: Int? {
        guard let monthly = manager.products.first(where: {
            $0.id == SubscriptionManager.ProductID.monthly
        }),
              let yearly = manager.products.first(where: {
                  $0.id == SubscriptionManager.ProductID.yearly
              }) else {
            return nil
        }
        let monthlyPrice = NSDecimalNumber(decimal: monthly.price).doubleValue
        let yearlyPrice = NSDecimalNumber(decimal: yearly.price).doubleValue
        guard monthlyPrice > 0, yearlyPrice > 0 else { return nil }
        let fullYear = monthlyPrice * 12
        let saving = Int(((fullYear - yearlyPrice) / fullYear * 100).rounded())
        return saving > 0 ? saving : nil
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(spacing: 20) {
                    header
                    benefits
                    productsSection
                    restoreSection
                    legal
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(AppBackground())
            .safeAreaInset(edge: .bottom) {
                purchaseBar
            }
            .navigationTitle("练途 Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                await manager.load()
            }
            .alert(
                "提示",
                isPresented: Binding(
                    get: { manager.message != nil },
                    set: { if !$0 { manager.message = nil } }
                )
            ) {
                Button("知道了", role: .cancel) {
                    manager.message = nil
                }
            } message: {
                Text(manager.message ?? "")
            }
        }
    }

    @ViewBuilder
    private var purchaseBar: some View {
        if !manager.isPro, let product = effectiveProduct {
            VStack(spacing: 8) {
                Button {
                    Task { await manager.purchase(product) }
                } label: {
                    HStack {
                        Text("立即订阅")
                        Spacer()
                        Text(product.displayPrice)
                    }
                    .font(.headline)
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(Theme.accent)
                    )
                }
                .buttonStyle(.plain)

                Text("自动续期，可随时在系统设置中取消")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Theme.chrome)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Theme.stroke)
                    .frame(height: 1)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.16))
                    .frame(width: 76, height: 76)
                Image(systemName: "crown.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }

            Text("把 AI 教练带在身边")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("解锁 DeepSeek AI 计划、三种专业 Skill 与完整的教练对话。")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 24)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefit("DeepSeek AI 计划生成与调整", icon: "wand.and.stars")
            benefit("健身教练、康复师、营养师 AI Skills", icon: "person.3.fill")
            benefit("周复盘、训练偏好记忆与动作替代", icon: "bubble.left.and.bubble.right")
            benefit("器械拍照识别与饮食记录", icon: "camera.viewfinder")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func benefit(_ text: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)
            Spacer()
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.accent)
        }
    }

    @ViewBuilder
    private var productsSection: some View {
        if manager.isPro {
            VStack(spacing: 10) {
                Label("已订阅练途 Pro", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                Text("所有 Pro 功能已解锁。")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .card()
        } else if manager.isLoading {
            VStack(spacing: 10) {
                ProgressView().tint(Theme.accent)
                Text("正在加载订阅商品…")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .card(padding: 24)
        } else if manager.products.isEmpty {
            VStack(spacing: 12) {
                Text("订阅即将开放")
                    .font(.headline)
                Text("练途 Pro 正在准备中，稍后可以在 App Store 完成订阅。")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                Button("重新加载") {
                    Task { await manager.load() }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .frame(maxWidth: .infinity)
            .card()
        } else {
            VStack(spacing: 10) {
                ForEach(orderedProducts, id: \.id) { product in
                    let selected = effectiveProduct?.id == product.id
                    let yearly = product.id == SubscriptionManager.ProductID.yearly

                    Button {
                        selectedProductID = product.id
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 6) {
                                    Text(product.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    if yearly {
                                        Text("推荐")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(Color.black)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Theme.accent, in: Capsule())
                                        if let annualSaving {
                                            Text("省 \(annualSaving)%")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(Theme.accent)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Theme.accent.opacity(0.10), in: Capsule())
                                        }
                                    }
                                }
                                Text(product.description)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.secondaryText)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Text(product.displayPrice)
                                .font(.headline)
                                .foregroundStyle(selected ? Theme.accent : .white)

                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selected ? Theme.accent : Theme.tertiaryText)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selected ? Theme.accent.opacity(0.08) : Theme.surfaceStrong)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    selected ? Theme.accent.opacity(0.75) : Theme.stroke,
                                    lineWidth: selected ? 1.5 : 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var orderedProducts: [Product] {
        manager.products.sorted { lhs, rhs in
            if lhs.id == SubscriptionManager.ProductID.yearly { return true }
            if rhs.id == SubscriptionManager.ProductID.yearly { return false }
            return lhs.id < rhs.id
        }
    }

    private var restoreSection: some View {
        VStack(spacing: 8) {
            Button("恢复购买") {
                Task { await manager.restore() }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.accent)

            Text("订阅会自动续期，可随时在系统「设置 → Apple ID → 订阅」中取消。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var legal: some View {
        Text("付款将通过 Apple ID 完成。订阅到期前 24 小时会自动续期，可在系统设置中关闭。商品与价格以 App Store 页面为准。")
            .font(.caption2)
            .foregroundStyle(Theme.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 14)
    }
}
