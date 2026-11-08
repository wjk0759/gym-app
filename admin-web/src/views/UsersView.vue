<template>
  <div class="page-shell">
    <PageHeader title="用户管理" subtitle="查看用户画像、训练轨迹，并处理停用、恢复与数据导出。">
      <template #actions>
        <el-button :icon="Refresh" :loading="loading" @click="load">刷新</el-button>
      </template>
    </PageHeader>

    <section class="panel table-panel">
      <div class="filter-bar">
        <el-input
          v-model="filters.q"
          class="filter-grow"
          clearable
          placeholder="搜索昵称、手机号、账号或用户 ID"
          :prefix-icon="Search"
          @keyup.enter="applyFilters"
          @clear="applyFilters"
        />
        <el-select v-model="filters.status" clearable placeholder="用户状态" @change="applyFilters">
          <el-option label="启用" value="active" />
          <el-option label="已停用" value="suspended" />
          <el-option label="已删除" value="deleted" />
        </el-select>
        <el-select v-model="filters.test" clearable placeholder="账号类型" @change="applyFilters">
          <el-option label="测试账号" :value="true" />
          <el-option label="普通账号" :value="false" />
        </el-select>
        <el-checkbox v-model="filters.includeDeleted" @change="applyFilters">包含已删除</el-checkbox>
        <el-button type="primary" @click="applyFilters">查询</el-button>
        <el-button text @click="resetFilters">重置</el-button>
      </div>

      <el-table v-loading="loading" :data="rows" row-key="id" @row-dblclick="openDetail" @row-click="onRowClick">
        <el-table-column label="用户" min-width="190">
          <template #default="{ row }">
            <div class="user-cell">
              <div class="user-avatar">{{ (row.nickname || row.phone || row.username || 'U').slice(0, 1) }}</div>
              <div class="user-copy">
                <strong>{{ row.nickname || row.phone || row.username || '未命名用户' }}</strong>
                <span>{{ row.phone || row.username || shortId(row.id) }}</span>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="96">
          <template #default="{ row }">
            <div class="stack-tags">
              <StatusTag :status="row.status" />
              <el-tag v-if="row.deleted" type="danger" effect="plain" size="small">已删除</el-tag>
              <el-tag v-if="row.test" type="warning" effect="plain" size="small">测试</el-tag>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="目标" width="92" class-name="hide-mobile">
          <template #default="{ row }">{{ goalLabel(row.goalType) }}</template>
        </el-table-column>
        <el-table-column label="周训练" width="82" align="center" class-name="hide-mobile">
          <template #default="{ row }">{{ row.weeklyDays ? `${row.weeklyDays} 天` : '—' }}</template>
        </el-table-column>
        <el-table-column label="训练次数" width="94" align="right" class-name="hide-mobile">
          <template #default="{ row }">{{ formatNumber(row.workoutCount) }}</template>
        </el-table-column>
        <el-table-column label="创建时间" width="150" class-name="hide-mobile">
          <template #default="{ row }">{{ formatDateTime(row.createdAt) }}</template>
        </el-table-column>
        <el-table-column label="最近登录" width="150" class-name="hide-mobile">
          <template #default="{ row }">{{ formatDateTime(row.lastLoginAt) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="96">
          <template #default="{ row }">
            <el-dropdown trigger="click" @command="(command: string) => handleAction(command, row)">
              <el-button link type="primary">
                操作<el-icon class="el-icon--right"><ArrowDown /></el-icon>
              </el-button>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item command="detail">查看详情</el-dropdown-item>
                  <el-dropdown-item v-if="canWrite && !row.deleted" command="status">
                    {{ row.status === 'active' ? '停用账号' : '启用账号' }}
                  </el-dropdown-item>
                  <el-dropdown-item v-if="canWrite && !row.deleted" command="test">
                    {{ row.test ? '取消测试标记' : '标记为测试账号' }}
                  </el-dropdown-item>
                  <el-dropdown-item v-if="canWrite && !row.deleted" command="delete">删除账号</el-dropdown-item>
                  <el-dropdown-item v-if="canWrite && row.deleted" command="restore">恢复账号</el-dropdown-item>
                  <el-dropdown-item v-if="canWrite && row.deleted" command="purge">彻底删除</el-dropdown-item>
                  <el-dropdown-item command="export" divided>导出 JSON</el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </template>
        </el-table-column>
        <template #empty>
          <el-empty description="没有匹配的用户" :image-size="90" />
        </template>
      </el-table>

      <PaginationBar
        :page="page"
        :size="size"
        :total="total"
        @update:page="onPageChange"
        @update:size="onSizeChange"
      />
    </section>

    <el-drawer
      v-model="drawerVisible"
      title="用户详情"
      size="min(760px, 94vw)"
      destroy-on-close
      @closed="detail = null"
    >
      <div v-loading="detailLoading" class="drawer-body">
        <template v-if="detail">
          <div class="profile-hero">
            <div class="profile-avatar">{{ (detail.user.nickname || detail.user.phone || 'U').slice(0, 1) }}</div>
            <div class="profile-copy">
              <h3>{{ detail.user.nickname || detail.user.phone || detail.user.username || '未命名用户' }}</h3>
              <p>{{ detail.user.phone || detail.user.username || detail.user.id }}</p>
              <div class="row">
                <StatusTag :status="detail.user.status" />
                <el-tag v-if="detail.user.deleted" type="danger" effect="plain" size="small">已删除</el-tag>
                <el-tag v-if="detail.user.test" type="warning" effect="plain" size="small">测试账号</el-tag>
                <span class="faint">加入于 {{ formatDateTime(detail.user.createdAt) }}</span>
              </div>
            </div>
            <el-button v-if="canWrite" size="small" @click="exportUser(detail.user)">导出 JSON</el-button>
          </div>

          <div class="metric-strip">
            <div><span>训练</span><strong>{{ formatNumber(detail.metrics.workouts) }}</strong></div>
            <div><span>容量</span><strong>{{ formatNumber(detail.metrics.volumeKg) }} kg</strong></div>
            <div><span>计划</span><strong>{{ formatNumber(detail.metrics.programs) }}</strong></div>
            <div><span>对话</span><strong>{{ formatNumber(detail.metrics.chats) }}</strong></div>
            <div><span>识别</span><strong>{{ formatNumber(detail.metrics.scans) }}</strong></div>
            <div><span>饮食</span><strong>{{ formatNumber(detail.metrics.meals) }}</strong></div>
          </div>

          <el-tabs v-model="detailTab">
            <el-tab-pane label="画像" name="profile">
              <div class="drawer-section">
                <h4 class="section-title">基础资料</h4>
                <div class="detail-grid">
                  <div class="detail-item"><span>性别</span><span>{{ sexLabel(detail.profile.sex) }}</span></div>
                  <div class="detail-item"><span>出生日期</span><span>{{ display(detail.profile.birthDate) }}</span></div>
                  <div class="detail-item"><span>身高</span><span>{{ displayWithUnit(detail.profile.heightCm, 'cm') }}</span></div>
                  <div class="detail-item"><span>体重</span><span>{{ displayWithUnit(detail.profile.weightKg, 'kg') }}</span></div>
                  <div class="detail-item"><span>体脂率</span><span>{{ displayWithUnit(detail.profile.bodyFatPct, '%') }}</span></div>
                  <div class="detail-item"><span>腰围</span><span>{{ displayWithUnit(detail.profile.waistCm, 'cm') }}</span></div>
                  <div class="detail-item"><span>经验</span><span>{{ display(detail.profile.experience) }}</span></div>
                  <div class="detail-item"><span>训练频率</span><span>{{ displayWithUnit(detail.profile.weeklyDays, '天/周') }}</span></div>
                  <div class="detail-item"><span>单次时长</span><span>{{ displayWithUnit(detail.profile.sessionMinutes, '分钟') }}</span></div>
                  <div class="detail-item"><span>完成引导</span><span>{{ display(detail.profile.onboardedAt) }}</span></div>
                </div>
              </div>
              <div class="drawer-section">
                <h4 class="section-title">目标</h4>
                <div v-if="Object.keys(detail.goal).length" class="detail-grid">
                  <div class="detail-item"><span>目标类型</span><span>{{ goalLabel(asString(detail.goal.type)) }}</span></div>
                  <div class="detail-item"><span>目标体重</span><span>{{ displayWithUnit(detail.goal.targetWeightKg, 'kg') }}</span></div>
                  <div class="detail-item"><span>目标体脂</span><span>{{ displayWithUnit(detail.goal.targetBodyFatPct, '%') }}</span></div>
                  <div class="detail-item"><span>目标腰围</span><span>{{ displayWithUnit(detail.goal.targetWaistCm, 'cm') }}</span></div>
                  <div class="detail-item"><span>目标日期</span><span>{{ display(detail.goal.targetDate) }}</span></div>
                </div>
                <el-empty v-else description="尚未设置目标" :image-size="70" />
              </div>
              <div class="drawer-section">
                <h4 class="section-title">可用器械</h4>
                <div class="chip-row">
                  <el-tag v-for="item in asArray(detail.profile.equipment)" :key="item" effect="plain">{{ item }}</el-tag>
                  <span v-if="!asArray(detail.profile.equipment).length" class="muted">未配置</span>
                </div>
              </div>
            </el-tab-pane>

            <el-tab-pane :label="`身体数据 · ${insights?.bodyMetrics.length ?? 0}`" name="body">
              <div v-loading="insightsLoading" class="drawer-section">
                <h4 class="section-title">体重趋势</h4>
                <TrendChart
                  v-if="bodyChart.labels.length"
                  :labels="bodyChart.labels"
                  :series="bodyChart.series"
                  height="220px"
                />
                <span v-else class="muted">暂无体重记录</span>
              </div>
              <div class="drawer-section">
                <h4 class="section-title">身体记录</h4>
                <el-table :data="insights?.bodyMetrics || []" size="small">
                  <el-table-column label="测量时间" width="150">
                    <template #default="{ row }">{{ formatDateTime(row.measuredAt) }}</template>
                  </el-table-column>
                  <el-table-column label="体重" width="80" align="right">
                    <template #default="{ row }">{{ row.weightKg ?? '—' }}</template>
                  </el-table-column>
                  <el-table-column label="体脂 %" width="80" align="right">
                    <template #default="{ row }">{{ row.bodyFatPct ?? '—' }}</template>
                  </el-table-column>
                  <el-table-column label="腰围" width="80" align="right">
                    <template #default="{ row }">{{ row.waistCm ?? '—' }}</template>
                  </el-table-column>
                  <el-table-column label="臂围" width="80" align="right">
                    <template #default="{ row }">{{ row.armCm ?? '—' }}</template>
                  </el-table-column>
                  <el-table-column label="腿围" width="80" align="right">
                    <template #default="{ row }">{{ row.thighCm ?? '—' }}</template>
                  </el-table-column>
                  <template #empty><el-empty description="暂无身体数据" :image-size="70" /></template>
                </el-table>
              </div>
            </el-tab-pane>

            <el-tab-pane :label="`训练计划 · ${detail.programs.length}`" name="plans">
              <el-table :data="detail.programs" size="small">
                <el-table-column prop="title" label="计划" min-width="180" />
                <el-table-column label="状态" width="90">
                  <template #default="{ row }"><StatusTag :status="row.status" /></template>
                </el-table-column>
                <el-table-column prop="version" label="版本" width="70" align="center" />
                <el-table-column label="周期" width="90">
                  <template #default="{ row }">{{ row.weeks }} 周</template>
                </el-table-column>
                <el-table-column label="创建时间" width="150">
                  <template #default="{ row }">{{ formatDateTime(row.createdAt) }}</template>
                </el-table-column>
                <template #empty><el-empty description="暂无训练计划" :image-size="70" /></template>
              </el-table>
            </el-tab-pane>

            <el-tab-pane :label="`训练记录 · ${detail.workouts.length}`" name="workouts">
              <el-table :data="detail.workouts" size="small">
                <el-table-column label="开始时间" min-width="150">
                  <template #default="{ row }">{{ formatDateTime(row.startedAt) }}</template>
                </el-table-column>
                <el-table-column label="时长" width="100">
                  <template #default="{ row }">{{ formatDuration(row.durationMin) }}</template>
                </el-table-column>
                <el-table-column label="感受" width="90" align="center">
                  <template #default="{ row }">{{ row.feeling ?? '—' }}</template>
                </el-table-column>
                <template #empty><el-empty description="暂无训练记录" :image-size="70" /></template>
              </el-table>
            </el-tab-pane>

            <el-tab-pane :label="`教练对话 · ${detail.chats.length}`" name="chats">
              <el-table :data="detail.chats" size="small">
                <el-table-column prop="title" label="对话" min-width="200" />
                <el-table-column prop="messageCount" label="消息" width="80" align="right" />
                <el-table-column label="创建时间" width="150">
                  <template #default="{ row }">{{ formatDateTime(row.createdAt) }}</template>
                </el-table-column>
                <template #empty><el-empty description="暂无教练对话" :image-size="70" /></template>
              </el-table>
            </el-tab-pane>

            <el-tab-pane :label="`器械识别 · ${detail.scans.length}`" name="scans">
              <el-table :data="detail.scans" size="small">
                <el-table-column prop="model" label="模型" min-width="160" />
                <el-table-column label="状态" width="100">
                  <template #default="{ row }"><StatusTag :status="row.status" /></template>
                </el-table-column>
                <el-table-column label="结果" min-width="220">
                  <template #default="{ row }">
                    <span class="faint">{{ summarizeScan(row.result) }}</span>
                  </template>
                </el-table-column>
                <el-table-column label="时间" width="150">
                  <template #default="{ row }">{{ formatDateTime(row.createdAt) }}</template>
                </el-table-column>
                <template #empty><el-empty description="暂无器械识别" :image-size="70" /></template>
              </el-table>
            </el-tab-pane>

            <el-tab-pane :label="`饮食 · ${insights?.mealPlans.length ?? 0}`" name="meals">
              <div v-loading="insightsLoading" class="drawer-section">
                <h4 class="section-title">餐单</h4>
                <el-table :data="insights?.mealPlans || []" size="small">
                  <el-table-column label="日期" width="110">
                    <template #default="{ row }">{{ formatDate(row.planDate) }}</template>
                  </el-table-column>
                  <el-table-column label="周起始" width="110">
                    <template #default="{ row }">{{ formatDate(row.weekStart) }}</template>
                  </el-table-column>
                  <el-table-column label="策略" width="100">
                    <template #default="{ row }">{{ row.strategy }}</template>
                  </el-table-column>
                  <el-table-column label="目标热量" width="100" align="right">
                    <template #default="{ row }">{{ row.targetKcal ? `${row.targetKcal} kcal` : '—' }}</template>
                  </el-table-column>
                  <el-table-column label="蛋白 / 碳水 / 脂肪" min-width="150">
                    <template #default="{ row }">
                      {{ row.targetProteinG ?? '—' }} / {{ row.targetCarbG ?? '—' }} / {{ row.targetFatG ?? '—' }} g
                    </template>
                  </el-table-column>
                  <el-table-column label="生成" width="100">
                    <template #default="{ row }">{{ row.generatedBy }}</template>
                  </el-table-column>
                  <el-table-column label="创建时间" width="150">
                    <template #default="{ row }">{{ formatDateTime(row.createdAt) }}</template>
                  </el-table-column>
                  <template #empty><el-empty description="暂无饮食计划" :image-size="70" /></template>
                </el-table>
              </div>

              <div class="drawer-section">
                <h4 class="section-title">饮食记录 · {{ insights?.foodLogs.length ?? 0 }}</h4>
                <el-table :data="insights?.foodLogs || []" size="small">
                  <el-table-column label="时间" width="150">
                    <template #default="{ row }">{{ formatDateTime(row.loggedAt) }}</template>
                  </el-table-column>
                  <el-table-column prop="meal" label="餐次" width="76" />
                  <el-table-column prop="foodName" label="食物" min-width="140" />
                  <el-table-column label="克数" width="76" align="right">
                    <template #default="{ row }">{{ row.grams ?? '—' }}</template>
                  </el-table-column>
                  <el-table-column label="热量" width="78" align="right">
                    <template #default="{ row }">{{ row.kcal ?? '—' }}</template>
                  </el-table-column>
                  <el-table-column label="蛋白" width="70" align="right">
                    <template #default="{ row }">{{ row.protein ?? '—' }}</template>
                  </el-table-column>
                  <el-table-column label="碳水" width="70" align="right">
                    <template #default="{ row }">{{ row.carbs ?? '—' }}</template>
                  </el-table-column>
                  <el-table-column label="脂肪" width="70" align="right">
                    <template #default="{ row }">{{ row.fat ?? '—' }}</template>
                  </el-table-column>
                  <template #empty><el-empty description="暂无饮食记录" :image-size="70" /></template>
                </el-table>
              </div>
            </el-tab-pane>

            <el-tab-pane :label="`AI 任务 · ${detail.aiJobs.length}`" name="aiJobs">
              <el-table :data="detail.aiJobs" size="small">
                <el-table-column prop="kind" label="任务" min-width="130" />
                <el-table-column prop="model" label="模型" min-width="150" show-overflow-tooltip />
                <el-table-column label="状态" width="100">
                  <template #default="{ row }"><StatusTag :status="row.status" /></template>
                </el-table-column>
                <el-table-column label="耗时" width="100" align="right">
                  <template #default="{ row }">{{ row.latencyMs ? `${row.latencyMs} ms` : '—' }}</template>
                </el-table-column>
                <el-table-column label="时间" width="150">
                  <template #default="{ row }">{{ formatDateTime(row.createdAt) }}</template>
                </el-table-column>
                <template #empty><el-empty description="暂无 AI 任务" :image-size="70" /></template>
              </el-table>
            </el-tab-pane>

            <el-tab-pane label="会员" name="access">
              <div v-loading="accessLoading" class="drawer-section">
                <h4 class="section-title">Pro 权益</h4>
                <div class="detail-grid">
                  <div class="detail-item">
                    <span>状态</span>
                    <span>
                      <el-tag :type="access?.pro ? 'success' : 'info'" effect="plain">
                        {{ access?.pro ? 'Pro 有效' : '未开通' }}
                      </el-tag>
                    </span>
                  </div>
                  <div class="detail-item"><span>到期时间</span><span>{{ display(access?.proExpiresAt) }}</span></div>
                  <div class="detail-item"><span>来源</span><span>{{ access?.sources?.join('、') || '—' }}</span></div>
                  <div class="detail-item"><span>今日 AI 教练</span><span>{{ access ? `${access.coach.used}/${access.coach.dailyLimit}` : '—' }}</span></div>
                </div>
                <div class="chip-row">
                  <el-button v-if="canManageAccess" type="primary" size="small" @click="openGrant">设置 Pro 时长</el-button>
                  <el-button v-if="canManageAccess" size="small" @click="resetTrial('training_plan')">重置训练计划体验</el-button>
                  <el-button v-if="canManageAccess" size="small" @click="resetTrial('meal_plan')">重置饮食体验</el-button>
                </div>
              </div>

              <div class="drawer-section">
                <h4 class="section-title">免费体验</h4>
                <div class="detail-grid">
                  <div class="detail-item">
                    <span>训练计划</span>
                    <span>{{ trialLabel('training_plan') }}</span>
                  </div>
                  <div class="detail-item">
                    <span>饮食周计划</span>
                    <span>{{ trialLabel('meal_plan') }}</span>
                  </div>
                </div>
              </div>

              <div class="drawer-section">
                <h4 class="section-title">权益记录</h4>
                <el-table :data="access?.entitlements || []" size="small">
                  <el-table-column prop="source" label="来源" width="90" />
                  <el-table-column label="开始" width="150">
                    <template #default="{ row }">{{ formatDateTime(row.startsAt) }}</template>
                  </el-table-column>
                  <el-table-column label="到期" width="150">
                    <template #default="{ row }">{{ formatDateTime(row.expiresAt) }}</template>
                  </el-table-column>
                  <el-table-column label="状态" width="90">
                    <template #default="{ row }">
                      <StatusTag :status="row.revokedAt ? 'suspended' : 'active'" />
                    </template>
                  </el-table-column>
                  <el-table-column prop="reason" label="原因" min-width="120" />
                  <el-table-column label="操作" width="80">
                    <template #default="{ row }">
                      <el-button
                        v-if="canManageAccess && !row.revokedAt"
                        link
                        type="danger"
                        @click="revokeAccess(row.id)"
                      >撤销</el-button>
                    </template>
                  </el-table-column>
                </el-table>
              </div>
            </el-tab-pane>

            <el-tab-pane :label="`排期 · ${insights?.schedule.length ?? 0}`" name="schedule">
              <div v-loading="insightsLoading" class="drawer-section">
                <h4 class="section-title">训练排期</h4>
                <el-table :data="insights?.schedule || []" size="small">
                  <el-table-column label="计划" min-width="130">
                    <template #default="{ row }">
                      <span class="mono">{{ shortId(row.planId) }}</span>
                      <span class="faint"> v{{ row.planVersion ?? '—' }}</span>
                    </template>
                  </el-table-column>
                  <el-table-column label="训练日" min-width="120">
                    <template #default="{ row }"><span class="mono">{{ shortId(row.dayId) }}</span></template>
                  </el-table-column>
                  <el-table-column label="安排日期" width="110">
                    <template #default="{ row }">{{ row.assignedDate || '未安排' }}</template>
                  </el-table-column>
                  <el-table-column label="状态" width="96">
                    <template #default="{ row }">
                      <el-tag v-if="row.skippedAt" type="warning" effect="plain" size="small">已跳过</el-tag>
                      <el-tag v-else type="success" effect="plain" size="small">正常</el-tag>
                    </template>
                  </el-table-column>
                  <el-table-column label="客户端更新" width="150">
                    <template #default="{ row }">{{ formatDateTime(row.clientUpdatedAt) }}</template>
                  </el-table-column>
                  <el-table-column label="服务端写入" width="150">
                    <template #default="{ row }">{{ formatDateTime(row.updatedAt) }}</template>
                  </el-table-column>
                  <template #empty><el-empty description="暂无排期状态" :image-size="70" /></template>
                </el-table>
              </div>
            </el-tab-pane>

            <el-tab-pane :label="`Watch · ${insights?.watchSessions.length ?? 0}`" name="watch">
              <div v-loading="insightsLoading" class="drawer-section">
                <h4 class="section-title">Watch 登录会话</h4>
                <el-table :data="insights?.watchSessions || []" size="small">
                  <el-table-column label="设备" min-width="150">
                    <template #default="{ row }">
                      <div class="cell-stack">
                        <strong>{{ row.deviceName || 'Apple Watch' }}</strong>
                        <span class="mono">{{ shortId(row.deviceId) }}</span>
                      </div>
                    </template>
                  </el-table-column>
                  <el-table-column label="创建" width="150">
                    <template #default="{ row }">{{ formatDateTime(row.createdAt) }}</template>
                  </el-table-column>
                  <el-table-column label="最近使用" width="150">
                    <template #default="{ row }">{{ formatDateTime(row.lastUsedAt) }}</template>
                  </el-table-column>
                  <el-table-column label="到期" width="150">
                    <template #default="{ row }">{{ formatDateTime(row.expiresAt) }}</template>
                  </el-table-column>
                  <el-table-column label="状态" width="96">
                    <template #default="{ row }">
                      <el-tag :type="row.revokedAt ? 'danger' : 'success'" effect="plain" size="small">
                        {{ row.revokedAt ? '已撤销' : '有效' }}
                      </el-tag>
                    </template>
                  </el-table-column>
                  <template #empty><el-empty description="没有 Watch 会话" :image-size="70" /></template>
                </el-table>
              </div>

              <div class="drawer-section">
                <h4 class="section-title">Watch 训练 · {{ insights?.watchWorkouts.length ?? 0 }}</h4>
                <el-table :data="insights?.watchWorkouts || []" size="small">
                  <el-table-column label="开始" width="150">
                    <template #default="{ row }">{{ formatDateTime(row.startedAt) }}</template>
                  </el-table-column>
                  <el-table-column label="时长" width="100" align="right">
                    <template #default="{ row }">{{ row.durationMin ? `${row.durationMin} 分钟` : '—' }}</template>
                  </el-table-column>
                  <el-table-column label="感受" width="80" align="center">
                    <template #default="{ row }">{{ row.feeling ?? '—' }}</template>
                  </el-table-column>
                  <el-table-column label="HealthKit ID" min-width="160">
                    <template #default="{ row }"><span class="mono">{{ row.healthkitWorkoutId || '—' }}</span></template>
                  </el-table-column>
                  <template #empty><el-empty description="暂无 Watch 训练" :image-size="70" /></template>
                </el-table>
              </div>
            </el-tab-pane>

            <el-tab-pane :label="`记忆与器械 · ${insights?.memories.length ?? 0}`" name="memory">
              <div v-loading="insightsLoading" class="drawer-section">
                <h4 class="section-title">AI 记忆</h4>
                <el-table :data="insights?.memories || []" size="small">
                  <el-table-column prop="kind" label="类型" width="100" />
                  <el-table-column prop="content" label="内容" min-width="240" show-overflow-tooltip />
                  <el-table-column prop="memoryKey" label="Key" width="120" show-overflow-tooltip />
                  <el-table-column label="状态" width="80">
                    <template #default="{ row }">
                      <el-tag :type="row.active ? 'success' : 'info'" effect="plain" size="small">
                        {{ row.active ? '生效' : '停用' }}
                      </el-tag>
                    </template>
                  </el-table-column>
                  <el-table-column label="创建" width="150">
                    <template #default="{ row }">{{ formatDateTime(row.createdAt) }}</template>
                  </el-table-column>
                  <template #empty><el-empty description="暂无 AI 记忆" :image-size="70" /></template>
                </el-table>
              </div>

              <div class="drawer-section">
                <h4 class="section-title">个人器械库 · {{ insights?.equipment.length ?? 0 }}</h4>
                <el-table :data="insights?.equipment || []" size="small">
                  <el-table-column prop="name" label="名称" min-width="160" />
                  <el-table-column prop="muscle" label="部位" width="100" />
                  <el-table-column prop="equipment" label="器械" width="100" />
                  <el-table-column prop="source" label="来源" width="90" />
                  <el-table-column prop="notes" label="备注" min-width="160" show-overflow-tooltip />
                  <el-table-column label="创建" width="150">
                    <template #default="{ row }">{{ formatDateTime(row.createdAt) }}</template>
                  </el-table-column>
                  <template #empty><el-empty description="暂无个人器械" :image-size="70" /></template>
                </el-table>
              </div>
            </el-tab-pane>
          </el-tabs>
        </template>
      </div>
    </el-drawer>

    <el-dialog v-model="grantDialogVisible" title="设置 Pro 会员" width="420px">
      <el-form label-width="88px">
        <el-form-item label="时长">
          <el-input-number v-model="grantForm.durationDays" :min="1" :max="3650" />
          <span class="faint" style="margin-left: 8px">天</span>
        </el-form-item>
        <el-form-item label="操作原因">
          <el-input v-model="grantForm.reason" type="textarea" :rows="2" maxlength="200" show-word-limit />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="grantDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="granting" @click="submitGrant">确认开通</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Refresh, Search, ArrowDown } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import PaginationBar from '@/components/PaginationBar.vue'
