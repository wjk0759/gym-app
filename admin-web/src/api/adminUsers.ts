import { apiGet, apiPatch, apiPost } from './client'
import type {
  AdminAccount,
  CreateAdminAccountPayload,
  RoleOption,
  UpdateAdminAccountPayload,
} from './types'

export const adminUsersApi = {
  async list(): Promise<AdminAccount[]> {
    return apiGet<AdminAccount[]>('/admin-users')
  },
  async roles(): Promise<RoleOption[]> {
    return apiGet<RoleOption[]>('/admin-users/roles')
  },
  async create(payload: CreateAdminAccountPayload): Promise<AdminAccount> {
    return apiPost<AdminAccount>('/admin-users', payload)
  },
  async update(id: string, payload: UpdateAdminAccountPayload): Promise<AdminAccount> {
    return apiPatch<AdminAccount>(`/admin-users/${encodeURIComponent(id)}`, payload)
  },
  async resetPassword(id: string, password: string): Promise<void> {
    await apiPost(`/admin-users/${encodeURIComponent(id)}/reset-password`, { password })
  },
}
