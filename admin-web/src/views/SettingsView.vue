<template>
  <div class="page-shell">
    <PageHeader title="系统设置" subtitle="管理控制台账号与角色。所有账号变更都会写入审计日志并撤销相关会话。">
      <template #actions>
        <el-button :icon="Refresh" :loading="loading" @click="load">刷新</el-button>
        <el-button type="primary" :icon="Plus" @click="openCreate">新增管理员</el-button>
      </template>
    </PageHeader>

    <el-alert
      title="最小权限原则：运营人员使用 OPERATOR，审计人员使用 AUDITOR；SUPER_ADMIN 仅保留给必要的系统负责人。"
      type="info"
      :closable="false"
      show-icon
    />

    <section class="panel table-panel">
      <el-table v-loading="loading" :data="accounts" row-key="id" @row-click="onRowClick">
        <el-table-column label="管理员" min-width="200">
          <template #default="{ row }">
            <div class="account-cell">
              <div class="account-avatar">{{ (row.displayName || row.username).slice(0, 1) }}</div>
              <div class="cell-stack">
                <strong>{{ row.displayName || row.username }}</strong>
                <span>{{ row.username }}</span>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="角色" min-width="180">
          <template #default="{ row }">
            <div class="role-row">
              <el-tag v-for="role in row.roles" :key="role" effect="plain" size="small">{{ roleLabel(role) }}</el-tag>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="96">
          <template #default="{ row }">
            <div class="row">
              <StatusTag :status="row.status" />
              <el-tag v-if="isSelf(row)" size="small" type="primary" effect="plain">当前</el-tag>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="最近登录" width="156">
          <template #default="{ row }">{{ formatDateTime(row.lastLoginAt) }}</template>
        </el-table-column>
        <el-table-column label="创建时间" width="156">
          <template #default="{ row }">{{ formatDateTime(row.createdAt) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="210">
          <template #default="{ row }">
            <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
            <el-button link type="warning" :disabled="isSelf(row)" @click="openReset(row)">重置密码</el-button>
          </template>
        </el-table-column>
        <template #empty><el-empty description="暂无管理员账号" :image-size="90" /></template>
      </el-table>
    </section>

    <el-dialog
      v-model="createVisible"
      title="新增管理员"
      width="min(500px, calc(100vw - 28px))"
      destroy-on-close
    >
      <el-form ref="createFormRef" :model="createForm" :rules="createRules" label-position="top">
        <el-form-item label="管理员账号" prop="username">
          <el-input v-model="createForm.username" maxlength="64" autocomplete="off" />
        </el-form-item>
        <el-form-item label="显示名称" prop="displayName">
          <el-input v-model="createForm.displayName" maxlength="80" />
        </el-form-item>
        <el-form-item label="初始密码" prop="password">
          <el-input v-model="createForm.password" type="password" show-password autocomplete="new-password" />
        </el-form-item>
        <el-form-item label="角色" prop="roleCode">
          <el-select v-model="createForm.roleCode" style="width: 100%">
            <el-option v-for="role in roles" :key="role.code" :label="role.name" :value="role.code">
              <div class="role-option">
                <span>{{ role.name }}</span>
                <small>{{ role.description }}</small>
              </div>
            </el-option>
          </el-select>
        </el-form-item>
        <el-alert title="初始密码至少 10 位；创建后请通过安全渠道转交。" type="warning" :closable="false" show-icon />
      </el-form>
      <template #footer>
        <el-button @click="createVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="submitCreate">创建</el-button>
      </template>
    </el-dialog>

    <el-dialog
      v-model="editVisible"
      title="编辑管理员"
      width="min(500px, calc(100vw - 28px))"
      destroy-on-close
    >
      <el-form ref="editFormRef" :model="editForm" :rules="editRules" label-position="top">
        <el-form-item label="账号">
          <el-input :model-value="editing?.username" disabled />
        </el-form-item>
        <el-form-item label="显示名称" prop="displayName">
          <el-input v-model="editForm.displayName" maxlength="80" />
        </el-form-item>
        <el-form-item label="状态" prop="status">
          <el-select v-model="editForm.status" :disabled="isSelf(editing)" style="width: 100%">
            <el-option label="启用" value="active" />
            <el-option label="已停用" value="suspended" />
            <el-option label="已禁用" value="disabled" />
          </el-select>
        </el-form-item>
        <el-form-item label="角色" prop="roleCodes">
          <el-select
            v-model="editForm.roleCodes"
            multiple
            :disabled="isSelf(editing)"
            style="width: 100%"
            placeholder="请选择角色"
          >
            <el-option v-for="role in roles" :key="role.code" :label="role.name" :value="role.code" />
          </el-select>
        </el-form-item>
        <el-alert
          v-if="isSelf(editing)"
          title="当前登录账号不能停用，也不能移除自己的超级管理员角色。"
          type="info"
          :closable="false"
          show-icon
        />
      </el-form>
      <template #footer>
        <el-button @click="editVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="submitEdit">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog
      v-model="resetVisible"
      title="重置管理员密码"
      width="min(460px, calc(100vw - 28px))"
      destroy-on-close
    >
      <p class="reset-hint">为 <strong>{{ resetting?.username }}</strong> 设置新密码，保存后该账号所有登录会话将被撤销。</p>
      <el-form ref="resetFormRef" :model="resetForm" :rules="resetRules" label-position="top">
        <el-form-item label="新密码" prop="password">
          <el-input v-model="resetForm.password" type="password" show-password autocomplete="new-password" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="resetVisible = false">取消</el-button>
        <el-button type="warning" :loading="saving" @click="submitReset">确认重置</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