import StatusTag from '@/components/StatusTag.vue'
import TrendChart from '@/components/TrendChart.vue'
import { usersApi } from '@/api/users'
import { errorMessage } from '@/api/client'
import { useAuthStore } from '@/stores/auth'
import type { UserAccess, UserDetail, UserInsights, UserListItem } from '@/api/types'
import {
  formatDate,
  formatDateTime,
  formatDuration,
  formatNumber,
  goalLabel,
  shortId,
} from '@/utils/format'

const auth = useAuthStore()
const canWrite = auth.hasPermission('user:write')
const canManageAccess = auth.hasPermission('user:entitlement:write')
const rows = ref<UserListItem[]>([])
const total = ref(0)
const page = ref(1)
const size = ref(20)
const loading = ref(false)
const drawerVisible = ref(false)
const detailLoading = ref(false)
const detail = ref<UserDetail | null>(null)
const detailTab = ref('profile')
const access = ref<UserAccess | null>(null)
const accessLoading = ref(false)
const insights = ref<UserInsights | null>(null)
const insightsLoading = ref(false)
const grantDialogVisible = ref(false)
const granting = ref(false)
const grantForm = reactive({
  durationDays: 30,
  reason: '',
})

const filters = reactive({
  q: '',
  status: '',
  test: '' as boolean | '',
  includeDeleted: false,
})

