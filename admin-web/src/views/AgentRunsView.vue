<template>
  <div class="page-shell">
    <PageHeader
      title="Agent 运行"
      subtitle="查看教练 Agent 的意图、工具调用、计划草案和失败原因。"
    >
      <template #actions>
        <el-button :icon="Refresh" :loading="loading" @click="load">刷新</el-button>
      </template>
    </PageHeader>

    <section class="panel">
      <div class="panel-heading">
        <div>
          <h3>运行记录</h3>
          <p>只读审计视图；生产环境只通过确认接口应用计划草案。</p>
        </div>
        <div class="filter-inline">
          <el-select v-model="filters.status" clearable placeholder="状态" @change="applyFilters">
            <el-option label="运行中" value="running" />
            <el-option label="待确认" value="needs_confirmation" />
            <el-option label="已完成" value="completed" />
            <el-option label="失败" value="failed" />
          </el-select>
          <el-select v-model="filters.intent" clearable placeholder="意图" @change="applyFilters">
            <el-option label="教练对话" value="coach_chat" />
            <el-option label="计划调整" value="plan_change" />
          </el-select>
          <el-input
            v-model="filters.q"
            clearable
            placeholder="用户昵称 / 手机号 / 用户 ID"
            :prefix-icon="Search"
            @keyup.enter="applyFilters"
            @clear="applyFilters"
          />
          <el-button @click="applyFilters">查询</el-button>
        </div>
      </div>

      <el-table v-loading="loading" :data="runs" row-key="id" @row-click="openRun">
        <el-table-column label="用户" min-width="160">
          <template #default="{ row }">
            <div class="cell-main">{{ row.userLabel || '—' }}</div>
            <div class="cell-sub">{{ shortId(row.userId) }}</div>
          </template>
        </el-table-column>
        <el-table-column label="意图" width="120">
          <template #default="{ row }">{{ intentLabel(row.intent) }}</template>
        </el-table-column>
        <el-table-column label="状态" width="110">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column prop="stepCount" label="步骤" width="70" align="right" />
        <el-table-column label="模型" width="140" show-overflow-tooltip>
          <template #default="{ row }">{{ row.model || '—' }}</template>
        </el-table-column>
        <el-table-column label="草案" width="120">
          <template #default="{ row }">
            <StatusTag v-if="row.proposalStatus" :status="row.proposalStatus" />
            <span v-else class="faint">—</span>
          </template>
        </el-table-column>
        <el-table-column label="时间" width="154">
          <template #default="{ row }">{{ formatDateTime(row.createdAt) }}</template>
        </el-table-column>
        <el-table-column label="耗时" width="90" align="right">
          <template #default="{ row }">{{ row.completedAt ? '—' : '运行中' }}</template>
        </el-table-column>
        <template #empty><el-empty description="没有匹配的 Agent 运行记录" :image-size="80" /></template>
      </el-table>

      <PaginationBar
        :page="page"
        :size="size"
        :total="total"
        @update:page="onPage"
        @update:size="onSize"
      />
    </section>

    <el-drawer v-model="drawerOpen" size="min(760px, 94vw)" title="Agent 运行详情" destroy-on-close>
      <div v-if="detail" class="drawer-stack">
        <section class="detail-head">
          <div>
            <div class="cell-sub">运行 ID</div>
            <div class="mono">{{ detail.run.id }}</div>
          </div>
          <StatusTag :status="detail.run.status" />
        </section>

        <section class="panel inset-panel">
          <div class="detail-grid">
            <div><span>用户</span><strong>{{ detail.run.userLabel }}</strong></div>
            <div><span>意图</span><strong>{{ intentLabel(detail.run.intent) }}</strong></div>
            <div><span>模型</span><strong>{{ detail.run.model || '—' }}</strong></div>
            <div><span>步骤</span><strong>{{ detail.run.stepCount }}</strong></div>
            <div><span>创建</span><strong>{{ formatDateTime(detail.run.createdAt) }}</strong></div>
            <div><span>完成</span><strong>{{ formatDateTime(detail.run.completedAt) }}</strong></div>
          </div>
          <div class="quote-block">{{ detail.run.inputText }}</div>
          <div v-if="detail.run.outputText" class="quote-block output">{{ detail.run.outputText }}</div>
          <el-alert v-if="detail.run.error" :title="detail.run.error" type="error" :closable="false" show-icon />
        </section>

        <section v-if="detail.proposals.length" class="panel inset-panel">
          <div class="panel-heading compact">
            <h3>计划草案</h3>
          </div>
          <div v-for="item in detail.proposals" :key="item.id" class="proposal-block">
            <div class="proposal-title">
              <strong>{{ item.title }}</strong>
              <StatusTag :status="item.status" />
            </div>
            <JsonBlock :value="item.diff" />
            <details>
              <summary>校验结果</summary>
              <JsonBlock :value="item.validation" />
            </details>
          </div>
        </section>

        <section class="panel inset-panel">
          <div class="panel-heading compact">
            <h3>工具轨迹</h3>
            <p>每一步都会落库，模型不能直接写正式计划。</p>
          </div>
          <div v-if="detail.steps.length" class="step-list">
            <div v-for="step in detail.steps" :key="step.id" class="step-row">
              <div class="step-index">{{ step.stepIndex }}</div>
              <div class="step-body">
                <div class="step-head">
                  <strong>{{ step.stepType === 'tool' ? `工具 · ${step.toolName || '未知'}` : '模型决策' }}</strong>
                  <StatusTag :status="step.status" />
                  <span class="faint">{{ step.latencyMs ? `${step.latencyMs} ms` : '' }}</span>
                </div>
                <details>
                  <summary>输入</summary>
                  <JsonBlock :value="step.input" />
                </details>
                <details>
                  <summary>输出</summary>
                  <JsonBlock :value="step.output" />
                </details>
                <el-alert v-if="step.error" :title="step.error" type="error" :closable="false" show-icon />
              </div>
            </div>
          </div>
          <el-empty v-else description="这次运行没有工具步骤" :image-size="64" />
        </section>
      </div>
      <div v-else v-loading="detailLoading" class="drawer-loading" />
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
import type { AgentRunDetail, AgentRunItem } from '@/api/types'
import { formatDateTime, shortId } from '@/utils/format'