import { Plus, Refresh } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import StatusTag from '@/components/StatusTag.vue'
import { adminUsersApi } from '@/api/adminUsers'
import { errorMessage } from '@/api/client'
import { useAuthStore } from '@/stores/auth'
import type { AdminAccount, CreateAdminAccountPayload, RoleOption } from '@/api/types'
import { formatDateTime, roleLabel } from '@/utils/format'

const auth = useAuthStore()
const accounts = ref<AdminAccount[]>([])
const roles = ref<RoleOption[]>([])
const loading = ref(false)
const saving = ref(false)

const createVisible = ref(false)
const editVisible = ref(false)
const resetVisible = ref(false)
const editing = ref<AdminAccount | null>(null)
const resetting = ref<AdminAccount | null>(null)

const createFormRef = ref<FormInstance>()
const editFormRef = ref<FormInstance>()
const resetFormRef = ref<FormInstance>()

const createForm = reactive<CreateAdminAccountPayload>({
  username: '',
  password: '',
  displayName: '',
  roleCode: 'OPERATOR',
})
const editForm = reactive<{ displayName: string; status: string; roleCodes: string[] }>({
  displayName: '',
  status: 'active',
  roleCodes: [],
})
const resetForm = reactive({ password: '' })

const createRules: FormRules = {
  username: [
    { required: true, message: '请输入管理员账号', trigger: 'blur' },
    { pattern: /^[A-Za-z0-9._-]{3,64}$/, message: '账号需为 3–64 位字母、数字、点、下划线或短横线', trigger: 'blur' },
  ],
  displayName: [{ required: true, message: '请输入显示名称', trigger: 'blur' }],
  password: [
    { required: true, message: '请输入初始密码', trigger: 'blur' },
    { min: 10, max: 72, message: '密码长度需为 10–72 位', trigger: 'blur' },
  ],
  roleCode: [{ required: true, message: '请选择角色', trigger: 'change' }],
}

const editRules: FormRules = {
  displayName: [{ required: true, message: '请输入显示名称', trigger: 'blur' }],
  status: [{ required: true, message: '请选择状态', trigger: 'change' }],
  roleCodes: [{ type: 'array', required: true, min: 1, message: '至少选择一个角色', trigger: 'change' }],
}

