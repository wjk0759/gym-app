<template>
  <div class="page-shell">
    <PageHeader title="教学视频" subtitle="维护动作示范视频、封面与授权信息；发布后自动同步到动作库。">
      <template #actions>
        <el-button :icon="Refresh" :loading="loading" @click="load">刷新</el-button>
        <el-button v-if="canWrite" type="primary" :icon="Plus" @click="openCreate">新建视频</el-button>
      </template>
    </PageHeader>

    <section class="panel table-panel">
      <div class="filter-bar">
        <el-input
          v-model="filters.q"
          class="filter-grow"
          clearable
          placeholder="搜索视频标题、动作名称或 slug"
          :prefix-icon="Search"
          @keyup.enter="applyFilters"
          @clear="applyFilters"
        />
        <el-select v-model="filters.status" clearable placeholder="发布状态" @change="applyFilters">
          <el-option label="草稿" value="draft" />
          <el-option label="已发布" value="published" />
          <el-option label="已归档" value="archived" />
        </el-select>
        <el-button type="primary" @click="applyFilters">查询</el-button>
        <el-button text @click="resetFilters">重置</el-button>
      </div>

      <el-table v-loading="loading" :data="rows" row-key="id" @row-click="onRowClick">
        <el-table-column label="视频" min-width="240">
          <template #default="{ row }">
            <div class="video-cell">
              <el-image v-if="row.posterUrl" :src="row.posterUrl" fit="cover" class="poster" />
              <div v-else class="poster poster-placeholder"><el-icon><VideoCamera /></el-icon></div>
              <div class="cell-stack">
                <strong>{{ row.title }}</strong>
                <span>{{ row.exerciseName }} · <span class="mono">{{ row.exerciseSlug }}</span></span>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="94">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column label="版本" width="68" align="center">
          <template #default="{ row }">v{{ row.version }}</template>
        </el-table-column>
        <el-table-column label="时长" width="84">
          <template #default="{ row }">{{ durationLabel(row.durationSeconds) }}</template>
        </el-table-column>
        <el-table-column label="来源 / 许可" min-width="150">
          <template #default="{ row }">
            <div class="cell-stack">
              <span>{{ row.source || '—' }}</span>
              <span class="faint">{{ row.licenseNote || '—' }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="更新时间" width="150">
          <template #default="{ row }">{{ formatDateTime(row.updatedAt) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="190">
          <template #default="{ row }">
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
          </template>
        </el-table-column>
        <template #empty><el-empty description="没有匹配的教学视频" :image-size="90" /></template>
      </el-table>

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
      :title="editingId ? '编辑教学视频' : '新建教学视频'"
      width="min(760px, calc(100vw - 28px))"
      destroy-on-close
    >
      <el-form ref="formRef" :model="form" :rules="rules" label-position="top">
        <div class="form-grid">
          <el-form-item label="关联动作" prop="exerciseSlug">
            <el-select
              v-model="form.exerciseSlug"
              filterable
              :disabled="Boolean(editingId)"
              placeholder="搜索动作"
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
          <el-form-item label="视频标题" prop="title">
            <el-input v-model="form.title" maxlength="120" placeholder="请输入视频标题" />
          </el-form-item>
        </div>

        <el-form-item label="视频文件" prop="videoUrl">
          <div class="upload-row">
            <el-input v-model="form.videoUrl" placeholder="/media/videos/... 或 https://..." />
            <el-upload
              v-if="canWrite"
              :show-file-list="false"
              accept="video/mp4,video/quicktime,video/webm"
              :http-request="uploadVideo"
            >
              <el-button :loading="uploadingVideo" :icon="Upload">上传视频</el-button>
            </el-upload>
          </div>
          <span class="upload-hint">支持 mp4 / mov / webm，最大 100MB。发布后同步到动作库。</span>
        </el-form-item>

        <el-form-item label="封面图">
          <div class="upload-row">
            <el-input v-model="form.posterUrl" placeholder="/media/posters/... 或 https://..." />
            <el-upload
              v-if="canWrite"
              :show-file-list="false"
              accept="image/jpeg,image/png,image/webp"
              :http-request="uploadPoster"
            >
              <el-button :loading="uploadingPoster" :icon="Picture">上传封面</el-button>
            </el-upload>
          </div>
        </el-form-item>

        <div class="form-grid">
          <el-form-item label="时长（秒）">
            <el-input-number v-model="form.durationSeconds" :min="0" :max="86400" style="width: 100%" />
          </el-form-item>
          <el-form-item label="来源">
            <el-input v-model="form.source" maxlength="80" />
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

        <el-form-item label="描述">
          <el-input v-model="form.description" type="textarea" :rows="3" maxlength="5000" show-word-limit />
        </el-form-item>

        <el-form-item v-if="!editingId" label="创建后状态">
          <el-radio-group v-model="form.status">
            <el-radio-button value="draft">保存草稿</el-radio-button>
            <el-radio-button value="published">立即发布</el-radio-button>
          </el-radio-group>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button v-if="canWrite" type="primary" :loading="saving" @click="save">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules, type UploadRequestOptions } from 'element-plus'
