<template>
  <div class="page-shell">
    <PageHeader title="AI 运营" subtitle="监控 AI 技能调用量、延迟、Token 消耗与失败率，定位模型质量问题。">
      <template #actions>
        <el-button :icon="Refresh" :loading="loading" @click="loadAll">刷新</el-button>
      </template>
    </PageHeader>

    <div v-loading="loading" class="stack">
      <section class="metric-grid">
        <MetricCard
          label="30 天请求"
          :value="formatNumber(overview?.total)"
          :foot="`成功 ${formatNumber(overview?.ok)} · 降级 ${formatNumber(overview?.fallback)}`"
          glow="rgba(91, 140, 255, 0.26)"
        />
        <MetricCard
          label="失败请求"
          :value="formatNumber(overview?.error)"
          :foot="`失败率 ${percent(overview?.error ?? 0, overview?.total ?? 0)}`"
          glow="rgba(255, 107, 129, 0.2)"
        />
        <MetricCard
          label="平均延迟"
          :value="`${formatNumber(overview?.avgLatencyMs)} ms`"
          :foot="`P95 ${formatNumber(overview?.p95LatencyMs)} ms`"
          glow="rgba(248, 196, 92, 0.18)"
        />
        <MetricCard
          label="Token 消耗"
          :value="formatNumber((overview?.inputTokens ?? 0) + (overview?.outputTokens ?? 0))"
          :foot="`输入 ${formatNumber(overview?.inputTokens)} · 输出 ${formatNumber(overview?.outputTokens)}`"
          glow="rgba(61, 220, 151, 0.2)"
        />
      </section>

      <section class="ai-grid">
        <div class="panel chart-panel">
          <div class="panel-heading">
            <div>
              <h3>近 14 天调用趋势</h3>
              <p>请求量 vs 失败量</p>
            </div>
          </div>
          <div class="chart-wrap">
            <TrendChart :labels="dailyLabels" :series="dailySeries" height="280px" />
          </div>
        </div>

        <div class="panel kind-panel">
          <div class="panel-heading">
            <div>
              <h3>能力分布</h3>
              <p>近 30 天</p>
            </div>
          </div>
          <div v-if="overview?.kinds.length" class="kind-list">
            <div v-for="item in overview.kinds" :key="item.kind" class="kind-row">
              <div class="kind-meta">
                <span>{{ item.label }}</span>
                <strong>{{ formatNumber(item.total) }}</strong>
              </div>
              <div class="kind-track"><span :style="{ width: kindWidth(item.total) }" /></div>
              <div class="kind-foot">
                <span :class="{ 'text-danger': item.errors > 0 }">{{ item.errors }} 失败</span>
                <span>{{ percent(item.errors, item.total) }} 失败率</span>
              </div>
            </div>
          </div>
          <el-empty v-else description="暂无调用数据" :image-size="76" />
        </div>
      </section>

      <section class="skill-grid">
        <div v-for="skill in overview?.skills ?? []" :key="skill.key" class="panel skill-card">
          <div class="skill-key">{{ skill.key }}</div>
          <h3>{{ skill.name }}</h3>
          <p>{{ skill.description }}</p>
          <span class="faint">Prompt {{ skill.promptVersion }}</span>
        </div>
      </section>

      <section class="panel table-panel">
        <div class="panel-heading jobs-heading">
          <div>
            <h3>请求明细</h3>
            <p>按能力、状态或用户筛选</p>
          </div>
          <div class="filter-inline">
            <el-select v-model="jobFilters.kind" clearable placeholder="能力" @change="applyJobFilters">
              <el-option v-for="item in kindOptions" :key="item.value" :label="item.label" :value="item.value" />
            </el-select>
            <el-select v-model="jobFilters.status" clearable placeholder="状态" @change="applyJobFilters">
              <el-option label="成功" value="ok" />
              <el-option label="降级" value="fallback" />
              <el-option label="失败" value="error" />
            </el-select>
            <el-input
              v-model="jobFilters.q"
              clearable
              placeholder="用户昵称 / 手机号"
              :prefix-icon="Search"
              @keyup.enter="applyJobFilters"
              @clear="applyJobFilters"
            />
            <el-button @click="applyJobFilters">查询</el-button>
          </div>
        </div>

        <el-table v-loading="jobsLoading" :data="jobs" row-key="id">
          <el-table-column label="用户" min-width="150">
            <template #default="{ row }">{{ row.userLabel || '—' }}</template>
          </el-table-column>
          <el-table-column label="能力" width="150">
            <template #default="{ row }">{{ row.kindLabel }}</template>
          </el-table-column>
          <el-table-column prop="model" label="模型" width="140" show-overflow-tooltip />
          <el-table-column label="状态" width="88">
            <template #default="{ row }"><StatusTag :status="row.status" /></template>
          </el-table-column>
          <el-table-column label="Token" width="106" align="right">
            <template #default="{ row }">{{ formatNumber((row.inputTokens ?? 0) + (row.outputTokens ?? 0)) }}</template>
          </el-table-column>
          <el-table-column label="延迟" width="94" align="right">
            <template #default="{ row }">{{ row.latencyMs ? `${formatNumber(row.latencyMs)} ms` : '—' }}</template>
          </el-table-column>
          <el-table-column label="时间" width="154">
            <template #default="{ row }">{{ formatDateTime(row.createdAt) }}</template>
          </el-table-column>
          <el-table-column label="错误" min-width="180" show-overflow-tooltip>
            <template #default="{ row }"><span :class="{ 'text-danger': row.error }">{{ row.error || '—' }}</span></template>
          </el-table-column>
          <template #empty><el-empty description="没有匹配的 AI 请求" :image-size="80" /></template>
        </el-table>

        <PaginationBar
          :page="jobPage"
          :size="jobSize"
          :total="jobTotal"
          @update:page="onJobPage"
          @update:size="onJobSize"
        />
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { Refresh, Search } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import MetricCard from '@/components/MetricCard.vue'
import TrendChart, { type TrendSeries } from '@/components/TrendChart.vue'
import PaginationBar from '@/components/PaginationBar.vue'
import StatusTag from '@/components/StatusTag.vue'
import { aiApi } from '@/api/operations'
import { errorMessage } from '@/api/client'
import type { AiJobItem, AiOverview } from '@/api/types'
import { formatDateTime, formatNumber, percent } from '@/utils/format'