async function load(): Promise<void> {
  loading.value = true
  try {
    const result = await usersApi.list({
      q: filters.q.trim() || undefined,
      status: filters.status || undefined,
      test: filters.test === '' ? undefined : filters.test,
      includeDeleted: filters.includeDeleted || undefined,
      page: page.value,
      size: size.value,
    })
    rows.value = result.items
    total.value = result.total
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    loading.value = false
  }
}

function applyFilters(): void {
  page.value = 1
  void load()
}

function resetFilters(): void {
  filters.q = ''
  filters.status = ''
  filters.test = ''
  filters.includeDeleted = false
  applyFilters()
}

function onPageChange(value: number): void {
  page.value = value
  void load()
}

function onSizeChange(value: number): void {
  size.value = value
  page.value = 1
  void load()
}

async function openDetail(row: UserListItem): Promise<void> {
  drawerVisible.value = true
  detailLoading.value = true
  detailTab.value = 'profile'
  access.value = null
  insights.value = null
  try {
    detail.value = await usersApi.detail(row.id)
    await Promise.all([loadAccess(row.id), loadInsights(row.id)])
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
    drawerVisible.value = false
  } finally {
    detailLoading.value = false
  }
}

async function loadAccess(userId: string): Promise<void> {
  accessLoading.value = true
  try {
    access.value = await usersApi.access(userId)
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    accessLoading.value = false
  }
}

