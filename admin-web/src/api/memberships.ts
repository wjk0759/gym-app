import { apiGet } from './client'
import type {
  MembershipItem,
  MembershipSummary,
  PageResponse,
} from './types'

export interface MembershipQuery {
  q?: string
  source?: string
  status?: string
  page?: number
  size?: number
}

export const membershipsApi = {
  async list(query: MembershipQuery): Promise<PageResponse<MembershipItem>> {
    return apiGet<PageResponse<MembershipItem>>('/memberships', { params: query })
  },
  async summary(): Promise<MembershipSummary> {
    return apiGet<MembershipSummary>('/memberships/summary')
  },
}
