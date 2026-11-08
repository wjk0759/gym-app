import { apiDelete, apiGet, apiPatch, apiPost, http } from './client'
import type {
  CreateMediaAssetPayload,
  MediaAssetItem,
  MediaCoverage,
  MediaUpload,
  PageResponse,
  UpdateMediaAssetPayload,
} from './types'

export interface MediaAssetQuery {
  q?: string
  sex?: string
  status?: string
  coverage?: string
  page?: number
  size?: number
}

export const mediaAssetsApi = {
  async list(query: MediaAssetQuery): Promise<PageResponse<MediaAssetItem>> {
    return apiGet<PageResponse<MediaAssetItem>>('/media-assets', { params: query })
  },
  async coverage(): Promise<MediaCoverage> {
    return apiGet<MediaCoverage>('/media-assets/coverage')
  },
  async get(id: string): Promise<MediaAssetItem> {
    return apiGet<MediaAssetItem>(`/media-assets/${encodeURIComponent(id)}`)
  },
  async create(payload: CreateMediaAssetPayload): Promise<MediaAssetItem> {
    return apiPost<MediaAssetItem>('/media-assets', payload)
  },
  async update(id: string, payload: UpdateMediaAssetPayload): Promise<MediaAssetItem> {
    return apiPatch<MediaAssetItem>(`/media-assets/${encodeURIComponent(id)}`, payload)
  },
  async publish(id: string): Promise<MediaAssetItem> {
    return apiPost<MediaAssetItem>(`/media-assets/${encodeURIComponent(id)}/publish`)
  },
  async unpublish(id: string): Promise<MediaAssetItem> {
    return apiPost<MediaAssetItem>(`/media-assets/${encodeURIComponent(id)}/unpublish`)
  },
  async remove(id: string): Promise<void> {
    await apiDelete(`/media-assets/${encodeURIComponent(id)}`)
  },
  async upload(file: File, kind: 'video' | 'poster'): Promise<MediaUpload> {
    const data = new FormData()
    data.append('file', file)
    data.append('kind', kind)
    const response = await http.post<MediaUpload>('/media-assets/upload', data, {
      timeout: 120_000,
    })
    return response.data
  },
}
