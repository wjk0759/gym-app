<template>
  <div class="admin-shell" :class="{ 'sidebar-collapsed': collapsed, 'mobile-open': mobileOpen }">
    <div v-if="mobileOpen" class="sidebar-overlay" @click="mobileOpen = false" />

    <aside class="sidebar">
      <div class="sidebar-brand">
        <div class="brand-symbol">F</div>
        <div v-show="!collapsed || isMobile" class="brand-copy">
          <strong>FitAI</strong>
          <span>Admin Control Plane</span>
        </div>
      </div>

      <nav class="sidebar-nav" aria-label="主导航">
        <router-link
          v-for="item in menuItems"
          :key="item.path"
          :to="item.path"
          class="nav-item"
          :title="item.label"
          @click="mobileOpen = false"
        >
          <el-icon :size="19"><component :is="item.icon" /></el-icon>
          <span v-show="!collapsed || isMobile" class="nav-label">{{ item.label }}</span>
        </router-link>
      </nav>

      <div class="sidebar-foot">
        <div v-show="!collapsed || isMobile" class="sidebar-note">
          <span class="status-dot" />
          <span>v1.0 · 企业级控制面</span>
        </div>
      </div>
    </aside>

    <div class="main-shell">
      <header class="topbar">
        <div class="topbar-left">
          <el-button
            text
            class="menu-toggle"
            :aria-label="isMobile ? '打开导航' : '收起导航'"
            @click="toggleSidebar"
          >
            <el-icon :size="20"><component :is="mobileOpen || !collapsed ? Fold : Expand" /></el-icon>
          </el-button>
          <div class="title-block">
            <span class="breadcrumb">FitAI / 管理控制台</span>
            <h2>{{ pageTitle }}</h2>
          </div>
        </div>

        <div class="topbar-right">
          <span class="topbar-chip">UTC+8</span>
          <el-dropdown trigger="click" @command="handleUserCommand">
            <button class="user-trigger" type="button">
              <el-avatar :size="34" class="user-avatar">{{ initials }}</el-avatar>
              <span class="user-meta">
                <strong>{{ auth.user?.displayName || auth.user?.username }}</strong>
                <small>{{ roleText }}</small>
              </span>
              <el-icon class="user-chevron"><ArrowDown /></el-icon>
            </button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item disabled>
                  <span class="dropdown-id">{{ auth.user?.username }}</span>
                </el-dropdown-item>
                <el-dropdown-item command="password" divided>
                  <el-icon><Lock /></el-icon>修改密码
                </el-dropdown-item>
                <el-dropdown-item command="logout">
                  <el-icon><SwitchButton /></el-icon>退出登录
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </header>

      <main class="main-area">
        <router-view v-slot="{ Component }">
          <transition name="page-fade" mode="out-in">
            <component :is="Component" />
          </transition>
        </router-view>
      </main>
    </div>

    <el-dialog v-model="passwordVisible" title="修改密码" width="min(440px, calc(100vw - 32px))" destroy-on-close>
      <el-form ref="passwordFormRef" :model="passwordForm" :rules="passwordRules" label-position="top">
        <el-form-item label="当前密码" prop="currentPassword">
          <el-input v-model="passwordForm.currentPassword" type="password" show-password autocomplete="current-password" />
        </el-form-item>
        <el-form-item label="新密码" prop="newPassword">
          <el-input v-model="passwordForm.newPassword" type="password" show-password autocomplete="new-password" />
        </el-form-item>
        <el-form-item label="确认新密码" prop="confirmPassword">
          <el-input v-model="passwordForm.confirmPassword" type="password" show-password autocomplete="new-password" />
        </el-form-item>
        <el-alert
          title="修改成功后所有登录会话会被撤销，需要使用新密码重新登录。"
          type="warning"
          :closable="false"
          show-icon
        />
      </el-form>
      <template #footer>
        <el-button @click="passwordVisible = false">取消</el-button>
        <el-button type="primary" :loading="passwordSaving" @click="submitPassword">确认修改</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus'
import {
  ArrowDown,
  Calendar,
  Camera,
  ChatDotRound,
  Cpu,
  DataLine,
  Document,
  Expand,
  Fold,
  Lock,
  Reading,
  Setting,
  SwitchButton,
  TrendCharts,
  User,
  VideoCamera,
} from '@element-plus/icons-vue'
import type { Component } from 'vue'
import { authApi } from '@/api/auth'
import { errorMessage } from '@/api/client'
import { useAuthStore } from '@/stores/auth'
import { roleLabel } from '@/utils/format'

interface MenuItem {
  path: string
  label: string
  icon: Component
  permission: string
}

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const collapsed = ref(false)
const mobileOpen = ref(false)
const isMobile = ref(window.innerWidth < 900)

