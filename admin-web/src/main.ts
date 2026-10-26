import { createApp } from 'vue'
import { createPinia } from 'pinia'
import ElementPlus from 'element-plus'
import zhCn from 'element-plus/es/locale/lang/zh-cn'
import 'element-plus/dist/index.css'
import 'element-plus/theme-chalk/dark/css-vars.css'
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
app.use(router)
app.use(ElementPlus, { locale: zhCn })

router.isReady().then(() => {
  app.mount('#app')
})
