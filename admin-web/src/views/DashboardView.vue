<template>
  <div class="page-shell">
    <PageHeader title="运营总览" subtitle="实时掌握 FitAI 用户增长、训练活跃度与 AI 服务质量。">
      <template #actions>
        <el-button :icon="Refresh" :loading="loading" @click="load">刷新数据</el-button>
      </template>
    </PageHeader>

    <div v-loading="loading" class="stack">
      <section class="metric-grid">
        <MetricCard
          label="有效用户"
          :value="formatNumber(summary?.usersTotal)"
          :foot="`近 7 天新增 ${formatNumber(summary?.usersNew7d)} · 完成引导 ${formatNumber(summary?.onboardedUsers)}`"
          glow="rgba(91, 140, 255, 0.28)"
        />
        <MetricCard
          label="训练记录"
          :value="formatNumber(summary?.sessionsTotal)"
          :foot="`近 7 天 ${formatNumber(summary?.sessions7d)} 次训练`"
          glow="rgba(61, 220, 151, 0.22)"
        />
        <MetricCard
          label="活跃计划"
          :value="formatNumber(summary?.programsActive)"
          :foot="`累计生成 ${formatNumber(summary?.programsTotal)} 份计划`"
          glow="rgba(248, 196, 92, 0.2)"
        />
        <MetricCard
          label="教练对话"
          :value="formatNumber(summary?.chatsTotal)"
          :foot="`${formatNumber(summary?.messagesTotal)} 条消息 · ${formatNumber(summary?.safetyFlags)} 条安全标记`"
          glow="rgba(255, 107, 129, 0.18)"
        />
        <MetricCard
          label="器械识别"
          :value="formatNumber(summary?.scansTotal)"
          foot="视觉识别请求累计"
          glow="rgba(148, 163, 184, 0.18)"
        />
        <MetricCard
          label="动作库"
          :value="formatNumber(summary?.exercisesTotal)"
          :foot="`${formatNumber(summary?.videosPublished)} 个动作已配置发布视频`"
          glow="rgba(91, 140, 255, 0.2)"
        />
        <MetricCard
          label="饮食计划"
          :value="formatNumber(summary?.mealPlansTotal)"
          foot="用户每日营养方案累计"
          glow="rgba(61, 220, 151, 0.18)"
        />
        <MetricCard
          label="内容发布率"
          :value="publishedRate"
          :foot="`${formatNumber(summary?.videosPublished)} / ${formatNumber(summary?.exercisesTotal)} 动作视频已发布`"
          glow="rgba(248, 196, 92, 0.18)"
        />
      </section>

      <section class="dashboard-grid">
        <div class="panel chart-panel">
          <div class="panel-heading">
            <div>
              <h3>近 14 天增长</h3>
              <p>每日新增用户与训练记录</p>
            </div>
            <span class="legend-note"><i class="dot users-dot" />新增用户 <i class="dot workouts-dot" />训练记录</span>
          </div>
          <div v-if="summary" class="chart-wrap">
            <TrendChart :labels="dailyLabels" :series="dailySeries" height="300px" />
          </div>
        </div>

        <div class="panel ai-panel">
          <div class="panel-heading">
            <div>
              <h3>AI 请求分布</h3>
              <p>近 30 天按能力类型统计</p>
            </div>
            <router-link to="/ai" class="panel-link">查看 AI 运营</router-link>
          </div>
          <div v-if="summary?.aiKinds?.length" class="kind-list">
            <div v-for="item in summary.aiKinds" :key="item.kind" class="kind-row">
              <div class="kind-meta">
                <span>{{ aiKindLabel(item.kind) }}</span>
                <strong>{{ formatNumber(item.count) }}</strong>
              </div>
              <div class="kind-track">
                <span :style="{ width: kindWidth(item.count) }" />
              </div>
            </div>
          </div>
          <el-empty v-else description="暂无 AI 请求数据" :image-size="80" />
        </div>
      </section>

      <section class="panel quick-panel">
        <div class="panel-heading">
          <div>
            <h3>快捷入口</h3>
            <p>高频运营任务</p>
          </div>
        </div>
        <div class="quick-grid">
          <router-link to="/users" class="quick-card">
            <el-icon><User /></el-icon>
            <div><strong>用户排查</strong><span>查看用户画像与训练轨迹</span></div>
          </router-link>
          <router-link to="/videos" class="quick-card">
            <el-icon><VideoCamera /></el-icon>
            <div><strong>内容运营</strong><span>上传、发布与下架教学视频</span></div>
          </router-link>
          <router-link to="/chats" class="quick-card">
            <el-icon><ChatDotRound /></el-icon>
            <div><strong>安全审核</strong><span>筛选带安全标记的教练对话</span></div>
          </router-link>
          <router-link to="/audit" class="quick-card">
            <el-icon><Document /></el-icon>
            <div><strong>审计追踪</strong><span>查看所有后台写操作记录</span></div>
          </router-link>
        </div>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { ChatDotRound, Document, Refresh, User, VideoCamera } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import MetricCard from '@/components/MetricCard.vue'
