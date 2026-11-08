<template>
  <div class="page-shell">
    <PageHeader
      title="饮食运营"
      subtitle="查看餐单策略、生成来源、用户饮食记录与近 30 天目标热量"
    >
      <template #actions>
        <el-button :icon="Refresh" :loading="loading" @click="load">刷新</el-button>
      </template>
    </PageHeader>

    <div v-loading="loading" class="stack">
      <section class="metric-grid">
        <MetricCard
          label="餐单总数"
          :value="formatNumber(summary?.mealPlansTotal)"
          :foot="`近 7 天 ${formatNumber(summary?.mealPlans7d)} 份`"
          glow="rgba(61, 220, 151, 0.22)"
        />
        <MetricCard
          label="饮食记录"
          :value="formatNumber(summary?.foodLogsTotal)"
          :foot="`近 7 天 ${formatNumber(summary?.foodLogs7d)} 条`"
          glow="rgba(91, 140, 255, 0.24)"
        />
        <MetricCard
          label="近 7 天饮食活跃"
          :value="formatNumber(summary?.activeUsers7d)"
          foot="有餐单或饮食记录的用户"
          glow="rgba(248, 196, 92, 0.2)"
        />
        <MetricCard
          label="30 天平均目标热量"
          :value="summary?.avgTargetKcal ? `${formatNumber(Math.round(summary.avgTargetKcal))} kcal` : '—'"
          foot="仅统计已填写 target_kcal 的餐单"
          glow="rgba(255, 107, 129, 0.18)"
        />
      </section>

      <template v-if="hasDietData">
      <section class="two-col-grid">
        <div class="panel insight-panel">
          <div class="panel-heading">
            <div>
              <h3>策略分布</h3>
              <p>全量餐单按 strategy 统计</p>
            </div>
            <span class="faint">{{ formatNumber(summary?.strategies.length) }} 种</span>
          </div>
          <div v-if="summary?.strategies.length" class="dist-list">
            <div v-for="item in summary.strategies" :key="item.strategy" class="dist-row">
              <div class="dist-meta">
                <span>{{ strategyLabel(item.strategy) }}</span>
                <strong>{{ formatNumber(item.count) }}</strong>
              </div>
              <div class="dist-track">
                <span :style="{ width: shareWidth(item.count, strategyMax) }" />
              </div>
            </div>
          </div>
          <el-empty v-else description="暂无餐单数据" :image-size="70" />
        </div>

        <div class="panel insight-panel">
          <div class="panel-heading">
            <div>
              <h3>生成来源</h3>
              <p>AI / 模板 / 规则生成占比</p>
            </div>
          </div>
          <div v-if="summary?.generatedBy.length" class="chip-row">
            <el-tag v-for="item in summary.generatedBy" :key="item.generatedBy" effect="plain">
              {{ generatedByLabel(item.generatedBy) }} · {{ item.count }}
            </el-tag>
          </div>
          <el-empty v-else description="暂无生成来源" :image-size="70" />
        </div>
      </section>

      <section class="panel table-panel">
        <div class="panel-heading">
          <div>
            <h3>最近餐单</h3>
            <p>最新 20 份，按创建时间倒序</p>
          </div>
        </div>
        <el-table :data="summary?.recentPlans || []" size="small">
          <el-table-column label="用户" min-width="150">
            <template #default="{ row }">{{ row.userLabel }}</template>
          </el-table-column>
          <el-table-column label="日期" width="110">
            <template #default="{ row }">{{ formatDate(row.planDate) }}</template>
          </el-table-column>
          <el-table-column label="周起始" width="110">
            <template #default="{ row }">{{ formatDate(row.weekStart) }}</template>
          </el-table-column>
          <el-table-column label="策略" width="120">
            <template #default="{ row }">{{ strategyLabel(row.strategy) }}</template>
          </el-table-column>
          <el-table-column label="来源" width="100">
            <template #default="{ row }">{{ generatedByLabel(row.generatedBy) }}</template>
          </el-table-column>
          <el-table-column label="目标热量" width="100" align="right">
            <template #default="{ row }">{{ row.targetKcal ? `${row.targetKcal} kcal` : '—' }}</template>
          </el-table-column>
          <el-table-column label="创建时间" width="150">
            <template #default="{ row }">{{ formatDateTime(row.createdAt) }}</template>
          </el-table-column>
          <template #empty><el-empty description="暂无餐单" :image-size="70" /></template>
        </el-table>
      </section>

      <section class="panel table-panel">
        <div class="panel-heading">
          <div>
            <h3>最近饮食记录</h3>
            <p>最新 20 条 food_logs</p>
          </div>
        </div>
        <el-table :data="summary?.recentLogs || []" size="small">
          <el-table-column label="用户" min-width="140">
            <template #default="{ row }">{{ row.userLabel }}</template>
          </el-table-column>
          <el-table-column label="时间" width="150">
            <template #default="{ row }">{{ formatDateTime(row.loggedAt) }}</template>
          </el-table-column>
          <el-table-column prop="meal" label="餐次" width="80" />
          <el-table-column prop="foodName" label="食物" min-width="160" />
          <el-table-column label="克数" width="80" align="right">
            <template #default="{ row }">{{ row.grams ?? '—' }}</template>
          </el-table-column>
          <el-table-column label="热量" width="80" align="right">
            <template #default="{ row }">{{ row.kcal ?? '—' }}</template>
          </el-table-column>
          <el-table-column label="蛋白 / 碳水 / 脂肪" min-width="150">
            <template #default="{ row }">
              {{ row.protein ?? '—' }} / {{ row.carbs ?? '—' }} / {{ row.fat ?? '—' }} g
            </template>
          </el-table-column>
          <template #empty><el-empty description="暂无饮食记录" :image-size="70" /></template>
        </el-table>
      </section>
      </template>

      <section v-else class="panel empty-panel">
        <el-empty
          description="还没有饮食数据；用户生成餐单或记录饮食后，这里会出现策略分布和最近记录。"
          :image-size="90"
        />
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { Refresh } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import MetricCard from '@/components/MetricCard.vue'
import { dietApi } from '@/api/diet'
import { errorMessage } from '@/api/client'
import type { DietSummary } from '@/api/types'
import { formatDate, formatDateTime, formatNumber } from '@/utils/format'

