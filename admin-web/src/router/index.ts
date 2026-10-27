import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

declare module 'vue-router' {
  interface RouteMeta {
    title?: string
    permission?: string
    public?: boolean
  }
}

const routes: RouteRecordRaw[] = [
  {
    path: '/login',
    name: 'login',
    component: () => import('@/views/LoginView.vue'),
    meta: { title: '登录', public: true },
  },
  {
    path: '/',
    component: () => import('@/layouts/AdminLayout.vue'),
    redirect: { name: 'dashboard' },
    children: [
      {
        path: 'dashboard',
        name: 'dashboard',
        component: () => import('@/views/DashboardView.vue'),
        meta: { title: '运营总览', permission: 'dashboard:read' },
      },
      {
        path: 'users',
        name: 'users',
        component: () => import('@/views/UsersView.vue'),
        meta: { title: '用户管理', permission: 'user:read' },
      },
      {
        path: 'plans',
        name: 'plans',
        component: () => import('@/views/PlansView.vue'),
        meta: { title: '训练计划', permission: 'plan:read' },
      },
      {
        path: 'workouts',
        name: 'workouts',
        component: () => import('@/views/WorkoutsView.vue'),
        meta: { title: '训练记录', permission: 'workout:read' },
      },
      {
        path: 'chats',
        name: 'chats',
        component: () => import('@/views/ChatsView.vue'),
        meta: { title: '教练对话', permission: 'chat:read' },
      },
      {
        path: 'scans',
        name: 'scans',
        component: () => import('@/views/ScansView.vue'),
        meta: { title: '器械识别', permission: 'scan:read' },
      },
      {
        path: 'exercises',
        name: 'exercises',
        component: () => import('@/views/ExercisesView.vue'),
        meta: { title: '动作库', permission: 'exercise:read' },
      },
      {
        path: 'videos',
        name: 'videos',
        component: () => import('@/views/VideosView.vue'),
        meta: { title: '教学视频', permission: 'video:read' },
      },
      {
        path: 'ai',
        name: 'ai',
        component: () => import('@/views/AiView.vue'),
        meta: { title: 'AI 运营', permission: 'ai:read' },
      },
      {
        path: 'agent-runs',
        name: 'agent-runs',
        component: () => import('@/views/AgentRunsView.vue'),
        meta: { title: 'Agent 运行', permission: 'ai:read' },
      },
      {
        path: 'audit',
        name: 'audit',
        component: () => import('@/views/AuditView.vue'),
        meta: { title: '审计日志', permission: 'audit:read' },
      },
      {
        path: 'settings',
        name: 'settings',
        component: () => import('@/views/SettingsView.vue'),
        meta: { title: '系统设置', permission: 'settings:manage' },
      },
    ],
  },
  {
    path: '/403',
    name: 'forbidden',
    component: () => import('@/views/ForbiddenView.vue'),
    meta: { title: '无权限', public: true },
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'not-found',
    component: () => import('@/views/NotFoundView.vue'),
    meta: { title: '页面不存在', public: true },
  },
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
  scrollBehavior: () => ({ top: 0 }),
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  await auth.bootstrap()

  if (to.meta.public) {
    if (to.name === 'login' && auth.isAuthenticated) {
      return { name: 'dashboard' }
    }
    return true
  }

  if (!auth.isAuthenticated) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
  if (to.meta.permission && !auth.hasPermission(to.meta.permission)) {
    return { name: 'forbidden' }
  }
  return true
})

router.afterEach((to) => {
  document.title = to.meta.title ? `${to.meta.title} · FitAI 管理控制台` : 'FitAI 管理控制台'
})

export default router
