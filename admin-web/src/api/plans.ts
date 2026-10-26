import { apiGet, apiPost } from './client'
import type { PageResponse, PlanDetail, PlanListItem } from './types'

export interface PlanQuery {
  q?: string
  status?: string
  page?: number
  size?: number
}

export const plansApi = {
  async list(query: PlanQuery): Promise<PageResponse<PlanListItem>> {
    return apiGet<PageResponse<PlanListItem>>('/plans', { params: query })
  },
  async detail(id: string): Promise<PlanDetail> {
    return apiGet<PlanDetail>(`/plans/${encodeURIComponent(id)}`)
  },
  async archive(id: string): Promise<void> {
    await apiPost(`/plans/${encodeURIComponent(id)}/archive`)
  },
  async activate(id: string): Promise<void> {
    await apiPost(`/plans/${encodeURIComponent(id)}/activate`)
  },
}
