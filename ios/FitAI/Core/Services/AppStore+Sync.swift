import Foundation

extension AppStore {
    /// 将本地训练记录补传到 FastAPI；失败时保持 pending，下次登录或完成训练再试。
    /// 创建、修改、删除共用一个串行通道，避免离线恢复时互相覆盖。
    func syncPendingWorkouts() {
        guard !isSyncingWorkouts,
              AuthTokenStore.shared.accessToken != nil else { return }
        let pendingCreates = sessions.filter { $0.syncedAt == nil }
        let pendingUpdates = sessions.filter {
            $0.remoteID != nil && $0.syncedAt != nil && $0.pendingRemoteUpdate == true
        }
        let pendingDeletes = pendingWorkoutDeletionIDs
        guard !pendingCreates.isEmpty || !pendingUpdates.isEmpty || !pendingDeletes.isEmpty else {
            return
        }
        let accountID = currentUserID
        isSyncingWorkouts = true
        Task { @MainActor in
            defer { self.isSyncingWorkouts = false }
            var createdAny = false
            var changedAny = false

            for remoteID in pendingDeletes {
                do {
                    try await workoutSync.deleteRemote(id: remoteID)
                    guard self.currentUserID == accountID else { return }
                    self.pendingWorkoutDeletionIDs.removeAll { $0 == remoteID }
                    self.persist()
                    changedAny = true
                } catch let error as APIError where error.statusCode == 404 {
                    // 服务端已经不存在该记录，删除墓碑视为完成。
                    guard self.currentUserID == accountID else { return }
                    self.pendingWorkoutDeletionIDs.removeAll { $0 == remoteID }
                    self.persist()
                    changedAny = true
                } catch {
                    // 保留墓碑，下一次前台刷新继续删除，避免离线删除被服务端数据复活。
                }
            }

            for session in pendingCreates {
                do {
                    let remoteID = try await workoutSync.createRemote(session)
                    guard self.currentUserID == accountID else { return }
                    if let index = self.sessions.firstIndex(where: { $0.id == session.id }) {
                        self.sessions[index].remoteID = remoteID
                        self.sessions[index].syncedAt = Date()
                        self.sessions[index].pendingRemoteUpdate = nil
                    }
                    createdAny = true
                    changedAny = true
                } catch {
                    // 网络或服务端暂时不可用时保留待同步状态，不阻塞本地训练闭环。
                }
            }

            for session in pendingUpdates {
                guard let remoteID = session.remoteID else { continue }
                do {
                    try await workoutSync.updateRemote(id: remoteID, session: session)
                    guard self.currentUserID == accountID else { return }
                    if let index = self.sessions.firstIndex(where: { $0.id == session.id }) {
                        var latest = self.sessions[index]
                        var sent = session
                        latest.pendingRemoteUpdate = nil
                        sent.pendingRemoteUpdate = nil
                        if latest == sent {
                            self.sessions[index].pendingRemoteUpdate = nil
                        }
                    }
                    changedAny = true
                } catch {
                    // 保留 pendingRemoteUpdate，下一次前台刷新重试 PATCH。
                }
            }
            self.persist()
            if changedAny {
                self.refreshWeeklyReview(force: true, notifyWhenReady: createdAny)
            }
        }
    }

    func deleteSession(_ id: UUID) {
        guard let remoteID = sessions.first(where: { $0.id == id })?.remoteID else {
            sessions.removeAll { $0.id == id }
            persist()
            return
        }
        sessions.removeAll { $0.id == id }
        if !pendingWorkoutDeletionIDs.contains(remoteID) {
            pendingWorkoutDeletionIDs.append(remoteID)
        }
        persist()
        syncPendingWorkouts()
    }

    /// 拉取服务端近 90 天训练历史，按 remoteID 合并；本地未上传的修改优先。
    func syncRemoteWorkouts() {
        guard !isSyncingRemoteWorkouts,
              AuthTokenStore.shared.accessToken != nil else { return }
        let accountID = currentUserID
        isSyncingRemoteWorkouts = true
        Task { @MainActor in
            defer { self.isSyncingRemoteWorkouts = false }
            do {
                let remote = try await workoutSync.fetchRecent()
                guard self.currentUserID == accountID else { return }
                self.mergeRemoteWorkouts(remote)
            } catch {
                // 离线或服务端暂不可用时保留本地历史，下一次前台刷新再试。
            }
        }
    }

