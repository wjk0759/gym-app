<template>
  <div class="page-shell">
    <PageHeader title="训练记录" subtitle="查看用户训练完成度、训练量与动作组记录，支持异常数据清理。">
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
          placeholder="搜索用户昵称、手机号或用户 ID"
          :prefix-icon="Search"
          @keyup.enter="applyFilters"
          @clear="applyFilters"
        />
        <el-button type="primary" @click="applyFilters">查询</el-button>
        <el-button text @click="resetFilters">重置</el-button>
      </div>

      <el-table v-loading="loading" :data="rows" row-key="id" @row-dblclick="openDetail" @row-click="onRowClick">
        <el-table-column label="用户" min-width="170">
          <template #default="{ row }">
            <div class="cell-stack">
              <strong>{{ row.userLabel }}</strong>
              <span class="mono">{{ shortId(row.userId) }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="开始时间" width="158">
          <template #default="{ row }">{{ formatDateTime(row.startedAt) }}</template>
        </el-table-column>
        <el-table-column label="时长" width="100">
          <template #default="{ row }">{{ formatDuration(row.durationMin) }}</template>
        </el-table-column>
        <el-table-column label="动作 / 组数" width="120" align="center">
          <template #default="{ row }">{{ row.exerciseCount }} / {{ row.setCount }}</template>
        </el-table-column>
        <el-table-column label="训练容量" width="120" align="right">
          <template #default="{ row }">{{ formatNumber(Math.round(row.volumeKg)) }} kg</template>
        </el-table-column>
        <el-table-column label="感受" width="82" align="center">
          <template #default="{ row }">
            <el-tag v-if="row.feeling" size="small" effect="plain">{{ row.feeling }} / 5</el-tag>
            <span v-else class="faint">—</span>
          </template>
        </el-table-column>
        <el-table-column label="结束时间" width="158">
          <template #default="{ row }">{{ formatDateTime(row.finishedAt) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="120">
          <template #default="{ row }">
            <el-button link type="primary" @click="openDetail(row)">查看</el-button>
            <el-button v-if="canWrite" link type="danger" @click="remove(row)">删除</el-button>
          </template>
        </el-table-column>
        <template #empty><el-empty description="没有匹配的训练记录" :image-size="90" /></template>
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
      title="训练详情"
      size="min(860px, 96vw)"
      destroy-on-close
      @closed="detail = null"
    >
      <div v-loading="detailLoading" class="drawer-body">
        <template v-if="detail">
          <div class="workout-hero">
            <div>
              <p class="eyebrow">WORKOUT SESSION</p>
              <h3>{{ detail.workout.userLabel }}</h3>
              <p>{{ formatDateTime(detail.workout.startedAt) }} · {{ formatDuration(detail.workout.durationMin) }}</p>
            </div>
            <div class="hero-stats">
              <div><strong>{{ detail.workout.exerciseCount }}</strong><span>动作</span></div>
              <div><strong>{{ detail.workout.setCount }}</strong><span>组数</span></div>
              <div><strong>{{ formatNumber(Math.round(detail.workout.volumeKg)) }}</strong><span>容量 kg</span></div>
            </div>
          </div>

          <div class="drawer-section">
            <div class="detail-grid">
              <div class="detail-item"><span>训练记录 ID</span><span class="mono">{{ detail.workout.id }}</span></div>
              <div class="detail-item"><span>用户 ID</span><span class="mono">{{ detail.workout.userId }}</span></div>
              <div class="detail-item"><span>结束时间</span><span>{{ formatDateTime(detail.workout.finishedAt) }}</span></div>
              <div class="detail-item"><span>主观感受</span><span>{{ detail.workout.feeling ? `${detail.workout.feeling} / 5` : '未记录' }}</span></div>
            </div>
          </div>

          <div class="drawer-section">
            <h4 class="section-title">动作组记录</h4>
            <el-table :data="detail.sets" size="small" class="set-table">
              <el-table-column label="动作" min-width="170">
                <template #default="{ row }">
                  <div class="cell-stack">
                    <strong>{{ row.nameZh || row.slug }}</strong>
                    <span class="mono">{{ row.slug }}</span>
                  </div>
                </template>
              </el-table-column>
              <el-table-column label="组" width="58" align="center">
                <template #default="{ row }">#{{ row.setIndex }}</template>
              </el-table-column>
              <el-table-column label="重量" width="90" align="right">
                <template #default="{ row }">{{ row.weightKg ? `${row.weightKg} kg` : '自重' }}</template>
              </el-table-column>
              <el-table-column label="次数" width="72" align="center">
                <template #default="{ row }">{{ row.reps ?? '—' }}</template>
              </el-table-column>
              <el-table-column label="RPE" width="68" align="center">
                <template #default="{ row }">{{ row.rpe ?? '—' }}</template>
              </el-table-column>
              <el-table-column label="完成" width="76" align="center">
                <template #default="{ row }">
                  <el-tag :type="row.completed ? 'success' : 'info'" effect="plain" size="small">
                    {{ row.completed ? '完成' : '未完成' }}
                  </el-tag>
                </template>
              </el-table-column>
              <template #empty><el-empty description="没有组记录" :image-size="70" /></template>
            </el-table>
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
import { workoutsApi } from '@/api/workouts'
import { errorMessage } from '@/api/client'
import { useAuthStore } from '@/stores/auth'
import type { WorkoutDetail, WorkoutListItem } from '@/api/types'
import {
  formatDateTime,
  formatDuration,
  formatNumber,
  shortId,
} from '@/utils/format'

const auth = useAuthStore()
const canWrite = auth.hasPermission('workout:write')
const rows = ref<WorkoutListItem[]>([])
const total = ref(0)
const page = ref(1)
const size = ref(20)
const loading = ref(false)
const drawerVisible = ref(false)
const detailLoading = ref(false)
const detail = ref<WorkoutDetail | null>(null)
const filters = reactive({ q: '' })

async function load(): Promise<void> {
  loading.value = true
  try {
    const result = await workoutsApi.list({
      q: filters.q.trim() || undefined,
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

async function openDetail(row: WorkoutListItem): Promise<void> {
  drawerVisible.value = true
  detailLoading.value = true
  try {
    detail.value = await workoutsApi.detail(row.id)
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
    drawerVisible.value = false
  } finally {
    detailLoading.value = false
  }
}

async function remove(row: WorkoutListItem): Promise<void> {
  try {
    await ElMessageBox.confirm(
      '删除训练记录会同时删除其组记录，且不可恢复。确定删除吗？',
      '删除训练记录',
      { confirmButtonText: '删除', cancelButtonText: '取消', type: 'warning' },
    )
    await workoutsApi.remove(row.id)
    ElMessage.success('训练记录已删除')
    if (detail.value?.workout.id === row.id) drawerVisible.value = false
    await load()
  } catch (reason) {
    if (reason !== 'cancel' && reason !== 'close') ElMessage.error(errorMessage(reason))
  }
}

function onRowClick(row: WorkoutListItem, _column: unknown, event: MouseEvent): void {
  const target = event.target as HTMLElement | null
  if (target?.closest('button, a, .el-dropdown, .el-switch, input, textarea, select')) return
  void openDetail(row)
}

onMounted(load)
</script>

<style scoped>
.cell-stack {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.cell-stack strong {
  color: #dfe8f6;
  font-size: 13px;
  font-weight: 600;
}

.cell-stack span {
  color: #687890;
  font-size: 11px;
}

.workout-hero {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 18px;
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

.workout-hero h3 {
  margin: 0;
  color: #edf3fc;
  font-size: 21px;
}

.workout-hero p:last-child {
  margin: 6px 0 0;
  color: var(--fitai-text-muted);
  font-size: 12px;
}

.hero-stats {
  display: flex;
  gap: 8px;
}

.hero-stats div {
  display: flex;
  min-width: 72px;
  flex-direction: column;
  gap: 2px;
  padding: 9px 12px;
  border: 1px solid var(--fitai-border);
  border-radius: 9px;
  background: rgba(148, 163, 184, 0.04);
}

.hero-stats strong {
  color: #dce8ff;
  font-size: 17px;
}

.hero-stats span {
  color: var(--fitai-text-faint);
  font-size: 10px;
}

.set-table {
  margin-top: 10px;
}

@media (max-width: 640px) {
  .workout-hero {
    flex-direction: column;
  }

  .hero-stats {
    width: 100%;
  }

  .hero-stats div {
    flex: 1;
  }
}
</style>
