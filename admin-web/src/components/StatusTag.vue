<template>
  <el-tag :type="statusTagType(status)" effect="plain" size="small">
    {{ statusLabel(status) }}
  </el-tag>
</template>

<script setup lang="ts">
import { statusLabel, statusTagType } from '@/utils/format'

defineProps<{
  status: string | null | undefined
}>()
</script>
