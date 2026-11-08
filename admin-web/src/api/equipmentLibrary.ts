import { apiGet } from './client'
import type { EquipmentLibraryItem, PageResponse } from './types'

export interface EquipmentLibraryQuery {
  q?: string
  source?: string
  page?: number
  size?: number
}

export const equipmentLibraryApi = {
  async list(query: EquipmentLibraryQuery): Promise<PageResponse<EquipmentLibraryItem>> {
    return apiGet<PageResponse<EquipmentLibraryItem>>('/equipment-library', { params: query })
  },
}
