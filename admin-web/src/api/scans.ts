import { apiDelete, apiGet } from './client'
import type { PageResponse, ScanDetail, ScanListItem } from './types'

export interface ScanQuery {
  q?: string
  status?: string
  page?: number
  size?: number
}

export const scansApi = {
  async list(query: ScanQuery): Promise<PageResponse<ScanListItem>> {
    return apiGet<PageResponse<ScanListItem>>('/scans', { params: query })
  },
  async detail(id: string): Promise<ScanDetail> {
    return apiGet<ScanDetail>(`/scans/${encodeURIComponent(id)}`)
  },
  async remove(id: string): Promise<void> {
    await apiDelete(`/scans/${encodeURIComponent(id)}`)
  },
}
