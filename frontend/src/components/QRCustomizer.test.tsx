/**
 * @vitest-environment jsdom
 *
 * Tests for QRCustomizer (bead qr_code_generator-yfx): the reusable customization
 * panel that can be embedded in both Generator and LinkDetail.
 */
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { createElement } from 'react'

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------
vi.mock('@/qr/renderer', () => ({
  create: vi.fn(() => ({
    update: vi.fn(),
    attachTo: vi.fn(),
    toBlob: vi.fn(),
    destroy: vi.fn(),
  })),
}))

vi.mock('@/state/styleStore', () => ({
  DEFAULT_STYLE: {
    foreground: '#000000',
    background: '#ffffff',
    dotType: 'square',
    ecl: 'M',
  },
  QR_RENDER_SIZE: 320,
}))

vi.mock('react-dropzone', () => ({
  useDropzone: vi.fn(() => ({
    getRootProps: () => ({}),
    getInputProps: () => ({}),
    isDragActive: false,
  })),
}))

vi.mock('@/components/ui/ColorPickerField', () => ({
  ColorPickerField: ({
    label,
    onChange,
    disabled,
  }: {
    label: string
    value: string
    onChange: (c: string) => void
    disabled?: boolean
  }) =>
    createElement('button', {
      'data-testid': `color-picker-${label}`,
      onClick: () => onChange('#ff0000'),
      disabled,
    }, label),
}))

import type { QRStyle } from '@/state/styleStore'
import { QRCustomizer } from './QRCustomizer'

const DEFAULT_STYLE: QRStyle = {
  foreground: '#000000',
  background: '#ffffff',
  dotType: 'square',
  ecl: 'M',
}

function makeProps(overrides = {}) {
  return {
    style: DEFAULT_STYLE,
    onStyleChange: vi.fn(),
    logoObjectUrl: null as string | null,
    logoScale: 0.2,
    onLogoAccepted: vi.fn(),
    onLogoRemove: vi.fn(),
    onLogoScaleChange: vi.fn(),
    disabled: false,
    ...overrides,
  }
}

beforeEach(() => {
  vi.clearAllMocks()
})

describe('QRCustomizer — controls rendered', () => {
  it('renders foreground colour picker', () => {
    render(createElement(QRCustomizer, makeProps()))
    expect(screen.getByTestId('color-picker-前景色')).toBeTruthy()
  })

  it('renders background colour picker', () => {
    render(createElement(QRCustomizer, makeProps()))
    expect(screen.getByTestId('color-picker-背景色')).toBeTruthy()
  })

  it('renders the dot-style select', () => {
    render(createElement(QRCustomizer, makeProps()))
    expect(screen.getByLabelText(/點點樣式/)).toBeTruthy()
  })

  it('renders the ECL select', () => {
    render(createElement(QRCustomizer, makeProps()))
    expect(screen.getByLabelText(/錯誤修正等級/)).toBeTruthy()
  })

  it('renders the logo dropzone when no logo is loaded', () => {
    render(createElement(QRCustomizer, makeProps()))
    expect(screen.getByText(/拖曳或點擊上傳 Logo/)).toBeTruthy()
  })

  it('renders logo preview + remove button when logo is set', () => {
    render(
      createElement(QRCustomizer, makeProps({ logoObjectUrl: 'blob:fake' })),
    )
    expect(screen.getByAltText(/Logo 預覽/)).toBeTruthy()
    expect(screen.getByText(/移除 Logo/)).toBeTruthy()
  })

  it('renders a reset button', () => {
    render(createElement(QRCustomizer, makeProps()))
    expect(screen.getByText(/重設為預設值/)).toBeTruthy()
  })
})

describe('QRCustomizer — interactions', () => {
  it('calls onStyleChange when dot-style is changed', () => {
    const onStyleChange = vi.fn()
    render(createElement(QRCustomizer, makeProps({ onStyleChange })))

    const select = screen.getByLabelText(/點點樣式/) as HTMLSelectElement
    fireEvent.change(select, { target: { value: 'dots' } })

    expect(onStyleChange).toHaveBeenCalledWith(
      expect.objectContaining({ dotType: 'dots' }),
    )
  })

  it('calls onStyleChange when ECL is changed', () => {
    const onStyleChange = vi.fn()
    render(createElement(QRCustomizer, makeProps({ onStyleChange })))

    const select = screen.getByLabelText(/錯誤修正等級/) as HTMLSelectElement
    fireEvent.change(select, { target: { value: 'H' } })

    expect(onStyleChange).toHaveBeenCalledWith(
      expect.objectContaining({ ecl: 'H' }),
    )
  })

  it('calls onStyleChange with DEFAULT_STYLE when reset is clicked', () => {
    const onStyleChange = vi.fn()
    render(createElement(QRCustomizer, makeProps({ onStyleChange })))

    fireEvent.click(screen.getByText(/重設為預設值/))

    expect(onStyleChange).toHaveBeenCalledWith(DEFAULT_STYLE)
  })

  it('calls onLogoRemove when remove button is clicked', () => {
    const onLogoRemove = vi.fn()
    render(
      createElement(
        QRCustomizer,
        makeProps({ logoObjectUrl: 'blob:fake', onLogoRemove }),
      ),
    )

    fireEvent.click(screen.getByText(/移除 Logo/))

    expect(onLogoRemove).toHaveBeenCalled()
  })
})

describe('QRCustomizer — disabled state', () => {
  it('disables the dot-style select when disabled prop is true', () => {
    render(createElement(QRCustomizer, makeProps({ disabled: true })))
    const select = screen.getByLabelText(/點點樣式/) as HTMLSelectElement
    expect(select.disabled).toBe(true)
  })

  it('disables the ECL select when disabled prop is true', () => {
    render(createElement(QRCustomizer, makeProps({ disabled: true })))
    const select = screen.getByLabelText(/錯誤修正等級/) as HTMLSelectElement
    expect(select.disabled).toBe(true)
  })
})
