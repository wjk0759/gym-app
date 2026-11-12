import XCTest

@testable import FitAI

final class PlanReviewEngineTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 11,
            day: day,
            hour: hour
        ))!
    }

    private func exercise(sets: Int = 3) -> PlanExercise {
        PlanExercise(
            slug: "bench",
            sets: sets,
            reps: "8",
            weightKG: 40,
            restSec: 90,
            rpe: 7.5
        )
    }

    private func planDay(
        date: Date,
        title: String,
        skippedAt: Date? = nil
    ) -> PlanDay {
        PlanDay(
            weekIndex: 1,
            weekday: calendar.component(.weekday, from: date),
            date: date,
            skippedAt: skippedAt,
            scheduleUpdatedAt: nil,
            title: title,
            focus: [],
            exercises: [exercise()]
        )
    }

    private func session(
        date: Date,
        day: PlanDay,
        completedSets: Int
    ) -> WorkoutSession {
        WorkoutSession(
            date: date,
            dayTitle: day.title,
            durationMinutes: 40,
            feeling: 3,
            sets: (1...completedSets).map {
                SetLog(
                    slug: "bench",
                    setIndex: $0,
                    weightKG: 40,
                    reps: 8,
                    rpe: 8
                )
            },
            programDayID: day.id.uuidString,
            plannedSets: 3
        )
    }

    func testAdherenceExcludesSkippedAndCountsMissedPlanDays() {
        let monday = date(day: 9)
        let tuesday = date(day: 10)
        let wednesday = date(day: 11)
        let completed = planDay(date: monday, title: "推")
        let skipped = planDay(date: tuesday, title: "拉", skippedAt: date(day: 10))
        let missed = planDay(date: wednesday, title: "腿")
        let plan = TrainingPlan(
            title: "测试计划",
            days: [completed, skipped, missed]
        )
        let input = ReviewInput(
            sessions: [session(date: monday, day: completed, completedSets: 3)],
            foodLogs: [],
            bodyMetrics: [],
            profile: UserProfile(),
            plan: plan
        )

        let review = PlanReviewEngine.make(
            input: input,
            period: .week,
            now: date(day: 12)
        )

        XCTAssertEqual(review.current.adherence.plannedDays, 3)
        XCTAssertEqual(review.current.adherence.completedDays, 1)
        XCTAssertEqual(review.current.adherence.skippedDays, 1)
        XCTAssertEqual(review.current.adherence.missedDays, 1)
        XCTAssertEqual(review.current.adherence.eligibleDays, 2)
        XCTAssertEqual(review.current.adherence.rate, 0.5)
        XCTAssertEqual(review.nextAction?.title, "先补一次错过的训练")
    }

    func testPartialSessionIsNotACompletedPlanDay() {
        let monday = date(day: 9)
        let day = planDay(date: monday, title: "推")
        let plan = TrainingPlan(title: "测试计划", days: [day])
        let input = ReviewInput(
            sessions: [session(date: monday, day: day, completedSets: 2)],
            foodLogs: [],
            bodyMetrics: [],
            profile: UserProfile(),
            plan: plan
        )

        let review = PlanReviewEngine.make(
            input: input,
            period: .week,
            now: date(day: 12)
        )

        XCTAssertEqual(review.current.adherence.completedDays, 0)
        XCTAssertEqual(review.current.adherence.missedDays, 1)
        XCTAssertEqual(review.current.averageRPE, 8)
    }
}
