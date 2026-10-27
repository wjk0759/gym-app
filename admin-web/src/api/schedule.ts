import { apiGet } from './client'
import type { PageResponse, ScheduleStateItem } from './types'

export interface ScheduleStateFilters {
  q?: string
  planId?: string
  page?: number
  size?: number
}

export const scheduleApi = {
  async list(filters: ScheduleStateFilters = {}): Promise<PageResponse<ScheduleStateItem>> {
    const params = new URLSearchParams()
    if (filters.q) params.set('q', filters.q)
    if (filters.planId) params.set('planId', filters.planId)
    params.set('page', String(filters.page ?? 1))
    params.set('size', String(filters.size ?? 20))
    return apiGet<PageResponse<ScheduleStateItem>>(`/schedule?${params.toString()}`)
  },
}
