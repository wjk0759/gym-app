<template>
  <div class="page-shell">
    <PageHeader title="审计日志" subtitle="追踪后台写操作、登录事件与数据导出，每条记录都带有请求关联 ID。">
      <template #actions>
        <el-button :icon="Refresh" :loading="loading" @click="load">刷新</el-button>
      </template>
    </PageHeader>

    <section class="panel table-panel">
      <div class="filter-bar">
        <el-input
          v-model="filters.actor"
          clearable
          placeholder="操作人账号"
          :prefix-icon="Search"
          @keyup.enter="applyFilters"
          @clear="applyFilters"
        />
        <el-input
          v-model="filters.action"
          clearable
          placeholder="动作，如 USER_DELETED"
          @keyup.enter="applyFilters"
          @clear="applyFilters"
        />
        <el-input
          v-model="filters.targetType"
          clearable
          placeholder="对象类型，如 user"
          @keyup.enter="applyFilters"
          @clear="applyFilters"
        />
        <el-button type="primary" @click="applyFilters">查询</el-button>
        <el-button text @click="resetFilters">重置</el-button>
      </div>

      <el-table v-loading="loading" :data="rows" row-key="id" @row-dblclick="openDetail" @row-click="onRowClick">
        <el-table-column label="操作" min-width="180">
          <template #default="{ row }">
            <div class="cell-stack">
              <strong>{{ actionLabel(row.action) }}</strong>
              <span class="mono">{{ row.action }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="操作人" width="120">
          <template #default="{ row }"><span class="actor">{{ row.actor }}</span></template>
        </el-table-column>
        <el-table-column label="对象" width="150">
          <template #default="{ row }">
            <div class="cell-stack">
              <span>{{ row.targetType }}</span>
              <span class="mono">{{ shortId(row.targetId) }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="时间" width="158">
          <template #default="{ row }">{{ formatDateTime(row.createdAt) }}</template>
        </el-table-column>
        <el-table-column label="详情" min-width="220" show-overflow-tooltip>
          <template #default="{ row }"><span class="mono faint">{{ compact(row.detail) }}</span></template>
        </el-table-column>
        <el-table-column label="操作" width="88">
          <template #default="{ row }">
            <el-button link type="primary" @click="openDetail(row)">详情</el-button>
          </template>
        </el-table-column>
        <template #empty><el-empty description="没有匹配的审计日志" :image-size="90" /></template>
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
      title="审计详情"
      size="min(680px, 96vw)"
      destroy-on-close
      @closed="detail = null"
    >
      <div v-if="detail" class="stack">
        <div class="audit-hero">
          <div>
            <p class="eyebrow">AUDIT EVENT</p>
            <h3>{{ actionLabel(detail.action) }}</h3>
            <p>{{ detail.action }}</p>
          </div>
          <span class="actor-chip">{{ detail.actor }}</span>
        </div>
        <div class="detail-grid">
          <div class="detail-item"><span>日志 ID</span><span class="mono">{{ detail.id }}</span></div>
          <div class="detail-item"><span>对象类型</span><span>{{ detail.targetType }}</span></div>
          <div class="detail-item"><span>对象 ID</span><span class="mono">{{ detail.targetId || '—' }}</span></div>
          <div class="detail-item"><span>发生时间</span><span>{{ formatDateTime(detail.createdAt) }}</span></div>
        </div>
        <div>
          <h4 class="section-title">事件上下文</h4>
          <JsonBlock :value="detail.detail" />
        </div>
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
import JsonBlock from '@/components/JsonBlock.vue'
import { auditApi } from '@/api/operations'
import { errorMessage } from '@/api/client'
import type { AuditItem } from '@/api/types'
import { actionLabel, formatDateTime, shortId } from '@/utils/format'

const rows = ref<AuditItem[]>([])
const total = ref(0)
const page = ref(1)
const size = ref(20)
const loading = ref(false)
const drawerVisible = ref(false)
const detail = ref<AuditItem | null>(null)
const filters = reactive({ actor: '', action: '', targetType: '' })

async function load(): Promise<void> {
  loading.value = true
  try {
    const result = await auditApi.list({
      actor: filters.actor.trim() || undefined,
      action: filters.action.trim() || undefined,
      targetType: filters.targetType.trim() || undefined,
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
  filters.actor = ''
  filters.action = ''
  filters.targetType = ''
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

function openDetail(row: AuditItem): void {
  detail.value = row
  drawerVisible.value = true
}

function onRowClick(row: AuditItem, _column: unknown, event: MouseEvent): void {
  const target = event.target as HTMLElement | null
  if (target?.closest('button, a, .el-dropdown')) return
  openDetail(row)
}

function compact(value: unknown): string {
  if (!value) return '—'
  if (typeof value === 'string') return value
  try {
    return JSON.stringify(value)
  } catch {
    return String(value)
  }
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

.actor {
  color: #a9b9d0;
  font-size: 12px;
}

.audit-hero {
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

.audit-hero h3 {
  margin: 0;
  color: #edf3fc;
  font-size: 21px;
}

.audit-hero p:last-child {
  margin: 6px 0 0;
  color: var(--fitai-text-muted);
  font-family: 'JetBrains Mono', monospace;
  font-size: 11px;
}

.actor-chip {
  padding: 6px 10px;
  border: 1px solid var(--fitai-border);
  border-radius: 999px;
  color: #9eb8ef;
  font-size: 11px;
}
</style>
