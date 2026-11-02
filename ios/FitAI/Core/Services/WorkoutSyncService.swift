import Foundation

/// API and mapping boundary for workout history sync. AppStore keeps the
/// merge policy and local pending flags; this service only talks to the API and
/// converts remote rows into local sessions.
struct WorkoutSyncService {
    var client: APIClient = .shared

    func deleteRemote(id: String) async throws {
        try await client.deleteWorkout(id: id)
    }

    func createRemote(_ session: WorkoutSession) async throws -> String {
        try await client.createWorkout(session)
    }

    func updateRemote(id: String, session: WorkoutSession) async throws {
        try await client.updateWorkout(id: id, session: session)
    }

    func fetchRecent() async throws -> [RemoteWorkout] {
        try await client.fetchRecentWorkouts()
    }

    func makeSession(
        from item: RemoteWorkout,
        dayTitle: String,
        localID: UUID = UUID()
    ) -> WorkoutSession {
        let finishedAt = item.finishedAt ?? item.startedAt
        let duration = item.durationMin ?? max(
            0,
            Int(finishedAt.timeIntervalSince(item.startedAt) / 60)
        )
        return WorkoutSession(
            id: localID,
            date: finishedAt,
            dayTitle: dayTitle,
            durationMinutes: duration,
            feeling: min(5, max(1, item.feeling ?? 3)),
            notes: item.notes,
            sets: item.sets.map { set in
                SetLog(
                    slug: set.slug,
                    setIndex: set.setIndex,
                    weightKG: set.weightKG ?? 0,
                    reps: set.reps ?? 0,
                    rpe: set.rpe ?? 7,
                    completed: set.completed
                )
            },
            programDayID: item.programDayID,
            remoteID: item.id,
            syncedAt: Date()
        )
    }
}