async function loadInsights(userId: string): Promise<void> {
  insightsLoading.value = true
  try {
    insights.value = await usersApi.insights(userId)
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    insightsLoading.value = false
  }
}

const bodyChart = computed(() => {
  const items = [...(insights.value?.bodyMetrics ?? [])]
    .reverse()
    .filter((item) => item.weightKg !== null)
  return {
    labels: items.map((item) => formatDate(item.measuredAt)),
    series: items.length
      ? [{ name: '体重 (kg)', data: items.map((item) => item.weightKg as number), color: '#5b8cff' }]
      : [],
  }
})

function trialLabel(featureKey: string): string {
  const trial = access.value?.trials.find((item) => item.featureKey === featureKey)
  if (!trial) return '未使用'
  return `已使用 · ${formatDateTime(trial.usedAt)}`
}

function openGrant(): void {
  grantForm.durationDays = 30
  grantForm.reason = ''
  grantDialogVisible.value = true
}

async function submitGrant(): Promise<void> {
  const userId = detail.value?.user.id
  if (!userId) return
  if (!grantForm.reason.trim()) {
    ElMessage.warning('请填写操作原因')
    return
  }
  granting.value = true
  try {
    access.value = await usersApi.grantAccess(
      userId,
      grantForm.durationDays,
      grantForm.reason.trim(),
    )
    grantDialogVisible.value = false
    ElMessage.success('Pro 会员已开通')
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    granting.value = false
  }
}

