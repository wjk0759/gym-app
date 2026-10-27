import { apiGet } from './client'
import type {
  AgentActionItem,
  AgentRunDetail,
  AgentRunItem,
  PageResponse,
} from './types'

export interface AgentRunFilters {
  status?: string
  intent?: string
  q?: string
  page?: number
  size?: number
}

export interface AgentActionFilters {
  status?: string
  actionType?: string
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
  async actions(filters: AgentActionFilters = {}): Promise<PageResponse<AgentActionItem>> {
    const params = new URLSearchParams()
    if (filters.status) params.set('status', filters.status)
    if (filters.actionType) params.set('actionType', filters.actionType)
    if (filters.q) params.set('q', filters.q)
    params.set('page', String(filters.page ?? 1))
    params.set('size', String(filters.size ?? 20))
    return apiGet<PageResponse<AgentActionItem>>(`/agent/actions?${params.toString()}`)
  },
}
