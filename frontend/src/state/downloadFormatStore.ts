export type DownloadFormat = 'png' | 'svg' | 'webp'

const KEY = 'qr-download-format'
const VALID: DownloadFormat[] = ['png', 'svg', 'webp']

export function getDownloadFormat(storage: Storage = localStorage): DownloadFormat {
  const val = storage.getItem(KEY)
  if (val && (VALID as string[]).includes(val)) return val as DownloadFormat
  return 'png'
}

export function setDownloadFormat(format: DownloadFormat, storage: Storage = localStorage): void {
  storage.setItem(KEY, format)
}
