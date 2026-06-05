/**
 * Tests for getQrImageUrl helper (bead 65g).
 * Pure URL construction — no module mock needed.
 */
import { describe, it, expect } from 'vitest'
import { getQrImageUrl } from './qr'

describe('getQrImageUrl', () => {
  it('returns a relative URL rooted at /api/qr/{token}/image', () => {
    const url = getQrImageUrl('abc1234')
    expect(url).toMatch(/^\/api\/qr\/abc1234\/image/)
  })

  it('adds no query param when updatedAt is omitted', () => {
    const url = getQrImageUrl('abc1234')
    expect(url).toBe('/api/qr/abc1234/image')
  })

  it('adds ?v=<updatedAt> when updatedAt is provided', () => {
    const url = getQrImageUrl('abc1234', '2026-06-01T10:00:00Z')
    expect(url).toBe('/api/qr/abc1234/image?v=2026-06-01T10%3A00%3A00Z')
  })

  it('URL-encodes special characters in the cache-bust value', () => {
    const url = getQrImageUrl('tok1', '2026-06-01T10:00:00+08:00')
    expect(url).toContain('%2B')
  })
})
