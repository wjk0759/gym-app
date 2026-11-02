import Foundation
import Observation

/// Owns the one paywall presentation slot. Pages must not keep their own
/// `showPaywall` flags; they ask this coordinator so duplicate sheets cannot
/// stack and every feature uses the same sheet.
/// Mutated from the main thread only (AppStore/views are main-thread driven).
@Observable
final class ProPaywallCoordinator {
    var feature: ProFeature?

    func present(_ feature: ProFeature) {
        self.feature = feature
    }

    func dismiss() {
        feature = nil
    }
}