const loading = ref(false)
const jobsLoading = ref(false)
const overview = ref<AiOverview | null>(null)
const jobs = ref<AiJobItem[]>([])
const jobTotal = ref(0)
const jobPage = ref(1)
const jobSize = ref(20)
const jobFilters = reactive({ kind: '', status: '', q: '' })

const kindOptions = [
  { value: 'plan', label: '训练计划生成' },
  { value: 'coach_trainer', label: '健身教练' },
  { value: 'coach_rehab', label: '康复师' },
  { value: 'coach_nutrition', label: '营养师' },
  { value: 'food_vision', label: '饮食照片识别' },
  { value: 'body_vision', label: '体型照片分析' },
  { value: 'equipment_vision', label: '器械照片识别' },
]

const dailyLabels = computed(() => (overview.value?.daily ?? []).map((item) => item.date.slice(5)))
const dailySeries = computed<TrendSeries[]>(() => [
  {
    name: '请求量',
    data: (overview.value?.daily ?? []).map((item) => item.total),
    color: '#5b8cff',
  },
  {
    name: '失败量',
    data: (overview.value?.daily ?? []).map((item) => item.errors),
    color: '#ff6b81',
  },
])
const maxKind = computed(() => Math.max(1, ...(overview.value?.kinds ?? []).map((item) => item.total)))

async function loadOverview(): Promise<void> {
  loading.value = true
  try {
    overview.value = await aiApi.overview()
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    loading.value = false
  }
}

async function loadJobs(): Promise<void> {
  jobsLoading.value = true
  try {
    const result = await aiApi.jobs({
      kind: jobFilters.kind || undefined,
      status: jobFilters.status || undefined,
      q: jobFilters.q.trim() || undefined,
      page: jobPage.value,
      size: jobSize.value,
    })
    jobs.value = result.items
    jobTotal.value = result.total
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    jobsLoading.value = false
  }
}

async function loadAll(): Promise<void> {
  await Promise.all([loadOverview(), loadJobs()])
}

function applyJobFilters(): void {
  jobPage.value = 1
  void loadJobs()
}

function onJobPage(value: number): void {
  jobPage.value = value
  void loadJobs()
}

function onJobSize(value: number): void {
  jobSize.value = value
  jobPage.value = 1
  void loadJobs()
}

function kindWidth(count: number): string {
  return `${Math.max(6, Math.round((count / maxKind.value) * 100))}%`
}

onMounted(loadAll)
</script>

<style scoped>
.ai-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.4fr) minmax(300px, 0.8fr);
  gap: 14px;
}

.chart-panel,
.kind-panel {
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
}

.panel-heading p {
  margin: 5px 0 0;
  color: var(--fitai-text-muted);
  font-size: 12px;
}

.chart-wrap {
  padding: 8px 10px 12px;
}

.kind-list {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 20px 18px;
}

.kind-meta,
.kind-foot {
  display: flex;
  justify-content: space-between;
  gap: 10px;
  color: var(--fitai-text-muted);
  font-size: 11px;
}

.kind-meta {
  margin-bottom: 6px;
}

.kind-meta strong {
  color: var(--fitai-text);
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

.kind-foot {
  margin-top: 4px;
  color: var(--fitai-text-faint);
  font-size: 10px;
}

.skill-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 14px;
}

.skill-card {
  position: relative;
  padding: 18px;
}

.skill-key {
  color: #6f8dd4;
  font-family: 'JetBrains Mono', monospace;
  font-size: 10px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.skill-card h3 {
  margin: 8px 0 6px;
  font-size: 15px;
}

.skill-card p {
  margin: 0 0 12px;
  color: var(--fitai-text-muted);
  font-size: 12px;
  line-height: 1.6;
}

.jobs-heading {
  align-items: center;
  padding-bottom: 14px;
}

.filter-inline {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
}

.filter-inline .el-select {
  width: 132px;
}

.filter-inline .el-input {
  width: 180px;
}

@media (max-width: 1100px) {
  .ai-grid,
  .skill-grid {
    grid-template-columns: 1fr;
  }

  .jobs-heading {
    align-items: flex-start;
    flex-direction: column;
  }

  .filter-inline {
    width: 100%;
  }

  .filter-inline .el-select,
  .filter-inline .el-input {
    flex: 1 1 140px;
    width: auto;
  }
}
</style>
