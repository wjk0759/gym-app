<template>
  <div class="status-page">
    <p class="code">403</p>
    <h1>没有访问权限</h1>
    <p>当前管理员角色没有该模块的权限。请切换账号或联系超级管理员。</p>
    <div class="actions">
      <el-button type="primary" @click="router.push('/dashboard')">返回总览</el-button>
      <el-button @click="auth.logout().then(() => router.replace('/login'))">退出登录</el-button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const auth = useAuthStore()
</script>

<style scoped>
.status-page {
  display: grid;
  min-height: 100vh;
  place-content: center;
  justify-items: center;
  padding: 24px;
  text-align: center;
}

.code {
  margin: 0;
  color: #5b8cff;
  font-family: 'JetBrains Mono', monospace;
  font-size: 80px;
  font-weight: 800;
  line-height: 1;
  opacity: 0.78;
}

h1 {
  margin: 18px 0 8px;
  font-size: 24px;
}

p {
  max-width: 420px;
  margin: 0 0 24px;
  color: var(--fitai-text-muted);
  font-size: 13px;
  line-height: 1.7;
}

.actions {
  display: flex;
  gap: 10px;
}
</style>
