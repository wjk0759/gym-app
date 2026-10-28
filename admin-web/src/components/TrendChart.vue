<template>
  <div ref="chartRef" class="trend-chart" :style="{ height }" />
</template>

<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { LineChart } from 'echarts/charts'
import { GridComponent, LegendComponent, TooltipComponent } from 'echarts/components'
import { init, type ECharts } from 'echarts/core'

use([CanvasRenderer, LineChart, GridComponent, LegendComponent, TooltipComponent])

export interface TrendSeries {
  name: string
  data: number[]
  color?: string
}

const props = withDefaults(defineProps<{
  labels: string[]
  series: TrendSeries[]
  height?: string
}>(), {
  height: '280px',
})

const chartRef = ref<HTMLDivElement | null>(null)
let chart: ECharts | null = null
let observer: ResizeObserver | null = null

function render(): void {
  if (!chart) return
  chart.setOption({
    backgroundColor: 'transparent',
    color: props.series.map((item) => item.color ?? '#5b8cff'),
    grid: { top: 36, right: 18, bottom: 30, left: 44 },
    tooltip: {
      trigger: 'axis',
      backgroundColor: 'rgba(17, 25, 37, 0.96)',
      borderColor: 'rgba(148, 163, 184, 0.2)',
      textStyle: { color: '#e8eef8' },
    },
    legend: {
      top: 0,
      right: 8,
      textStyle: { color: '#8d9bb1' },
    },
    xAxis: {
      type: 'category',
      boundaryGap: false,
      data: props.labels,
      axisLine: { lineStyle: { color: 'rgba(148, 163, 184, 0.18)' } },
      axisLabel: { color: '#64748b', fontSize: 11 },
      axisTick: { show: false },
    },
    yAxis: {
      type: 'value',
      minInterval: 1,
      splitLine: { lineStyle: { color: 'rgba(148, 163, 184, 0.08)' } },
      axisLabel: { color: '#64748b', fontSize: 11 },
    },
    series: props.series.map((item) => ({
      name: item.name,
      type: 'line',
      smooth: true,
      symbol: 'circle',
      symbolSize: 5,
      showSymbol: false,
      lineStyle: { width: 2 },
      areaStyle: { opacity: 0.08 },
      data: item.data,
    })),
  })
}

onMounted(() => {
  if (!chartRef.value) return
  chart = init(chartRef.value)
  render()
  observer = new ResizeObserver(() => chart?.resize())
  observer.observe(chartRef.value)
})

watch(() => [props.labels, props.series], render, { deep: true })

onBeforeUnmount(() => {
  observer?.disconnect()
  chart?.dispose()
  chart = null
})
</script>

<style scoped>
.trend-chart {
  width: 100%;
}
</style>
