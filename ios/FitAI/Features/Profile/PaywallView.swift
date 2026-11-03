import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var manager
    @Environment(AppStore.self) private var store

    @State private var selectedProductID: String?
    @State private var legalDocument: LegalDocumentKind?

    private var effectiveProduct: Product? {
        manager.products.first { $0.id == selectedProductID }
            ?? manager.products.first { $0.id == SubscriptionManager.ProductID.yearly }
            ?? manager.products.first
    }

    /// StoreKit has a verified purchase but the server snapshot has not caught
    /// up yet. Keep the paywall honest: purchased is not the same as active.
    private var isAwaitingServerEntitlement: Bool {
        !store.hasProAccess && manager.isPro
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
                .appPagePadding()
                .padding(.top, 8)
                .padding(.bottom, 24)
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
            .sheet(item: $legalDocument) { kind in
                LegalDocumentView(kind: kind)
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
        if !store.hasProAccess, !manager.isPro, let product = effectiveProduct {
            VStack(spacing: 8) {
                Button {
                    Task { await manager.purchase(product) }
                } label: {
                    HStack {
                        Text("立即订阅")
                        Spacer()
                        Text(product.displayPrice)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 2)
                }
                .buttonStyle(PrimaryButtonStyle())

                Text("自动续期，可随时在系统设置中取消")
                    .font(.system(size: 9.5, weight: .medium))
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.onPrimary)
                    .frame(width: 38, height: 38)
                    .background(Theme.primary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("练途 Pro")
                        .font(AppType.overline)
                        .tracking(1.2)
                        .foregroundStyle(Theme.cobalt)
                    Text("解锁完整教练")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }

                Spacer(minLength: 0)
            }

            Text("把 AI 教练\n带在身边")
                .font(AppType.hero)
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("解锁 DeepSeek AI 计划、完整私人教练对话与视觉分析。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorialCard(accent: Theme.lime)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefit("DeepSeek AI 计划生成与调整", icon: "wand.and.stars")
            benefit("一个 AI 私人健身教练，训练、饮食、恢复都能问", icon: "person.fill")
            benefit("周复盘、训练偏好记忆与动作替代", icon: "bubble.left.and.bubble.right")
            benefit("器械拍照识别与饮食记录", icon: "camera.viewfinder")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func benefit(_ text: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Theme.cobalt)
                .frame(width: 22)
            Text(text)
                .font(AppType.callout)
                .foregroundStyle(Theme.ink)
            Spacer()
            Image(systemName: "checkmark")
                .font(AppType.micro)
                .foregroundStyle(Theme.cobalt)
        }
    }

    @ViewBuilder
    private var productsSection: some View {
        if store.hasProAccess {
            VStack(spacing: 10) {
                Label("已开通练途 Pro", systemImage: "checkmark.seal.fill")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.cobalt)
                if let expires = store.accessSnapshot?.proExpiresAt {
                    Text("有效期至 \(expires.formatted(date: .abbreviated, time: .omitted))")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity)
            .card()
        } else if isAwaitingServerEntitlement {
            VStack(spacing: 10) {
                Label("订阅已购买，正在同步权益", systemImage: "arrow.triangle.2.circlepath")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.cobalt)
                Text("Apple 已确认购买，正在等待服务端开通。通常几秒内完成，不需要重复支付。")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                Button("重新同步") {
                    Task {
                        await manager.refreshEntitlements()
                        await store.refreshAccess()
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .frame(maxWidth: .infinity)
            .card()
        } else if manager.isLoading {
            VStack(spacing: 10) {
                ProgressView().tint(Theme.cobalt)
                Text("正在加载订阅商品…")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .card(padding: 24)
        } else if manager.products.isEmpty {
            VStack(spacing: 12) {
                Text("订阅即将开放")
                    .font(AppType.headline)
                Text("练途 Pro 正在准备中，稍后可以在 App Store 完成订阅。")
                    .font(AppType.caption)
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
                                        .font(AppType.callout.weight(.semibold))
                                        .foregroundStyle(Theme.ink)
                                    if yearly {
                                        Text("推荐")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(Theme.onAccent)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Theme.cobalt, in: Capsule())
                                        if let annualSaving {
                                            Text("省 \(annualSaving)%")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(Theme.cobalt)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Theme.cobalt.opacity(0.10), in: Capsule())
                                        }
                                    }
                                }
                                Text(product.description)
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundStyle(Theme.secondaryText)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Text(product.displayPrice)
                                .font(AppType.headline)
                                .foregroundStyle(selected ? Theme.cobalt : Theme.ink)

                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(selected ? Theme.cobalt : Theme.tertiaryText)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selected ? Theme.cobalt.opacity(0.08) : Theme.paper)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    selected ? Theme.cobalt.opacity(0.75) : Theme.stroke,
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
            .font(AppType.caption.weight(.semibold))
            .foregroundStyle(Theme.cobalt)

            Text("订阅会自动续期，可随时在系统「设置 → Apple ID → 订阅」中取消。")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var legal: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("付款将通过 Apple ID 完成。订阅到期前 24 小时会自动续期，可在系统设置中关闭。商品与价格以 App Store 页面为准。")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                legalLink("《用户协议》", kind: .terms)
                legalLink("《隐私政策》", kind: .privacy)
                legalLink("《健康免责声明》", kind: .health)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }

    private func legalLink(_ title: String, kind: LegalDocumentKind) -> some View {
        Button(title) {
            legalDocument = kind
        }
        .font(.system(size: 9.5, weight: .medium))
        .foregroundStyle(Theme.cobalt)
        .buttonStyle(.plain)
    }
}