async function revokeAccess(entitlementId: string): Promise<void> {
  const userId = detail.value?.user.id
  if (!userId) return
  try {
    const result = await ElMessageBox.prompt('请填写撤销原因', '撤销 Pro 权益', {
      confirmButtonText: '撤销',
      cancelButtonText: '取消',
      inputPattern: /\S+/,
      inputErrorMessage: '原因不能为空',
    })
    access.value = await usersApi.revokeAccess(userId, entitlementId, result.value)
    ElMessage.success('权益已撤销')
  } catch (reason) {
    if (reason !== 'cancel' && reason !== 'close') ElMessage.error(errorMessage(reason))
  }
}

async function resetTrial(featureKey: string): Promise<void> {
  const userId = detail.value?.user.id
  if (!userId) return
  try {
    await ElMessageBox.confirm(
      '重置后该用户会重新获得一次免费体验。仅建议测试账号使用。',
      '重置免费体验',
      { confirmButtonText: '重置', cancelButtonText: '取消', type: 'warning' },
    )
    access.value = await usersApi.resetTrial(userId, featureKey)
    ElMessage.success('免费体验已重置')
  } catch (reason) {
    if (reason !== 'cancel' && reason !== 'close') ElMessage.error(errorMessage(reason))
  }
}

async function toggleStatus(row: UserListItem): Promise<void> {
  const next = row.status === 'active' ? 'suspended' : 'active'
  const verb = next === 'suspended' ? '停用' : '启用'
  try {
    await ElMessageBox.confirm(`确定${verb}用户「${row.nickname || row.phone || row.id}」吗？`, `${verb}用户`, {
      confirmButtonText: verb,
      cancelButtonText: '取消',
      type: 'warning',
    })
    await usersApi.setStatus(row.id, next)
    ElMessage.success(`已${verb}`)
    await load()
  } catch (reason) {
    if (reason !== 'cancel' && reason !== 'close') ElMessage.error(errorMessage(reason))
  }
}

