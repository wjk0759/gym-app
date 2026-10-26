import { http, plainHttp } from './client'
import type { AdminUser, LoginResponse } from './types'

export interface LoginPayload {
  username: string
  password: string
}

export interface ChangePasswordPayload {
  currentPassword: string
  newPassword: string
}

export const authApi = {
  async login(payload: LoginPayload): Promise<LoginResponse> {
    const { data } = await plainHttp.post<LoginResponse>('/auth/login', payload)
    return data
  },

  async refresh(): Promise<LoginResponse> {
    const { data } = await plainHttp.post<LoginResponse>('/auth/refresh')
    return data
  },

  async logout(): Promise<void> {
    await plainHttp.post('/auth/logout')
  },

  async me(): Promise<AdminUser> {
    const { data } = await http.get<AdminUser>('/auth/me')
    return data
  },

  async changePassword(payload: ChangePasswordPayload): Promise<void> {
    await http.post('/auth/change-password', payload)
  },
}
