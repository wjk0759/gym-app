import Foundation

/// One logical data mutation and the cache/UI domains that depend on it.
///
/// Write paths should call `dataDidChange` instead of remembering ad-hoc
/// `bump`, target-cache and weekly-review refreshes. Remote sync paths still
/// use `refreshDomains` because they fetch the affected modules themselves.
enum AppDataChange {
    case bodyMetric
    case profile
    case foodLog
    case workout
    case plan
    case equipment
    case bodyAnalysis

    var dependency: AppDataDependency {
        switch self {
        case .bodyMetric:
            return AppDataDependency(
                domains: [.body, .profile, .diet, .review],
                invalidatesTargets: true
            )
        case .profile:
            return AppDataDependency(
                domains: [.profile, .body, .diet, .review],
                invalidatesTargets: true
            )
        case .foodLog:
            return AppDataDependency(domains: [.diet, .review])
        case .workout:
            return AppDataDependency(
                domains: [.workouts, .plan, .schedule, .review]
            )
        case .plan:
            return AppDataDependency(
                domains: [.plan, .schedule, .diet, .workouts, .review],
                invalidatesTargets: true,
                reschedulesNotifications: true
            )
        case .equipment:
            return AppDataDependency(domains: [.equipment, .plan])
        case .bodyAnalysis:
            return AppDataDependency(domains: [.body, .profile, .review])
        }
    }
}

struct AppDataDependency: Equatable {
    let domains: Set<AppDataDomain>
    let invalidatesTargets: Bool
    let reschedulesNotifications: Bool

    init(
        domains: Set<AppDataDomain>,
        invalidatesTargets: Bool = false,
        reschedulesNotifications: Bool = false
    ) {
        self.domains = domains
        self.invalidatesTargets = invalidatesTargets
        self.reschedulesNotifications = reschedulesNotifications
    }
}

extension AppStore {
    func dataDidChange(
        _ change: AppDataChange,
        refreshReview: Bool = true
    ) {
        let dependency = change.dependency
        if dependency.invalidatesTargets {
            invalidateNutritionTargetCaches()
        }
        bump(dependency.domains)
        if dependency.reschedulesNotifications {
            rescheduleNotifications()
        }
        persist()

        if dependency.invalidatesTargets {
            Task { @MainActor in
                await self.refreshNutritionTargets()
            }
        }
        if refreshReview {
            refreshWeeklyReview(force: true)
        }
    }
}