async function toggleTest(row: UserListItem): Promise<void> {
  const next = !row.test
  const verb = next ? '标记为测试账号' : '取消测试标记'
  try {
    await ElMessageBox.confirm(`确定${verb}「${row.nickname || row.phone || row.id}」吗？`, verb, {
      confirmButtonText: '确认',
      cancelButtonText: '取消',
      type: 'warning',
    })
    await usersApi.setTest(row.id, next)
    ElMessage.success(`已${verb}`)
    await load()
    if (detail.value?.user.id === row.id) {
      detail.value.user.test = next
    }
  } catch (reason) {
    if (reason !== 'cancel' && reason !== 'close') ElMessage.error(errorMessage(reason))
  }
}

async function remove(row: UserListItem): Promise<void> {
  try {
    await ElMessageBox.confirm(
      `删除后用户数据默认保留软删除状态，可随时恢复。确定删除「${row.nickname || row.phone || row.id}」吗？`,
      '删除用户',
      { confirmButtonText: '删除', cancelButtonText: '取消', type: 'warning' },
    )
    await usersApi.remove(row.id)
    ElMessage.success('用户已删除')
    if (detail.value?.user.id === row.id) drawerVisible.value = false
    await load()
  } catch (reason) {
    if (reason !== 'cancel' && reason !== 'close') ElMessage.error(errorMessage(reason))
  }
}