const allMenuItems: MenuItem[] = [
  { path: '/dashboard', label: '运营总览', icon: DataLine, permission: 'dashboard:read' },
  { path: '/users', label: '用户管理', icon: User, permission: 'user:read' },
  { path: '/plans', label: '训练计划', icon: Calendar, permission: 'plan:read' },
  { path: '/workouts', label: '训练记录', icon: TrendCharts, permission: 'workout:read' },
  { path: '/chats', label: '教练对话', icon: ChatDotRound, permission: 'chat:read' },
  { path: '/scans', label: '器械识别', icon: Camera, permission: 'scan:read' },
  { path: '/exercises', label: '动作库', icon: Reading, permission: 'exercise:read' },
  { path: '/videos', label: '教学视频', icon: VideoCamera, permission: 'video:read' },
  { path: '/ai', label: 'AI 运营', icon: Cpu, permission: 'ai:read' },
  { path: '/audit', label: '审计日志', icon: Document, permission: 'audit:read' },
  { path: '/settings', label: '系统设置', icon: Setting, permission: 'settings:manage' },
]

const menuItems = computed(() => allMenuItems.filter((item) => auth.hasPermission(item.permission)))
const pageTitle = computed(() => route.meta.title ?? '管理控制台')
const roleText = computed(() => (auth.user?.roles ?? []).map(roleLabel).join(' / ') || '管理员')
const initials = computed(() => {
  const name = auth.user?.displayName || auth.user?.username || 'A'
  return name.slice(0, 1).toUpperCase()
})

function toggleSidebar(): void {
  if (isMobile.value) {
    mobileOpen.value = !mobileOpen.value
  } else {
    collapsed.value = !collapsed.value
  }
}

function resize(): void {
  isMobile.value = window.innerWidth < 900
  if (!isMobile.value) {
    mobileOpen.value = false
  }
}

async function handleUserCommand(command: string): Promise<void> {
  if (command === 'password') {
    passwordVisible.value = true
    return
  }
  if (command === 'logout') {
    try {
      await ElMessageBox.confirm('确定退出当前管理员会话吗？', '退出登录', {
        confirmButtonText: '退出',
        cancelButtonText: '取消',
        type: 'warning',
      })
      await auth.logout()
      await router.replace({ name: 'login' })
    } catch {
      // Cancelled.
    }
  }
}

const passwordVisible = ref(false)
const passwordSaving = ref(false)
const passwordFormRef = ref<FormInstance>()
const passwordForm = reactive({
  currentPassword: '',
  newPassword: '',
  confirmPassword: '',
})

const passwordRules: FormRules = {
  currentPassword: [{ required: true, message: '请输入当前密码', trigger: 'blur' }],
  newPassword: [
    { required: true, message: '请输入新密码', trigger: 'blur' },
    { min: 10, max: 72, message: '新密码长度需为 10–72 位', trigger: 'blur' },
  ],
  confirmPassword: [
    { required: true, message: '请再次输入新密码', trigger: 'blur' },
    {
      validator: (_rule, value: string, callback) => {
        if (value !== passwordForm.newPassword) {
          callback(new Error('两次输入的密码不一致'))
        } else {
          callback()
        }
      },
      trigger: 'blur',
    },
  ],
}

async function submitPassword(): Promise<void> {
  const valid = await passwordFormRef.value?.validate().catch(() => false)
  if (!valid) return
  passwordSaving.value = true
  try {
    await authApi.changePassword({
      currentPassword: passwordForm.currentPassword,
      newPassword: passwordForm.newPassword,
    })
    passwordVisible.value = false
    ElMessage.success('密码已修改，请重新登录')
    await auth.logout()
    await router.replace({ name: 'login' })
  } catch (reason) {
    ElMessage.error(errorMessage(reason))
  } finally {
    passwordSaving.value = false
  }
}

watch(() => route.fullPath, () => {
  mobileOpen.value = false
})

onMounted(() => window.addEventListener('resize', resize))
onBeforeUnmount(() => window.removeEventListener('resize', resize))
</script>

<style scoped>
.admin-shell {
  display: flex;
  min-height: 100vh;
}

.sidebar {
  position: fixed;
  z-index: 30;
  top: 0;
  bottom: 0;
  left: 0;
  display: flex;
  width: 236px;
  flex-direction: column;
  border-right: 1px solid var(--fitai-border);
  background: rgba(9, 14, 22, 0.9);
  backdrop-filter: blur(18px);
  transition: width 220ms ease, transform 220ms ease;
}

.sidebar-collapsed .sidebar {
  width: 76px;
}

.sidebar-brand {
  display: flex;
  height: 82px;
  align-items: center;
  gap: 12px;
  padding: 0 18px;
}

.brand-symbol {
  display: grid;
  width: 38px;
  height: 38px;
  flex: 0 0 38px;
  place-items: center;
  border: 1px solid rgba(91, 140, 255, 0.34);
  border-radius: 12px;
  background: linear-gradient(145deg, rgba(91, 140, 255, 0.32), rgba(61, 220, 151, 0.1));
  color: #dce8ff;
  font-size: 20px;
  font-weight: 800;
  box-shadow: 0 10px 24px rgba(91, 140, 255, 0.18);
}

