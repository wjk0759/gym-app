import Foundation
import HealthKit

final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    private init() {}

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }
        if let height = HKObjectType.quantityType(forIdentifier: .height) {
            types.insert(height)
        }
        if let bodyFat = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) {
            types.insert(bodyFat)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }

    private var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType()]
    }

    func requestAuthorization() async throws -> Bool {
        guard isAvailable else { return false }
        return try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    func latestBodyMassKG() async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            return nil
        }
        let sort = [
            NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        ]

        return try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Double?, Error>) in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: sort
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let kilograms = (samples?.first as? HKQuantitySample)?
                    .quantity
                    .doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kilograms)
            }
            store.execute(query)
        }
    }

    func saveStrengthWorkout(start: Date, end: Date) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        let builder = HKWorkoutBuilder(
            healthStore: store,
            configuration: configuration,
            device: .local()
        )
        try await builder.beginCollection(at: start)
        try await builder.endCollection(at: end)
        guard let workout = try await builder.finishWorkout() else { return }
        try await store.save(workout)
    }
}