const loading = ref(false)
const detailLoading = ref(false)
const runs = ref<AgentRunItem[]>([])
const total = ref(0)
const page = ref(1)
const size = ref(20)
const filters = reactive({ status: '', intent: '', q: '' })
const drawerOpen = ref(false)
const detail = ref<AgentRunDetail | null>(null)

async function load(): Promise<void> {
  loading.value = true
  try {
    const response = await agentApi.runs({
      status: filters.status || undefined,
      intent: filters.intent || undefined,
      q: filters.q.trim() || undefined,
      page: page.value,
      size: size.value,
    })
    runs.value = response.items
    total.value = response.total
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    loading.value = false
  }
}

async function openRun(row: AgentRunItem): Promise<void> {
  drawerOpen.value = true
  detailLoading.value = true
  detail.value = null
  try {
    detail.value = await agentApi.detail(row.id)
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    detailLoading.value = false
  }
}

function applyFilters(): void {
  page.value = 1
  void load()
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

function intentLabel(value: string): string {
  if (value === 'plan_change') return '计划调整'
  if (value === 'coach_chat') return '教练对话'
  return value
}

onMounted(load)
</script>

<style scoped>
.panel {
  padding: 0;
  overflow: hidden;
}

.panel-heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  padding: 18px;
}

.panel-heading.compact {
  padding-bottom: 10px;
}

.panel-heading h3 {
  margin: 0;
}

.panel-heading p {
  margin: 5px 0 0;
  color: var(--fitai-text-muted);
  font-size: 12px;
}

.filter-inline {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.filter-inline .el-select {
  width: 128px;
}

.filter-inline .el-input {
  width: 220px;
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

.faint {
  color: var(--fitai-text-faint);
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

.mono {
  margin-top: 4px;
  color: var(--fitai-text-muted);
  font-family: 'JetBrains Mono', monospace;
  font-size: 10px;
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

.quote-block.output {
  color: var(--fitai-text);
  background: rgba(91, 140, 255, 0.05);
}

.proposal-block + .proposal-block {
  margin-top: 12px;
}

.proposal-block {
  padding-top: 10px;
}

.proposal-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 8px;
}

.proposal-title strong {
  color: var(--fitai-text);
  font-size: 13px;
}

details {
  margin-top: 8px;
}

summary {
  cursor: pointer;
  color: var(--fitai-text-muted);
  font-size: 11px;
}

.step-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.step-row {
  display: flex;
  gap: 10px;
  padding: 10px;
  border: 1px solid var(--fitai-border);
  border-radius: 10px;
}

.step-index {
  display: grid;
  width: 22px;
  height: 22px;
  flex: 0 0 22px;
  place-items: center;
  border-radius: 50%;
  background: rgba(91, 140, 255, 0.14);
  color: #8cb0ff;
  font-family: 'JetBrains Mono', monospace;
  font-size: 10px;
}

.step-body {
  min-width: 0;
  flex: 1;
}

.step-head {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--fitai-text);
  font-size: 12px;
}

.step-head .faint {
  margin-left: auto;
  font-size: 10px;
}

.drawer-loading {
  min-height: 180px;
}

@media (max-width: 900px) {
  .panel-heading {
    align-items: flex-start;
    flex-direction: column;
  }

  .filter-inline {
    width: 100%;
  }

  .filter-inline .el-select,
  .filter-inline .el-input {
    flex: 1 1 140px;
    width: auto;
  }

  .detail-grid {
    grid-template-columns: 1fr;
  }
}
</style>
