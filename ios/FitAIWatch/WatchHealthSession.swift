import Foundation
import HealthKit

/// Keeps the watch app and screen active during a workout. The phone remains
/// the single writer for the saved strength workout, so this session never
/// creates or finishes an HKWorkout. It also forwards the user's pause/resume
/// intent so the workout ring reflects the session state.
@MainActor
final class WatchHealthSession: NSObject, HKWorkoutSessionDelegate {
    static let shared = WatchHealthSession()

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private(set) var isRunning = false
    private(set) var isPaused = false
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
            isPaused = false
        } catch {
            isRunning = false
        }
    }

    func pause() {
        guard isRunning, !isPaused else { return }
        session?.pause()
        isPaused = true
    }

    func resume() {
        guard isRunning, isPaused else { return }
        session?.resume()
        isPaused = false
    }

    func stop() {
        session?.end()
        session = nil
        isRunning = false
        isPaused = false
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
        let paused = toState == .paused
        Task { @MainActor [weak self] in
            self?.isRunning = running
            self?.isPaused = paused
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.isRunning = false
            self?.isPaused = false
            self?.session = nil
        }
    }
}