    private func mergeRemoteWorkouts(_ remote: [RemoteWorkout]) {
        let deleting = Set(pendingWorkoutDeletionIDs)
        var changed = false
        for item in remote where !deleting.contains(item.id) {
            let planTitle = item.programDayID.flatMap { dayID in
                plan?.days.first(where: { $0.id.uuidString == dayID })?.title
            }
            if let index = sessions.firstIndex(where: { $0.remoteID == item.id }) {
                guard sessions[index].pendingRemoteUpdate != true else { continue }
                let localID = sessions[index].id
                let localTitle = sessions[index].dayTitle
                let localPlannedSets = sessions[index].plannedSets
                var merged = workoutSync.makeSession(
                    from: item,
                    dayTitle: planTitle ?? localTitle,
                    localID: localID
                )
                merged.plannedSets = localPlannedSets ?? merged.plannedSets
                if merged != sessions[index] {
                    sessions[index] = merged
                    changed = true
                }
            } else if let clientID = item.clientID,
                      let localID = UUID(uuidString: clientID),
                      let index = sessions.firstIndex(where: { $0.id == localID }) {
                // The create response was lost after the server committed.
                // Match the local client UUID instead of appending a duplicate.
                guard sessions[index].pendingRemoteUpdate != true else { continue }
                let localTitle = sessions[index].dayTitle
                let localPlannedSets = sessions[index].plannedSets
                var merged = workoutSync.makeSession(
                    from: item,
                    dayTitle: planTitle ?? localTitle,
                    localID: localID
                )
                merged.plannedSets = localPlannedSets ?? merged.plannedSets
                if merged != sessions[index] {
                    sessions[index] = merged
                    changed = true
                }
            } else {
                sessions.append(
                    workoutSync.makeSession(
                        from: item,
                        dayTitle: planTitle ?? "训练记录",
                        localID: item.clientID.flatMap { UUID(uuidString: $0) } ?? UUID()
                    )
                )
                changed = true
            }
        }
        if changed {
            sessions.sort { $0.date > $1.date }
            persist()
        }
    }

    // MARK: - Cross-device data sync

    func syncPendingUserData() {
        guard AuthTokenStore.shared.accessToken != nil else { return }
        if isSyncingUserData {
            scheduleSyncRequested = true
            return
        }
        let hadFoodWork = !pendingFoodDeletionIDs.isEmpty
            || !pendingFoodUpdateIDs.isEmpty
            || foodLogs.contains { $0.syncedAt == nil }
        isSyncingUserData = true
        Task { @MainActor in
            defer {
                self.isSyncingUserData = false
                self.persist()
                if self.scheduleSyncRequested {
                    self.scheduleSyncRequested = false
                    self.syncPendingUserData()
                }
            }
            await self.pushPendingFoodDeletions()
            await self.pushPendingFoodLogs()
            await self.pushPendingBodyMetrics()
            await self.pushPendingEquipment()
            await self.syncPlanIfNeeded()
            await self.pushPlanSchedule()
            await self.pullCloudUserData()
            if hadFoodWork {
                self.refreshWeeklyReview(force: true)
            }
        }
    }

    /// Upload a locally generated plan before schedule/coach flows depend on it.
    /// This is what makes local-template fallback and offline plan edits visible
    /// to the server, other devices, and the coach action executor.
    private func syncPlanIfNeeded() async {
        guard planNeedsServerSync, let plan else { return }
        // Server validation uses the current profile, especially weekly_days,
        // equipment and injury constraints.
        try? await APIClient.shared.syncProfile(profile)
        do {
            let remote = try await APIClient.shared.importPlan(
                plan,
                expectedPlanVersion: plan.version > 1 ? plan.version - 1 : nil
            )
            mergeServerPlan(remote)
            planNeedsServerSync = false
            persist()
        } catch {
            // Keep the pending flag. The next login/foreground retries.
        }
    }