async function restore(row: UserListItem): Promise<void> {
  try {
    await ElMessageBox.confirm(`确定恢复用户「${row.nickname || row.phone || row.id}」吗？`, '恢复用户', {
      confirmButtonText: '恢复',
      cancelButtonText: '取消',
      type: 'warning',
    })
    await usersApi.restore(row.id)
    ElMessage.success('用户已恢复')
    await load()
  } catch (reason) {
    if (reason !== 'cancel' && reason !== 'close') ElMessage.error(errorMessage(reason))
  }
}

async function purge(row: UserListItem): Promise<void> {
  try {
    await ElMessageBox.confirm(
      `彻底删除会永久移除「${row.nickname || row.phone || row.id}」及其关联数据，且无法恢复。确定继续吗？`,
      '彻底删除用户',
      { confirmButtonText: '永久删除', cancelButtonText: '取消', type: 'error' },
    )
    await usersApi.purge(row.id)
    ElMessage.success('用户数据已永久删除')
    if (detail.value?.user.id === row.id) drawerVisible.value = false
    await load()
  } catch (reason) {
    if (reason !== 'cancel' && reason !== 'close') ElMessage.error(errorMessage(reason))
  }
}

async function exportUser(row: UserListItem): Promise<void> {
  try {
    await usersApi.export(row.id)
    ElMessage.success('导出已开始')
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  }
}