const loading = ref(false)
const summary = ref<DietSummary | null>(null)

const strategyMax = computed(() =>
  Math.max(1, ...(summary.value?.strategies ?? []).map((item) => item.count)),
)

const hasDietData = computed(() =>
  (summary.value?.mealPlansTotal ?? 0) + (summary.value?.foodLogsTotal ?? 0) > 0,
)

async function load(): Promise<void> {
  loading.value = true
  try {
    summary.value = await dietApi.summary()
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    loading.value = false
  }
}

function shareWidth(value: number, max: number): string {
  return `${Math.max(4, Math.round((value / Math.max(1, max)) * 100))}%`
}

function strategyLabel(strategy: string): string {
  const labels: Record<string, string> = {
    balanced: '均衡',
    carb_cycle: '碳循环',
    low_carb: '低碳',
    high_protein: '高蛋白',
    mediterranean: '地中海',
    vegetarian: '素食',
    fasting_16_8: '16:8 轻断食',
  }
  return labels[strategy] ?? strategy
}

function generatedByLabel(value: string): string {
  if (value === 'ai') return 'AI'
  if (value === 'template') return '模板'
  if (value === 'rule') return '规则'
  return value
}

onMounted(load)
</script>

<style scoped>
.stack {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.two-col-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.4fr) minmax(280px, 0.8fr);
  gap: 16px;
}

.empty-panel {
  min-height: 180px;
}

.chip-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  padding: 18px;
}

@media (max-width: 1100px) {
  .two-col-grid {
    grid-template-columns: 1fr;
  }
}
</style>
