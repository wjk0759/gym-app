export interface PageResponse<T> {
  items: T[]
  page: number
  size: number
  total: number
  totalPages: number
}

export interface ApiProblem {
  type?: string
  title?: string
  status?: number
  detail?: string
  code?: string
  requestId?: string
  errors?: Array<{ field: string; message: string }>
}

export interface AdminUser {
  id: string
  username: string
  displayName: string
  roles: string[]
  permissions: string[]
}

export interface LoginResponse {
  accessToken: string
  expiresIn: number
  user: AdminUser
}

export interface DashboardDailyPoint {
  date: string
  users: number
  workouts: number
}

export interface DashboardKindPoint {
  kind: string
  count: number
}

export interface DashboardSummary {
  usersTotal: number
  usersNew7d: number
  onboardedUsers: number
  sessionsTotal: number
  sessions7d: number
  programsActive: number
  programsTotal: number
  chatsTotal: number
  messagesTotal: number
  safetyFlags: number
  scansTotal: number
  exercisesTotal: number
  videosPublished: number
  mealPlansTotal: number
  daily: DashboardDailyPoint[]
  aiKinds: DashboardKindPoint[]
}

export interface UserListItem {
  id: string
  phone: string | null
  username: string | null
  nickname: string | null
  status: string
  sex: string | null
  createdAt: string | null
  lastLoginAt: string | null
  weeklyDays: number | null
  goalType: string | null
  workoutCount: number
  deleted: boolean
}

export interface UserProgramBrief {
  id: string
  title: string
  status: string
  version: number
  startDate: string
  weeks: number
  createdAt: string
}

export interface UserWorkoutBrief {
  id: string
  startedAt: string
  durationMin: number | null
  feeling: number | null
}

export interface UserChatBrief {
  id: string
  title: string
  createdAt: string
  messageCount: number
}

export interface UserDetail {
  user: UserListItem
  profile: Record<string, unknown>
  goal: Record<string, unknown>
  programs: UserProgramBrief[]
  workouts: UserWorkoutBrief[]
  chats: UserChatBrief[]
}

export interface PlanListItem {
  id: string
  userId: string
  userLabel: string
  title: string
  goalType: string
  version: number
  status: string
  startDate: string
  weeks: number
  dayCount: number
  exerciseCount: number
  createdAt: string
}

export interface PlanExerciseItem {
  id: string
  slug: string
  nameZh: string
  muscleGroup: string
  equipment: string
  sets: number
  reps: string
  weightKg: number | null
  restSec: number
  rpe: number | null
  notes: string | null
}

export interface PlanDay {
  id: string
  weekIndex: number
  weekday: number
  title: string
  focus: unknown
  exercises: PlanExerciseItem[]
}

export interface PlanDetail {
  plan: PlanListItem
  days: PlanDay[]
}

export interface WorkoutListItem {
  id: string
  userId: string
  userLabel: string
  startedAt: string
  finishedAt: string | null
  durationMin: number | null
  feeling: number | null
  exerciseCount: number
  setCount: number
  volumeKg: number
}

export interface WorkoutSetItem {
  id: string
  slug: string
  nameZh: string | null
  setIndex: number
  weightKg: number | null
  reps: number | null
  rpe: number | null
  completed: boolean
  createdAt: string
}

export interface WorkoutDetail {
  workout: WorkoutListItem
  sets: WorkoutSetItem[]
}

export interface ChatListItem {
  id: string
  userId: string
  userLabel: string
  title: string
  createdAt: string
  messageCount: number
  safetyCount: number
  lastMessageAt: string | null
}

export interface ChatMessageItem {
  id: string
  role: string
  content: string
  citations: unknown
  safetyFlag: string | null
  tokens: number | null
  createdAt: string
}

export interface ChatDetail {
  chat: ChatListItem
  messages: ChatMessageItem[]
}

export interface ScanListItem {
  id: string
  userId: string
  userLabel: string
  imageUrl: string | null
  status: string
  model: string | null
  resultCount: number
  topResult: unknown
  createdAt: string
}

export interface ScanDetail {
  scan: ScanListItem
  result: unknown
}

export interface ExerciseItem {
  slug: string
  nameZh: string
  nameEn: string | null
  muscleGroup: string
  equipment: string
  compound: boolean
  difficulty: number
  instructions: string | null
  videoUrl: string | null
  thumbnailUrl: string | null
  contraindications: unknown
  source: string | null
  license: string | null
  createdAt: string
}

export interface PatchExercisePayload {
  nameZh?: string
  nameEn?: string
  muscleGroup?: string
  equipment?: string
  compound?: boolean
  difficulty?: number
  instructions?: string
  videoUrl?: string
  thumbnailUrl?: string
  contraindications?: string[]
  source?: string
  license?: string
}

export interface VideoItem {
  id: string
  exerciseSlug: string
  exerciseName: string
  title: string
  description: string | null
  videoUrl: string
  posterUrl: string | null
  durationSeconds: number | null
  source: string | null
  licenseNote: string | null
  licenseExpiresAt: string | null
  status: string
  version: number
  createdBy: string | null
  createdAt: string
  updatedAt: string
}

export interface MediaUpload {
  url: string
  originalName: string
  size: number
  contentType: string | null
}

export interface CreateVideoPayload {
  exerciseSlug: string
  title: string
  description?: string
  videoUrl: string
  posterUrl?: string
  durationSeconds?: number | null
  source?: string
  licenseNote?: string
  licenseExpiresAt?: string | null
  status?: 'draft' | 'published'
}

export interface UpdateVideoPayload {
  title?: string
  description?: string
  videoUrl?: string
  posterUrl?: string
  durationSeconds?: number | null
  source?: string
  licenseNote?: string
  licenseExpiresAt?: string | null
}

export interface AiDailyPoint {
  date: string
  total: number
  errors: number
}

export interface AiKindPoint {
  kind: string
  label: string
  total: number
  errors: number
}

export interface AiSkillInfo {
  key: string
  name: string
  description: string
  promptVersion: string
}

export interface AiOverview {
  total: number
  ok: number
  fallback: number
  error: number
  avgLatencyMs: number
  p95LatencyMs: number
  inputTokens: number
  outputTokens: number
  daily: AiDailyPoint[]
  kinds: AiKindPoint[]
  skills: AiSkillInfo[]
}

export interface AiJobItem {
  id: string
  userId: string | null
  userLabel: string | null
  kind: string
  kindLabel: string
  model: string | null
  promptVersion: string | null
  inputTokens: number | null
  outputTokens: number | null
  latencyMs: number | null
  status: string
  error: string | null
  createdAt: string
}

export interface AuditItem {
  id: string
  actor: string
  action: string
  targetType: string
  targetId: string | null
  detail: unknown
  createdAt: string
}

export interface AdminAccount {
  id: string
  username: string
  displayName: string
  status: string
  lastLoginAt: string | null
  createdAt: string
  roles: string[]
}

export interface RoleOption {
  code: string
  name: string
  description: string | null
}

export interface CreateAdminAccountPayload {
  username: string
  password: string
  displayName: string
  roleCode: string
}

export interface UpdateAdminAccountPayload {
  displayName?: string
  status?: string
  roleCodes?: string[]
}
