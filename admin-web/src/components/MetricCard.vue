<template>
  <div class="metric-card" :style="{ '--metric-glow': glow }">
    <div class="metric-label">{{ label }}</div>
    <div class="metric-value">{{ value }}</div>
    <div v-if="foot" class="metric-foot">{{ foot }}</div>
  </div>
</template>

<script setup lang="ts">
withDefaults(defineProps<{
  label: string
  value: string | number
  foot?: string
  glow?: string
}>(), {
  foot: '',
  glow: 'rgba(91, 140, 255, 0.24)',
})
</script>
