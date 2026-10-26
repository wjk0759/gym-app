<template>
  <div class="pagination-bar">
    <el-pagination
      :current-page="page"
      :page-size="size"
      :page-sizes="[10, 20, 50, 100]"
      :total="total"
      background
      layout="total, sizes, prev, pager, next"
      @current-change="(value: number) => emit('update:page', value)"
      @size-change="(value: number) => emit('update:size', value)"
    />
  </div>
</template>

<script setup lang="ts">
defineProps<{
  page: number
  size: number
  total: number
}>()

const emit = defineEmits<{
  'update:page': [value: number]
  'update:size': [value: number]
}>()
</script>