    private func pushPlanSchedule() async {
        guard let plan else { return }
        let uploads = plan.days.map { day in
            PlanScheduleUploadDay(
                dayID: day.id.uuidString,
                assignedDate: plan.scheduledDate(for: day).map { FitnessDate.key($0) },
                skippedAt: day.skippedAt,
                clientUpdatedAt: day.scheduleUpdatedAt
                    ?? plan.updatedAt
                    ?? plan.createdAt
            )
        }
        guard let remote = try? await APIClient.shared.syncSchedule(
            planID: plan.id.uuidString,
            planVersion: plan.version,
            days: uploads
        ) else { return }
        applyRemoteSchedule(remote)
    }

    private func applyRemoteSchedule(_ remote: RemoteScheduleState) {
        guard var current = plan,
              current.id.uuidString == remote.planID,
              !remote.days.isEmpty else { return }
        var changed = false
        for item in remote.days {
            guard let id = UUID(uuidString: item.dayID),
                  let index = current.days.firstIndex(where: { $0.id == id }) else {
                continue
            }
            if let localAt = current.days[index].scheduleUpdatedAt,
               let remoteAt = item.clientUpdatedAt,
               remoteAt < localAt {
                continue
            }
            let remoteDate = item.assignedDate.flatMap { FitnessDate.date(from: $0) }
            if current.days[index].date != remoteDate {
                current.days[index].date = remoteDate
                changed = true
            }
            if current.days[index].skippedAt != item.skippedAt {
                current.days[index].skippedAt = item.skippedAt
                changed = true
            }
            let remoteUpdated = item.clientUpdatedAt ?? item.serverUpdatedAt ?? Date()
            if current.days[index].scheduleUpdatedAt != remoteUpdated {
                current.days[index].scheduleUpdatedAt = remoteUpdated
                changed = true
            }
        }
        guard changed else { return }
        current.updatedAt = Date()
        plan = current
        persist()
        rescheduleNotifications()
    }

    private func pushPendingFoodDeletions() async {
        for key in pendingFoodDeletionIDs {
            guard let id = UUID(uuidString: key) else {
                pendingFoodDeletionIDs.removeAll { $0 == key }
                continue
            }
            do {
                try await APIClient.shared.deleteFoodLog(id: id)
                pendingFoodDeletionIDs.removeAll { $0 == key }
            } catch let error as APIError where error.statusCode == 404 {
                pendingFoodDeletionIDs.removeAll { $0 == key }
            } catch {
                // Keep pending; a later sync retries the delete.
            }
        }
        persist()
    }

    private func pushPendingFoodLogs() async {
        for log in foodLogs where log.syncedAt == nil {
            do {
                try await nutrition.push(log)
                if let index = foodLogs.firstIndex(where: { $0.id == log.id }) {
                    foodLogs[index].syncedAt = Date()
                }
                pendingFoodUpdateIDs.removeAll { $0 == log.id.uuidString }
            } catch {
                // Keep pending for the next foreground/login retry.
            }
        }
        foodLogs.sort { $0.date > $1.date }
    }

    private func pushPendingBodyMetrics() async {
        for metric in bodyMetrics where metric.syncedAt == nil {
            do {
                try await APIClient.shared.syncBodyMetric(metric)
                if let index = bodyMetrics.firstIndex(where: { $0.id == metric.id }) {
                    bodyMetrics[index].syncedAt = Date()
                }
            } catch {
                // Keep pending.
            }
        }
        bodyMetrics.sort { $0.date > $1.date }
    }

    private func pushPendingEquipment() async {
        for item in equipmentLibrary {
            let needsSync = item.syncedAt == nil
            let needsPhoto = item.photoData != nil && item.photoURL == nil
            guard needsSync || needsPhoto else { continue }
            do {
                if needsSync {
                    try await APIClient.shared.syncEquipmentItem(item)
                    if let index = equipmentLibrary.firstIndex(where: { $0.id == item.id }) {
                        equipmentLibrary[index].syncedAt = Date()
                    }
                }
                if let data = item.photoData, item.photoURL == nil {
                    let response = try await APIClient.shared.uploadEquipmentPhoto(
                        clientID: item.id,
                        imageData: data
                    )
                    if let index = equipmentLibrary.firstIndex(where: { $0.id == item.id }),
                       let url = AppConfig.resolveMediaURL(response.photoURL)?.absoluteString {
                        equipmentLibrary[index].photoURL = url
                        equipmentLibrary[index].photoData = data
                        equipmentLibrary[index].syncedAt = Date()
                    }
                }
            } catch {
                // Keep pending: the next sync retries both the item and photo.
            }
        }
    }

