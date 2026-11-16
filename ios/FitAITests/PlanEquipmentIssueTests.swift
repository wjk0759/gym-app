import XCTest
@testable import FitAI

final class PlanEquipmentIssueTests: XCTestCase {
    private let today = Date(timeIntervalSince1970: 1_800_000_000)
    private let machineSlug = "vital-seated-machine-chest-press"

    private func day(
        _ slug: String,
        date: Date?,
        skippedAt: Date? = nil
    ) -> PlanDay {
        PlanDay(
            weekday: 2,
            date: date,
            skippedAt: skippedAt,
            title: "胸",
            focus: [.chest],
            exercises: [
                PlanExercise(
                    slug: slug,
                    sets: 3,
                    reps: "8-12",
                    weightKG: nil,
                    restSec: 90,
                    rpe: 7.5
                )
            ]
        )
    }

    private func plan(
        _ days: [PlanDay],
        id: UUID = UUID(),
        version: Int = 1
    ) -> TrainingPlan {
        TrainingPlan(id: id, title: "测试计划", version: version, days: days)
    }

    private var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
    }

    func testStrictPlanFlagsUnavailableFutureExercises() {
        let plan = plan([day(machineSlug, date: tomorrow)])

        let issue = PlanEquipmentCheck.issue(
            plan: plan,
            strictEquipment: true,
            planPoolSlugs: [],
            today: today
        )

        XCTAssertEqual(issue?.unavailableSlugs, [machineSlug])
        XCTAssertEqual(issue?.count, 1)
        XCTAssertEqual(issue?.planID, plan.id)
    }

    func testAvailablePoolAndNonStrictModeDoNotWarn() {
        let plan = plan([day(machineSlug, date: tomorrow)])

        XCTAssertNil(
            PlanEquipmentCheck.issue(
                plan: plan,
                strictEquipment: true,
                planPoolSlugs: [machineSlug],
                today: today
            )
        )
        XCTAssertNil(
            PlanEquipmentCheck.issue(
                plan: plan,
                strictEquipment: false,
                planPoolSlugs: [],
                today: today
            )
        )
    }

    func testPastAndSkippedDaysAreIgnored() {
        let yesterday = Calendar.current.date(
            byAdding: .day,
            value: -1,
            to: today
        ) ?? today
        let plan = plan([
            day(machineSlug, date: yesterday),
            day(machineSlug, date: tomorrow, skippedAt: today)
        ])

        XCTAssertNil(
            PlanEquipmentCheck.issue(
                plan: plan,
                strictEquipment: true,
                planPoolSlugs: [],
                today: today
            )
        )
    }

    func testDuplicateSlugsAcrossDaysAreCountedOnce() {
        let plan = plan([
            day(machineSlug, date: tomorrow),
            day(machineSlug, date: Calendar.current.date(
                byAdding: .day,
                value: 2,
                to: today
            ))
        ])

        let issue = PlanEquipmentCheck.issue(
            plan: plan,
            strictEquipment: true,
            planPoolSlugs: [],
            today: today
        )

        XCTAssertEqual(issue?.count, 1)
        XCTAssertEqual(issue?.unavailableSlugs, [machineSlug])
    }

    func testUnknownSlugsAreNotFlagged() {
        let plan = plan([day("unknown-slug-for-test", date: tomorrow)])

        XCTAssertNil(
            PlanEquipmentCheck.issue(
                plan: plan,
                strictEquipment: true,
                planPoolSlugs: [],
                today: today
            )
        )
    }

    func testPlanVersionChangesDismissalSignature() {
        let id = UUID()
        let first = plan([day(machineSlug, date: tomorrow)], id: id, version: 1)
        let second = plan([day(machineSlug, date: tomorrow)], id: id, version: 2)

        let firstIssue = PlanEquipmentCheck.issue(
            plan: first,
            strictEquipment: true,
            planPoolSlugs: [],
            today: today
        )
        let secondIssue = PlanEquipmentCheck.issue(
            plan: second,
            strictEquipment: true,
            planPoolSlugs: [],
            today: today
        )

        XCTAssertNotEqual(firstIssue?.signature, secondIssue?.signature)
    }
}
