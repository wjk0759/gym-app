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
                  <el-dropdown-item v-if="canWrite && !row.deleted" command="delete">删除账号</el-dropdown-item>
                  <el-dropdown-item v-if="canWrite && row.deleted" command="restore">恢复账号</el-dropdown-item>
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
                <span class="faint">加入于 {{ formatDateTime(detail.user.createdAt) }}</span>
              </div>
            </div>
            <el-button v-if="canWrite" size="small" @click="exportUser(detail.user)">导出 JSON</el-button>
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
          </el-tabs>
        </template>
      </div>
    </el-drawer>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Refresh, Search, ArrowDown } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import PaginationBar from '@/components/PaginationBar.vue'
import StatusTag from '@/components/StatusTag.vue'
import { usersApi } from '@/api/users'
import { errorMessage } from '@/api/client'
import { useAuthStore } from '@/stores/auth'
import type { UserDetail, UserListItem } from '@/api/types'
import {
  formatDateTime,
  formatDuration,
  formatNumber,
  goalLabel,
  shortId,
} from '@/utils/format'

const auth = useAuthStore()
const canWrite = auth.hasPermission('user:write')
const rows = ref<UserListItem[]>([])
const total = ref(0)
const page = ref(1)
const size = ref(20)
const loading = ref(false)
const drawerVisible = ref(false)
const detailLoading = ref(false)
const detail = ref<UserDetail | null>(null)
const detailTab = ref('profile')

const filters = reactive({
  q: '',
  status: '',
  includeDeleted: false,
})

async function load(): Promise<void> {
  loading.value = true
  try {
    const result = await usersApi.list({
      q: filters.q.trim() || undefined,
      status: filters.status || undefined,
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
  try {
    detail.value = await usersApi.detail(row.id)
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
    drawerVisible.value = false
  } finally {
    detailLoading.value = false
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
  } else if (command === 'delete') {
    void remove(row)
  } else if (command === 'restore') {
    void restore(row)
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
}
</style>
