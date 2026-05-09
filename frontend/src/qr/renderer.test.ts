import { describe, it, expect, vi, beforeEach } from 'vitest'
import QRCodeStyling from 'qr-code-styling'
import { create } from '@/qr/renderer'

vi.mock('qr-code-styling', () => ({
  default: vi.fn(),
}))

const MockQRCodeStyling = vi.mocked(QRCodeStyling)

beforeEach(() => {
  MockQRCodeStyling.mockClear()
})

describe('QRRenderer.toBlob', () => {
  it('returns a Blob with image/png type for png format', async () => {
    const pngBlob = new Blob(['fake-png-data'], { type: 'image/png' })
    const getRawData = vi.fn().mockResolvedValue(pngBlob)
    MockQRCodeStyling.mockImplementation(() => ({
      update: vi.fn(),
      append: vi.fn(),
      getRawData,
    }) as never)

    const renderer = create({ width: 128, height: 128, data: 'https://example.com' })
    const result = await renderer.toBlob('png')

    expect(result).toBe(pngBlob)
    expect(result.type).toBe('image/png')
    expect(getRawData).toHaveBeenCalledWith('png')
  })

  it('returns a Blob with image/svg+xml type for svg format', async () => {
    const svgBlob = new Blob(['<svg/>'], { type: 'image/svg+xml' })
    const getRawData = vi.fn().mockResolvedValue(svgBlob)
    MockQRCodeStyling.mockImplementation(() => ({
      update: vi.fn(),
      append: vi.fn(),
      getRawData,
    }) as never)

    const renderer = create({ width: 128, height: 128, data: 'https://example.com' })
    const result = await renderer.toBlob('svg')

    expect(result).toBe(svgBlob)
    expect(result.type).toBe('image/svg+xml')
    expect(getRawData).toHaveBeenCalledWith('svg')
  })

  it('returns a Blob for webp format', async () => {
    const webpBlob = new Blob(['fake-webp-data'], { type: 'image/webp' })
    const getRawData = vi.fn().mockResolvedValue(webpBlob)
    MockQRCodeStyling.mockImplementation(() => ({
      update: vi.fn(),
      append: vi.fn(),
      getRawData,
    }) as never)

    const renderer = create({ width: 128, height: 128, data: 'https://example.com' })
    const result = await renderer.toBlob('webp')

    expect(result).toBe(webpBlob)
    expect(result.type).toBe('image/webp')
    expect(getRawData).toHaveBeenCalledWith('webp')
  })

  it('throws when getRawData returns null', async () => {
    const getRawData = vi.fn().mockResolvedValue(null)
    MockQRCodeStyling.mockImplementation(() => ({
      update: vi.fn(),
      append: vi.fn(),
      getRawData,
    }) as never)

    const renderer = create({ width: 128, height: 128, data: 'https://example.com' })
    await expect(renderer.toBlob('png')).rejects.toThrow()
  })

  it('throws when getRawData returns null for svg format', async () => {
    const getRawData = vi.fn().mockResolvedValue(null)
    MockQRCodeStyling.mockImplementation(() => ({
      update: vi.fn(),
      append: vi.fn(),
      getRawData,
    }) as never)

    const renderer = create({ width: 128, height: 128, data: 'https://example.com' })
    await expect(renderer.toBlob('svg')).rejects.toThrow('getRawData returned null for format: svg')
  })
})
