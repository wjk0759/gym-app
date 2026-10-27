import dayjs from 'dayjs'

const STATUS_LABELS: Record<string, string> = {
  active: '启用',
  suspended: '已停用',
  disabled: '已禁用',
  deleted: '已删除',
  draft: '草稿',
  published: '已发布',
  archived: '已归档',
  pending: '识别中',
  processing: '处理中',
  ok: '成功',
  fallback: '降级',
  error: '失败',
  success: '成功',
  failed: '失败',
  running: '运行中',
  completed: '已完成',
  needs_confirmation: '待确认',
  applied: '已应用',
  superseded: '已替代',
  expired: '已过期',
  rejected: '已拒绝',
  male: '男',
  female: '女',
}

const GOAL_LABELS: Record<string, string> = {
  fat_loss: '减脂',
  muscle_gain: '增肌',
  strength: '力量',
  endurance: '体能',
  rehab: '康复',
  general: '综合',
}

const ROLE_LABELS: Record<string, string> = {
  SUPER_ADMIN: '超级管理员',
  OPERATOR: '运营管理员',
  AUDITOR: '审计员',
}

const ACTION_LABELS: Record<string, string> = {
  USER_STATUS_CHANGED: '修改用户状态',
  USER_DELETED: '删除用户',
  USER_RESTORED: '恢复用户',
  USER_EXPORTED: '导出用户',
  PLAN_ARCHIVED: '归档计划',
  PLAN_ACTIVATED: '启用计划',
  WORKOUT_DELETED: '删除训练记录',
  CHAT_DELETED: '删除教练对话',
  SCAN_DELETED: '删除器械识别',
  EXERCISE_UPDATED: '编辑动作',
  VIDEO_CREATED: '创建视频',
  VIDEO_UPDATED: '编辑视频',
  VIDEO_PUBLISHED: '发布视频',
  VIDEO_UNPUBLISHED: '下架视频',
  VIDEO_DELETED: '删除视频',
  ADMIN_LOGIN: '管理员登录',
  ADMIN_LOGIN_FAILED: '登录失败',
  ADMIN_TOKEN_REFRESH: '刷新登录',
  ADMIN_PASSWORD_CHANGED: '修改密码',
  ADMIN_BOOTSTRAP: '初始化管理员',
}

export function formatDateTime(value: string | null | undefined): string {
  if (!value) return '—'
  const parsed = dayjs(value)
  return parsed.isValid() ? parsed.format('YYYY-MM-DD HH:mm') : '—'
}

export function formatDate(value: string | null | undefined): string {
  if (!value) return '—'
  const parsed = dayjs(value)
  return parsed.isValid() ? parsed.format('YYYY-MM-DD') : '—'
}

export function formatNumber(value: number | null | undefined): string {
  if (value === null || value === undefined || Number.isNaN(value)) return '—'
  return new Intl.NumberFormat('zh-CN').format(value)
}

export function formatDecimal(value: number | null | undefined, digits = 1): string {
  if (value === null || value === undefined || Number.isNaN(value)) return '—'
  return value.toFixed(digits)
}

export function formatWeight(value: number | null | undefined): string {
  return value === null || value === undefined ? '—' : `${formatDecimal(value, 1)} kg`
}

export function formatDuration(minutes: number | null | undefined): string {
  if (minutes === null || minutes === undefined) return '—'
  if (minutes < 60) return `${minutes} 分钟`
  const hours = Math.floor(minutes / 60)
  const rest = minutes % 60
  return rest ? `${hours} 小时 ${rest} 分钟` : `${hours} 小时`
}

export function shortId(id: string | null | undefined): string {
  return id ? `${id.slice(0, 8)}…` : '—'
}

export function statusLabel(status: string | null | undefined): string {
  return status ? STATUS_LABELS[status] ?? status : '—'
}

export function goalLabel(goal: string | null | undefined): string {
  return goal ? GOAL_LABELS[goal] ?? goal : '未设置'
}

export function roleLabel(role: string): string {
  return ROLE_LABELS[role] ?? role
}

export function actionLabel(action: string): string {
  return ACTION_LABELS[action] ?? action
}

export function statusTagType(status: string | null | undefined):
  'success' | 'warning' | 'danger' | 'info' | 'primary' {
  if (status === 'active' || status === 'published' || status === 'ok' || status === 'success' || status === 'completed' || status === 'applied') return 'success'
  if (status === 'suspended' || status === 'pending' || status === 'processing' || status === 'fallback' || status === 'running' || status === 'needs_confirmation') return 'warning'
  if (status === 'deleted' || status === 'disabled' || status === 'error' || status === 'failed' || status === 'rejected') return 'danger'
  if (status === 'draft' || status === 'superseded' || status === 'expired') return 'info'
  return 'info'
}

export function prettyJson(value: unknown): string {
  if (value === null || value === undefined) return '—'
  try {
    return JSON.stringify(value, null, 2)
  } catch {
    return String(value)
  }
}

export function percent(value: number, total: number): string {
  if (!total) return '0%'
  return `${Math.round((value / total) * 100)}%`
}
