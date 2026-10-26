<template>
  <div class="page-shell">
    <PageHeader title="训练计划" subtitle="审核 AI 生成的训练计划，处理启用与归档，查看每日动作编排。">
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
          placeholder="搜索计划标题、用户昵称或手机号"
          :prefix-icon="Search"
          @keyup.enter="applyFilters"
          @clear="applyFilters"
        />
        <el-select v-model="filters.status" clearable placeholder="计划状态" @change="applyFilters">
          <el-option label="启用" value="active" />
          <el-option label="草稿" value="draft" />
          <el-option label="已归档" value="archived" />
        </el-select>
        <el-button type="primary" @click="applyFilters">查询</el-button>
        <el-button text @click="resetFilters">重置</el-button>
      </div>

      <el-table v-loading="loading" :data="rows" row-key="id" @row-dblclick="openDetail" @row-click="onRowClick">
        <el-table-column label="计划" min-width="220">
          <template #default="{ row }">
            <div class="plan-cell">
              <strong>{{ row.title }}</strong>
              <span>{{ row.userLabel }} · {{ shortId(row.id) }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="目标" width="90">
          <template #default="{ row }">{{ goalLabel(row.goalType) }}</template>
        </el-table-column>
        <el-table-column label="状态" width="92">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column prop="version" label="版本" width="68" align="center" />
        <el-table-column label="编排" width="116" align="center">
          <template #default="{ row }">{{ row.dayCount }} 天 / {{ row.exerciseCount }} 动作</template>
        </el-table-column>
        <el-table-column label="开始日期" width="110">
          <template #default="{ row }">{{ formatDate(row.startDate) }}</template>
        </el-table-column>
        <el-table-column label="创建时间" width="150">
          <template #default="{ row }">{{ formatDateTime(row.createdAt) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="156">
          <template #default="{ row }">
            <el-button link type="primary" @click="openDetail(row)">查看</el-button>
            <el-button
              v-if="canWrite && row.status !== 'active'"
              link
              type="success"
              @click="activate(row)"
            >启用</el-button>
            <el-button
              v-if="canWrite && row.status !== 'archived'"
              link
              type="warning"
              @click="archive(row)"
            >归档</el-button>
          </template>
        </el-table-column>
        <template #empty><el-empty description="没有匹配的训练计划" :image-size="90" /></template>
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
      title="计划详情"
      size="min(900px, 96vw)"
      destroy-on-close
      @closed="detail = null"
    >
      <div v-loading="detailLoading" class="drawer-body">
        <template v-if="detail">
          <div class="plan-hero">
            <div>
              <p class="eyebrow">TRAINING PROGRAM</p>
              <h3>{{ detail.plan.title }}</h3>
              <p>{{ detail.plan.userLabel }} · {{ detail.plan.weeks }} 周 · v{{ detail.plan.version }}</p>
            </div>
            <div class="plan-hero-actions">
              <StatusTag :status="detail.plan.status" />
              <el-button
                v-if="canWrite && detail.plan.status !== 'active'"
                type="primary"
                size="small"
                @click="activate(detail.plan)"
              >设为当前计划</el-button>
            </div>
          </div>

          <div class="drawer-section">
            <div class="detail-grid">
              <div class="detail-item"><span>计划 ID</span><span class="mono">{{ detail.plan.id }}</span></div>
              <div class="detail-item"><span>用户 ID</span><span class="mono">{{ detail.plan.userId }}</span></div>
              <div class="detail-item"><span>目标</span><span>{{ goalLabel(detail.plan.goalType) }}</span></div>
              <div class="detail-item"><span>开始日期</span><span>{{ formatDate(detail.plan.startDate) }}</span></div>
              <div class="detail-item"><span>总天数</span><span>{{ detail.plan.dayCount }} 天</span></div>
              <div class="detail-item"><span>总动作数</span><span>{{ detail.plan.exerciseCount }} 个</span></div>
            </div>
          </div>

          <div class="drawer-section">
            <div class="row-between">
              <h4 class="section-title">每日编排</h4>
              <span class="faint">{{ detail.days.length }} 个训练日</span>
            </div>
            <el-collapse v-if="detail.days.length" class="day-collapse">
              <el-collapse-item v-for="day in detail.days" :key="day.id" :name="day.id">
                <template #title>
                  <div class="day-title">
                    <span class="day-badge">W{{ day.weekIndex }} · 周{{ day.weekday }}</span>
                    <strong>{{ day.title }}</strong>
                    <span class="faint">{{ day.exercises.length }} 个动作</span>
                  </div>
                </template>
                <div class="focus-row">
                  <el-tag v-for="focus in asArray(day.focus)" :key="focus" size="small" effect="plain">{{ focus }}</el-tag>
                </div>
                <el-table :data="day.exercises" size="small">
                  <el-table-column prop="nameZh" label="动作" min-width="150" />
                  <el-table-column prop="muscleGroup" label="部位" width="86" />
                  <el-table-column prop="equipment" label="器械" width="86" />
                  <el-table-column label="组数 × 次数" width="108">
                    <template #default="{ row }">{{ row.sets }} × {{ row.reps }}</template>
                  </el-table-column>
                  <el-table-column label="重量" width="84">
                    <template #default="{ row }">{{ row.weightKg ? `${row.weightKg} kg` : '自重' }}</template>
                  </el-table-column>
                  <el-table-column label="休息" width="76">
                    <template #default="{ row }">{{ row.restSec }}s</template>
                  </el-table-column>
                  <el-table-column prop="notes" label="备注" min-width="130" show-overflow-tooltip />
                </el-table>
              </el-collapse-item>
            </el-collapse>
            <el-empty v-else description="计划尚未编排训练日" :image-size="80" />
          </div>
        </template>
      </div>
    </el-drawer>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Refresh, Search } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import PaginationBar from '@/components/PaginationBar.vue'