import { Picture, Plus, Refresh, Search, Upload, VideoCamera } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import PaginationBar from '@/components/PaginationBar.vue'
import StatusTag from '@/components/StatusTag.vue'
import { videosApi } from '@/api/videos'
import { exercisesApi } from '@/api/exercises'
import { errorMessage } from '@/api/client'
import { useAuthStore } from '@/stores/auth'
import type {
  CreateVideoPayload,
  ExerciseItem,
  UpdateVideoPayload,
  VideoItem,
} from '@/api/types'
import { formatDateTime } from '@/utils/format'

const auth = useAuthStore()
const canWrite = auth.hasPermission('video:write')

const rows = ref<VideoItem[]>([])
const total = ref(0)
const page = ref(1)
const size = ref(20)
const loading = ref(false)
const filters = reactive({ q: '', status: '' })
const exerciseOptions = ref<ExerciseItem[]>([])

const dialogVisible = ref(false)
const editingId = ref<string | null>(null)
const saving = ref(false)
const uploadingVideo = ref(false)
const uploadingPoster = ref(false)
const formRef = ref<FormInstance>()
const form = reactive({
  exerciseSlug: '',
  title: '',
  description: '',
  videoUrl: '',
  posterUrl: '',
  durationSeconds: 0,
  source: '',
  licenseNote: '',
  licenseExpiresAt: '',
  status: 'draft' as 'draft' | 'published',
})

const rules: FormRules = {
  exerciseSlug: [{ required: true, message: '请选择关联动作', trigger: 'change' }],
  title: [{ required: true, message: '请输入视频标题', trigger: 'blur' }],
  videoUrl: [{ required: true, message: '请上传视频或填写视频地址', trigger: 'blur' }],
}

