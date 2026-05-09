import { describe, it, expect, beforeEach } from 'vitest'
import { getDownloadFormat, setDownloadFormat, type DownloadFormat } from '@/state/downloadFormatStore'

function makeStorage(): Storage {
  const data: Record<string, string> = {}
  return {
    getItem: (k: string) => data[k] ?? null,
    setItem: (k: string, v: string) => { data[k] = v },
    removeItem: (k: string) => { delete data[k] },
    clear: () => { Object.keys(data).forEach(k => delete data[k]) },
    get length() { return Object.keys(data).length },
    key: (i: number) => Object.keys(data)[i] ?? null,
  } as Storage
}

let storage: Storage

beforeEach(() => {
  storage = makeStorage()
})

describe('getDownloadFormat', () => {
  it('returns png by default when nothing stored', () => {
    expect(getDownloadFormat(storage)).toBe('png')
  })

  it('returns stored format when valid', () => {
    storage.setItem('qr-download-format', 'svg')
    expect(getDownloadFormat(storage)).toBe('svg')

    storage.setItem('qr-download-format', 'webp')
    expect(getDownloadFormat(storage)).toBe('webp')

    storage.setItem('qr-download-format', 'png')
    expect(getDownloadFormat(storage)).toBe('png')
  })

  it('returns png when stored value is invalid', () => {
    storage.setItem('qr-download-format', 'gif')
    expect(getDownloadFormat(storage)).toBe('png')
  })

  it('returns png when stored value is empty string', () => {
    storage.setItem('qr-download-format', '')
    expect(getDownloadFormat(storage)).toBe('png')
  })
})

describe('setDownloadFormat', () => {
  it('persists format to storage', () => {
    setDownloadFormat('svg', storage)
    expect(storage.getItem('qr-download-format')).toBe('svg')
  })

  it('overwrites previously stored format', () => {
    setDownloadFormat('svg', storage)
    setDownloadFormat('webp', storage)
    expect(getDownloadFormat(storage)).toBe('webp')
  })

  it('round-trips all valid formats', () => {
    const formats: DownloadFormat[] = ['png', 'svg', 'webp']
    for (const fmt of formats) {
      setDownloadFormat(fmt, storage)
      expect(getDownloadFormat(storage)).toBe(fmt)
    }
  })
})
