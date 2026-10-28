import { createApp } from 'vue'
import { createPinia } from 'pinia'
import { ElLoading } from 'element-plus'
import 'element-plus/theme-chalk/dark/css-vars.css'
import 'element-plus/es/components/base/style/css'
import 'element-plus/es/components/loading/style/css'
import 'element-plus/es/components/message/style/css'
import 'element-plus/es/components/message-box/style/css'
import './styles/base.css'

import App from './App.vue'
import router from './router'
import { permission } from '@/directives/permission'
import { useAuthStore } from '@/stores/auth'
import { setUnauthorizedHandler } from '@/api/session'

const app = createApp(App)
const pinia = createPinia()
app.use(pinia)

const auth = useAuthStore(pinia)
auth.installSessionHandlers()

setUnauthorizedHandler(() => {
  auth.clearSession()
  const current = router.currentRoute.value
  if (current.name !== 'login') {
    void router.replace({ name: 'login', query: { redirect: current.fullPath } })
  }
})

app.directive('permission', permission)
app.directive('loading', ElLoading.directive)
app.use(router)

router.isReady().then(() => {
  app.mount('#app')
})
