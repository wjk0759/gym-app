import { apiDelete, apiGet } from './client'
import type { PageResponse, WorkoutDetail, WorkoutListItem } from './types'

export interface WorkoutQuery {
  q?: string
  page?: number
  size?: number
}

export const workoutsApi = {
  async list(query: WorkoutQuery): Promise<PageResponse<WorkoutListItem>> {
    return apiGet<PageResponse<WorkoutListItem>>('/workouts', { params: query })
  },
  async detail(id: string): Promise<WorkoutDetail> {
    return apiGet<WorkoutDetail>(`/workouts/${encodeURIComponent(id)}`)
  },
  async remove(id: string): Promise<void> {
    await apiDelete(`/workouts/${encodeURIComponent(id)}`)
  },
}
