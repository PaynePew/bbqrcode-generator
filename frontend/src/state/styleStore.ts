import type { ECL } from '@/qr/eclPolicy'

export type DotType = 'square' | 'dots' | 'rounded' | 'extra-rounded' | 'classy'
export type { ECL }

export interface QRStyle {
  foreground: string
  background: string
  size: number
  dotType: DotType
  ecl: ECL
}

export const DEFAULT_STYLE: QRStyle = {
  foreground: '#000000',
  background: '#ffffff',
  size: 320,
  dotType: 'square',
  ecl: 'M',
}

const DEFAULT_KEY = 'qr-style:default'

function tokenKey(token: string): string {
  return `qr-style:${token}`
}

const VALID_ECLS: ECL[] = ['L', 'M', 'Q', 'H']

function parse(raw: string | null): QRStyle | null {
  if (!raw) return null
  try {
    const parsed: unknown = JSON.parse(raw)
    if (typeof parsed !== 'object' || parsed === null) return null
    const obj = parsed as Record<string, unknown>
    if (
      typeof obj.foreground === 'string' &&
      typeof obj.background === 'string' &&
      typeof obj.size === 'number' &&
      typeof obj.dotType === 'string'
    ) {
      const ecl: ECL = typeof obj.ecl === 'string' && VALID_ECLS.includes(obj.ecl as ECL)
        ? (obj.ecl as ECL)
        : DEFAULT_STYLE.ecl
      return { ...(obj as unknown as QRStyle), ecl }
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
  return parse(storage.getItem(tokenKey(token))) ?? getDefault(storage)
}

export function setStyle(token: string, style: QRStyle, storage: Storage = globalThis.localStorage): void {
  storage.setItem(tokenKey(token), JSON.stringify(style))
}
