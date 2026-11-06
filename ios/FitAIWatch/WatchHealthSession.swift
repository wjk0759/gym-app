import Foundation
import HealthKit

/// Keeps the watch app and screen active during a workout. We intentionally do
/// not create a second HealthKit workout here; the iPhone remains the single
/// writer for the saved strength workout.
@MainActor
final class WatchHealthSession: NSObject, HKWorkoutSessionDelegate {
    static let shared = WatchHealthSession()

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private(set) var isRunning = false
    private var hasRequestedAuthorization = false

    func startIfNeeded() async {
        guard HKHealthStore.isHealthDataAvailable(), !isRunning else { return }
        guard await requestAuthorizationIfNeeded() else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        do {
            let session = try HKWorkoutSession(
                healthStore: healthStore,
                configuration: configuration
            )
            session.delegate = self
            self.session = session
            session.startActivity(with: Date())
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    func stop() {
        session?.end()
        session = nil
        isRunning = false
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        if hasRequestedAuthorization {
            return true
        }
        hasRequestedAuthorization = true
        return await withCheckedContinuation { continuation in
            healthStore.requestAuthorization(
                toShare: [HKObjectType.workoutType()],
                read: []
            ) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        let running = toState == .running
        Task { @MainActor [weak self] in
            self?.isRunning = running
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.isRunning = false
            self?.session = nil
        }
    }
}
