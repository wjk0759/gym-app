import { apiDelete, apiGet } from './client'
import type { ChatDetail, ChatListItem, PageResponse } from './types'

export interface ChatQuery {
  q?: string
  safetyOnly?: boolean
  page?: number
  size?: number
}

export const chatsApi = {
  async list(query: ChatQuery): Promise<PageResponse<ChatListItem>> {
    return apiGet<PageResponse<ChatListItem>>('/chats', { params: query })
  },
  async detail(id: string): Promise<ChatDetail> {
    return apiGet<ChatDetail>(`/chats/${encodeURIComponent(id)}`)
  },
  async remove(id: string): Promise<void> {
    await apiDelete(`/chats/${encodeURIComponent(id)}`)
  },
}
