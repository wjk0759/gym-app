import Foundation

/// Where a coach text turn should run. Free accounts must use the server Agent
/// so the daily quota is consumed; only a Pro account that explicitly turned
/// remote AI off may stay on the local rule engine.
enum CoachChatTransport: Equatable {
    case agent
    case local
}

enum CoachChatPolicy {
    static func transport(hasPro: Bool, remoteEnabled: Bool) -> CoachChatTransport {
        hasPro && !remoteEnabled ? .local : .agent
    }

    static func shouldShowQuotaCard(
        hasPro: Bool,
        remaining: Int?,
        exhausted: Bool
    ) -> Bool {
        guard !hasPro else { return false }
        return exhausted || remaining == 0
    }
}
