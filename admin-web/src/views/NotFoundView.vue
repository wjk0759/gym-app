<template>
  <div class="status-page">
    <p class="code">404</p>
    <h1>页面不存在</h1>
    <p>你访问的管理页面不存在，可能已被移动或链接有误。</p>
    <el-button type="primary" @click="router.push('/dashboard')">返回总览</el-button>
  </div>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'

const router = useRouter()
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
  color: #3ddc97;
  font-family: 'JetBrains Mono', monospace;
  font-size: 80px;
  font-weight: 800;
  line-height: 1;
  opacity: 0.72;
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
</style>
