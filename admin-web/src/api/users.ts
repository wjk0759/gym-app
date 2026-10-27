import { apiDelete, apiGet, apiPatch, apiPost, downloadBlob } from './client'
import type {
  PageResponse,
  UserDetail,
  UserListItem,
} from './types'

export interface UserQuery {
  q?: string
  status?: string
  includeDeleted?: boolean
  page?: number
  size?: number
}

export const usersApi = {
  async list(query: UserQuery): Promise<PageResponse<UserListItem>> {
    return apiGet<PageResponse<UserListItem>>('/users', { params: query })
  },

  async detail(id: string): Promise<UserDetail> {
    return apiGet<UserDetail>(`/users/${encodeURIComponent(id)}`)
  },

  async setStatus(id: string, status: 'active' | 'suspended'): Promise<void> {
    await apiPatch(`/users/${encodeURIComponent(id)}/status`, { status })
  },

  async remove(id: string): Promise<void> {
    await apiDelete(`/users/${encodeURIComponent(id)}`)
  },

  async purge(id: string): Promise<void> {
    await apiDelete(`/users/${encodeURIComponent(id)}/purge`)
  },

  async restore(id: string): Promise<void> {
    await apiPost(`/users/${encodeURIComponent(id)}/restore`)
  },

  async export(id: string): Promise<void> {
    await downloadBlob(`/users/${encodeURIComponent(id)}/export`, `fitai-user-${id}.json`)
  },
}
