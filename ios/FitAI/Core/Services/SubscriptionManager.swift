import Foundation
import Observation
import StoreKit

@Observable
final class SubscriptionManager {
    enum ProductID {
        static let monthly = "com.fitai.app.pro.monthly"
        static let yearly = "com.fitai.app.pro.yearly"
        static let all = [monthly, yearly]
    }

    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var isLoading = false
    var message: String?
    /// Bumped after a signed transaction has been accepted by the server, so
    /// the access snapshot can refresh without coupling SubscriptionManager to
    /// AppStore.
    var serverSyncGeneration = 0

    var isPro: Bool {
        !purchasedProductIDs.isEmpty
    }

    @MainActor
    func load() async {
        isLoading = true
        do {
            products = try await Product.products(for: ProductID.all)
            await refreshEntitlements()
            if products.isEmpty {
                message = "App Store 暂未配置订阅商品。请先在 App Store Connect 创建商品，或使用 StoreKit 本地配置文件测试。"
            }
        } catch {
            message = "加载订阅失败：\(error.localizedDescription)"
        }
        isLoading = false
    }

    @MainActor
    func purchase(_ product: Product) async {
        do {
            let options = AuthTokenStore.shared.userID
                .flatMap(UUID.init(uuidString:))
                .map { [Product.PurchaseOption.appAccountToken($0)] } ?? []
            let result = try await product.purchase(options: options)
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                    message = "订阅成功，感谢支持。"
                case .unverified(_, let error):
                    message = "购买校验失败：\(error.localizedDescription)"
                }
            case .userCancelled:
                break
            case .pending:
                message = "购买正在等待处理，完成后会自动解锁。"
            @unknown default:
                break
            }
        } catch {
            message = "购买失败：\(error.localizedDescription)"
        }
    }

    @MainActor
    func restore() async {
        do {
            try await StoreKit.AppStore.sync()
            await refreshEntitlements()
            message = isPro ? "已恢复订阅。" : "没有找到可恢复的订阅。"
        } catch {
            message = "恢复失败：\(error.localizedDescription)"
        }
    }

    @MainActor
    func refreshEntitlements() async {
        var active: Set<String> = []
        var signedTransactions: [String] = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                active.insert(transaction.productID)
                signedTransactions.append(result.jwsRepresentation)
            }
        }
        purchasedProductIDs = active
        await syncTransactions(signedTransactions)
    }

    @MainActor
    private func syncTransactions(_ signedTransactions: [String]) async {
        guard AuthTokenStore.shared.accessToken != nil, !signedTransactions.isEmpty else {
            return
        }
        var synced = false
        for jws in signedTransactions {
            let snapshot = try? await APIClient.shared.syncStoreKitTransaction(
                signedTransaction: jws
            )
            synced = synced || snapshot != nil
        }
        guard synced else {
            message = "订阅已购买，权益同步暂时失败，稍后会自动重试。"
            return
        }
        serverSyncGeneration += 1
    }
}
