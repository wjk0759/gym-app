import { apiGet } from './client'
import type { AgentRunDetail, AgentRunItem, PageResponse } from './types'

export interface AgentRunFilters {
  status?: string
  intent?: string
  q?: string
  page?: number
  size?: number
}

export const agentApi = {
  async runs(filters: AgentRunFilters = {}): Promise<PageResponse<AgentRunItem>> {
    const params = new URLSearchParams()
    if (filters.status) params.set('status', filters.status)
    if (filters.intent) params.set('intent', filters.intent)
    if (filters.q) params.set('q', filters.q)
    params.set('page', String(filters.page ?? 1))
    params.set('size', String(filters.size ?? 20))
    return apiGet<PageResponse<AgentRunItem>>(`/agent/runs?${params.toString()}`)
  },
  async detail(id: string): Promise<AgentRunDetail> {
    return apiGet<AgentRunDetail>(`/agent/runs/${encodeURIComponent(id)}`)
  },
}