    private func pullCloudUserData() async {
        if !planNeedsServerSync,
           let remote = try? await APIClient.shared.fetchCurrentPlan() {
            if let local = plan,
               local.id == remote.id,
               local.version > remote.version {
                // Local is ahead only while an edit is still in flight.
            } else {
                mergeServerPlan(remote)
                planNeedsServerSync = false
                persist()
            }
        }
        if let remote = try? await nutrition.fetchRemote() {
            let localIDs = Set(foodLogs.map(\.id))
            let pendingDeletes = Set(pendingFoodDeletionIDs)
            let pendingUpdates = Set(pendingFoodUpdateIDs)
            for item in remote {
                if pendingDeletes.contains(item.clientID)
                    || pendingUpdates.contains(item.clientID) {
                    continue
                }
                guard let value = nutrition.makeFoodLog(from: item) else {
                    continue
                }
                if let index = foodLogs.firstIndex(where: { $0.id == value.id }) {
                    foodLogs[index] = value
                } else if !localIDs.contains(value.id) {
                    foodLogs.append(value)
                }
            }
            foodLogs.sort { $0.date > $1.date }
        }
        if let remote = try? await APIClient.shared.fetchBodyMetrics() {
            for item in remote {
                guard let id = UUID(uuidString: item.clientID) else { continue }
                let value = BodyMetric(
                    id: id,
                    date: item.measuredAt,
                    weightKG: item.weightKG,
                    bodyFatPCT: item.bodyFatPCT,
                    waistCM: item.waistCM,
                    armCM: item.armCM,
                    thighCM: item.thighCM,
                    syncedAt: Date()
                )
                if let index = bodyMetrics.firstIndex(where: { $0.id == id }) {
                    bodyMetrics[index] = value
                } else {
                    bodyMetrics.append(value)
                }
            }
            bodyMetrics.sort { $0.date > $1.date }
            if let latest = bodyMetrics.first {
                if let weight = latest.weightKG { profile.weightKG = weight }
                if let bodyFat = latest.bodyFatPCT { profile.bodyFatPCT = bodyFat }
                if let waist = latest.waistCM { profile.waistCM = waist }
                if let arm = latest.armCM, arm > 0 { profile.armCM = arm }
                if let thigh = latest.thighCM, thigh > 0 { profile.thighCM = thigh }
            }
        }
        if let remote = try? await APIClient.shared.fetchEquipmentItems() {
            for item in remote {
                guard let id = UUID(uuidString: item.clientID) else { continue }
                var value = EquipmentItem(
                    id: id,
                    name: item.name,
                    equipmentType: item.equipmentType,
                    category: item.category,
                    photoURL: AppConfig.resolveMediaURL(item.photoURL)?.absoluteString,
                    enabledExerciseSlugs: item.enabledExerciseSlugs ?? [],
                    slug: item.slug,
                    muscle: item.muscle.flatMap { MuscleGroup(rawValue: $0) },
                    equipment: item.equipment.flatMap { Equipment(rawValue: $0) },
                    videoURL: nil,
                    notes: item.notes,
                    photoData: nil,
                    createdAt: item.createdAt,
                    syncedAt: Date(),
                    targetMuscles: item.targetMuscles ?? []
                )
                if let local = equipmentLibrary.first(where: { $0.id == id }),
                   local.photoURL == value.photoURL {
                    // Keep the local image cache when it still matches the remote URL.
                    value.photoData = local.photoData
                }
                if let index = equipmentLibrary.firstIndex(where: { $0.id == id }) {
                    equipmentLibrary[index] = value
                } else {
                    equipmentLibrary.append(value)
                }
            }
        }
        if let remote = try? await APIClient.shared.fetchUniversalEquipment() {
            selectedUniversalSlugs = remote.filter(\.enabled).map(\.slug)
        }
    }
}
