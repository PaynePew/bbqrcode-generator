import { test, expect } from '@playwright/test'

// Proves the bypass end-to-end: the minted session cookie (loaded via
// storageState) lands on the AUTHENTICATED dashboard WITH its owner data — no
// Google round-trip (bead 8vd). The bug this guards against is a cross-origin
// DATA-fetch failure (axios hitting the wrong origin with the cookie), so we
// assert the owner link-list actually rendered — proving the authed /api/qr
// call succeeded same-origin — not just the /auth/me-gated chrome.
test('injected session cookie lands on the authenticated dashboard with data', async ({
  page,
}) => {
  await page.goto('/dashboard')

  // Never the logged-out prompt.
  await expect(page.getByText('請先登入')).toHaveCount(0)
  // The seeded demo account's link-list rendered (authed data fetch succeeded).
  await expect(page.getByText(/你建立的連結/)).toBeVisible()
})
