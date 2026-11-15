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
}

extension AppStore {
    func dataDidChange(
        _ change: AppDataChange,
        refreshReview: Bool = true
    ) {
        var domains: Set<AppDataDomain> = []
        var invalidateTargets = false
        var reschedule = false
        var shouldRefreshReview = refreshReview

        switch change {
        case .bodyMetric:
            domains = [.body, .profile, .diet, .review]
            invalidateTargets = true
        case .profile:
            domains = [.profile, .body, .diet, .review]
            invalidateTargets = true
        case .foodLog:
            domains = [.diet, .review]
        case .workout:
            domains = [.workouts, .plan, .schedule, .review]
        case .plan:
            domains = [.plan, .schedule, .diet, .workouts, .review]
            invalidateTargets = true
            reschedule = true
        case .equipment:
            domains = [.equipment, .plan]
        case .bodyAnalysis:
            domains = [.body, .profile, .review]
        }

        if invalidateTargets {
            invalidateNutritionTargetCaches()
        }
        bump(domains)
        if reschedule {
            rescheduleNotifications()
        }
        persist()

        if invalidateTargets {
            Task { @MainActor in
                await self.refreshNutritionTargets()
            }
        }
        if shouldRefreshReview {
            refreshWeeklyReview(force: true)
        }
    }
}