.brand-copy {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
}

.brand-copy strong {
  color: #f0f5ff;
  font-size: 17px;
  letter-spacing: -0.025em;
}

.brand-copy span {
  color: #5f7089;
  font-size: 10px;
  letter-spacing: 0.03em;
}

.sidebar-nav {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 3px;
  padding: 10px 10px;
  overflow-y: auto;
}

.nav-item {
  display: flex;
  min-height: 44px;
  align-items: center;
  gap: 12px;
  padding: 0 13px;
  border: 1px solid transparent;
  border-radius: 10px;
  color: #8493a9;
  font-size: 13px;
  transition: background 160ms ease, color 160ms ease, border-color 160ms ease;
}

.nav-item:hover {
  background: rgba(148, 163, 184, 0.07);
  color: #d8e3f5;
}

.nav-item.router-link-active {
  border-color: rgba(91, 140, 255, 0.18);
  background: linear-gradient(90deg, rgba(91, 140, 255, 0.17), rgba(91, 140, 255, 0.03));
  color: #dce8ff;
}

.nav-item.router-link-active .el-icon {
  color: #78a1ff;
}

.nav-label {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.sidebar-collapsed .nav-item {
  justify-content: center;
  padding: 0;
}

.sidebar-foot {
  padding: 12px 14px 18px;
}

.sidebar-note {
  display: flex;
  align-items: center;
  gap: 7px;
  color: #526178;
  font-size: 10px;
  white-space: nowrap;
}

.status-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--fitai-success);
  box-shadow: 0 0 10px rgba(61, 220, 151, 0.75);
}

.main-shell {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  margin-left: 236px;
  transition: margin-left 220ms ease;
}

.sidebar-collapsed .main-shell {
  margin-left: 76px;
}

.topbar {
  position: sticky;
  z-index: 20;
  top: 0;
  display: flex;
  min-height: 72px;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 0 26px;
  border-bottom: 1px solid var(--fitai-border);
  background: rgba(10, 13, 19, 0.78);
  backdrop-filter: blur(18px);
}

.topbar-left,
.topbar-right {
  display: flex;
  align-items: center;
  gap: 14px;
}

.menu-toggle {
  color: #8fa0b7;
}

.title-block {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.breadcrumb {
  color: #55647b;
  font-size: 10px;
  letter-spacing: 0.04em;
}

.title-block h2 {
  margin: 0;
  color: #eaf1fc;
  font-size: 16px;
  font-weight: 650;
  letter-spacing: -0.015em;
}

.topbar-chip {
  padding: 5px 8px;
  border: 1px solid var(--fitai-border);
  border-radius: 7px;
  color: #75859c;
  font-size: 10px;
}

.user-trigger {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 4px 7px 4px 4px;
  border: 1px solid transparent;
  border-radius: 10px;
  background: transparent;
  color: inherit;
  cursor: pointer;
}

.user-trigger:hover {
  border-color: var(--fitai-border);
  background: rgba(148, 163, 184, 0.06);
}

.user-avatar {
  background: linear-gradient(145deg, #416cc2, #27457d);
  color: #eaf1ff;
  font-size: 13px;
  font-weight: 700;
}

.user-meta {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 1px;
}

.user-meta strong {
  color: #dce6f5;
  font-size: 12px;
  font-weight: 600;
}

.user-meta small {
  color: #65758c;
  font-size: 10px;
}

.user-chevron {
  color: #61718a;
  font-size: 11px;
}

.dropdown-id {
  color: var(--fitai-text-faint);
  font-size: 11px;
}

.main-area {
  flex: 1;
  padding: 26px;
}

.page-fade-enter-active,
.page-fade-leave-active {
  transition: opacity 160ms ease, transform 160ms ease;
}

.page-fade-enter-from {
  opacity: 0;
  transform: translateY(4px);
}

.page-fade-leave-to {
  opacity: 0;
}

.sidebar-overlay {
  display: none;
}

@media (max-width: 900px) {
  .sidebar {
    width: 250px;
    transform: translateX(-100%);
    box-shadow: 24px 0 60px rgba(0, 0, 0, 0.36);
  }

  .mobile-open .sidebar {
    transform: translateX(0);
  }

  .sidebar-overlay {
    position: fixed;
    z-index: 25;
    inset: 0;
    display: block;
    background: rgba(3, 7, 18, 0.62);
    backdrop-filter: blur(2px);
  }

  .main-shell,
  .sidebar-collapsed .main-shell {
    margin-left: 0;
  }

  .topbar {
    min-height: 64px;
    padding: 0 16px;
  }

  .main-area {
    padding: 18px 16px;
  }

  .topbar-chip,
  .user-meta,
  .breadcrumb {
    display: none;
  }

  .sidebar-collapsed .sidebar {
    width: 250px;
  }
}

@media (max-width: 520px) {
  .topbar {
    padding: 0 12px;
  }

  .main-area {
    padding: 14px 12px;
  }

  .user-trigger {
    padding-right: 0;
  }
}
</style>
