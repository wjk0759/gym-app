import SwiftUI

extension HomeV2View {
    // MARK: - Actions

    func presentPendingWorkout() {
        guard let day = pendingWorkoutDay else { return }
        pendingWorkoutDay = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            workoutDay = day
        }
    }

    func presentLaunchIfNeeded() {
        guard let dayID = store.workoutLaunchDayID,
              let day = store.plan?.days.first(where: { $0.id == dayID }) else {
            return
        }
        store.workoutLaunchDayID = nil
        workoutDay = day
    }
}