async function load(): Promise<void> {
  loading.value = true
  try {
    const result = await videosApi.list({
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

async function loadExercises(): Promise<void> {
  try {
    const result = await exercisesApi.list({ page: 1, size: 100 })
    exerciseOptions.value = result.items
  } catch {
    exerciseOptions.value = []
  }
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

function resetForm(): void {
  editingId.value = null
  form.exerciseSlug = ''
  form.title = ''
  form.description = ''
  form.videoUrl = ''
  form.posterUrl = ''
  form.durationSeconds = 0
  form.source = ''
  form.licenseNote = ''
  form.licenseExpiresAt = ''
  form.status = 'draft'
}

function openCreate(): void {
  resetForm()
  dialogVisible.value = true
}

function openEdit(row: VideoItem): void {
  editingId.value = row.id
  form.exerciseSlug = row.exerciseSlug
  form.title = row.title
  form.description = row.description ?? ''
  form.videoUrl = row.videoUrl
  form.posterUrl = row.posterUrl ?? ''
  form.durationSeconds = row.durationSeconds ?? 0
  form.source = row.source ?? ''
  form.licenseNote = row.licenseNote ?? ''
  form.licenseExpiresAt = row.licenseExpiresAt ?? ''
  dialogVisible.value = true
}

async function uploadVideo(options: UploadRequestOptions): Promise<void> {
  uploadingVideo.value = true
  try {
    const result = await videosApi.upload(options.file, 'video')
    form.videoUrl = result.url
    ElMessage.success('视频上传完成')
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    uploadingVideo.value = false
  }
}

async function uploadPoster(options: UploadRequestOptions): Promise<void> {
  uploadingPoster.value = true
  try {
    const result = await videosApi.upload(options.file, 'poster')
    form.posterUrl = result.url
    ElMessage.success('封面上传完成')
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
      const payload: UpdateVideoPayload = {
        title: form.title.trim(),
        description: form.description.trim(),
        videoUrl: form.videoUrl.trim(),
        posterUrl: form.posterUrl.trim(),
        durationSeconds: form.durationSeconds,
        source: form.source.trim(),
        licenseNote: form.licenseNote.trim(),
        licenseExpiresAt: form.licenseExpiresAt || null,
      }
      await videosApi.update(editingId.value, payload)
      ElMessage.success('视频已更新')
    } else {
      const payload: CreateVideoPayload = {
        exerciseSlug: form.exerciseSlug,
        title: form.title.trim(),
        description: form.description.trim(),
        videoUrl: form.videoUrl.trim(),
        posterUrl: form.posterUrl.trim(),
        durationSeconds: form.durationSeconds,
        source: form.source.trim(),
        licenseNote: form.licenseNote.trim(),
        licenseExpiresAt: form.licenseExpiresAt || null,
        status: form.status,
      }
      await videosApi.create(payload)
      ElMessage.success(form.status === 'published' ? '视频已创建并发布' : '视频草稿已创建')
    }
    dialogVisible.value = false
    await load()
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    saving.value = false
  }
}

async function publish(row: VideoItem): Promise<void> {
  try {
    await ElMessageBox.confirm('发布后，该动作当前已发布的视频会自动归档。确定发布吗？', '发布视频', {
      confirmButtonText: '发布',
      cancelButtonText: '取消',
      type: 'warning',
    })
    await videosApi.publish(row.id)
    ElMessage.success('视频已发布并同步到动作库')
    await load()
  } catch (reason) {
    if (reason !== 'cancel' && reason !== 'close') ElMessage.error(errorMessage(reason))
  }
}

async function unpublish(row: VideoItem): Promise<void> {
  try {
    await ElMessageBox.confirm('下架后动作库将不再显示该视频。确定下架吗？', '下架视频', {
      confirmButtonText: '下架',
      cancelButtonText: '取消',
      type: 'warning',
    })
    await videosApi.unpublish(row.id)
    ElMessage.success('视频已下架')
    await load()
  } catch (reason) {
    if (reason !== 'cancel' && reason !== 'close') ElMessage.error(errorMessage(reason))
  }
}

async function remove(row: VideoItem): Promise<void> {
  try {
    await ElMessageBox.confirm('删除视频会同时删除本地媒体文件，且不可恢复。确定删除吗？', '删除视频', {
      confirmButtonText: '删除',
      cancelButtonText: '取消',
      type: 'warning',
    })
    await videosApi.remove(row.id)
    ElMessage.success('视频已删除')
    await load()
  } catch (reason) {
    if (reason !== 'cancel' && reason !== 'close') ElMessage.error(errorMessage(reason))
  }
}

function durationLabel(seconds: number | null): string {
  if (seconds === null || seconds === undefined) return '—'
  const minutes = Math.floor(seconds / 60)
  const rest = seconds % 60
  return `${minutes}:${String(rest).padStart(2, '0')}`
}

function onRowClick(row: VideoItem, _column: unknown, event: MouseEvent): void {
  const target = event.target as HTMLElement | null
  if (target?.closest('button, a, .el-dropdown, .el-switch, input, textarea, select')) return
  openEdit(row)
}

onMounted(() => {
  void load()
  void loadExercises()
})
</script>

<style scoped>
.video-cell {
  display: flex;
  align-items: center;
  gap: 10px;
}

.poster {
  width: 54px;
  height: 36px;
  flex: 0 0 54px;
  border-radius: 7px;
  background: rgba(148, 163, 184, 0.06);
}

.poster-placeholder {
  display: grid;
  place-items: center;
  border: 1px solid var(--fitai-border);
  color: #5e708b;
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

.upload-hint {
  display: block;
  margin-top: 5px;
  color: var(--fitai-text-faint);
  font-size: 11px;
}

@media (max-width: 560px) {
  .form-grid {
    grid-template-columns: 1fr;
  }

  .upload-row {
    align-items: stretch;
    flex-direction: column;
  }
}
</style>
