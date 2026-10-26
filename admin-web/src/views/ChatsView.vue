<template>
  <div class="page-shell">
    <PageHeader title="教练对话" subtitle="查看 AI 教练会话、安全标记与引用内容，处理需要下线的对话。">
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
          placeholder="搜索对话标题、用户昵称、手机号"
          :prefix-icon="Search"
          @keyup.enter="applyFilters"
          @clear="applyFilters"
        />
        <el-checkbox v-model="filters.safetyOnly" @change="applyFilters">只看安全标记</el-checkbox>
        <el-button type="primary" @click="applyFilters">查询</el-button>
        <el-button text @click="resetFilters">重置</el-button>
      </div>

      <el-table v-loading="loading" :data="rows" row-key="id" @row-dblclick="openDetail" @row-click="onRowClick">
        <el-table-column label="对话" min-width="230">
          <template #default="{ row }">
            <div class="cell-stack">
              <strong>{{ row.title }}</strong>
              <span>{{ row.userLabel }} · {{ shortId(row.id) }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="消息数" width="86" align="right">
          <template #default="{ row }">{{ formatNumber(row.messageCount) }}</template>
        </el-table-column>
        <el-table-column label="安全标记" width="100" align="center">
          <template #default="{ row }">
            <el-tag v-if="row.safetyCount" type="danger" effect="plain" size="small">{{ row.safetyCount }}</el-tag>
            <span v-else class="faint">—</span>
          </template>
        </el-table-column>
        <el-table-column label="创建时间" width="158">
          <template #default="{ row }">{{ formatDateTime(row.createdAt) }}</template>
        </el-table-column>
        <el-table-column label="最后消息" width="158">
          <template #default="{ row }">{{ formatDateTime(row.lastMessageAt) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="122">
          <template #default="{ row }">
            <el-button link type="primary" @click="openDetail(row)">查看</el-button>
            <el-button v-if="canWrite" link type="danger" @click="remove(row)">删除</el-button>
          </template>
        </el-table-column>
        <template #empty><el-empty description="没有匹配的教练对话" :image-size="90" /></template>
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
      title="对话详情"
      size="min(820px, 96vw)"
      destroy-on-close
      @closed="detail = null"
    >
      <div v-loading="detailLoading" class="drawer-body">
        <template v-if="detail">
          <div class="chat-hero">
            <div>
              <p class="eyebrow">COACH CONVERSATION</p>
              <h3>{{ detail.chat.title }}</h3>
              <p>{{ detail.chat.userLabel }} · {{ formatDateTime(detail.chat.createdAt) }} · {{ detail.chat.messageCount }} 条消息</p>
            </div>
            <el-tag v-if="detail.chat.safetyCount" type="danger" effect="plain">
              {{ detail.chat.safetyCount }} 条安全标记
            </el-tag>
          </div>

          <div v-if="detail.messages.length" class="message-list">
            <article
              v-for="message in detail.messages"
              :key="message.id"
              class="message"
              :class="`role-${message.role}`"
            >
              <div class="message-meta">
                <span class="role-label">{{ roleLabel(message.role) }}</span>
                <span>{{ formatDateTime(message.createdAt) }}</span>
                <el-tag v-if="message.safetyFlag" type="danger" effect="plain" size="small">{{ message.safetyFlag }}</el-tag>
                <span v-if="message.tokens" class="faint">{{ message.tokens }} tokens</span>
              </div>
              <div class="message-content">{{ message.content }}</div>
              <details v-if="hasCitations(message.citations)" class="citations">
                <summary>查看引用</summary>
                <JsonBlock :value="message.citations" />
              </details>
            </article>
          </div>
          <el-empty v-else description="该对话没有消息" :image-size="80" />
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
import JsonBlock from '@/components/JsonBlock.vue'
import { chatsApi } from '@/api/chats'
import { errorMessage } from '@/api/client'
import { useAuthStore } from '@/stores/auth'
import type { ChatDetail, ChatListItem } from '@/api/types'
import { formatDateTime, formatNumber, shortId } from '@/utils/format'

const auth = useAuthStore()
const canWrite = auth.hasPermission('chat:write')
const rows = ref<ChatListItem[]>([])
const total = ref(0)
const page = ref(1)
const size = ref(20)
const loading = ref(false)
const drawerVisible = ref(false)
const detailLoading = ref(false)
const detail = ref<ChatDetail | null>(null)
const filters = reactive({ q: '', safetyOnly: false })

async function load(): Promise<void> {
  loading.value = true
  try {
    const result = await chatsApi.list({
      q: filters.q.trim() || undefined,
      safetyOnly: filters.safetyOnly || undefined,
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
  filters.safetyOnly = false
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

async function openDetail(row: ChatListItem): Promise<void> {
  drawerVisible.value = true
  detailLoading.value = true
  try {
    detail.value = await chatsApi.detail(row.id)
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
    drawerVisible.value = false
  } finally {
    detailLoading.value = false
  }
}

async function remove(row: ChatListItem): Promise<void> {
  try {
    await ElMessageBox.confirm('删除对话会同时删除全部消息，且不可恢复。确定删除吗？', '删除教练对话', {
      confirmButtonText: '删除',
      cancelButtonText: '取消',
      type: 'warning',
    })
    await chatsApi.remove(row.id)
    ElMessage.success('对话已删除')
    if (detail.value?.chat.id === row.id) drawerVisible.value = false
    await load()
  } catch (reason) {
    if (reason !== 'cancel' && reason !== 'close') ElMessage.error(errorMessage(reason))
  }
}

function roleLabel(role: string): string {
  return { user: '用户', assistant: 'AI 教练', system: '系统' }[role] ?? role
}

function hasCitations(value: unknown): boolean {
  if (Array.isArray(value)) return value.length > 0
  return Boolean(value && typeof value === 'object')
}

function onRowClick(row: ChatListItem, _column: unknown, event: MouseEvent): void {
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

.chat-hero {
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

.chat-hero h3 {
  margin: 0;
  color: #edf3fc;
  font-size: 21px;
}

.chat-hero p:last-child {
  margin: 6px 0 0;
  color: var(--fitai-text-muted);
  font-size: 12px;
}

.message-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding-top: 18px;
}

.message {
  max-width: 92%;
  padding: 12px 14px;
  border: 1px solid var(--fitai-border);
  border-radius: 12px;
  background: rgba(148, 163, 184, 0.035);
}

.message.role-user {
  align-self: flex-end;
  border-color: rgba(91, 140, 255, 0.22);
  background: rgba(91, 140, 255, 0.07);
}

.message.role-system {
  max-width: 100%;
  border-style: dashed;
  background: transparent;
}

.message-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
  color: var(--fitai-text-faint);
  font-size: 10px;
}

.role-label {
  color: #9eb8ef;
  font-weight: 600;
}

.message-content {
  color: #d7e1ef;
  font-size: 13px;
  line-height: 1.7;
  white-space: pre-wrap;
  word-break: break-word;
}

.citations {
  margin-top: 10px;
  color: var(--fitai-text-muted);
  font-size: 11px;
}

.citations summary {
  cursor: pointer;
}

.citations .json-block {
  margin-top: 8px;
}

@media (max-width: 640px) {
  .chat-hero {
    flex-direction: column;
  }

  .message {
    max-width: 100%;
  }
}
</style>
