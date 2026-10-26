import { computed, ref } from 'vue'
import { defineStore } from 'pinia'
import { authApi } from '@/api/auth'
import { setAccessToken, setRefreshHandler } from '@/api/session'
import type { AdminUser, LoginResponse } from '@/api/types'

export const useAuthStore = defineStore('auth', () => {
  const user = ref<AdminUser | null>(null)
  const initialized = ref(false)
  const busy = ref(false)

  const isAuthenticated = computed(() => Boolean(user.value))
  const permissions = computed(() => new Set(user.value?.permissions ?? []))

  function applySession(response: LoginResponse): void {
    user.value = response.user
    setAccessToken(response.accessToken)
  }

  function clearSession(): void {
    user.value = null
    setAccessToken(null)
  }

  function hasPermission(permission: string): boolean {
    return permissions.value.has(permission)
  }

  function hasAnyPermission(required: string | string[] | undefined): boolean {
    if (!required) {
      return true
    }
    const list = Array.isArray(required) ? required : [required]
    return list.some((permission) => permissions.value.has(permission))
  }

  async function login(username: string, password: string): Promise<void> {
    busy.value = true
    try {
      applySession(await authApi.login({ username, password }))
      initialized.value = true
    } finally {
      busy.value = false
    }
  }

  async function refreshSession(): Promise<boolean> {
    try {
      applySession(await authApi.refresh())
      return true
    } catch {
      clearSession()
      return false
    }
  }

  async function bootstrap(): Promise<void> {
    if (initialized.value) {
      return
    }
    initialized.value = true
    await refreshSession()
  }

  async function logout(): Promise<void> {
    busy.value = true
    try {
      await authApi.logout()
    } catch {
      // The local session must still be cleared if the API is unavailable.
    } finally {
      clearSession()
      busy.value = false
    }
  }

  function installSessionHandlers(): void {
    setRefreshHandler(refreshSession)
  }

  return {
    user,
    initialized,
    busy,
    isAuthenticated,
    permissions,
    login,
    refreshSession,
    bootstrap,
    logout,
    clearSession,
    hasPermission,
    hasAnyPermission,
    installSessionHandlers,
  }
})
