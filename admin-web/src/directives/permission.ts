import type { Directive } from 'vue'
import { useAuthStore } from '@/stores/auth'

export const permission: Directive<HTMLElement, string | string[]> = {
  mounted(element, binding) {
    const auth = useAuthStore()
    if (!auth.hasAnyPermission(binding.value)) {
      element.remove()
    }
  },
}
