<template>
  <div class="page-shell">
    <PageHeader
      title="动作媒体"
      subtitle="iPhone 训练页与 Apple Watch 共用的循环动画、封面与授权；发布后按动作 + 性别生效"
    >
      <template #actions>
        <el-button :icon="Refresh" :loading="loading" @click="refresh">刷新</el-button>
        <el-button @click="goLegacy">旧版讲解视频</el-button>
        <el-button v-if="canWrite" :icon="Upload" @click="openImport">批量导入</el-button>
        <el-button v-if="canWrite" type="primary" :icon="Plus" @click="openCreate">新建媒体</el-button>
      </template>
    </PageHeader>

    <section v-loading="coverageLoading" class="metric-grid three media-metrics">
      <MetricCard
        label="启用动作"
        :value="formatNumber(coverage?.activeExercises)"
        foot="动作库 is_active = 1"
        glow="rgba(91, 140, 255, 0.26)"
      />
      <MetricCard
        label="已覆盖"
        :value="formatNumber(coverage?.exercisesWithAnyMedia)"
        :foot="`覆盖率 ${percent(coverage?.exercisesWithAnyMedia ?? 0, coverage?.activeExercises ?? 0)}`"
        glow="rgba(61, 220, 151, 0.22)"
      />
      <MetricCard
        label="男版覆盖"
        :value="formatNumber(coverage?.exercisesWithMale)"
        :foot="`缺口 ${formatNumber(coverage?.missingMaleCount)}`"
        glow="rgba(91, 140, 255, 0.2)"
      />
      <MetricCard
        label="女版覆盖"
        :value="formatNumber(coverage?.exercisesWithFemale)"
        :foot="`缺口 ${formatNumber(coverage?.missingFemaleCount)}`"
        glow="rgba(248, 196, 92, 0.2)"
      />
      <MetricCard
        label="Watch 就绪"
        :value="formatNumber(coverage?.watchReady)"
        :foot="`海报 ${formatNumber(coverage?.posterReady)} · iPhone ${formatNumber(coverage?.phoneReady)}`"
        glow="rgba(61, 220, 151, 0.18)"
      />
      <MetricCard
        label="30 天内授权到期"
        :value="formatNumber(coverage?.licenseExpiring30d)"
        foot="已发布媒体"
        glow="rgba(255, 107, 129, 0.2)"
      />
    </section>

    <section class="panel table-panel coverage-panel">
      <div class="panel-heading">
        <div>
          <h3>覆盖缺口</h3>
          <p>按启用动作统计；中性素材同时计入男版和女版。点击动作行可快速筛选下方媒体列表。</p>
        </div>
        <span v-if="coverage" class="faint">
          已覆盖 {{ coverage.exercisesWithAnyMedia }} / {{ coverage.activeExercises }}
        </span>
      </div>

      <div class="coverage-switch">
        <button
          v-for="tab in gapTabs"
          :key="tab.key"
          type="button"
          class="coverage-stat"
          :class="{ active: coverageTab === tab.key }"
          @click="coverageTab = tab.key"
        >
          <span>{{ tab.label }}</span>
          <strong>{{ tab.count }}</strong>
          <small>{{ tab.hint }}</small>
        </button>
      </div>

      <div class="coverage-toolbar">
        <el-input
          v-model="gapQuery"
          clearable
          placeholder="搜索动作名称、slug 或部位"
          :prefix-icon="Search"
        />
        <span class="faint">{{ filteredGapRows.length }} / {{ gapRows.length }} 条</span>
        <el-button text :icon="DocumentCopy" @click="copyGapList">复制清单</el-button>
      </div>

      <el-table
        :data="filteredGapRows"
        size="small"
        max-height="300"
        @row-click="(row: MediaCoverageMissing) => filterBySlug(row.slug)"
      >
        <el-table-column label="动作" min-width="190">
          <template #default="{ row }">
            <div class="cell-stack">
              <strong>{{ row.nameZh }}</strong>
              <span class="mono faint">{{ row.slug }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="部位" width="100">
          <template #default="{ row }">
            <el-tag effect="plain" size="small">{{ muscleLabel(row.muscleGroup) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="" width="86" align="right">
          <template #default>
            <el-button link type="primary">筛选</el-button>
          </template>
        </el-table-column>
        <template #empty>
          <el-empty :description="gapEmptyText" :image-size="60" />
        </template>
      </el-table>
      <p v-if="gapRows.length >= 100" class="faint coverage-note">
        仅显示前 100 个动作，完整数量见上方统计。
      </p>
    </section>

    <section class="panel table-panel media-table-panel">
      <div class="filter-bar">
        <el-input
          v-model="filters.q"
          class="filter-grow"
          clearable
          placeholder="搜索动作名称、英文名或 slug"
          :prefix-icon="Search"
          @keyup.enter="applyFilters"
          @clear="applyFilters"
        />
        <el-select v-model="filters.sex" clearable placeholder="性别版本" @change="applyFilters">
          <el-option label="男版" value="male" />
          <el-option label="女版" value="female" />
          <el-option label="中性" value="unisex" />
        </el-select>
        <el-select v-model="filters.status" clearable placeholder="发布状态" @change="applyFilters">
          <el-option label="草稿" value="draft" />
          <el-option label="已发布" value="published" />
          <el-option label="已归档" value="archived" />
        </el-select>
        <el-select v-model="filters.coverage" clearable placeholder="覆盖筛选" @change="applyFilters">
          <el-option label="缺 iPhone 视频" value="missing_phone" />
          <el-option label="缺 Watch 视频" value="missing_watch" />
          <el-option label="缺海报" value="missing_poster" />
          <el-option label="30 天内到期" value="expiring" />
        </el-select>
        <el-button type="primary" @click="applyFilters">查询</el-button>
        <el-button text @click="resetFilters">重置</el-button>
      </div>

      <el-table v-loading="loading" :data="rows" row-key="id" class="media-table" @row-dblclick="openEdit">
        <el-table-column label="封面" width="64">
          <template #default="{ row }">
            <el-image v-if="row.posterUrl" :src="row.posterUrl" fit="cover" class="poster" />
            <div v-else class="poster poster-placeholder">无</div>
          </template>
        </el-table-column>
        <el-table-column label="动作" min-width="190">
          <template #default="{ row }">
            <div class="cell-stack">
              <strong>{{ row.exerciseName }}</strong>
              <span class="mono">{{ row.exerciseSlug }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="版本" width="80">
          <template #default="{ row }">
            <el-tag :type="sexTagType(row.sex)" effect="plain" size="small">{{ sexLabel(row.sex) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="媒体" width="170">
          <template #default="{ row }">
            <div class="mini-tags">
              <el-tag :type="row.phoneUrl ? 'success' : 'info'" effect="plain" size="small">iPhone</el-tag>
              <el-tag :type="row.watchUrl ? 'success' : 'info'" effect="plain" size="small">Watch</el-tag>
              <el-tag :type="row.posterUrl ? 'success' : 'warning'" effect="plain" size="small">海报</el-tag>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="时长 / 循环" width="112">
          <template #default="{ row }">
            <div class="cell-stack">
              <span>{{ durationLabel(row.durationSeconds) }}</span>
              <span class="faint">{{ loopLabel(row) }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="授权" min-width="150">
          <template #default="{ row }">
            <div class="cell-stack">
              <span class="truncate">{{ row.licenseNote || '未填写' }}</span>
              <span :class="expiringSoon(row.licenseExpiresAt) ? 'text-warning' : 'faint'">
                {{ row.licenseExpiresAt ? `到期 ${formatDate(row.licenseExpiresAt)}` : '无到期日' }}
              </span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="82">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column label="操作" width="92">
          <template #default="{ row }">
            <el-dropdown trigger="click" @command="handleRowAction($event, row)">
              <el-button link type="primary">
                操作<el-icon class="el-icon--right"><ArrowDown /></el-icon>
              </el-button>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item command="preview">预览</el-dropdown-item>
                  <el-dropdown-item command="edit">{{ canWrite ? '编辑' : '查看' }}</el-dropdown-item>
                  <el-dropdown-item v-if="canWrite && row.status !== 'published'" command="publish">
                    发布
                  </el-dropdown-item>
                  <el-dropdown-item v-if="canWrite && row.status === 'published'" command="unpublish">
                    下架
                  </el-dropdown-item>
                  <el-dropdown-item v-if="canWrite" command="delete" divided>删除</el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </template>
        </el-table-column>
        <template #empty><el-empty description="没有匹配的动作媒体" :image-size="80" /></template>
      </el-table>

      <div class="media-mobile-list">
        <article v-for="row in rows" :key="row.id" class="media-mobile-card">
          <div class="media-mobile-head">
            <el-image v-if="row.posterUrl" :src="row.posterUrl" fit="cover" class="poster" />
            <div v-else class="poster poster-placeholder">无</div>
            <div class="cell-stack">
              <strong>{{ row.exerciseName }}</strong>
              <span class="mono">{{ row.exerciseSlug }}</span>
            </div>
            <StatusTag :status="row.status" />
          </div>
          <div class="mini-tags">
            <el-tag :type="sexTagType(row.sex)" effect="plain" size="small">{{ sexLabel(row.sex) }}</el-tag>
            <el-tag :type="row.phoneUrl ? 'success' : 'info'" effect="plain" size="small">iPhone</el-tag>
            <el-tag :type="row.watchUrl ? 'success' : 'info'" effect="plain" size="small">Watch</el-tag>
            <el-tag :type="row.posterUrl ? 'success' : 'warning'" effect="plain" size="small">海报</el-tag>
          </div>
          <div class="media-mobile-meta">
            {{ durationLabel(row.durationSeconds) }} · {{ loopLabel(row) }}
            <span class="faint"> · {{ row.licenseExpiresAt ? `授权至 ${formatDate(row.licenseExpiresAt)}` : '无授权到期日' }}</span>
          </div>
          <div class="media-mobile-actions">
            <el-button link type="primary" @click="openPreview(row)">预览</el-button>
            <el-button link type="primary" @click="openEdit(row)">{{ canWrite ? '编辑' : '查看' }}</el-button>
            <el-button
              v-if="canWrite && row.status !== 'published'"
              link
              type="success"
              @click="publish(row)"
            >发布</el-button>
            <el-button
              v-if="canWrite && row.status === 'published'"
              link
              type="warning"
              @click="unpublish(row)"
            >下架</el-button>
            <el-button v-if="canWrite" link type="danger" @click="remove(row)">删除</el-button>
          </div>
        </article>
        <el-empty v-if="!rows.length" description="没有匹配的动作媒体" :image-size="70" />
      </div>

      <PaginationBar
        :page="page"
        :size="size"
        :total="total"
        @update:page="onPageChange"
        @update:size="onSizeChange"
      />
    </section>

    <el-dialog
      v-model="dialogVisible"
      :title="editingId ? '编辑动作媒体' : '新建动作媒体'"
      width="min(820px, calc(100vw - 28px))"
      destroy-on-close
    >
      <el-form ref="formRef" :model="form" :rules="rules" label-position="top">
        <div class="form-grid">
          <el-form-item label="关联动作" prop="exerciseSlug">
            <el-select
              v-model="form.exerciseSlug"
              filterable
              remote
              :remote-method="searchExercises"
              :loading="exerciseLoading"
              :disabled="Boolean(editingId)"
              placeholder="输入动作名称或 slug 搜索"
              style="width: 100%"
            >
              <el-option
                v-for="item in exerciseOptions"
                :key="item.slug"
                :label="`${item.nameZh} · ${item.slug}`"
                :value="item.slug"
              />
            </el-select>
          </el-form-item>
          <el-form-item label="性别版本" prop="sex">
            <el-select v-model="form.sex" :disabled="Boolean(editingId)" style="width: 100%">
              <el-option label="男版" value="male" />
              <el-option label="女版" value="female" />
              <el-option label="中性" value="unisex" />
            </el-select>
          </el-form-item>
          <el-form-item label="素材来源" prop="source">
            <el-input v-model="form.source" maxlength="40" placeholder="如 purchased / sample / internal" />
          </el-form-item>
          <el-form-item label="采购引用">
            <el-input v-model="form.purchaseRef" maxlength="120" placeholder="订单号 / 供应商批次" />
          </el-form-item>
        </div>

        <el-form-item label="iPhone 循环视频" prop="phoneUrl">
          <div class="upload-row">
            <el-input v-model="form.phoneUrl" placeholder="/media/videos/... 或 https://..." />
            <el-upload
              v-if="canWrite && uploadEnabled"
              :show-file-list="false"
              accept="video/mp4,video/quicktime,video/webm"
              :http-request="uploadPhone"
            >
              <el-button :loading="uploadingPhone" :icon="Upload">上传</el-button>
            </el-upload>
          </div>
        </el-form-item>

        <el-form-item label="Watch 循环视频" prop="watchUrl">
          <div class="upload-row">
            <el-input v-model="form.watchUrl" placeholder="/media/videos/... 或 https://..." />
            <el-upload
              v-if="canWrite && uploadEnabled"
              :show-file-list="false"
              accept="video/mp4,video/quicktime,video/webm"
              :http-request="uploadWatch"
            >
              <el-button :loading="uploadingWatch" :icon="Upload">上传</el-button>
            </el-upload>
          </div>
        </el-form-item>

        <el-form-item label="封面 / 海报">
          <div class="upload-row">
            <el-input v-model="form.posterUrl" placeholder="/media/posters/... 或 https://..." />
            <el-upload
              v-if="canWrite && uploadEnabled"
              :show-file-list="false"
              accept="image/jpeg,image/png,image/webp"
              :http-request="uploadPoster"
            >
              <el-button :loading="uploadingPoster" :icon="Picture">上传</el-button>
            </el-upload>
          </div>
        </el-form-item>

        <div class="form-grid">
          <el-form-item label="时长（秒）">
            <el-input-number v-model="form.durationSeconds" :min="0" :max="86400" style="width: 100%" />
          </el-form-item>
          <el-form-item label="Watch SHA-256">
            <el-input v-model="form.watchSha256" maxlength="64" placeholder="64 位十六进制，可留空" />
          </el-form-item>
          <el-form-item label="循环起点（毫秒）">
            <el-input-number v-model="form.loopStartMs" :min="0" style="width: 100%" />
          </el-form-item>
          <el-form-item label="循环终点（毫秒）">
            <el-input-number v-model="form.loopEndMs" :min="0" style="width: 100%" />
          </el-form-item>
          <el-form-item label="许可说明">
            <el-input v-model="form.licenseNote" maxlength="200" />
          </el-form-item>
          <el-form-item label="授权到期日">
            <el-date-picker
              v-model="form.licenseExpiresAt"
              type="date"
              value-format="YYYY-MM-DD"
              placeholder="选择日期"
              style="width: 100%"
            />
          </el-form-item>
        </div>

        <el-form-item v-if="!editingId" label="创建后状态">
          <el-radio-group v-model="form.status">
            <el-radio-button value="draft">保存草稿</el-radio-button>
            <el-radio-button value="published">立即发布</el-radio-button>
          </el-radio-group>
        </el-form-item>

        <el-alert
          type="info"
          :closable="false"
          show-icon
          title="同一动作 + 性别的已发布版本会自动归档；Watch 缺失时 App 会回退到静态海报，不显示假动画。"
        />
        <el-alert
          v-if="!uploadEnabled"
          type="warning"
          :closable="false"
          show-icon
          style="margin-top: 10px"
          title="当前后台未启用媒体上传：请填写生产可访问的 URL，或在生产机运行 admin-server。"
        />
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button v-if="canWrite" type="primary" :loading="saving" @click="save">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="importVisible" title="批量导入动作媒体" width="min(680px, calc(100vw - 28px))" destroy-on-close>
      <el-alert
        type="info"
        :closable="false"
        show-icon
        title="CSV 表头：exercise_slug, sex, source, phone_url, watch_url, poster_url, duration_seconds, loop_start_ms, loop_end_ms, watch_sha256, license_note, license_expires_at, purchase_ref, status"
      />
      <el-alert
        v-if="!uploadEnabled"
        type="warning"
        :closable="false"
        show-icon
        style="margin-top: 8px"
        title="当前后台不接收文件上传；CSV 里的 phone_url / watch_url / poster_url 必须是生产可访问的 URL。"
      />
      <div class="import-row">
        <el-upload
          :auto-upload="false"
          :show-file-list="false"
          accept=".csv,text/csv"
          :on-change="onImportChange"
        >
          <el-button :icon="Document">选择 CSV</el-button>
        </el-upload>
        <span class="muted">{{ importFile ? importFile.name : '未选择文件' }}</span>
        <el-button text @click="downloadTemplate">下载模板</el-button>
      </div>
      <el-alert
        v-if="importResult"
        :type="importResult.failed ? 'warning' : 'success'"
        :closable="false"
        show-icon
        :title="`共 ${importResult.total} 行，成功 ${importResult.created} 行，失败 ${importResult.failed} 行`"
      />
      <el-table v-if="importResult?.errors?.length" :data="importResult.errors" size="small" max-height="240">
        <el-table-column prop="line" label="行号" width="80" />
        <el-table-column prop="message" label="错误" min-width="240" show-overflow-tooltip />
      </el-table>
      <template #footer>
        <el-button @click="importVisible = false">关闭</el-button>
        <el-button type="primary" :loading="importing" :disabled="!importFile" @click="submitImport">
          开始导入
        </el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="previewVisible" title="媒体预览" width="min(760px, calc(100vw - 28px))" destroy-on-close>
      <div v-if="preview" class="preview-grid">
        <div>
          <h4>iPhone</h4>
          <video v-if="preview.phoneUrl" :src="preview.phoneUrl" class="preview-video" controls loop muted />
          <span v-else class="muted">未配置</span>
        </div>
        <div>
          <h4>Watch</h4>
          <video v-if="preview.watchUrl" :src="preview.watchUrl" class="preview-video" controls loop muted />
          <span v-else class="muted">未配置</span>
        </div>
        <div>
          <h4>海报</h4>
          <el-image v-if="preview.posterUrl" :src="preview.posterUrl" fit="contain" class="preview-poster" />
          <span v-else class="muted">未配置，App 将显示文字兜底</span>
        </div>
      </div>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules, type UploadFile, type UploadRequestOptions } from 'element-plus'
import { ArrowDown, Document, DocumentCopy, Picture, Plus, Refresh, Search, Upload } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import PaginationBar from '@/components/PaginationBar.vue'
import StatusTag from '@/components/StatusTag.vue'
import MetricCard from '@/components/MetricCard.vue'
import { mediaAssetsApi } from '@/api/mediaAssets'
import { exercisesApi } from '@/api/exercises'
import { errorMessage } from '@/api/client'
import { useAuthStore } from '@/stores/auth'
import type {
  CreateMediaAssetPayload,
  ExerciseItem,
  MediaAssetItem,
  MediaCoverage,
  MediaCoverageMissing,
  MediaImportResult,
  UpdateMediaAssetPayload,
} from '@/api/types'
import { formatDate, formatNumber, percent } from '@/utils/format'

const auth = useAuthStore()
const router = useRouter()
const canWrite = auth.hasPermission('video:write')

const rows = ref<MediaAssetItem[]>([])
const total = ref(0)
const page = ref(1)
const size = ref(20)
const loading = ref(false)
const coverage = ref<MediaCoverage | null>(null)
const coverageLoading = ref(false)
const uploadEnabled = ref(true)
const coverageTab = ref<'female' | 'male' | 'any'>('female')
const gapQuery = ref('')
const filters = reactive({ q: '', sex: '', status: '', coverage: '' })

const gapTabs = computed(() => [
  {
    key: 'female' as const,
    label: '女版缺口',
    count: coverage.value?.missingFemaleCount ?? 0,
    hint: '缺 female / unisex',
  },
  {
    key: 'male' as const,
    label: '男版缺口',
    count: coverage.value?.missingMaleCount ?? 0,
    hint: '缺 male / unisex',
  },
  {
    key: 'any' as const,
    label: '完全缺失',
    count: coverage.value?.missingAnyCount ?? 0,
    hint: '没有任何已发布媒体',
  },
])

const gapRows = computed<MediaCoverageMissing[]>(() => {
  if (coverageTab.value === 'male') return coverage.value?.missingMale ?? []
  if (coverageTab.value === 'any') return coverage.value?.missingAny ?? []
  return coverage.value?.missingFemale ?? []
})

const filteredGapRows = computed(() => {
  const query = gapQuery.value.trim().toLowerCase()
  if (!query) return gapRows.value
  return gapRows.value.filter((item) =>
    item.nameZh.toLowerCase().includes(query)
    || item.slug.toLowerCase().includes(query)
    || item.muscleGroup.toLowerCase().includes(query),
  )
})

const gapEmptyText = computed(() => {
  if (coverageTab.value === 'female') return '女版覆盖完整'
  if (coverageTab.value === 'male') return '男版覆盖完整'
  return '所有启用动作都有媒体'
})

const dialogVisible = ref(false)
const editingId = ref<string | null>(null)
const saving = ref(false)
const uploadingPhone = ref(false)
const uploadingWatch = ref(false)
const uploadingPoster = ref(false)
const formRef = ref<FormInstance>()
const exerciseOptions = ref<ExerciseItem[]>([])
const exerciseLoading = ref(false)

const previewVisible = ref(false)
const preview = ref<MediaAssetItem | null>(null)

const importVisible = ref(false)
const importing = ref(false)
const importFile = ref<File | null>(null)
const importResult = ref<MediaImportResult | null>(null)

const form = reactive({
  exerciseSlug: '',
  sex: 'male' as 'male' | 'female' | 'unisex',
  source: 'purchased',
  phoneUrl: '',
  watchUrl: '',
  posterUrl: '',
  durationSeconds: 0,
  loopStartMs: 0,
  loopEndMs: 0,
  watchSha256: '',
  licenseNote: '',
  licenseExpiresAt: '',
  purchaseRef: '',
  status: 'draft' as 'draft' | 'published',
})

const rules: FormRules = {
  exerciseSlug: [{ required: true, message: '请选择关联动作', trigger: 'change' }],
  sex: [{ required: true, message: '请选择性别版本', trigger: 'change' }],
  source: [{ required: true, message: '请填写素材来源', trigger: 'blur' }],
  phoneUrl: [{ required: true, message: '请上传或填写 iPhone 视频', trigger: 'blur' }],
  watchUrl: [{ required: true, message: '请上传或填写 Watch 视频', trigger: 'blur' }],
}

async function load(): Promise<void> {
  loading.value = true
  try {
    const result = await mediaAssetsApi.list({
      q: filters.q.trim() || undefined,
      sex: filters.sex || undefined,
      status: filters.status || undefined,
      coverage: filters.coverage || undefined,
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

async function loadCoverage(): Promise<void> {
  coverageLoading.value = true
  try {
    coverage.value = await mediaAssetsApi.coverage()
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    coverageLoading.value = false
  }
}

async function loadConfig(): Promise<void> {
  try {
    const config = await mediaAssetsApi.config()
    uploadEnabled.value = config.uploadEnabled
  } catch {
    uploadEnabled.value = true
  }
}

function refresh(): void {
  void load()
  void loadCoverage()
  void loadConfig()
}

async function loadExercises(query = ''): Promise<void> {
  exerciseLoading.value = true
  try {
    const result = await exercisesApi.list({ q: query.trim() || undefined, page: 1, size: 100 })
    exerciseOptions.value = result.items
  } catch {
    exerciseOptions.value = []
  } finally {
    exerciseLoading.value = false
  }
}

function searchExercises(query: string): void {
  void loadExercises(query)
}

function applyFilters(): void {
  page.value = 1
  void load()
}

function resetFilters(): void {
  filters.q = ''
  filters.sex = ''
  filters.status = ''
  filters.coverage = ''
  applyFilters()
}

async function filterBySlug(slug: string): Promise<void> {
  filters.q = slug
  filters.coverage = ''
  page.value = 1
  await load()
  document.querySelector('.media-table-panel')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

function muscleLabel(value: string): string {
  const labels: Record<string, string> = {
    chest: '胸',
    back: '背',
    legs: '腿',
    shoulders: '肩',
    arms: '手臂',
    core: '核心',
    glutes: '臀',
    cardio: '有氧',
  }
  return labels[value] ?? value
}

async function copyGapList(): Promise<void> {
  if (!filteredGapRows.value.length) {
    ElMessage.warning('当前没有可复制的缺口')
    return
  }
  const text = filteredGapRows.value
    .map((item) => `${item.nameZh}\t${item.slug}\t${muscleLabel(item.muscleGroup)}`)
    .join('\n')
  try {
    await navigator.clipboard.writeText(text)
    ElMessage.success(`已复制 ${filteredGapRows.value.length} 条缺口`)
  } catch {
    ElMessage.error('复制失败，请检查浏览器剪贴板权限')
  }
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

function resetForm(): void {
  editingId.value = null
  form.exerciseSlug = ''
  form.sex = 'male'
  form.source = 'purchased'
  form.phoneUrl = ''
  form.watchUrl = ''
  form.posterUrl = ''
  form.durationSeconds = 0
  form.loopStartMs = 0
  form.loopEndMs = 0
  form.watchSha256 = ''
  form.licenseNote = ''
  form.licenseExpiresAt = ''
  form.purchaseRef = ''
  form.status = 'draft'
}

function openCreate(): void {
  resetForm()
  void loadExercises()
  dialogVisible.value = true
}

function openEdit(row: MediaAssetItem): void {
  editingId.value = row.id
  form.exerciseSlug = row.exerciseSlug
  form.sex = row.sex as 'male' | 'female' | 'unisex'
  form.source = row.source
  form.phoneUrl = row.phoneUrl
  form.watchUrl = row.watchUrl
  form.posterUrl = row.posterUrl ?? ''
  form.durationSeconds = row.durationSeconds ?? 0
  form.loopStartMs = row.loopStartMs ?? 0
  form.loopEndMs = row.loopEndMs ?? 0
  form.watchSha256 = row.watchSha256 ?? ''
  form.licenseNote = row.licenseNote ?? ''
  form.licenseExpiresAt = row.licenseExpiresAt ?? ''
  form.purchaseRef = row.purchaseRef ?? ''
  if (!exerciseOptions.value.some((item) => item.slug === row.exerciseSlug)) {
    void loadExercises(row.exerciseSlug)
  }
  dialogVisible.value = true
}

function openPreview(row: MediaAssetItem): void {
  preview.value = row
  previewVisible.value = true
}

function handleRowAction(command: string, row: MediaAssetItem): void {
  if (command === 'preview') {
    openPreview(row)
  } else if (command === 'edit') {
    openEdit(row)
  } else if (command === 'publish') {
    void publish(row)
  } else if (command === 'unpublish') {
    void unpublish(row)
  } else if (command === 'delete') {
    void remove(row)
  }
}

function openImport(): void {
  importFile.value = null
  importResult.value = null
  importVisible.value = true
}

function onImportChange(file: UploadFile): void {
  importFile.value = file.raw ?? null
  importResult.value = null
}

async function submitImport(): Promise<void> {
  if (!importFile.value) return
  importing.value = true
  try {
    importResult.value = await mediaAssetsApi.importCsv(importFile.value)
    ElMessage.success(`导入完成：成功 ${importResult.value.created} 行`)
    if (importResult.value.created > 0) refresh()
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    importing.value = false
  }
}

function downloadTemplate(): void {
  const csv = [
    'exercise_slug,sex,source,phone_url,watch_url,poster_url,duration_seconds,loop_start_ms,loop_end_ms,watch_sha256,license_note,license_expires_at,purchase_ref,status',
    'cm_squat,male,purchased,/media/videos/cm_squat_male.mp4,/media/videos/cm_squat_male_watch.mp4,/media/posters/cm_squat_male.jpg,6,0,6000,,示例授权,2027-12-31,PO-001,draft',
  ].join('\n')
  const blob = new Blob([`\uFEFF${csv}`], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const anchor = document.createElement('a')
  anchor.href = url
  anchor.download = 'fitai-media-template.csv'
  anchor.click()
  URL.revokeObjectURL(url)
}

async function uploadMedia(options: UploadRequestOptions, target: 'phone' | 'watch'): Promise<void> {
  const flag = target === 'phone' ? uploadingPhone : uploadingWatch
  flag.value = true
  try {
    const result = await mediaAssetsApi.upload(options.file, 'video')
    if (target === 'phone') {
      form.phoneUrl = result.url
    } else {
      form.watchUrl = result.url
    }
    ElMessage.success('视频上传完成')
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    flag.value = false
  }
}

function uploadPhone(options: UploadRequestOptions): Promise<void> {
  return uploadMedia(options, 'phone')
}

function uploadWatch(options: UploadRequestOptions): Promise<void> {
  return uploadMedia(options, 'watch')
}

async function uploadPoster(options: UploadRequestOptions): Promise<void> {
  uploadingPoster.value = true
  try {
    const result = await mediaAssetsApi.upload(options.file, 'poster')
    form.posterUrl = result.url
    ElMessage.success('封面已上传')
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    uploadingPoster.value = false
  }
}

async function save(): Promise<void> {
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return
  saving.value = true
  try {
    if (editingId.value) {
      const payload: UpdateMediaAssetPayload = {
        source: form.source.trim(),
        phoneUrl: form.phoneUrl.trim(),
        watchUrl: form.watchUrl.trim(),
        posterUrl: form.posterUrl.trim(),
        durationSeconds: form.durationSeconds,
        loopStartMs: form.loopStartMs,
        loopEndMs: form.loopEndMs,
        watchSha256: form.watchSha256.trim() || null,
        licenseNote: form.licenseNote.trim(),
        licenseExpiresAt: form.licenseExpiresAt || null,
        purchaseRef: form.purchaseRef.trim(),
      }
      await mediaAssetsApi.update(editingId.value, payload)
      ElMessage.success('动作媒体已更新')
    } else {
      const payload: CreateMediaAssetPayload = {
        exerciseSlug: form.exerciseSlug,
        sex: form.sex,
        source: form.source.trim(),
        phoneUrl: form.phoneUrl.trim(),
        watchUrl: form.watchUrl.trim(),
        posterUrl: form.posterUrl.trim() || null,
        durationSeconds: form.durationSeconds,
        loopStartMs: form.loopStartMs,
        loopEndMs: form.loopEndMs,
        watchSha256: form.watchSha256.trim() || null,
        licenseNote: form.licenseNote.trim() || null,
        licenseExpiresAt: form.licenseExpiresAt || null,
        purchaseRef: form.purchaseRef.trim() || null,
        status: form.status,
      }
      await mediaAssetsApi.create(payload)
      ElMessage.success(form.status === 'published' ? '媒体已创建并发布' : '媒体草稿已创建')
    }
    dialogVisible.value = false
    refresh()
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    saving.value = false
  }
}

async function publish(row: MediaAssetItem): Promise<void> {
  try {
    await ElMessageBox.confirm('发布后，同动作同性别的已发布版本会自动归档。确定发布吗？', '发布媒体', {
      confirmButtonText: '发布',
      cancelButtonText: '取消',
      type: 'warning',
    })
    await mediaAssetsApi.publish(row.id)
    ElMessage.success('媒体已发布')
    refresh()
  } catch (reason) {
    if (reason !== 'cancel' && reason !== 'close') ElMessage.error(errorMessage(reason))
  }
}

async function unpublish(row: MediaAssetItem): Promise<void> {
  try {
    await ElMessageBox.confirm('下架后 App 将不再显示该媒体，可能回退到海报或文字。确定下架吗？', '下架媒体', {
      confirmButtonText: '下架',
      cancelButtonText: '取消',
      type: 'warning',
    })
    await mediaAssetsApi.unpublish(row.id)
    ElMessage.success('媒体已下架')
    refresh()
  } catch (reason) {
    if (reason !== 'cancel' && reason !== 'close') ElMessage.error(errorMessage(reason))
  }
}

async function remove(row: MediaAssetItem): Promise<void> {
  try {
    await ElMessageBox.confirm('删除媒体会同时删除未被其他记录引用的本地文件，且不可恢复。确定删除吗？', '删除媒体', {
      confirmButtonText: '删除',
      cancelButtonText: '取消',
      type: 'warning',
    })
    await mediaAssetsApi.remove(row.id)
    ElMessage.success('媒体已删除')
    refresh()
  } catch (reason) {
    if (reason !== 'cancel' && reason !== 'close') ElMessage.error(errorMessage(reason))
  }
}

function goLegacy(): void {
  void router.push('/videos')
}

function sexLabel(sex: string): string {
  if (sex === 'male') return '男版'
  if (sex === 'female') return '女版'
  if (sex === 'unisex') return '中性'
  return sex
}

function sexTagType(sex: string): 'primary' | 'success' | 'warning' | 'info' {
  if (sex === 'male') return 'primary'
  if (sex === 'female') return 'warning'
  return 'info'
}

function durationLabel(seconds: number | null): string {
  if (seconds === null || seconds === undefined) return '未填写'
  const minutes = Math.floor(seconds / 60)
  const rest = seconds % 60
  return `${minutes}:${String(rest).padStart(2, '0')}`
}

function loopLabel(row: MediaAssetItem): string {
  const start = row.loopStartMs ?? 0
  const end = row.loopEndMs
  return end === null || end === undefined ? `${start} ms 起` : `${start}–${end} ms`
}

function expiringSoon(value: string | null): boolean {
  if (!value) return false
  const target = new Date(`${value}T00:00:00Z`).getTime()
  if (Number.isNaN(target)) return false
  const days = (target - Date.now()) / 86_400_000
  return days <= 30
}

onMounted(() => {
  refresh()
})
</script>

<style scoped>
.metric-grid {
  margin-bottom: 16px;
}

.coverage-panel {
  margin-bottom: 16px;
}

.coverage-switch {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
  padding: 14px 16px 0;
}

.coverage-stat {
  display: flex;
  min-height: 86px;
  flex-direction: column;
  align-items: flex-start;
  gap: 2px;
  padding: 12px 14px;
  border: 1px solid var(--fitai-border);
  border-radius: 10px;
  background: rgba(148, 163, 184, 0.03);
  color: var(--fitai-text);
  cursor: pointer;
  text-align: left;
  transition: border-color 0.18s ease, background 0.18s ease;
}

.coverage-stat:hover {
  border-color: var(--fitai-border-strong);
  background: rgba(91, 140, 255, 0.05);
}

.coverage-stat.active {
  border-color: rgba(91, 140, 255, 0.55);
  background: rgba(91, 140, 255, 0.09);
}

.coverage-stat span {
  color: var(--fitai-text-muted);
  font-size: 12px;
}

.coverage-stat strong {
  font-size: 24px;
  letter-spacing: -0.02em;
}

.coverage-stat small {
  color: var(--fitai-text-faint);
  font-size: 11px;
}

.coverage-toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 10px;
  padding: 12px 16px;
  border-bottom: 1px solid var(--fitai-border);
}

.coverage-toolbar .el-input {
  max-width: 320px;
}

.coverage-note {
  margin: 0;
  padding: 0 16px 14px;
  font-size: 11px;
}

@media (max-width: 720px) {
  .coverage-switch {
    grid-template-columns: 1fr;
  }

  .coverage-toolbar .el-input {
    max-width: none;
    width: 100%;
  }
}

.poster {
  width: 48px;
  height: 32px;
  border-radius: 6px;
  background: rgba(148, 163, 184, 0.06);
}

.poster-placeholder {
  display: grid;
  place-items: center;
  border: 1px dashed var(--fitai-border);
  color: #5e708b;
  font-size: 10px;
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

.mini-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}

.text-warning {
  color: #f8c45c;
}

.form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0 16px;
}

.upload-row {
  display: flex;
  align-items: center;
  gap: 9px;
  width: 100%;
}

.upload-row .el-input {
  flex: 1;
}

.preview-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16px;
}

.preview-grid h4 {
  margin: 0 0 8px;
  color: #dfe8f6;
  font-size: 13px;
}

.preview-video {
  width: 100%;
  max-height: 320px;
  border-radius: 8px;
  background: #0b1220;
}

.preview-poster {
  width: 100%;
  max-height: 320px;
  border-radius: 8px;
}

.import-row {
  display: flex;
  align-items: center;
  gap: 12px;
  margin: 14px 0;
}

.media-mobile-list {
  display: none;
}

.media-mobile-card {
  display: flex;
  flex-direction: column;
  gap: 9px;
  padding: 12px;
  border: 1px solid var(--fitai-border);
  border-radius: 10px;
  background: rgba(148, 163, 184, 0.03);
}

.media-mobile-head {
  display: flex;
  align-items: center;
  gap: 10px;
}

.media-mobile-head .cell-stack {
  flex: 1;
}

.media-mobile-meta {
  color: var(--fitai-text-muted);
  font-size: 11px;
}

.media-mobile-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

@media (max-width: 720px) {
  .media-table {
    display: none;
  }

  .media-mobile-list {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding: 12px;
  }
}

@media (max-width: 430px) {
  .metric-grid.media-metrics {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 760px) {
  .form-grid,
  .preview-grid {
    grid-template-columns: 1fr;
  }
}
</style>
