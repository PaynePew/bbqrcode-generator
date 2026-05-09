export const PREVIEW_NORMAL_HEIGHT = 280
export const PREVIEW_SHRUNK_HEIGHT = 160
const DEFAULT_SCROLL_THRESHOLD = 80

export function computePreviewHeight(scrollY: number, threshold = DEFAULT_SCROLL_THRESHOLD): number {
  return scrollY > threshold ? PREVIEW_SHRUNK_HEIGHT : PREVIEW_NORMAL_HEIGHT
}
