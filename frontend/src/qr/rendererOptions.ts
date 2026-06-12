/**
 * Converts a QRStyle + optional logo to RendererOptions for qr-code-styling.
 * Shared by Generator (new link) and LinkDetail (re-edit existing link).
 */
import { applyEclPolicy } from '@/qr/eclPolicy'
import { QR_RENDER_SIZE, type QRStyle } from '@/state/styleStore'
import type { RendererOptions } from '@/qr/renderer'

export function styleToRendererOptions(
  style: QRStyle,
  data: string | undefined,
  logoUrl: string | null | undefined,
  logoScale: number,
): RendererOptions {
  const dotType = style.dotType as import('qr-code-styling').DotType

  let cornerSquareType: 'square' | 'dot' | 'extra-rounded' = 'square'
  let cornerDotType: 'square' | 'dot' = 'square'
  if (style.dotType === 'dots') {
    cornerSquareType = 'dot'
    cornerDotType = 'dot'
  } else if (style.dotType === 'rounded' || style.dotType === 'extra-rounded') {
    cornerSquareType = 'extra-rounded'
    cornerDotType = 'dot'
  }

  const { ecl } = applyEclPolicy(!!logoUrl, style.ecl)

  return {
    ...(data ? { data } : {}),
    width: QR_RENDER_SIZE,
    height: QR_RENDER_SIZE,
    dotsOptions: { color: style.foreground, type: dotType },
    backgroundOptions: { color: style.background },
    cornersSquareOptions: { type: cornerSquareType },
    cornersDotOptions: { type: cornerDotType },
    qrOptions: { errorCorrectionLevel: ecl },
    ...(logoUrl
      ? {
          image: logoUrl,
          imageOptions: {
            imageSize: logoScale,
            margin: 4,
            hideBackgroundDots: true,
          },
        }
      : { image: '' }),
  }
}
