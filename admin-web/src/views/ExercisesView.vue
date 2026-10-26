<template>
  <div class="page-shell">
    <PageHeader title="动作库" subtitle="维护动作元数据、器械归属、难度与禁忌症；App 与计划生成共享同一份动作库。">
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
          placeholder="搜索动作名称、英文名或 slug"
          :prefix-icon="Search"
          @keyup.enter="applyFilters"
          @clear="applyFilters"
        />
        <el-select v-model="filters.muscleGroup" clearable placeholder="训练部位" @change="applyFilters">
          <el-option v-for="item in muscleOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
        <el-select v-model="filters.equipment" clearable placeholder="器械" @change="applyFilters">
          <el-option v-for="item in equipmentOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
        <el-button type="primary" @click="applyFilters">查询</el-button>
        <el-button text @click="resetFilters">重置</el-button>
      </div>

      <el-table v-loading="loading" :data="rows" row-key="slug" @row-click="onRowClick">
        <el-table-column label="动作" min-width="220">
          <template #default="{ row }">
            <div class="cell-stack">
              <strong>{{ row.nameZh }}</strong>
              <span>{{ row.nameEn || row.slug }} · <span class="mono">{{ row.slug }}</span></span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="部位" width="100">
          <template #default="{ row }">{{ muscleLabel(row.muscleGroup) }}</template>
        </el-table-column>
        <el-table-column label="器械" width="106">
          <template #default="{ row }">{{ equipmentLabel(row.equipment) }}</template>
        </el-table-column>
        <el-table-column label="难度" width="86" align="center">
          <template #default="{ row }">
            <span class="difficulty">{{ '●'.repeat(row.difficulty) }}<span class="faint">{{ '○'.repeat(5 - row.difficulty) }}</span></span>
          </template>
        </el-table-column>
        <el-table-column label="类型" width="92" align="center">
          <template #default="{ row }">
            <el-tag :type="row.compound ? 'warning' : 'info'" effect="plain" size="small">{{ row.compound ? '复合' : '孤立' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="视频" width="84" align="center">
          <template #default="{ row }">
            <el-link v-if="row.videoUrl" :href="row.videoUrl" target="_blank" type="primary">查看</el-link>
            <span v-else class="faint">—</span>
          </template>
        </el-table-column>
        <el-table-column label="禁忌症" min-width="150">
          <template #default="{ row }">
            <span class="truncate">{{ arrayLabel(row.contraindications) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="98">
          <template #default="{ row }">
            <el-button v-if="canWrite" link type="primary" @click="openEdit(row)">编辑</el-button>
            <span v-else class="faint">只读</span>
          </template>
        </el-table-column>
        <template #empty><el-empty description="没有匹配的动作" :image-size="90" /></template>
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
      title="编辑动作"
      width="min(720px, calc(100vw - 28px))"
      destroy-on-close
    >
      <el-form ref="formRef" :model="form" :rules="rules" label-position="top">
        <div class="form-grid">
          <el-form-item label="中文名称" prop="nameZh">
            <el-input v-model="form.nameZh" maxlength="80" />
          </el-form-item>
          <el-form-item label="英文名称">
            <el-input v-model="form.nameEn" maxlength="120" />
          </el-form-item>
          <el-form-item label="训练部位" prop="muscleGroup">
            <el-select v-model="form.muscleGroup" filterable allow-create style="width: 100%">
              <el-option v-for="item in muscleOptions" :key="item.value" :label="item.label" :value="item.value" />
            </el-select>
          </el-form-item>
          <el-form-item label="器械" prop="equipment">
            <el-select v-model="form.equipment" filterable allow-create style="width: 100%">
              <el-option v-for="item in equipmentOptions" :key="item.value" :label="item.label" :value="item.value" />
            </el-select>
          </el-form-item>
          <el-form-item label="难度 1–5" prop="difficulty">
            <el-input-number v-model="form.difficulty" :min="1" :max="5" style="width: 100%" />
          </el-form-item>
          <el-form-item label="动作类型">
            <el-switch v-model="form.compound" active-text="复合动作" inactive-text="孤立动作" />
          </el-form-item>
          <el-form-item label="来源">
            <el-input v-model="form.source" maxlength="40" />
          </el-form-item>
          <el-form-item label="许可信息">
            <el-input v-model="form.license" maxlength="120" />
          </el-form-item>
        </div>
        <el-form-item label="动作说明">
          <el-input v-model="form.instructions" type="textarea" :rows="4" maxlength="5000" show-word-limit />
        </el-form-item>
        <div class="form-grid">
          <el-form-item label="视频地址">
            <el-input v-model="form.videoUrl" placeholder="/media/... 或 https://..." />
          </el-form-item>
          <el-form-item label="缩略图地址">
            <el-input v-model="form.thumbnailUrl" placeholder="/media/... 或 https://..." />
          </el-form-item>
        </div>
        <el-form-item label="禁忌症（英文逗号分隔）">
          <el-input v-model="form.contraindicationsText" placeholder="例如：膝关节疼痛, 腰椎间盘突出" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="save">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
import { Refresh, Search } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import PaginationBar from '@/components/PaginationBar.vue'
import { exercisesApi } from '@/api/exercises'
import { errorMessage } from '@/api/client'
import { useAuthStore } from '@/stores/auth'
import type { ExerciseItem, PatchExercisePayload } from '@/api/types'

const auth = useAuthStore()
const canWrite = auth.hasPermission('exercise:write')

const muscleOptions = [
  { value: 'chest', label: '胸部' },
  { value: 'back', label: '背部' },
  { value: 'legs', label: '腿部' },
  { value: 'glutes', label: '臀部' },
  { value: 'shoulders', label: '肩部' },
  { value: 'arms', label: '手臂' },
  { value: 'core', label: '核心' },
  { value: 'full_body', label: '全身' },
]

const equipmentOptions = [
  { value: 'bodyweight', label: '徒手' },
  { value: 'dumbbell', label: '哑铃' },
  { value: 'barbell', label: '杠铃' },
  { value: 'machine', label: '固定器械' },
  { value: 'cable', label: '绳索' },
  { value: 'kettlebell', label: '壶铃' },
  { value: 'band', label: '弹力带' },
  { value: 'bench', label: '训练凳' },
  { value: 'pullup_bar', label: '单杠' },
]

const rows = ref<ExerciseItem[]>([])
const total = ref(0)
const page = ref(1)
const size = ref(50)
const loading = ref(false)
const filters = reactive({ q: '', muscleGroup: '', equipment: '' })

const dialogVisible = ref(false)
const saving = ref(false)
const formRef = ref<FormInstance>()
const editingSlug = ref('')
const form = reactive({
  nameZh: '',
  nameEn: '',
  muscleGroup: '',
  equipment: '',
  difficulty: 1,
  compound: false,
  source: '',
  license: '',
  instructions: '',
  videoUrl: '',
  thumbnailUrl: '',
  contraindicationsText: '',
})

const rules: FormRules = {
  nameZh: [{ required: true, message: '请输入中文名称', trigger: 'blur' }],
  muscleGroup: [{ required: true, message: '请选择训练部位', trigger: 'change' }],
  equipment: [{ required: true, message: '请选择器械', trigger: 'change' }],
  difficulty: [{ required: true, message: '请选择难度', trigger: 'change' }],
}

async function load(): Promise<void> {
  loading.value = true
  try {
    const result = await exercisesApi.list({
      q: filters.q.trim() || undefined,
      muscleGroup: filters.muscleGroup || undefined,
      equipment: filters.equipment || undefined,
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
  filters.muscleGroup = ''
  filters.equipment = ''
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

function openEdit(row: ExerciseItem): void {
  editingSlug.value = row.slug
  form.nameZh = row.nameZh
  form.nameEn = row.nameEn ?? ''
  form.muscleGroup = row.muscleGroup
  form.equipment = row.equipment
  form.difficulty = row.difficulty
  form.compound = row.compound
  form.source = row.source ?? ''
  form.license = row.license ?? ''
  form.instructions = row.instructions ?? ''
  form.videoUrl = row.videoUrl ?? ''
  form.thumbnailUrl = row.thumbnailUrl ?? ''
  form.contraindicationsText = arrayLabel(row.contraindications) === '—' ? '' : arrayLabel(row.contraindications)
  dialogVisible.value = true
}

async function save(): Promise<void> {
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return
  saving.value = true
  try {
    const payload: PatchExercisePayload = {
      nameZh: form.nameZh.trim(),
      nameEn: form.nameEn.trim(),
      muscleGroup: form.muscleGroup,
      equipment: form.equipment,
      difficulty: form.difficulty,
      compound: form.compound,
      source: form.source.trim(),
      license: form.license.trim(),
      instructions: form.instructions.trim(),
      videoUrl: form.videoUrl.trim(),
      thumbnailUrl: form.thumbnailUrl.trim(),
      contraindications: form.contraindicationsText
        .split(/[,，]/)
        .map((item) => item.trim())
        .filter(Boolean),
    }
    await exercisesApi.update(editingSlug.value, payload)
    ElMessage.success('动作已保存')
    dialogVisible.value = false
    await load()
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    saving.value = false
  }
}

function muscleLabel(value: string): string {
  return muscleOptions.find((item) => item.value === value)?.label ?? value
}

function equipmentLabel(value: string): string {
  return equipmentOptions.find((item) => item.value === value)?.label ?? value
}

function arrayLabel(value: unknown): string {
  if (!Array.isArray(value) || !value.length) return '—'
  return value.map(String).join('、')
}

function onRowClick(row: ExerciseItem, _column: unknown, event: MouseEvent): void {
  const target = event.target as HTMLElement | null
  if (target?.closest('button, a, .el-dropdown, .el-switch, input, textarea, select')) return
  if (canWrite) openEdit(row)
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

.difficulty {
  color: #f8c45c;
  font-size: 9px;
  letter-spacing: 1px;
}

.difficulty .faint {
  color: #3b485c;
}

.form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0 16px;
}

@media (max-width: 560px) {
  .form-grid {
    grid-template-columns: 1fr;
  }
}
</style>
