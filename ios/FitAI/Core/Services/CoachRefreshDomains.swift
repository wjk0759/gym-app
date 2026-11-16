import Foundation

/// Maps a confirmed coach capability to the modules that need a real refresh.
/// The server's `refresh_domains` wins; this table is the offline/older-server
/// fallback.
enum CoachRefreshDomains {
    static func domains(
        for capability: String,
        server: [String]? = nil
    ) -> Set<AppDataDomain> {
        let declared = Set((server ?? []).compactMap(AppDataDomain.init(rawValue:)))
        if !declared.isEmpty { return declared }
        return fallback[capability] ?? []
    }

    static let fallback: [String: Set<AppDataDomain>] = [
        "training.generate_plan": [.plan, .schedule, .workouts, .diet],
        "training.adjust_plan": [.plan, .schedule, .workouts, .diet],
        "training.configure_plan": [.plan, .schedule, .workouts, .diet],
        "training.edit_day_exercises": [.plan, .schedule, .workouts],
        "training.edit_day_exercise": [.plan, .schedule, .workouts],
        "training.add_plan_day": [.plan, .schedule, .workouts, .review],
        "training.reschedule": [.plan, .schedule, .diet],
        "training.skip": [.plan, .schedule, .review],
        "training.log_strength": [.workouts, .plan, .schedule, .review],
        "training.log_cardio": [.workouts, .plan, .schedule, .review],
        "training.update_workout": [.workouts, .plan, .schedule, .review],
        "training.delete_workout": [.workouts, .plan, .schedule, .review],
        "diet.log_food": [.diet, .review],
        "diet.update_log": [.diet, .review],
        "diet.delete_log": [.diet, .review],
        "diet.log_planned_meal": [.diet, .review],
        "diet.skip_planned_meal": [.diet, .review],
        "diet.restore_planned_meal": [.diet, .review],
        "diet.swap_meal": [.diet, .review],
        "diet.edit_day_strategy": [.diet],
        "diet.generate_day": [.diet],
        "diet.generate_week": [.diet],
        "body.log_weight": [.body, .profile, .diet, .review],
        "body.delete_metric": [.body, .profile, .diet, .review],
        "profile.update_goal": [.profile, .diet, .review],
        "memory.remember": [.profile]
    ]
}
