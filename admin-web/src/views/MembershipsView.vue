<template>
  <div class="page-shell">
    <PageHeader
      title="会员运营"
      subtitle="全局查看 Pro 权益、来源、到期与撤销；赠送和撤销都会写入审计日志"
    >
      <template #actions>
        <el-button :icon="Refresh" :loading="loading" @click="refresh">刷新</el-button>
        <el-button v-if="canManage" type="primary" :icon="Plus" @click="openGrant()">赠送 Pro</el-button>
      </template>
    </PageHeader>

    <section v-loading="summaryLoading" class="metric-grid five">
      <MetricCard
        label="有效 Pro 用户"
        :value="formatNumber(summary?.activeProUsers)"
        :foot="`权益记录 ${formatNumber(summary?.activeEntitlements)}`"
        glow="rgba(61, 220, 151, 0.22)"
      />
      <MetricCard
        label="7 天内到期"
        :value="formatNumber(summary?.expiring7d)"
        foot="需要续期或召回"
        glow="rgba(248, 196, 92, 0.24)"
      />
      <MetricCard
        label="30 天内到期"
        :value="formatNumber(summary?.expiring30d)"
        foot="本月续费窗口"
        glow="rgba(248, 196, 92, 0.16)"
      />
      <MetricCard
        label="7 天新增权益"
        :value="formatNumber(summary?.newGrants7d)"
        foot="含赠送与 App Store"
        glow="rgba(91, 140, 255, 0.24)"
      />
      <MetricCard
        label="30 天撤销"
        :value="formatNumber(summary?.revoked30d)"
        foot="退款 / 人工撤销"
        glow="rgba(255, 107, 129, 0.2)"
      />
    </section>

    <section class="panel source-panel">
      <div class="panel-heading">
        <div>
          <h3>有效权益来源</h3>
          <p>同一用户可能同时存在赠送和 App Store 订阅。</p>
        </div>
        <div class="chip-row">
          <el-tag v-for="item in summary?.sources || []" :key="item.source" effect="plain">
            {{ sourceLabel(item.source) }} · {{ item.count }}
          </el-tag>
          <span v-if="!summary?.sources?.length" class="muted">暂无有效来源</span>
        </div>
      </div>
    </section>

    <section class="panel table-panel">
      <div class="filter-bar">
        <el-input
          v-model="filters.q"
          class="filter-grow"
          clearable
          placeholder="搜索用户昵称、手机号、用户名或用户 ID"
          :prefix-icon="Search"
          @keyup.enter="applyFilters"
          @clear="applyFilters"
        />
        <el-select v-model="filters.source" clearable placeholder="来源" @change="applyFilters">
          <el-option label="后台赠送" value="admin" />
          <el-option label="App Store" value="storekit" />
          <el-option label="活动 / 兑换码" value="promo" />
        </el-select>
        <el-select v-model="filters.status" clearable placeholder="状态" @change="applyFilters">
          <el-option label="有效" value="active" />
          <el-option label="7 天内到期" value="expiring" />
          <el-option label="已过期" value="expired" />
          <el-option label="已撤销" value="revoked" />
        </el-select>
        <el-button type="primary" @click="applyFilters">查询</el-button>
        <el-button text @click="resetFilters">重置</el-button>
      </div>

      <el-table v-loading="loading" :data="rows" row-key="entitlementId">
        <el-table-column label="用户" min-width="200">
          <template #default="{ row }">
            <div class="cell-stack">
              <strong>{{ row.userLabel }}</strong>
              <span>{{ row.phone || row.nickname || shortId(row.userId) }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="来源" width="120">
          <template #default="{ row }">
            <el-tag effect="plain" size="small">{{ sourceLabel(row.source) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="开始" width="150">
          <template #default="{ row }">{{ formatDateTime(row.startsAt) }}</template>
        </el-table-column>
        <el-table-column label="到期" width="150">
          <template #default="{ row }">
            <span :class="row.status === 'expiring' ? 'text-warning' : ''">{{ formatDateTime(row.expiresAt) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="剩余" width="86" align="center">
          <template #default="{ row }">
            <span v-if="row.daysLeft !== null">{{ row.daysLeft }} 天</span>
            <span v-else class="faint">—</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="104">
          <template #default="{ row }">
            <el-tag :type="membershipStatusType(row.status)" effect="plain" size="small">
              {{ membershipStatusLabel(row.status) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="原因 / 引用" min-width="180">
          <template #default="{ row }">
            <div class="cell-stack">
              <span>{{ row.reason || '未填写原因' }}</span>
              <span class="faint mono">{{ row.sourceRef ? shortId(row.sourceRef) : '—' }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150">
          <template #default="{ row }">
            <el-button v-if="canManage && !row.revokedAt" link type="primary" @click="openGrant(row)">
              续期
            </el-button>
            <el-button
              v-if="canManage && !row.revokedAt"
              link
              type="danger"
              @click="revoke(row)"
            >撤销</el-button>
          </template>
        </el-table-column>
        <template #empty><el-empty description="没有匹配的会员权益" :image-size="80" /></template>
      </el-table>

      <PaginationBar
        :page="page"
        :size="size"
        :total="total"
        @update:page="onPageChange"
        @update:size="onSizeChange"
      />
    </section>

    <el-dialog v-model="grantVisible" title="赠送 Pro 会员" width="min(520px, calc(100vw - 28px))" destroy-on-close>
      <el-form ref="grantFormRef" :model="grantForm" :rules="grantRules" label-position="top">
        <el-form-item label="用户" prop="userId">
          <el-select
            v-model="grantForm.userId"
            filterable
            remote
            :remote-method="searchUsers"
            :loading="userLoading"
            placeholder="输入昵称、手机号或用户名搜索"
            style="width: 100%"
          >
            <el-option
              v-for="item in userOptions"
              :key="item.id"
              :label="userOptionLabel(item)"
              :value="item.id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="赠送时长（天）" prop="durationDays">
          <el-input-number v-model="grantForm.durationDays" :min="1" :max="3650" style="width: 100%" />
          <span class="upload-hint">重复赠送会从当前有效到期时间往后叠加。</span>
        </el-form-item>
        <el-form-item label="操作原因" prop="reason">
          <el-input
            v-model="grantForm.reason"
            type="textarea"
            :rows="3"
            maxlength="200"
            show-word-limit
            placeholder="例如：TestFlight 体验补偿 / 客服补偿"
          />
        </el-form-item>
        <el-alert type="info" :closable="false" show-icon title="保存后立即写入生产权益表，并记录审计日志。" />
      </el-form>
      <template #footer>
        <el-button @click="grantVisible = false">取消</el-button>
        <el-button type="primary" :loading="grantSaving" @click="submitGrant">确认赠送</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus'
import { Plus, Refresh, Search } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import PaginationBar from '@/components/PaginationBar.vue'
import MetricCard from '@/components/MetricCard.vue'
import { membershipsApi } from '@/api/memberships'
import { usersApi } from '@/api/users'
import { errorMessage } from '@/api/client'
import { useAuthStore } from '@/stores/auth'
import type { MembershipItem, MembershipSummary, UserListItem } from '@/api/types'
import { formatDateTime, formatNumber, shortId } from '@/utils/format'

const auth = useAuthStore()
const canManage = auth.hasPermission('user:entitlement:write')

const rows = ref<MembershipItem[]>([])
const total = ref(0)
const page = ref(1)
const size = ref(20)
const loading = ref(false)
const summary = ref<MembershipSummary | null>(null)
const summaryLoading = ref(false)
const filters = reactive({ q: '', source: '', status: '' })

const grantVisible = ref(false)
const grantSaving = ref(false)
const grantFormRef = ref<FormInstance>()
const userOptions = ref<UserListItem[]>([])
const userLoading = ref(false)
const grantForm = reactive({
  userId: '',
  durationDays: 30,
  reason: '',
})

const grantRules: FormRules = {
  userId: [{ required: true, message: '请选择用户', trigger: 'change' }],
  durationDays: [{ required: true, message: '请填写赠送天数', trigger: 'blur' }],
  reason: [{ required: true, message: '请填写操作原因', trigger: 'blur' }],
}

async function load(): Promise<void> {
  loading.value = true
  try {
    const result = await membershipsApi.list({
      q: filters.q.trim() || undefined,
      source: filters.source || undefined,
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
    summary.value = await membershipsApi.summary()
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    summaryLoading.value = false
  }
}

function refresh(): void {
  void load()
  void loadSummary()
}

function applyFilters(): void {
  page.value = 1
  void load()
}

function resetFilters(): void {
  filters.q = ''
  filters.source = ''
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

async function searchUsers(query: string): Promise<void> {
  userLoading.value = true
  try {
    const result = await usersApi.list({ q: query.trim() || undefined, page: 1, size: 20 })
    userOptions.value = result.items
  } catch {
    userOptions.value = []
  } finally {
    userLoading.value = false
  }
}

async function openGrant(row?: MembershipItem): Promise<void> {
  grantForm.userId = row?.userId ?? ''
  grantForm.durationDays = 30
  grantForm.reason = row ? `会员续期：${row.reason || row.source}` : ''
  await searchUsers(row?.userLabel ?? '')
  if (row) {
    const existing = userOptions.value.find((item) => item.id === row.userId)
    if (!existing) {
      userOptions.value = [
        {
          id: row.userId,
          phone: row.phone,
          username: null,
          nickname: row.nickname,
          status: 'active',
          sex: null,
          createdAt: null,
          lastLoginAt: null,
          weeklyDays: null,
          goalType: null,
          workoutCount: 0,
          deleted: false,
          test: false,
          updatedAt: null,
          authMethods: {},
        },
        ...userOptions.value,
      ]
    }
  }
  grantVisible.value = true
}

async function submitGrant(): Promise<void> {
  const valid = await grantFormRef.value?.validate().catch(() => false)
  if (!valid) return
  grantSaving.value = true
  try {
    await usersApi.grantAccess(grantForm.userId, grantForm.durationDays, grantForm.reason.trim())
    ElMessage.success('Pro 会员已赠送')
    grantVisible.value = false
    refresh()
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    grantSaving.value = false
  }
}

async function revoke(row: MembershipItem): Promise<void> {
  try {
    const result = await ElMessageBox.prompt('请填写撤销原因；撤销后不可恢复。', '撤销会员权益', {
      confirmButtonText: '撤销',
      cancelButtonText: '取消',
      inputPattern: /\S+/,
      inputErrorMessage: '请填写撤销原因',
      type: 'warning',
    })
    await usersApi.revokeAccess(row.userId, row.entitlementId, result.value.trim())
    ElMessage.success('会员权益已撤销')
    refresh()
  } catch (reason) {
    if (reason !== 'cancel' && reason !== 'close') ElMessage.error(errorMessage(reason))
  }
}

function sourceLabel(source: string): string {
  if (source === 'admin') return '后台赠送'
  if (source === 'storekit') return 'App Store'
  if (source === 'promo') return '活动 / 兑换码'
  if (source === 'trial') return '试用'
  return source
}

function membershipStatusLabel(status: string): string {
  if (status === 'active') return '有效'
  if (status === 'expiring') return '即将到期'
  if (status === 'expired') return '已过期'
  if (status === 'revoked') return '已撤销'
  return status
}

function membershipStatusType(status: string): 'success' | 'warning' | 'danger' | 'info' {
  if (status === 'active') return 'success'
  if (status === 'expiring') return 'warning'
  if (status === 'revoked') return 'danger'
  return 'info'
}

function userOptionLabel(item: UserListItem): string {
  const name = item.nickname || item.phone || item.username || shortId(item.id)
  const extra = item.phone && item.nickname ? ` · ${item.phone}` : ''
  return `${name}${extra}`
}

onMounted(() => {
  refresh()
})
</script>

<style scoped>
.metric-grid {
  margin-bottom: 16px;
}

.source-panel {
  margin-bottom: 16px;
}

.cell-stack {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
}

.cell-stack strong {
  overflow: hidden;
  color: #dfe8f6;
  font-size: 13px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.cell-stack span {
  overflow: hidden;
  color: #687890;
  font-size: 11px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.text-warning {
  color: #f8c45c;
}

.upload-hint {
  display: block;
  margin-top: 5px;
  color: var(--fitai-text-faint);
  font-size: 11px;
}
</style>
