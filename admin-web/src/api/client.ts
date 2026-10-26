import axios, { AxiosError, type AxiosRequestConfig, type InternalAxiosRequestConfig } from 'axios'
import { getAccessToken, notifyUnauthorized, requestRefresh, setAccessToken } from './session'
import type { ApiProblem } from './types'

export const API_BASE = import.meta.env.VITE_API_BASE ?? '/api/admin/v1'

export const http = axios.create({
  baseURL: API_BASE,
  withCredentials: true,
  timeout: 30_000,
})

/** The login/refresh calls must never enter the 401 refresh loop. */
export const plainHttp = axios.create({
  baseURL: API_BASE,
  withCredentials: true,
  timeout: 30_000,
})

interface RetryConfig extends InternalAxiosRequestConfig {
  _retry?: boolean
}

let refreshInFlight: Promise<boolean> | null = null

async function refreshOnce(): Promise<boolean> {
  if (!refreshInFlight) {
    refreshInFlight = requestRefresh().finally(() => {
      refreshInFlight = null
    })
  }
  return refreshInFlight
}

http.interceptors.request.use((config) => {
  const token = getAccessToken()
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

http.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const original = error.config as RetryConfig | undefined
    const status = error.response?.status
    if (status === 401 && original && !original._retry) {
      original._retry = true
      const refreshed = await refreshOnce()
      if (refreshed) {
        const token = getAccessToken()
        if (token) {
          original.headers.Authorization = `Bearer ${token}`
        }
        return http.request(original)
      }
      setAccessToken(null)
      notifyUnauthorized()
    }
    return Promise.reject(error)
  },
)

export function errorMessage(error: unknown): string {
  if (axios.isAxiosError(error)) {
    const problem = error.response?.data as ApiProblem | undefined
    if (problem?.errors?.length) {
      return problem.errors.map((item) => item.message).join('；')
    }
    return problem?.detail || problem?.title || error.message || '请求失败'
  }
  if (error instanceof Error) {
    return error.message
  }
  return '请求失败'
}

export async function downloadBlob(path: string, filename: string): Promise<void> {
  const response = await http.get<Blob>(path, { responseType: 'blob' })
  const url = URL.createObjectURL(response.data)
  const anchor = document.createElement('a')
  anchor.href = url
  anchor.download = filename
  document.body.appendChild(anchor)
  anchor.click()
  anchor.remove()
  URL.revokeObjectURL(url)
}

export async function apiGet<T>(path: string, config?: AxiosRequestConfig): Promise<T> {
  const response = await http.get<T>(path, config)
  return response.data
}

export async function apiPost<T>(path: string, data?: unknown): Promise<T> {
  const response = await http.post<T>(path, data)
  return response.data
}

export async function apiPatch<T>(path: string, data?: unknown): Promise<T> {
  const response = await http.patch<T>(path, data)
  return response.data
}

export async function apiDelete(path: string): Promise<void> {
  await http.delete(path)
}
