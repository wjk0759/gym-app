import Foundation

/// Identity fields that are safe to hydrate from `/me` even when the local
/// profile has unsynced edits. A local non-empty value always wins; only
/// missing identity data is filled from the server.
enum RemoteProfileIdentityPolicy {
    static func nickname(local: String, server: String?) -> String {
        let localValue = local.trimmingCharacters(in: .whitespacesAndNewlines)
        guard localValue.isEmpty else { return local }
        let serverValue = (server ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return serverValue.isEmpty ? local : serverValue
    }

    static func isOnboarded(local: Bool, server: Bool?) -> Bool {
        local || server == true
    }
}
