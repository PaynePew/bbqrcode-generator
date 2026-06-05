/**
 * @vitest-environment jsdom
 *
 * Tests for Dashboard (bead 65g): each link card renders a QR thumbnail
 * <img> whose src points at /api/qr/{token}/image.
 */
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen } from '@testing-library/react'
import { createElement } from 'react'

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------
vi.mock('react-router-dom', () => ({
  useNavigate: () => vi.fn(),
  Link: ({ children }: { children: React.ReactNode }) => children,
}))

vi.mock('@/state/linkEntry', () => ({
  useLinkList: vi.fn(),
}))

vi.mock('@/state/auth', () => ({
  useAuth: vi.fn(),
}))

vi.mock('@/components/ui/CopyButton', () => ({
  CopyButton: () => createElement('button', null, 'copy'),
}))

vi.mock('@/components/ui/StatusBadge', () => ({
  StatusBadge: ({ status }: { status: string }) => createElement('span', null, status),
}))

vi.mock('@/components/ui/button', () => ({
  Button: ({ children, ...props }: React.ButtonHTMLAttributes<HTMLButtonElement>) =>
    createElement('button', props, children),
}))

import { useLinkList } from '@/state/linkEntry'
import { useAuth } from '@/state/auth'
import { Dashboard } from './Dashboard'

const useLinkListMock = vi.mocked(useLinkList)
const useAuthMock = vi.mocked(useAuth)

const MOCK_ITEMS = [
  {
    token: 'abc1234',
    original_url: 'https://example.com/long',
    short_url: 'https://s.example.com/r/abc1234',
    status: 'active' as const,
    scan_count: 3,
    created_at: '2026-01-01T00:00:00Z',
    expires_at: null,
  },
  {
    token: 'xyz9999',
    original_url: 'https://another.example.com/path',
    short_url: 'https://s.example.com/r/xyz9999',
    status: 'active' as const,
    scan_count: 0,
    created_at: '2026-01-02T00:00:00Z',
    expires_at: null,
  },
]

beforeEach(() => {
  vi.clearAllMocks()

  useAuthMock.mockReturnValue({
    user: { id: 1, email: 'u@e.com', name: 'U', picture: null, is_demo: false },
    isLoading: false,
    isAuthenticated: true,
    isDemo: false,
    login: vi.fn(),
    loginAsGuest: vi.fn(),
    logout: vi.fn(),
  })

  useLinkListMock.mockReturnValue({
    data: { items: MOCK_ITEMS, next_cursor: null },
    isLoading: false,
    isSuccess: true,
    isError: false,
    error: null,
  } as ReturnType<typeof useLinkList>)
})

describe('Dashboard — QR thumbnail (bead 65g)', () => {
  it('renders an <img> per link card whose src starts with /api/qr/{token}/image', () => {
    render(createElement(Dashboard))

    const imgs = screen.getAllByRole('img', { name: /QR/ })
    expect(imgs.length).toBe(2)

    const srcs = imgs.map((img) => (img as HTMLImageElement).src)
    expect(srcs.some((s) => s.includes('/api/qr/abc1234/image'))).toBe(true)
    expect(srcs.some((s) => s.includes('/api/qr/xyz9999/image'))).toBe(true)
  })

  it('each QR thumbnail has loading="lazy" set', () => {
    render(createElement(Dashboard))

    const imgs = screen.getAllByRole('img', { name: /QR/ })
    for (const img of imgs) {
      // jsdom reflects the loading attribute as an attribute (not a DOM property).
      expect(img.getAttribute('loading')).toBe('lazy')
    }
  })

  it('each QR thumbnail has explicit width and height to prevent layout shift', () => {
    render(createElement(Dashboard))

    const imgs = screen.getAllByRole('img', { name: /QR/ })
    for (const img of imgs) {
      const el = img as HTMLImageElement
      expect(el.width).toBeGreaterThan(0)
      expect(el.height).toBeGreaterThan(0)
    }
  })
})
