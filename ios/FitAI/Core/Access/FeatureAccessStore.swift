import Foundation
import Observation

/// Server-authoritative access state plus the local StoreKit/debug fallback.
///
/// AppStore owns one instance for app-wide refresh, but the access rules live
/// here so AppStore does not become the entitlement store as well as the data
/// store. Async refreshes resume on the main actor; the API remains the final
/// authority for paid endpoints.
@Observable
final class FeatureAccessStore {
    private(set) var snapshot: AccessSnapshot?
    var storeKitPro = false
    var debugForcePro = AppConfig.debugForceRemoteAI

    let paywall = ProPaywallCoordinator()

    var policy: FeaturePolicy {
        FeaturePolicy(
            snapshot: snapshot,
            storeKitPro: storeKitPro,
            debugForcePro: debugForcePro
        )
    }

    var isPro: Bool { policy.isPro }

    func clear() {
        snapshot = nil
    }

    @MainActor
    func refresh() async {
        guard AuthTokenStore.shared.accessToken != nil else {
            snapshot = nil
            return
        }
        if let snapshot = try? await APIClient.shared.fetchAccess() {
            self.snapshot = snapshot
        }
    }

    @MainActor
    func consumeOnboardingTrial() async {
        if let snapshot = try? await APIClient.shared.consumeOnboardingTrial() {
            self.snapshot = snapshot
        }
    }

    func requestPro(_ feature: ProFeature) {
        paywall.present(feature)
    }

    @discardableResult
    func requirePro(_ feature: ProFeature) -> Bool {
        if isPro { return true }
        requestPro(feature)
        return false
    }
}
