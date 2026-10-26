import { apiGet, apiPatch } from './client'
import type { ExerciseItem, PageResponse, PatchExercisePayload } from './types'

export interface ExerciseQuery {
  q?: string
  muscleGroup?: string
  equipment?: string
  page?: number
  size?: number
}

export const exercisesApi = {
  async list(query: ExerciseQuery): Promise<PageResponse<ExerciseItem>> {
    return apiGet<PageResponse<ExerciseItem>>('/exercises', { params: query })
  },
  async update(slug: string, payload: PatchExercisePayload): Promise<ExerciseItem> {
    return apiPatch<ExerciseItem>(`/exercises/${encodeURIComponent(slug)}`, payload)
  },
}
