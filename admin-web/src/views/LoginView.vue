<template>
  <div class="login-page">
    <section class="login-visual">
      <div class="brand-mark">F</div>
      <div class="visual-copy">
        <p class="eyebrow">FITAI CONTROL PLANE</p>
        <h1>把训练数据，<br />变成可运营的洞察。</h1>
        <p class="visual-text">
          企业级 FitAI 管理控制台，覆盖用户、计划、训练、对话、器械、内容与 AI 质量。
        </p>
        <div class="visual-points">
          <span>RBAC 权限</span>
          <span>全链路审计</span>
          <span>AI 质量监控</span>
        </div>
      </div>
      <p class="visual-foot">FitAI · Admin v1.0</p>
    </section>

    <section class="login-panel">
      <div class="login-card">
        <div class="login-heading">
          <p class="eyebrow">WELCOME BACK</p>
          <h2>登录管理控制台</h2>
          <p>使用管理员账号继续，所有敏感操作都会写入审计日志。</p>
        </div>

        <el-form ref="formRef" :model="form" :rules="rules" label-position="top" @submit.prevent="submit">
          <el-form-item label="管理员账号" prop="username">
            <el-input v-model="form.username" size="large" autocomplete="username" placeholder="请输入账号">
              <template #prefix><el-icon><User /></el-icon></template>
            </el-input>
          </el-form-item>
          <el-form-item label="密码" prop="password">
            <el-input
              v-model="form.password"
              size="large"
              type="password"
              show-password
              autocomplete="current-password"
              placeholder="请输入密码"
              @keyup.enter="submit"
            >
              <template #prefix><el-icon><Lock /></el-icon></template>
            </el-input>
          </el-form-item>
          <el-alert v-if="error" :title="error" type="error" :closable="false" show-icon />
          <el-button class="login-button" type="primary" size="large" :loading="loading" @click="submit">
            登录控制台
          </el-button>
        </el-form>

        <p class="login-hint">初始账号由部署环境变量注入；忘记密码请联系超级管理员。</p>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
import { Lock, User } from '@element-plus/icons-vue'
import { useAuthStore } from '@/stores/auth'
import { errorMessage } from '@/api/client'

const auth = useAuthStore()
const route = useRoute()
const router = useRouter()
const formRef = ref<FormInstance>()
const loading = ref(false)
const error = ref('')
const form = reactive({ username: '', password: '' })

const rules: FormRules = {
  username: [{ required: true, message: '请输入管理员账号', trigger: 'blur' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }],
}

async function submit(): Promise<void> {
  if (loading.value) return
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return
  loading.value = true
  error.value = ''
  try {
    await auth.login(form.username.trim(), form.password)
    ElMessage.success('登录成功')
    const redirect = typeof route.query.redirect === 'string' && route.query.redirect.startsWith('/')
      ? route.query.redirect
      : '/dashboard'
    await router.replace(redirect)
  } catch (reason) {
    error.value = errorMessage(reason)
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-page {
  display: grid;
  min-height: 100vh;
  grid-template-columns: minmax(0, 1.1fr) minmax(420px, 0.9fr);
}

.login-visual {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding: 52px clamp(32px, 6vw, 92px);
  border-right: 1px solid var(--fitai-border);
  background:
    linear-gradient(140deg, rgba(91, 140, 255, 0.2), transparent 45%),
    radial-gradient(circle at 80% 78%, rgba(61, 220, 151, 0.12), transparent 22rem),
    #0b111b;
}

.brand-mark {
  display: grid;
  width: 46px;
  height: 46px;
  place-items: center;
  border: 1px solid rgba(91, 140, 255, 0.36);
  border-radius: 14px;
  background: rgba(91, 140, 255, 0.16);
  color: #cfe0ff;
  font-size: 24px;
  font-weight: 800;
}

.eyebrow {
  margin: 0;
  color: #7f9ee8;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.18em;
}

.visual-copy h1 {
  max-width: 620px;
  margin: 18px 0 20px;
  color: #f3f7ff;
  font-size: clamp(36px, 4.7vw, 66px);
  line-height: 1.08;
  letter-spacing: -0.045em;
}

.visual-text {
  max-width: 520px;
  margin: 0;
  color: #93a3ba;
  font-size: 15px;
  line-height: 1.8;
}

.visual-points {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-top: 34px;
}

.visual-points span {
  padding: 8px 12px;
  border: 1px solid rgba(148, 163, 184, 0.18);
  border-radius: 999px;
  background: rgba(20, 27, 39, 0.6);
  color: #aab8cc;
  font-size: 12px;
}

.visual-foot {
  margin: 0;
  color: #57677f;
  font-size: 12px;
}

.login-panel {
  display: grid;
  place-items: center;
  padding: 32px;
  background: rgba(8, 12, 19, 0.56);
}

.login-card {
  width: min(420px, 100%);
}

.login-heading h2 {
  margin: 12px 0 8px;
  color: #f1f5fb;
  font-size: 26px;
  letter-spacing: -0.03em;
}

.login-heading > p:last-child {
  margin: 0 0 28px;
  color: var(--fitai-text-muted);
  font-size: 13px;
  line-height: 1.65;
}

.login-button {
  width: 100%;
  margin-top: 8px;
}

.login-hint {
  margin: 22px 0 0;
  color: var(--fitai-text-faint);
  font-size: 12px;
  line-height: 1.6;
  text-align: center;
}

:deep(.el-alert) {
  margin-bottom: 14px;
}

@media (max-width: 900px) {
  .login-page {
    grid-template-columns: 1fr;
  }

  .login-visual {
    min-height: 280px;
    padding: 32px 24px;
    border-right: 0;
    border-bottom: 1px solid var(--fitai-border);
  }

  .visual-copy h1 {
    margin: 14px 0;
    font-size: clamp(30px, 8vw, 44px);
  }

  .visual-text {
    font-size: 13px;
  }

  .visual-points,
  .visual-foot {
    display: none;
  }

  .login-panel {
    padding: 34px 22px 50px;
  }
}
</style>
