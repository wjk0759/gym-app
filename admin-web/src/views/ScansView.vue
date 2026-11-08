<template>
  <div class="page-shell">
    <PageHeader title="器械识别" subtitle="检查视觉识别请求、候选质量、个人器械库与原始模型输出。">
      <template #actions>
        <el-button :icon="Refresh" :loading="loading || summaryLoading" @click="refresh">刷新</el-button>
      </template>
    </PageHeader>

    <section v-loading="summaryLoading" class="metric-grid">
      <MetricCard label="识别总数" :value="formatNumber(summary?.total)" foot="累计视觉识别请求" glow="rgba(91, 140, 255, 0.24)" />
      <MetricCard label="近 7 天" :value="formatNumber(summary?.last7d)" foot="最近一周请求" glow="rgba(61, 220, 151, 0.2)" />
      <MetricCard
        label="零候选率"
        :value="percent(summary?.zeroCandidate ?? 0, summary?.total ?? 0)"
        :foot="`${formatNumber(summary?.zeroCandidate)} 条无可用动作`"
        glow="rgba(255, 107, 129, 0.2)"
      />
      <MetricCard
        label="平均候选数"
        :value="formatDecimal(summary?.avgCandidates, 1)"
        :foot="`unavailable ${formatNumber(summary?.unavailable)} 条`"
        glow="rgba(248, 196, 92, 0.18)"
      />
    </section>

    <el-tabs v-model="activeTab" class="scan-tabs">
      <el-tab-pane label="识别记录" name="scans">
        <section class="panel quality-panel">
          <div class="panel-heading">
            <div>
              <h3>识别质量</h3>
              <p>当前只看模型候选质量；真实 top-1 / top-2 命中率需要 App 回传用户最终选择。</p>
            </div>
            <div class="chip-row">
              <el-tag v-for="item in summary?.models || []" :key="item.model" effect="plain" size="small">
                {{ item.model }} · {{ item.count }}
              </el-tag>
            </div>
          </div>
          <TrendChart
            v-if="summary?.daily?.length"
            :labels="dailyLabels"
            :series="dailySeries"
            height="180px"
          />
        </section>

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
        <el-select v-model="filters.status" clearable placeholder="识别状态" @change="applyFilters">
          <el-option label="成功" value="ok" />
          <el-option label="成功（旧）" value="succeeded" />
          <el-option label="未识别到器械" value="unknown_equipment" />
          <el-option label="动作库未收录" value="no_actions" />
          <el-option label="视觉不可用" value="unavailable" />
        </el-select>
        <el-button type="primary" @click="applyFilters">查询</el-button>
        <el-button text @click="resetFilters">重置</el-button>
      </div>

      <el-table v-loading="loading" :data="rows" row-key="id" @row-dblclick="openDetail" @row-click="onRowClick">
        <el-table-column label="用户" min-width="190">
          <template #default="{ row }">
            <div class="cell-stack">
              <strong>{{ row.userLabel }}</strong>
              <span class="mono">{{ shortId(row.userId) }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="112">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column label="识别数量" width="100" align="center">
          <template #default="{ row }">{{ row.resultCount }}</template>
        </el-table-column>
        <el-table-column label="首选结果" min-width="160">
          <template #default="{ row }">
            <span class="truncate">{{ topLabel(row.topResult) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="模型" width="120" show-overflow-tooltip>
          <template #default="{ row }">{{ row.model || '—' }}</template>
        </el-table-column>
        <el-table-column label="创建时间" width="158">
          <template #default="{ row }">{{ formatDateTime(row.createdAt) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="122">
          <template #default="{ row }">
            <el-button link type="primary" @click="openDetail(row)">查看</el-button>
            <el-button v-if="canWrite" link type="danger" @click="remove(row)">删除</el-button>
          </template>
        </el-table-column>
        <template #empty><el-empty description="没有匹配的器械识别记录" :image-size="90" /></template>
      </el-table>

      <PaginationBar
        :page="page"
        :size="size"
        :total="total"
        @update:page="onPageChange"
        @update:size="onSizeChange"
      />
        </section>
      </el-tab-pane>

      <el-tab-pane label="个人器械库" name="library">
        <section class="panel table-panel">
          <div class="filter-bar">
            <el-input
              v-model="libraryFilters.q"
              class="filter-grow"
              clearable
              placeholder="搜索器械名称、备注、用户手机号或用户名"
              :prefix-icon="Search"
              @keyup.enter="applyLibraryFilters"
              @clear="applyLibraryFilters"
            />
            <el-select
              v-model="libraryFilters.source"
              clearable
              placeholder="来源"
              @change="applyLibraryFilters"
            >
              <el-option label="手动添加" value="manual" />
              <el-option label="识别补充" value="recognition" />
            </el-select>
            <el-button type="primary" @click="applyLibraryFilters">查询</el-button>
            <el-button text @click="resetLibraryFilters">重置</el-button>
          </div>

          <el-table v-loading="libraryLoading" :data="libraryRows" row-key="id">
            <el-table-column label="用户" min-width="160">
              <template #default="{ row }">
                <div class="cell-stack">
                  <strong>{{ row.phone || row.username || shortId(row.userId) }}</strong>
                  <span class="mono">{{ shortId(row.userId) }}</span>
                </div>
              </template>
            </el-table-column>
            <el-table-column prop="name" label="器械名称" min-width="170" />
            <el-table-column label="部位 / 器械" width="150">
              <template #default="{ row }">
                {{ row.muscle || '—' }} / {{ row.equipment || '—' }}
              </template>
            </el-table-column>
            <el-table-column prop="slug" label="动作 slug" width="150" show-overflow-tooltip />
            <el-table-column label="来源" width="100">
              <template #default="{ row }">{{ row.source === 'manual' ? '手动添加' : row.source }}</template>
            </el-table-column>
            <el-table-column prop="notes" label="备注" min-width="180" show-overflow-tooltip />
            <el-table-column label="创建时间" width="150">
              <template #default="{ row }">{{ formatDateTime(row.createdAt) }}</template>
            </el-table-column>
            <template #empty><el-empty description="暂无个人器械" :image-size="70" /></template>
          </el-table>

          <PaginationBar
            :page="libraryPage"
            :size="librarySize"
            :total="libraryTotal"
            @update:page="onLibraryPageChange"
            @update:size="onLibrarySizeChange"
          />
        </section>
      </el-tab-pane>
    </el-tabs>

    <el-drawer
      v-model="drawerVisible"
      title="识别详情"
      size="min(780px, 96vw)"
      destroy-on-close
      @closed="detail = null"
    >
      <div v-loading="detailLoading" class="drawer-body">
        <template v-if="detail">
          <div class="scan-hero">
            <div>
              <p class="eyebrow">VISION SCAN</p>
              <h3>{{ detail.scan.userLabel }}</h3>
              <p>{{ formatDateTime(detail.scan.createdAt) }} · {{ detail.scan.model || '未知模型' }}</p>
            </div>
            <StatusTag :status="detail.scan.status" />
          </div>

          <div v-if="detail.scan.imageUrl" class="image-wrap">
            <el-image
              :src="detail.scan.imageUrl"
              :preview-src-list="[detail.scan.imageUrl]"
              fit="contain"
              preview-teleported
            >
              <template #error><div class="image-error">图片不可用</div></template>
            </el-image>
          </div>

          <div class="drawer-section">
            <div class="detail-grid">
              <div class="detail-item"><span>记录 ID</span><span class="mono">{{ detail.scan.id }}</span></div>
              <div class="detail-item"><span>用户 ID</span><span class="mono">{{ detail.scan.userId }}</span></div>
              <div class="detail-item"><span>识别数量</span><span>{{ detail.scan.resultCount }}</span></div>
              <div class="detail-item"><span>状态</span><span>{{ statusLabel(detail.scan.status) }}</span></div>
            </div>
          </div>

          <div class="drawer-section">
            <h4 class="section-title">识别结果</h4>
            <JsonBlock :value="detail.result" />
          </div>
        </template>
      </div>
    </el-drawer>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Refresh, Search } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import PaginationBar from '@/components/PaginationBar.vue'
import StatusTag from '@/components/StatusTag.vue'
import JsonBlock from '@/components/JsonBlock.vue'
import MetricCard from '@/components/MetricCard.vue'
import TrendChart from '@/components/TrendChart.vue'
import { scansApi } from '@/api/scans'
import { equipmentLibraryApi } from '@/api/equipmentLibrary'
import { errorMessage } from '@/api/client'
import { useAuthStore } from '@/stores/auth'
import type { EquipmentLibraryItem, ScanDetail, ScanListItem, ScanSummary } from '@/api/types'
import {
  formatDecimal,
  formatDateTime,
  formatNumber,
  percent,
  shortId,
  statusLabel,
} from '@/utils/format'

const auth = useAuthStore()
const canWrite = auth.hasPermission('scan:write')
const rows = ref<ScanListItem[]>([])
const total = ref(0)
const page = ref(1)
const size = ref(20)
const loading = ref(false)
const drawerVisible = ref(false)
const detailLoading = ref(false)
const detail = ref<ScanDetail | null>(null)
const filters = reactive({ q: '', status: '' })
const activeTab = ref('scans')
const summary = ref<ScanSummary | null>(null)
const summaryLoading = ref(false)

const libraryRows = ref<EquipmentLibraryItem[]>([])
const libraryTotal = ref(0)
const libraryPage = ref(1)
const librarySize = ref(20)
const libraryLoading = ref(false)
const libraryFilters = reactive({ q: '', source: '' })

const dailyLabels = computed(() => (summary.value?.daily ?? []).map((item) => item.date.slice(5)))
const dailySeries = computed(() => [
  { name: '识别数', data: (summary.value?.daily ?? []).map((item) => item.count), color: '#5b8cff' },
])

async function load(): Promise<void> {
  loading.value = true
  try {
    const result = await scansApi.list({
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

async function loadSummary(): Promise<void> {
  summaryLoading.value = true
  try {
    summary.value = await scansApi.summary()
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    summaryLoading.value = false
  }
}

async function loadLibrary(): Promise<void> {
  libraryLoading.value = true
  try {
    const result = await equipmentLibraryApi.list({
      q: libraryFilters.q.trim() || undefined,
      source: libraryFilters.source || undefined,
      page: libraryPage.value,
      size: librarySize.value,
    })
    libraryRows.value = result.items
    libraryTotal.value = result.total
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    libraryLoading.value = false
  }
}

function refresh(): void {
  void load()
  void loadSummary()
  void loadLibrary()
}

function applyLibraryFilters(): void {
  libraryPage.value = 1
  void loadLibrary()
}

function resetLibraryFilters(): void {
  libraryFilters.q = ''
  libraryFilters.source = ''
  applyLibraryFilters()
}

function onLibraryPageChange(value: number): void {
  libraryPage.value = value
  void loadLibrary()
}

function onLibrarySizeChange(value: number): void {
  librarySize.value = value
  libraryPage.value = 1
  void loadLibrary()
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

async function openDetail(row: ScanListItem): Promise<void> {
  drawerVisible.value = true
  detailLoading.value = true
  try {
    detail.value = await scansApi.detail(row.id)
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
    drawerVisible.value = false
  } finally {
    detailLoading.value = false
  }
}

async function remove(row: ScanListItem): Promise<void> {
  try {
    await ElMessageBox.confirm('删除识别记录不会删除原始图片文件。确定删除吗？', '删除识别记录', {
      confirmButtonText: '删除',
      cancelButtonText: '取消',
      type: 'warning',
    })
    await scansApi.remove(row.id)
    ElMessage.success('识别记录已删除')
    if (detail.value?.scan.id === row.id) drawerVisible.value = false
    await load()
  } catch (reason) {
    if (reason !== 'cancel' && reason !== 'close') ElMessage.error(errorMessage(reason))
  }
}

function topLabel(value: unknown): string {
  if (!value) return '—'
  if (typeof value === 'string') return value
  if (typeof value === 'object') {
    const record = value as Record<string, unknown>
    return String(record.name || record.label || record.name_zh || record.slug || JSON.stringify(value))
  }
  return String(value)
}

function onRowClick(row: ScanListItem, _column: unknown, event: MouseEvent): void {
  const target = event.target as HTMLElement | null
  if (target?.closest('button, a, .el-dropdown, .el-switch, input, textarea, select')) return
  void openDetail(row)
}

onMounted(refresh)
</script>

<style scoped>
.quality-panel {
  margin-bottom: 16px;
}

.scan-tabs {
  margin-top: 4px;
}

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

.scan-hero {
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

.scan-hero h3 {
  margin: 0;
  color: #edf3fc;
  font-size: 21px;
}

.scan-hero p:last-child {
  margin: 6px 0 0;
  color: var(--fitai-text-muted);
  font-size: 12px;
}

.image-wrap {
  display: grid;
  min-height: 220px;
  place-items: center;
  margin-top: 18px;
  overflow: hidden;
  border: 1px solid var(--fitai-border);
  border-radius: 12px;
  background: rgba(5, 9, 16, 0.6);
}

.image-wrap .el-image {
  max-height: 360px;
}

.image-error {
  padding: 40px;
  color: var(--fitai-text-muted);
  font-size: 12px;
}
</style>