const resetRules: FormRules = {
  password: [
    { required: true, message: '请输入新密码', trigger: 'blur' },
    { min: 10, max: 72, message: '密码长度需为 10–72 位', trigger: 'blur' },
  ],
}

function isSelf(account: AdminAccount | null): boolean {
  return Boolean(account && account.id === auth.user?.id)
}

async function load(): Promise<void> {
  loading.value = true
  try {
    const [accountList, roleList] = await Promise.all([adminUsersApi.list(), adminUsersApi.roles()])
    accounts.value = accountList
    roles.value = roleList
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    loading.value = false
  }
}

function openCreate(): void {
  createForm.username = ''
  createForm.password = ''
  createForm.displayName = ''
  createForm.roleCode = 'OPERATOR'
  createVisible.value = true
}

function openEdit(account: AdminAccount): void {
  editing.value = account
  editForm.displayName = account.displayName
  editForm.status = account.status
  editForm.roleCodes = [...account.roles]
  editVisible.value = true
}

function onRowClick(account: AdminAccount, _column: unknown, event: MouseEvent): void {
  const target = event.target as HTMLElement | null
  if (target?.closest('button, a, .el-dropdown')) return
  openEdit(account)
}

function openReset(account: AdminAccount): void {
  resetting.value = account
  resetForm.password = ''
  resetVisible.value = true
}

async function submitCreate(): Promise<void> {
  const valid = await createFormRef.value?.validate().catch(() => false)
  if (!valid) return
  saving.value = true
  try {
    await adminUsersApi.create({
      username: createForm.username.trim(),
      password: createForm.password,
      displayName: createForm.displayName.trim(),
      roleCode: createForm.roleCode,
    })
    ElMessage.success('管理员已创建')
    createVisible.value = false
    await load()
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    saving.value = false
  }
}

async function submitEdit(): Promise<void> {
  if (!editing.value) return
  const valid = await editFormRef.value?.validate().catch(() => false)
  if (!valid) return
  saving.value = true
  try {
    await adminUsersApi.update(editing.value.id, {
      displayName: editForm.displayName.trim(),
      status: editForm.status,
      roleCodes: editForm.roleCodes,
    })
    ElMessage.success('管理员信息已更新')
    editVisible.value = false
    await load()
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    saving.value = false
  }
}

async function submitReset(): Promise<void> {
  if (!resetting.value) return
  const valid = await resetFormRef.value?.validate().catch(() => false)
  if (!valid) return
  saving.value = true
  try {
    await adminUsersApi.resetPassword(resetting.value.id, resetForm.password)
    ElMessage.success('密码已重置，相关登录会话已撤销')
    resetVisible.value = false
    await load()
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.account-cell {
  display: flex;
  align-items: center;
  gap: 10px;
}

.account-avatar {
  display: grid;
  width: 34px;
  height: 34px;
  flex: 0 0 34px;
  place-items: center;
  border: 1px solid rgba(91, 140, 255, 0.24);
  border-radius: 10px;
  background: linear-gradient(145deg, rgba(91, 140, 255, 0.24), rgba(61, 220, 151, 0.08));
  color: #d7e4ff;
  font-size: 12px;
  font-weight: 700;
}

.cell-stack {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
}

.cell-stack strong {
  color: #dfe8f6;
  font-size: 13px;
}

.cell-stack span {
  color: #687890;
  font-size: 11px;
}

.role-row {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}

.role-option {
  display: flex;
  flex-direction: column;
  gap: 1px;
}

.role-option small {
  color: var(--fitai-text-muted);
  font-size: 10px;
}

.reset-hint {
  margin: 0 0 16px;
  color: var(--fitai-text-muted);
  font-size: 13px;
  line-height: 1.7;
}

.reset-hint strong {
  color: var(--fitai-text);
}
</style>
