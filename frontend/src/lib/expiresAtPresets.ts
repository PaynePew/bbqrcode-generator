export type ExpiresAtPreset = '+7d' | '+30d' | '+90d' | 'never' | 'custom'

export const PRESET_LABELS: Record<ExpiresAtPreset, string> = {
  '+7d': '+7 天',
  '+30d': '+30 天',
  '+90d': '+90 天',
  never: '永不過期',
  custom: '自訂時間',
}

const DAYS: Record<Exclude<ExpiresAtPreset, 'never' | 'custom'>, number> = {
  '+7d': 7,
  '+30d': 30,
  '+90d': 90,
}

export function computeExpiresAt(now: Date, preset: ExpiresAtPreset): string | null {
  if (preset === 'never' || preset === 'custom') return null
  const result = new Date(now.getTime() + DAYS[preset] * 24 * 60 * 60 * 1000)
  return result.toISOString()
}

export function resolveExpiresAt(preset: ExpiresAtPreset, customValue: string): string | null {
  if (preset === 'never') return null
  if (preset === 'custom') return customValue ? new Date(customValue).toISOString() : null
  return computeExpiresAt(new Date(), preset)
}

/** Convert a Date to the value format expected by <input type="datetime-local">. */
export function toDatetimeLocalValue(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0')
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
    `T${pad(date.getHours())}:${pad(date.getMinutes())}`
  )
}
