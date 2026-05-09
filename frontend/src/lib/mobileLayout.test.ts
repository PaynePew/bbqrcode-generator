import { describe, it, expect } from 'vitest'
import { computePreviewHeight, PREVIEW_NORMAL_HEIGHT, PREVIEW_SHRUNK_HEIGHT } from './mobileLayout'

describe('computePreviewHeight', () => {
  it('returns normal height when scrollY is 0', () => {
    expect(computePreviewHeight(0)).toBe(PREVIEW_NORMAL_HEIGHT)
  })

  it('returns normal height when scrollY is exactly at threshold', () => {
    expect(computePreviewHeight(80)).toBe(PREVIEW_NORMAL_HEIGHT)
  })

  it('returns shrunk height when scrollY exceeds threshold', () => {
    expect(computePreviewHeight(81)).toBe(PREVIEW_SHRUNK_HEIGHT)
  })

  it('returns shrunk height for large scroll values', () => {
    expect(computePreviewHeight(1000)).toBe(PREVIEW_SHRUNK_HEIGHT)
  })

  it('respects custom threshold', () => {
    expect(computePreviewHeight(50, 50)).toBe(PREVIEW_NORMAL_HEIGHT)
    expect(computePreviewHeight(51, 50)).toBe(PREVIEW_SHRUNK_HEIGHT)
  })
})
