import QRCodeStyling, { type Options } from 'qr-code-styling'

export type RendererOptions = Partial<Options>

export interface QRRenderer {
  update(options: RendererOptions): void
  attachTo(node: HTMLElement): void
  destroy(): void
}

export function create(options: RendererOptions): QRRenderer {
  const instance = new QRCodeStyling(options)
  let container: HTMLElement | null = null

  return {
    update(opts: RendererOptions) {
      instance.update(opts)
    },
    attachTo(node: HTMLElement) {
      container = node
      instance.append(node)
    },
    destroy() {
      if (container) {
        container.innerHTML = ''
        container = null
      }
    },
  }
}
