import Foundation
import MetricKit

/// First-party crash and hang diagnostics.
///
/// MetricKit delivers a diagnostic payload on a later launch. We forward the
/// raw JSON to the backend audit log so production issues are visible without
/// adding a third-party crash SDK.
final class DiagnosticsReporter: NSObject, MXMetricManagerSubscriber {
    static let shared = DiagnosticsReporter()

    private var started = false

    func start() {
        guard !started else { return }
        started = true
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let data = payload.jsonRepresentation()
            guard !data.isEmpty, data.count <= 280_000 else { continue }
            Task {
                try? await APIClient.shared.uploadClientDiagnostic(
                    kind: "metrickit",
                    data: data
                )
            }
        }
    }
}
