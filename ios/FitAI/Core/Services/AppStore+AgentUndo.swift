import Foundation

extension AppStore {
    func scheduleUndoState(for day: PlanDay) -> AgentUndoState? {
        guard let plan,
              let current = plan.days.first(where: { $0.id == day.id }) else {
            return nil
        }
        return .schedule(
            planID: plan.id,
            dayID: current.id,
            previousDate: current.date,
            previousWeekday: current.weekday,
            previousWeekIndex: current.weekIndex,
            previousSkippedAt: current.skippedAt
        )
    }

    func undoLastAgentAction() {
        guard let pending = pendingUndo else { return }
        pendingUndo = nil
        guard Date() < pending.expiresAt else {
            toast = "撤销窗口已结束"
            return
        }
        let now = Date()
        Task { @MainActor in
            let succeeded = await self.undoSingleAction(pending.state, at: now)
            if case let .batch(states) = pending.state {
                self.toast = succeeded
                    ? "已撤销本次 \(states.count) 项修改"
                    : "部分修改撤销失败，请检查计划"
            }
            try? await APIClient.shared.reportAgentAction(
                id: pending.id,
                runID: pending.runID,
                type: pending.actionType,
                status: "undone",
                message: "用户撤销"
            )
        }
    }

    @discardableResult
    private func undoSingleAction(
        _ state: AgentUndoState,
        at now: Date
    ) async -> Bool {
        switch state {
        case let .batch(states):
            var allSucceeded = true
            for item in states {
                let itemSucceeded = await undoSingleAction(item, at: now)
                if !itemSucceeded {
                    allSucceeded = false
                }
            }
            return allSucceeded

        case let .schedule(
            planID,
            dayID,
            previousDate,
            previousWeekday,
            previousWeekIndex,
            previousSkippedAt
        ):
            guard var current = plan,
                  current.id == planID,
                  let index = current.days.firstIndex(where: { $0.id == dayID }) else {
                toast = "当前计划已变化，无法撤销"
                return false
            }
            current.days[index].date = previousDate
            current.days[index].weekday = previousWeekday
            current.days[index].weekIndex = previousWeekIndex
            current.days[index].skippedAt = previousSkippedAt
            current.days[index].scheduleUpdatedAt = now
            current.version += 1
            current.updatedAt = now
            plan = current
            persist()
            rescheduleNotifications()
            syncPendingUserData()
            toast = "已撤销排期修改"
            return true

        case let .bodyMetric(metricID, previousMetric, previousProfile):
            removeBodyMetric(id: metricID)
            profile = previousProfile
            if let previousMetric {
                appendBodyMetric(previousMetric)
            }
            persist()
            syncPendingUserData()
            Task {
                try? await APIClient.shared.syncProfile(previousProfile)
                try? await APIClient.shared.syncGoal(previousProfile)
            }
            toast = "已撤销身体数据"
            return true

        case let .serverWorkoutAction(actionID, planID, dayID):
            guard let current = plan, current.id == planID else {
                toast = "当前计划已变化，无法撤销改课"
                return false
            }
            do {
                let updated = try await APIClient.shared.undoWorkoutAction(
                    actionID: actionID
                )
                guard let merged = mergeServerWorkoutPlan(
                    updated,
                    into: current,
                    dayID: dayID
                ) else {
                    toast = "撤销失败：服务端计划不一致"
                    return false
                }
                plan = merged
                persist()
                rescheduleNotifications()
                syncPendingUserData()
                toast = "已撤销改课"
                return true
            } catch {
                toast = "撤销失败：\(error.localizedDescription)"
                return false
            }

        case let .foodLogAction(actionID):
            do {
                _ = try await APIClient.shared.undoAgentAction(id: actionID)
                foodLogs.removeAll { $0.sourceActionID == actionID }
                persist()
                syncPendingUserData()
                refreshWeeklyReview(force: true)
                await refreshDailyNutritionTargets()
                toast = "已撤销饮食记录"
                return true
            } catch {
                toast = "撤销饮食记录失败：\(error.localizedDescription)"
                return false
            }

        case let .plan(previousPlan):
            guard let current = plan, current.id == previousPlan.id else {
                toast = "当前计划已变化，无法撤销改课"
                return false
            }
            plan = previousPlan
            persist()
            rescheduleNotifications()
            syncPendingUserData()
            toast = "已撤销改课"
            return true

        case let .profile(previousProfile):
            updateProfile(previousProfile)
            toast = "已撤销目标修改"
            return true
        }
    }
}
