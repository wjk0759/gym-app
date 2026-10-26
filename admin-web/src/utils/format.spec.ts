import { describe, expect, it } from 'vitest'
import {
  formatDate,
  formatDuration,
  formatNumber,
  goalLabel,
  prettyJson,
  shortId,
  statusLabel,
  statusTagType,
} from './format'

describe('format helpers', () => {
  it('formats dates and durations for the admin UI', () => {
    expect(formatDate('2026-10-27')).toBe('2026-10-27')
    expect(formatDate(null)).toBe('—')
    expect(formatDuration(90)).toBe('1 小时 30 分钟')
    expect(formatDuration(45)).toBe('45 分钟')
    expect(formatNumber(1234567)).toBe('1,234,567')
  })

  it('maps domain labels without inventing values', () => {
    expect(statusLabel('active')).toBe('启用')
    expect(statusLabel('custom_status')).toBe('custom_status')
    expect(goalLabel('fat_loss')).toBe('减脂')
    expect(goalLabel(null)).toBe('未设置')
    expect(statusTagType('published')).toBe('success')
    expect(statusTagType('error')).toBe('danger')
  })

  it('shortens ids and renders JSON safely', () => {
    expect(shortId('1234567890abcdef')).toBe('12345678…')
    expect(shortId(null)).toBe('—')
    expect(prettyJson({ a: 1 })).toContain('"a": 1')
    expect(prettyJson(undefined)).toBe('—')
  })
})
