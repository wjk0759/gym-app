import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var manager = SubscriptionManager()

    var body: some View {
        NavigationStack {
            ScrollView {
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
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("FitAI Pro")
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

            Text("解锁完整的计划生成、教练对话与器械识别。")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 24)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefit("无限次 AI 计划生成与调整", icon: "wand.and.stars")
            benefit("教练对话、周复盘与训练偏好记忆", icon: "bubble.left.and.bubble.right")
            benefit("器械拍照识别与动作库", icon: "camera.viewfinder")
            benefit("饮食计划与热量记录", icon: "fork.knife")
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
                Label("已订阅 FitAI Pro", systemImage: "checkmark.seal.fill")
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
                Text("订阅商品尚未配置")
                    .font(.headline)
                Text("在 App Store Connect 创建月付/年付商品，或添加 StoreKit 配置文件后即可测试。")
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
                ForEach(manager.products, id: \.id) { product in
                    Button {
                        Task { await manager.purchase(product) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(product.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(product.description)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.secondaryText)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Text(product.displayPrice)
                                .font(.headline)
                                .foregroundStyle(Theme.accent)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.surfaceStrong)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
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
        Text("付款将通过 Apple ID 完成。订阅到期前 24 小时会自动续期，可在系统设置中关闭。当前版本为订阅功能基础实现，商品与价格以 App Store 页面为准。")
            .font(.caption2)
            .foregroundStyle(Theme.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 14)
    }
}
