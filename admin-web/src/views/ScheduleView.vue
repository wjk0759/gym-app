<template>
  <div class="page-shell">
    <PageHeader
      title="排期状态"
      subtitle="跨设备同步的计划日期、跳过记录与最后写入时间（后写覆盖）"
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
          placeholder="用户昵称 / 手机号 / 用户 ID / 计划 ID / 天 ID"
          :prefix-icon="Search"
          @keyup.enter="applyFilters"
          @clear="applyFilters"
        />
        <el-input
          v-model="filters.planId"
          clearable
          placeholder="精确计划 ID"
          @keyup.enter="applyFilters"
          @clear="applyFilters"
        />
        <el-button type="primary" @click="applyFilters">查询</el-button>
        <el-button text @click="resetFilters">重置</el-button>
      </div>

      <el-table v-loading="loading" :data="rows" row-key="id">
        <el-table-column label="用户" min-width="160">
          <template #default="{ row }">
            <div class="cell-main">{{ row.userLabel || '—' }}</div>
            <div class="cell-sub">{{ shortId(row.userId) }}</div>
          </template>
        </el-table-column>
        <el-table-column label="计划" min-width="170">
          <template #default="{ row }">
            <div class="cell-main mono">{{ row.planId }}</div>
            <div class="cell-sub">v{{ row.planVersion ?? '—' }}</div>
          </template>
        </el-table-column>
        <el-table-column label="训练日 ID" min-width="160" class-name="hide-mobile">
          <template #default="{ row }"><span class="mono">{{ row.dayId }}</span></template>
        </el-table-column>
        <el-table-column label="安排日期" width="110">
          <template #default="{ row }">{{ row.assignedDate || '未安排' }}</template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag v-if="row.skippedAt" type="warning" effect="plain" size="small">已跳过</el-tag>
            <el-tag v-else type="success" effect="plain" size="small">正常</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="客户端更新" width="154" class-name="hide-mobile">
          <template #default="{ row }">{{ formatDateTime(row.clientUpdatedAt) }}</template>
        </el-table-column>
        <el-table-column label="服务端写入" width="154">
          <template #default="{ row }">{{ formatDateTime(row.updatedAt) }}</template>
        </el-table-column>
        <template #empty><el-empty description="暂无排期状态" :image-size="80" /></template>
      </el-table>

      <PaginationBar
        :page="page"
        :size="size"
        :total="total"
        @update:page="onPage"
        @update:size="onSize"
      />
    </section>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { Refresh, Search } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import PaginationBar from '@/components/PaginationBar.vue'
import { scheduleApi } from '@/api/schedule'
import { errorMessage } from '@/api/client'
import type { ScheduleStateItem } from '@/api/types'
import { formatDateTime, shortId } from '@/utils/format'

const loading = ref(false)
const rows = ref<ScheduleStateItem[]>([])
const total = ref(0)
const page = ref(1)
const size = ref(20)
const filters = reactive({ q: '', planId: '' })

async function load(): Promise<void> {
  loading.value = true
  try {
    const response = await scheduleApi.list({
      q: filters.q.trim() || undefined,
      planId: filters.planId.trim() || undefined,
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
  filters.planId = ''
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
  overflow: hidden;
  color: var(--fitai-text);
  font-size: 12px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
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

.filter-bar .el-input {
  width: min(260px, 100%);
}

@media (max-width: 720px) {
  :deep(.hide-mobile) {
    display: none;
  }
}
</style>
