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
  active7d: number
  active30d: number
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
  aiErrors: number
  daily: DashboardDailyPoint[]
  aiKinds: DashboardKindPoint[]
  goals: DashboardGoalCount[]
  equipment: DashboardEquipmentCount[]
  recentUsers: DashboardRecentUser[]
  recentWorkouts: DashboardRecentWorkout[]
  recentSafety: DashboardRecentSafety[]
}

export interface DashboardGoalCount {
  type: string
  label: string
  count: number
}

export interface DashboardEquipmentCount {
  type: string
  count: number
}

export interface DashboardRecentUser {
  id: string
  nickname: string
  createdAt: string
}

export interface DashboardRecentWorkout {
  id: string
  userId: string
  nickname: string
  startedAt: string
  setCount: number
  volumeKg: number
  durationMin: number | null
}

export interface DashboardRecentSafety {
  id: string
  userId: string
  nickname: string
  safetyFlag: string
  content: string
  createdAt: string
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
  test: boolean
  updatedAt: string | null
  authMethods: Record<string, boolean>
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

export interface UserScanBrief {
  id: string
  status: string
  model: string | null
  result: unknown
  createdAt: string
}

export interface UserMealBrief {
  id: string
  planDate: string
  targetKcal: number | null
  createdAt: string
}

export interface UserAiJobBrief {
  id: string
  kind: string
  model: string | null
  status: string
  latencyMs: number | null
  error: string | null
  createdAt: string
}

export interface UserMetrics {
  workouts: number
  volumeKg: number
  programs: number
  chats: number
  scans: number
  meals: number
}

export interface UserDetail {
  user: UserListItem
  profile: Record<string, unknown>
  goal: Record<string, unknown>
  metrics: UserMetrics
  goals: Array<Record<string, unknown>>
  programs: UserProgramBrief[]
  workouts: UserWorkoutBrief[]
  chats: UserChatBrief[]
  scans: UserScanBrief[]
  meals: UserMealBrief[]
  aiJobs: UserAiJobBrief[]
}

export interface UserBodyMetric {
  id: string
  measuredAt: string | null
  weightKg: number | null
  bodyFatPct: number | null
  waistCm: number | null
  armCm: number | null
  thighCm: number | null
  createdAt: string | null
}

export interface UserMealPlan {
  id: string
  planDate: string | null
  weekStart: string | null
  strategy: string
  generatedBy: string
  modelName: string | null
  targetKcal: number | null
  targetProteinG: number | null
  targetCarbG: number | null
  targetFatG: number | null
  plan: unknown
  createdAt: string | null
  updatedAt: string | null
}

export interface UserFoodLog {
  id: string
  loggedAt: string | null
  meal: string
  foodName: string
  grams: number | null
  kcal: number | null
  protein: number | null
  carbs: number | null
  fat: number | null
  fiber: number | null
}

export interface UserScheduleItem {
  planId: string
  dayId: string
  planVersion: number | null
  assignedDate: string | null
  skippedAt: string | null
  clientUpdatedAt: string | null
  updatedAt: string | null
}

export interface UserWatchSession {
  id: string
  deviceName: string | null
  deviceId: string | null
  createdAt: string | null
  lastUsedAt: string | null
  lastTouchedAt: string | null
  expiresAt: string | null
  revokedAt: string | null
}

export interface UserWatchWorkout {
  id: string
  startedAt: string | null
  durationMin: number | null
  feeling: number | null
  healthkitWorkoutId: string | null
}

export interface UserMemory {
  id: string
  kind: string
  content: string
  memoryKey: string
  source: string
  confidence: number | null
  active: boolean
  createdAt: string | null
  updatedAt: string | null
  lastUsedAt: string | null
}

export interface UserEquipment {
  id: string
  name: string
  slug: string | null
  muscle: string | null
  equipment: string | null
  notes: string
  source: string
  createdAt: string | null
  updatedAt: string | null
}

export interface UserInsights {
  bodyMetrics: UserBodyMetric[]
  mealPlans: UserMealPlan[]
  foodLogs: UserFoodLog[]
  schedule: UserScheduleItem[]
  watchSessions: UserWatchSession[]
  watchWorkouts: UserWatchWorkout[]
  memories: UserMemory[]
  equipment: UserEquipment[]
}

export interface UserEntitlementItem {
  id: string
  planCode: string
  source: string
  startsAt: string | null
  expiresAt: string | null
  revokedAt: string | null
  grantedBy: string | null
  reason: string | null
  createdAt: string | null
}

export interface UserTrialItem {
  featureKey: string
  source: string
  usedAt: string | null
  validUntil: string | null
}

export interface UserCoachUsage {
  dailyLimit: number
  used: number
  remaining: number
  periodStart: string
  resetAt: string
}

export interface UserAccess {
  pro: boolean
  proExpiresAt: string | null
  sources: string[]
  entitlements: UserEntitlementItem[]
  trials: UserTrialItem[]
  coach: UserCoachUsage
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

export interface MediaAssetItem {
  id: string
  exerciseSlug: string
  exerciseName: string
  sex: string
  source: string
  phoneUrl: string
  watchUrl: string
  posterUrl: string | null
  durationSeconds: number | null
  loopStartMs: number | null
  loopEndMs: number | null
  watchSha256: string | null
  version: number
  status: string
  licenseNote: string | null
  licenseExpiresAt: string | null
  purchaseRef: string | null
  createdAt: string
  updatedAt: string
}

export interface MediaCoverageMissing {
  slug: string
  nameZh: string
  muscleGroup: string
}

export interface MediaCoverage {
  activeExercises: number
  exercisesWithAnyMedia: number
  exercisesWithMale: number
  exercisesWithFemale: number
  exercisesWithUnisex: number
  phoneReady: number
  watchReady: number
  posterReady: number
  licenseExpiring30d: number
  missingAnyCount: number
  missingMaleCount: number
  missingFemaleCount: number
  missingAny: MediaCoverageMissing[]
  missingMale: MediaCoverageMissing[]
  missingFemale: MediaCoverageMissing[]
}

export interface CreateMediaAssetPayload {
  exerciseSlug: string
  sex: 'male' | 'female' | 'unisex'
  source: string
  phoneUrl: string
  watchUrl: string
  posterUrl?: string | null
  durationSeconds?: number | null
  loopStartMs?: number | null
  loopEndMs?: number | null
  watchSha256?: string | null
  licenseNote?: string | null
  licenseExpiresAt?: string | null
  purchaseRef?: string | null
  status?: 'draft' | 'published'
}

export interface UpdateMediaAssetPayload {
  source?: string
  phoneUrl?: string
  watchUrl?: string
  posterUrl?: string | null
  durationSeconds?: number | null
  loopStartMs?: number | null
  loopEndMs?: number | null
  watchSha256?: string | null
  licenseNote?: string | null
  licenseExpiresAt?: string | null
  purchaseRef?: string | null
}

export interface MembershipItem {
  entitlementId: string
  userId: string
  userLabel: string
  phone: string | null
  nickname: string | null
  planCode: string
  source: string
  sourceRef: string | null
  startsAt: string | null
  expiresAt: string | null
  revokedAt: string | null
  status: string
  daysLeft: number | null
  grantedBy: string | null
  reason: string | null
  createdAt: string | null
}

export interface MembershipSourceCount {
  source: string
  count: number
}

export interface MembershipSummary {
  activeProUsers: number
  activeEntitlements: number
  expiring7d: number
  expiring30d: number
  newGrants7d: number
  revoked30d: number
  sources: MembershipSourceCount[]
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

export interface AiControl {
  enabled: boolean
  reason: string | null
  updatedBy: string | null
  updatedAt: string | null
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


export interface AgentRunItem {
  id: string
  userId: string
  userLabel: string
  sessionId: string | null
  intent: string
  status: string
  model: string | null
  stepCount: number
  inputText: string
  outputText: string | null
  error: string | null
  createdAt: string
  completedAt: string | null
  proposalId: string | null
  proposalStatus: string | null
}

export interface AgentStepItem {
  id: string
  stepIndex: number
  stepType: string
  toolName: string | null
  status: string
  latencyMs: number | null
  input: unknown
  output: unknown
  error: string | null
  createdAt: string
}

export interface AgentProposalItem {
  id: string
  title: string
  status: string
  baseVersion: number | null
  diff: unknown
  validation: unknown
  createdAt: string
  expiresAt: string
  appliedAt: string | null
}

export interface AgentRunDetail {
  run: AgentRunItem
  steps: AgentStepItem[]
  proposals: AgentProposalItem[]
}

export interface AgentActionItem {
  id: string
  userId: string
  userLabel: string
  runId: string | null
  actionId: string
  actionType: string
  status: string
  message: string | null
  detail: unknown
  createdAt: string
}

export interface ScheduleStateItem {
  id: string
  userId: string
  userLabel: string
  planId: string
  planVersion: number | null
  dayId: string
  assignedDate: string | null
  skippedAt: string | null
  clientUpdatedAt: string
  updatedAt: string
}