import StatusTag from '@/components/StatusTag.vue'
import { plansApi } from '@/api/plans'
import { errorMessage } from '@/api/client'
import { useAuthStore } from '@/stores/auth'
import type { PlanDetail, PlanListItem } from '@/api/types'
import { formatDate, formatDateTime, goalLabel, shortId } from '@/utils/format'

const auth = useAuthStore()
const canWrite = auth.hasPermission('plan:write')
const rows = ref<PlanListItem[]>([])
const total = ref(0)
const page = ref(1)
const size = ref(20)
const loading = ref(false)
const drawerVisible = ref(false)
const detailLoading = ref(false)
const detail = ref<PlanDetail | null>(null)
const filters = reactive({ q: '', status: '' })

async function load(): Promise<void> {
  loading.value = true
  try {
    const result = await plansApi.list({
      q: filters.q.trim() || undefined,
      status: filters.status || undefined,
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

async function openDetail(row: PlanListItem): Promise<void> {
  drawerVisible.value = true
  detailLoading.value = true
  try {
    detail.value = await plansApi.detail(row.id)
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
    drawerVisible.value = false
  } finally {
    detailLoading.value = false
  }
}

async function activate(row: PlanListItem): Promise<void> {
  try {
    await ElMessageBox.confirm('启用后，该用户其他启用中的计划会自动归档。确定继续吗？', '启用计划', {
      confirmButtonText: '启用',
      cancelButtonText: '取消',
      type: 'warning',
    })
    await plansApi.activate(row.id)
    ElMessage.success('计划已启用')
    await load()
    if (detail.value?.plan.id === row.id) {
      detail.value = await plansApi.detail(row.id)
    }
  } catch (reason) {
    if (reason !== 'cancel' && reason !== 'close') ElMessage.error(errorMessage(reason))
  }
}

async function archive(row: PlanListItem): Promise<void> {
  try {
    await ElMessageBox.confirm('归档后该计划不会继续作为当前计划，用户数据不会被删除。确定归档吗？', '归档计划', {
      confirmButtonText: '归档',
      cancelButtonText: '取消',
      type: 'warning',
    })
    await plansApi.archive(row.id)
    ElMessage.success('计划已归档')
    await load()
    if (detail.value?.plan.id === row.id) {
      detail.value = await plansApi.detail(row.id)
    }
  } catch (reason) {
    if (reason !== 'cancel' && reason !== 'close') ElMessage.error(errorMessage(reason))
  }
}

function asArray(value: unknown): string[] {
  return Array.isArray(value) ? value.map(String) : []
}

function onRowClick(row: PlanListItem, _column: unknown, event: MouseEvent): void {
  const target = event.target as HTMLElement | null
  if (target?.closest('button, a, .el-dropdown, .el-switch, input, textarea, select')) return
  void openDetail(row)
}

onMounted(load)
</script>

<style scoped>
.plan-cell {
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.plan-cell strong {
  color: #dfe8f6;
  font-size: 13px;
  font-weight: 600;
}

.plan-cell span {
  color: #687890;
  font-size: 11px;
}

.plan-hero {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  padding-bottom: 18px;
  border-bottom: 1px solid var(--fitai-border);
}

.eyebrow {
  margin: 0 0 6px;
  color: #6f8dd4;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.16em;
}

.plan-hero h3 {
  margin: 0;
  color: #edf3fc;
  font-size: 21px;
  letter-spacing: -0.02em;
}

.plan-hero p:last-child {
  margin: 6px 0 0;
  color: var(--fitai-text-muted);
  font-size: 12px;
}

.plan-hero-actions {
  display: flex;
  align-items: center;
  gap: 10px;
}

.day-collapse {
  margin-top: 12px;
  border: 0;
}

.day-title {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
}

.day-title strong {
  color: #dce6f5;
  font-size: 13px;
}

.day-badge {
  padding: 3px 7px;
  border-radius: 5px;
  background: rgba(91, 140, 255, 0.12);
  color: #8eb0ff;
  font-family: 'JetBrains Mono', monospace;
  font-size: 10px;
  white-space: nowrap;
}

.focus-row {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
  margin-bottom: 10px;
}

@media (max-width: 640px) {
  .plan-hero {
    flex-direction: column;
  }

  .plan-hero-actions {
    width: 100%;
    justify-content: space-between;
  }
}
</style>
