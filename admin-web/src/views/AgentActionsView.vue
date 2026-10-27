<template>
  <div class="page-shell">
    <PageHeader
      title="Agent 动作"
      subtitle="用户确认后由 App 执行的动作结果、撤销与失败审计"
    >
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
          placeholder="用户昵称 / 手机号 / 用户 ID / 动作 ID"
          :prefix-icon="Search"
          @keyup.enter="applyFilters"
          @clear="applyFilters"
        />
        <el-select v-model="filters.actionType" clearable placeholder="动作类型" @change="applyFilters">
          <el-option v-for="item in actionTypes" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
        <el-select v-model="filters.status" clearable placeholder="执行状态" @change="applyFilters">
          <el-option label="已执行" value="executed" />
          <el-option label="已拒绝" value="rejected" />
          <el-option label="失败" value="failed" />
          <el-option label="已撤销" value="undone" />
        </el-select>
        <el-button type="primary" @click="applyFilters">查询</el-button>
        <el-button text @click="resetFilters">重置</el-button>
      </div>

      <el-table v-loading="loading" :data="rows" row-key="id" @row-click="openDetail">
        <el-table-column label="用户" min-width="170">
          <template #default="{ row }">
            <div class="cell-main">{{ row.userLabel || '—' }}</div>
            <div class="cell-sub">{{ shortId(row.userId) }}</div>
          </template>
        </el-table-column>
        <el-table-column label="动作" width="150">
          <template #default="{ row }">{{ actionTypeLabel(row.actionType) }}</template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column label="说明" min-width="240" show-overflow-tooltip>
          <template #default="{ row }">{{ row.message || '—' }}</template>
        </el-table-column>
        <el-table-column label="动作 ID" min-width="150" class-name="hide-mobile">
          <template #default="{ row }"><span class="mono">{{ row.actionId }}</span></template>
        </el-table-column>
        <el-table-column label="时间" width="154">
          <template #default="{ row }">{{ formatDateTime(row.createdAt) }}</template>
        </el-table-column>
        <template #empty><el-empty description="没有匹配的动作记录" :image-size="80" /></template>
      </el-table>

      <PaginationBar
        :page="page"
        :size="size"
        :total="total"
        @update:page="onPage"
        @update:size="onSize"
      />
    </section>

    <el-drawer v-model="drawerOpen" size="min(640px, 94vw)" title="动作详情" destroy-on-close>
      <div v-if="detail" class="drawer-stack">
        <section class="detail-head">
          <div>
            <div class="cell-sub">动作 ID</div>
            <div class="mono">{{ detail.actionId }}</div>
          </div>
          <StatusTag :status="detail.status" />
        </section>

        <section class="panel inset-panel">
          <div class="detail-grid">
            <div><span>用户</span><strong>{{ detail.userLabel }}</strong></div>
            <div><span>动作类型</span><strong>{{ actionTypeLabel(detail.actionType) }}</strong></div>
            <div><span>运行 ID</span><strong class="mono">{{ detail.runId || '—' }}</strong></div>
            <div><span>执行时间</span><strong>{{ formatDateTime(detail.createdAt) }}</strong></div>
          </div>
          <div v-if="detail.message" class="quote-block">{{ detail.message }}</div>
        </section>

        <section class="panel inset-panel">
          <div class="panel-heading compact"><h3>动作参数与结果</h3></div>
          <JsonBlock :value="detail.detail" />
        </section>
      </div>
    </el-drawer>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { Refresh, Search } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import PaginationBar from '@/components/PaginationBar.vue'
import StatusTag from '@/components/StatusTag.vue'
import JsonBlock from '@/components/JsonBlock.vue'
import { agentApi } from '@/api/agent'
import { errorMessage } from '@/api/client'
import type { AgentActionItem } from '@/api/types'
import { formatDateTime, shortId } from '@/utils/format'

const actionTypes = [
  { value: 'reschedule_training', label: '调整训练日期' },
  { value: 'skip_training', label: '跳过训练' },
  { value: 'start_training', label: '开始训练' },
  { value: 'open_screen', label: '打开页面' },
  { value: 'update_goal', label: '更新目标' },
  { value: 'log_body_metric', label: '记录身体指标' },
]

const loading = ref(false)
const rows = ref<AgentActionItem[]>([])
const total = ref(0)
const page = ref(1)
const size = ref(20)
const filters = reactive({ status: '', actionType: '', q: '' })
const drawerOpen = ref(false)
const detail = ref<AgentActionItem | null>(null)

async function load(): Promise<void> {
  loading.value = true
  try {
    const response = await agentApi.actions({
      status: filters.status || undefined,
      actionType: filters.actionType || undefined,
      q: filters.q.trim() || undefined,
      page: page.value,
      size: size.value,
    })
    rows.value = response.items
    total.value = response.total
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
  filters.actionType = ''
  applyFilters()
}

function onPage(value: number): void {
  page.value = value
  void load()
}

function onSize(value: number): void {
  size.value = value
  page.value = 1
  void load()
}

function openDetail(row: AgentActionItem): void {
  detail.value = row
  drawerOpen.value = true
}

function actionTypeLabel(value: string): string {
  return actionTypes.find((item) => item.value === value)?.label ?? value
}

onMounted(load)
</script>

<style scoped>
.panel {
  padding: 0;
  overflow: hidden;
}

.table-panel {
  padding: 0;
}

.cell-main {
  color: var(--fitai-text);
  font-weight: 600;
}

.cell-sub {
  margin-top: 3px;
  color: var(--fitai-text-faint);
  font-size: 10px;
}

.mono {
  color: var(--fitai-text-muted);
  font-family: 'JetBrains Mono', monospace;
  font-size: 10px;
}

.drawer-stack {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 0 20px 28px;
}

.detail-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.inset-panel {
  padding: 16px;
}

.detail-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.detail-grid span {
  display: block;
  color: var(--fitai-text-faint);
  font-size: 10px;
}

.detail-grid strong {
  display: block;
  margin-top: 3px;
  color: var(--fitai-text);
  font-size: 12px;
}

.quote-block {
  margin-top: 14px;
  padding: 10px 12px;
  border: 1px solid var(--fitai-border);
  border-radius: 9px;
  color: var(--fitai-text-muted);
  font-size: 12px;
  line-height: 1.6;
  white-space: pre-wrap;
}

.panel-heading.compact {
  padding-bottom: 10px;
}

@media (max-width: 720px) {
  :deep(.hide-mobile) {
    display: none;
  }

  .detail-grid {
    grid-template-columns: 1fr;
  }
}
</style>
