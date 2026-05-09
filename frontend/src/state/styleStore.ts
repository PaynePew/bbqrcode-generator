export type DotType = 'square' | 'dots' | 'rounded' | 'extra-rounded' | 'classy'

export interface QRStyle {
  foreground: string
  background: string
  size: number
  dotType: DotType
}

export const DEFAULT_STYLE: QRStyle = {
  foreground: '#000000',
  background: '#ffffff',
  size: 320,
  dotType: 'square',
}

const DEFAULT_KEY = 'qr-style:default'

function tokenKey(token: string): string {
  return `qr-style:${token}`
}

function parse(raw: string | null): QRStyle | null {
  if (!raw) return null
  try {
    const parsed = JSON.parse(raw) as unknown
    if (
      parsed !== null &&
      typeof parsed === 'object' &&
      'foreground' in parsed && typeof (parsed as Record<string, unknown>).foreground === 'string' &&
      'background' in parsed && typeof (parsed as Record<string, unknown>).background === 'string' &&
      'size' in parsed && typeof (parsed as Record<string, unknown>).size === 'number' &&
      'dotType' in parsed && typeof (parsed as Record<string, unknown>).dotType === 'string'
    ) {
      return parsed as QRStyle
    }
  } catch {
    // fall through
  }
  return null
}

export function getDefault(storage: Storage = globalThis.localStorage): QRStyle {
  return parse(storage.getItem(DEFAULT_KEY)) ?? { ...DEFAULT_STYLE }
}

export function setDefault(style: QRStyle, storage: Storage = globalThis.localStorage): void {
  storage.setItem(DEFAULT_KEY, JSON.stringify(style))
}

export function getStyle(token: string, storage: Storage = globalThis.localStorage): QRStyle {
  const raw = storage.getItem(tokenKey(token))
  if (raw !== null) {
    return parse(raw) ?? getDefault(storage)
  }
  return getDefault(storage)
}

export function setStyle(token: string, style: QRStyle, storage: Storage = globalThis.localStorage): void {
  storage.setItem(tokenKey(token), JSON.stringify(style))
}
