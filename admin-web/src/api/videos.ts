import { apiDelete, apiGet, apiPatch, apiPost, http } from './client'
import type {
  CreateVideoPayload,
  MediaUpload,
  PageResponse,
  UpdateVideoPayload,
  VideoItem,
} from './types'

export interface VideoQuery {
  q?: string
  status?: string
  exerciseSlug?: string
  page?: number
  size?: number
}

export const videosApi = {
  async list(query: VideoQuery): Promise<PageResponse<VideoItem>> {
    return apiGet<PageResponse<VideoItem>>('/videos', { params: query })
  },
  async get(id: string): Promise<VideoItem> {
    return apiGet<VideoItem>(`/videos/${encodeURIComponent(id)}`)
  },
  async create(payload: CreateVideoPayload): Promise<VideoItem> {
    return apiPost<VideoItem>('/videos', payload)
  },
  async update(id: string, payload: UpdateVideoPayload): Promise<VideoItem> {
    return apiPatch<VideoItem>(`/videos/${encodeURIComponent(id)}`, payload)
  },
  async publish(id: string): Promise<VideoItem> {
    return apiPost<VideoItem>(`/videos/${encodeURIComponent(id)}/publish`)
  },
  async unpublish(id: string): Promise<VideoItem> {
    return apiPost<VideoItem>(`/videos/${encodeURIComponent(id)}/unpublish`)
  },
  async remove(id: string): Promise<void> {
    await apiDelete(`/videos/${encodeURIComponent(id)}`)
  },
  async upload(file: File, kind: 'video' | 'poster'): Promise<MediaUpload> {
    const data = new FormData()
    data.append('file', file)
    data.append('kind', kind)
    const response = await http.post<MediaUpload>('/videos/upload', data, {
      timeout: 120_000,
    })
    return response.data
  },
}