import TrendChart, { type TrendSeries } from '@/components/TrendChart.vue'
import { dashboardApi } from '@/api/operations'
import { errorMessage } from '@/api/client'
import type { DashboardSummary } from '@/api/types'
import { formatNumber } from '@/utils/format'

const loading = ref(false)
const summary = ref<DashboardSummary | null>(null)

const dailyLabels = computed(() => (summary.value?.daily ?? []).map((item) => item.date.slice(5)))
const dailySeries = computed<TrendSeries[]>(() => [
  {
    name: '新增用户',
    data: (summary.value?.daily ?? []).map((item) => item.users),
    color: '#5b8cff',
  },
  {
    name: '训练记录',
    data: (summary.value?.daily ?? []).map((item) => item.workouts),
    color: '#3ddc97',
  },
])
const publishedRate = computed(() => {
  const total = summary.value?.exercisesTotal ?? 0
  const published = summary.value?.videosPublished ?? 0
  return total ? `${Math.round((published / total) * 100)}%` : '0%'
})
const maxKind = computed(() => Math.max(1, ...(summary.value?.aiKinds ?? []).map((item) => item.count)))

async function load(): Promise<void> {
  loading.value = true
  try {
    summary.value = await dashboardApi.summary()
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    loading.value = false
  }
}

function aiKindLabel(kind: string): string {
  return {
    plan: '训练计划生成',
    coach_trainer: '健身教练',
    coach_rehab: '康复师',
    coach_nutrition: '营养师',
    food_vision: '饮食照片识别',
    body_vision: '体型照片分析',
    equipment_vision: '器械照片识别',
  }[kind] ?? kind
}

function kindWidth(count: number): string {
  return `${Math.max(6, Math.round((count / maxKind.value) * 100))}%`
}

onMounted(load)
</script>

<style scoped>
.dashboard-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.65fr) minmax(280px, 0.75fr);
  gap: 14px;
}

.chart-panel,
.ai-panel,
.quick-panel {
  overflow: hidden;
}

.panel-heading {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  padding: 18px 18px 0;
}

.panel-heading h3 {
  margin: 0;
  font-size: 15px;
  letter-spacing: -0.01em;
}

.panel-heading p {
  margin: 5px 0 0;
  color: var(--fitai-text-muted);
  font-size: 12px;
}

.legend-note {
  display: flex;
  align-items: center;
  gap: 5px;
  color: var(--fitai-text-faint);
  font-size: 11px;
}

.dot {
  width: 6px;
  height: 6px;
  margin-left: 5px;
  border-radius: 50%;
}

.users-dot {
  background: #5b8cff;
}

.workouts-dot {
  background: #3ddc97;
}

.chart-wrap {
  padding: 8px 10px 12px;
}

.kind-list {
  display: flex;
  flex-direction: column;
  gap: 15px;
  padding: 22px 18px 24px;
}

.kind-meta {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 6px;
  color: var(--fitai-text-muted);
  font-size: 12px;
}

.kind-meta strong {
  color: var(--fitai-text);
  font-weight: 600;
}

.kind-track {
  height: 5px;
  overflow: hidden;
  border-radius: 999px;
  background: rgba(148, 163, 184, 0.1);
}

.kind-track span {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: linear-gradient(90deg, #5b8cff, #3ddc97);
}

.panel-link {
  color: #7fa3fa;
  font-size: 11px;
  white-space: nowrap;
}

.quick-panel .panel-heading {
  padding-bottom: 2px;
}

.quick-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 10px;
  padding: 16px 18px 20px;
}

.quick-card {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  padding: 13px;
  border: 1px solid var(--fitai-border);
  border-radius: 11px;
  background: rgba(148, 163, 184, 0.035);
  color: inherit;
  transition: border-color 160ms ease, background 160ms ease;
}

.quick-card:hover {
  border-color: rgba(91, 140, 255, 0.32);
  background: rgba(91, 140, 255, 0.07);
}

.quick-card > .el-icon {
  margin-top: 2px;
  color: #7fa3fa;
  font-size: 18px;
}

.quick-card div {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 4px;
}

.quick-card strong {
  color: #dce6f5;
  font-size: 12px;
  font-weight: 600;
}

.quick-card span {
  color: #6d7d93;
  font-size: 11px;
  line-height: 1.45;
}

@media (max-width: 1100px) {
  .dashboard-grid {
    grid-template-columns: 1fr;
  }

  .quick-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 600px) {
  .quick-grid {
    grid-template-columns: 1fr;
  }

  .legend-note {
    display: none;
  }
}
</style>
