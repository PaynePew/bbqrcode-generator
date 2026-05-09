export const DOWNLOAD_FORMATS = ['png', 'svg', 'webp'] as const
export type DownloadFormat = (typeof DOWNLOAD_FORMATS)[number]

const KEY = 'qr-download-format'

export function getDownloadFormat(storage: Storage = localStorage): DownloadFormat {
  const val = storage.getItem(KEY)
  if (val && (DOWNLOAD_FORMATS as readonly string[]).includes(val)) return val as DownloadFormat
  return 'png'
}

export function setDownloadFormat(format: DownloadFormat, storage: Storage = localStorage): void {
  storage.setItem(KEY, format)
}
