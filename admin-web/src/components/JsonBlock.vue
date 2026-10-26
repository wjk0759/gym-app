<template>
  <pre class="json-block">{{ prettyJson(value) }}</pre>
</template>

<script setup lang="ts">
import { prettyJson } from '@/utils/format'

defineProps<{
  value: unknown
}>()
</script>