function handleAction(command: string, row: UserListItem): void {
  if (command === 'detail') {
    void openDetail(row)
  } else if (command === 'status') {
    void toggleStatus(row)
  } else if (command === 'test') {
    void toggleTest(row)
  } else if (command === 'delete') {
    void remove(row)
  } else if (command === 'restore') {
    void restore(row)
  } else if (command === 'purge') {
    void purge(row)
  } else if (command === 'export') {
    void exportUser(row)
  }
}

function display(value: unknown): string {
  if (value === null || value === undefined || value === '') return '—'
  if (Array.isArray(value)) return value.length ? value.join('、') : '—'
  if (typeof value === 'object') return JSON.stringify(value)
  return String(value)
}

function summarizeScan(result: unknown): string {
  if (!Array.isArray(result) || !result.length) return '—'
  const first = result[0]
  if (first && typeof first === 'object') {
    const item = first as Record<string, unknown>
    return display(item.nameZh ?? item.name ?? item.equipment ?? item.label ?? first)
  }
  return display(first)
}

function displayWithUnit(value: unknown, unit: string): string {
  if (value === null || value === undefined || value === '') return '—'
  return `${value} ${unit}`
}

function asString(value: unknown): string | null {
  return typeof value === 'string' ? value : null
}

function asArray(value: unknown): string[] {
  if (!Array.isArray(value)) return []
  return value.map((item) => String(item))
}

function sexLabel(value: unknown): string {
  if (value === 'male') return '男'
  if (value === 'female') return '女'
  return display(value)
}

function onRowClick(row: UserListItem, _column: unknown, event: MouseEvent): void {
  const target = event.target as HTMLElement | null
  if (target?.closest('button, a, .el-dropdown, .el-switch, input, textarea, select')) return
  void openDetail(row)
}

onMounted(load)
</script>

<style scoped>
.user-cell {
  display: flex;
  align-items: center;
  gap: 10px;
}

.user-avatar,
.profile-avatar {
  display: grid;
  flex: 0 0 auto;
  place-items: center;
  border: 1px solid rgba(91, 140, 255, 0.22);
  border-radius: 10px;
  background: linear-gradient(145deg, rgba(91, 140, 255, 0.26), rgba(61, 220, 151, 0.08));
  color: #d7e4ff;
  font-weight: 700;
}

.user-avatar {
  width: 32px;
  height: 32px;
  font-size: 12px;
}

.user-copy {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
}

.user-copy strong {
  overflow: hidden;
  color: #dfe8f6;
  font-size: 13px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.user-copy span {
  overflow: hidden;
  color: #687890;
  font-size: 11px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.stack-tags {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 3px;
}

.drawer-body {
  min-height: 280px;
}

.cell-stack {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
}

.cell-stack strong {
  overflow: hidden;
  color: #dfe8f6;
  font-size: 13px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.cell-stack span {
  overflow: hidden;
  color: #687890;
  font-size: 11px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.profile-hero {
  display: flex;
  align-items: center;
  gap: 14px;
  padding-bottom: 18px;
  border-bottom: 1px solid var(--fitai-border);
}

.profile-avatar {
  width: 54px;
  height: 54px;
  border-radius: 16px;
  font-size: 20px;
}

.profile-copy {
  min-width: 0;
  flex: 1;
}

.profile-copy h3 {
  margin: 0 0 4px;
  color: #edf3fc;
  font-size: 18px;
}

.profile-copy p {
  margin: 0 0 8px;
  color: var(--fitai-text-muted);
  font-size: 12px;
}

.metric-strip {
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 8px;
  padding: 14px 0 2px;
}

.metric-strip div {
  padding: 9px 10px;
  border: 1px solid var(--fitai-border);
  border-radius: 9px;
  background: rgba(148, 163, 184, 0.035);
}

.metric-strip span {
  display: block;
  color: var(--fitai-text-faint);
  font-size: 10px;
}

.metric-strip strong {
  display: block;
  margin-top: 3px;
  color: var(--fitai-text);
  font-size: 13px;
}

.chip-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 10px;
}

:deep(.el-tabs__header) {
  margin-top: 8px;
}

@media (max-width: 720px) {
  :deep(.hide-mobile) {
    display: none;
  }

  .metric-strip {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}
</style>
