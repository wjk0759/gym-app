import { apiGet } from './client'
import type { DietSummary } from './types'

export const dietApi = {
  async summary(): Promise<DietSummary> {
    return apiGet<DietSummary>('/diet/summary')
  },
}
