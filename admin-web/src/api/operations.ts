import { apiGet } from './client'
import type {
  AiJobItem,
  AiOverview,
  AuditItem,
  DashboardSummary,
  PageResponse,
} from './types'

export interface AiJobQuery {
  kind?: string
  status?: string
  q?: string
  page?: number
  size?: number
}

export interface AuditQuery {
  actor?: string
  action?: string
  targetType?: string
  page?: number
  size?: number
}

export const dashboardApi = {
  async summary(): Promise<DashboardSummary> {
    return apiGet<DashboardSummary>('/dashboard/summary')
  },
}

export const aiApi = {
  async overview(): Promise<AiOverview> {
    return apiGet<AiOverview>('/ai/overview')
  },
  async jobs(query: AiJobQuery): Promise<PageResponse<AiJobItem>> {
    return apiGet<PageResponse<AiJobItem>>('/ai/jobs', { params: query })
  },
}

export const auditApi = {
  async list(query: AuditQuery): Promise<PageResponse<AuditItem>> {
    return apiGet<PageResponse<AuditItem>>('/audit', { params: query })
  },
}
