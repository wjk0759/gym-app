import { apiDelete, apiGet, apiPatch, apiPost, downloadBlob } from './client'
import type {
  PageResponse,
  UserAccess,
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

  async access(id: string): Promise<UserAccess> {
    return apiGet<UserAccess>(`/users/${encodeURIComponent(id)}/access`)
  },

  async grantAccess(id: string, durationDays: number, reason: string): Promise<UserAccess> {
    return apiPost<UserAccess>(`/users/${encodeURIComponent(id)}/entitlements`, {
      durationDays,
      reason,
    })
  },

  async revokeAccess(id: string, entitlementId: string, reason: string): Promise<UserAccess> {
    return apiPost<UserAccess>(
      `/users/${encodeURIComponent(id)}/entitlements/${encodeURIComponent(entitlementId)}/revoke`,
      { reason },
    )
  },

  async resetTrial(id: string, featureKey: string): Promise<UserAccess> {
    return apiPost<UserAccess>(
      `/users/${encodeURIComponent(id)}/trials/${encodeURIComponent(featureKey)}/reset`,
    )
  },
}
