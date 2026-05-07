## Problem Statement

Users need a way to distribute URLs via QR codes that remain useful after the target URL changes. Static QR codes encode the destination directly — once printed or shared, they cannot be updated without reissuing the physical asset. This makes them brittle for marketing materials, event signage, or any use case where the destination may change after distribution.

## Solution

A dynamic QR code service where each QR code encodes a short redirect URL hosted on the server. Users submit a long URL and receive a short URL token, a QR code image, and a redirect endpoint. Because the redirect target lives server-side, users can update the destination URL at any time without changing the QR code. Links can be soft-deleted with appropriate HTTP semantics, given an expiration timestamp, and basic scan analytics are tracked automatically.

## User Stories

1. As a user, I want to submit a long URL and receive a short URL token, so that I can share the shortened link.
2. As a user, I want to receive a QR code image when I create a short URL, so that I can embed it in print or digital media.
3. As a user, I want the QR code to encode a short redirect URL (not the original URL), so that I can update the destination later without reissuing the QR code.
4. As a user, I want to update the target URL for an existing short link, so that I can fix typos or redirect to new content without changing the QR code.
5. As a user, I want to soft-delete a short link, so that scans return an informative error rather than a broken redirect.
6. As a user, I want to set an expiration timestamp on a link at creation time, so that the link automatically becomes inactive after a certain date.
7. As a user, I want to update the expiration timestamp on an existing link, so that I can extend or shorten a link's lifetime.
8. As a user, I want expired links to return a 410 Gone status on redirect, so that scanners and crawlers are informed the resource is permanently gone.
9. As a user, I want deleted links to return a 410 Gone status on redirect, so that scanners and crawlers are informed the resource is permanently gone.
10. As a user, I want non-existent tokens to return a 404 Not Found, so that I can distinguish a typo from a deleted link.
11. As a user, I want to retrieve metadata for a short link (status, original URL, creation time, expiration), so that I can inspect the current state of any link I have created.
12. As a user, I want the info endpoint to return 200 even for deleted or expired links (with a status field), so that I can inspect historical link state without receiving an error.
13. As a user, I want to download the QR code image for any active link as a PNG, so that I can re-download the image at any time.
14. As a user, I want to view scan analytics for a link (total scans, scans by day, recent scans with IP and user agent), so that I can understand engagement with my QR code.
15. As a user, I want scan attempts on deleted or expired links to be recorded in analytics, so that I can see how many times a stale QR code was scanned after deactivation.
16. As a user, I want scan analytics to include the HTTP status code returned, so that I can distinguish successful redirects from failed attempts.
17. As a user, I want scan analytics to record the IP address and user agent of each scan, so that I can identify traffic sources and client types.
18. As a user, I want URL format validation on submission, so that I cannot create a short link pointing to a malformed URL.
19. As a user, I want URLs to be normalized before hashing, so that equivalent URLs (different casing, trailing slashes, sorted query params) resolve to the same token.
20. As a user, I want malicious URLs (private IPs, localhost, non-http(s) schemes) to be rejected, so that the service cannot be used for SSRF or protocol injection attacks.
21. As a user, I want the system to handle token collisions automatically, so that I never receive an error due to an internal hash collision.

## Implementation Decisions

### Database

SQLite via sync SQLAlchemy. WAL mode enabled at connection time (`PRAGMA journal_mode=WAL`) to allow concurrent reads during writes. Two tables:

**links schema:**

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PRIMARY KEY | |
| token | TEXT UNIQUE NOT NULL | |
| original_url | TEXT NOT NULL | |
| created_at | DATETIME NOT NULL | |
| updated_at | DATETIME NOT NULL | |
| deleted_at | DATETIME nullable | NULL = active |
| expires_at | DATETIME nullable | NULL = no expiration |

**scans schema:**

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PRIMARY KEY | |
| token | TEXT NOT NULL | plain string, no FK constraint |
| scanned_at | DATETIME NOT NULL | |
| status_code | INTEGER NOT NULL | |
| ip_address | TEXT nullable | |
| user_agent | TEXT nullable | |

`ip_address` and `user_agent` are nullable — some requests may not carry these headers (e.g. curl without User-Agent, or traffic behind a proxy).

### Token Generation

- Algorithm: SHA-256(original_url + SECRET + str(nonce)) → Base62 encode → first 7 characters
- Key space: 62^7 ≈ 3.5 trillion combinations
- Optimistic insertion: attempt INSERT, increment nonce on UNIQUE conflict, retry up to 3 times, raise HTTP 500 after 3 failures

### URL Validation and Normalization

Normalization applied before hashing for consistency and security. Each POST always creates a new token — no deduplication by URL:

1. Coerce `http://` to `https://`
2. Lowercase the host
3. Strip default ports (`:80`, `:443`)
4. Remove trailing slash from path (root path stays `/`)
5. Sort query parameters alphabetically

Malicious URL blocking (reject on any match):

- Non-`http(s)` schemes: `javascript:`, `data:`, `file:`, etc.
- Private IP ranges: `10.x.x.x`, `172.16–31.x.x`, `192.168.x.x`, `169.254.x.x`
- Loopback: `127.x.x.x`, `::1`, `localhost`

### Redirect Behavior

- `302 Found` on active, non-expired link — logs scan with `status_code=302`
- `410 Gone` on deleted or expired link — logs scan with `status_code=410`
- `404 Not Found` on unknown token — no scan logged

### API Behavior

- `GET /api/qr/{token}` returns 200 for all known tokens with a derived `status` field: `active | deleted | expired`. `deleted` takes precedence over `expired`, which takes precedence over `active`.
- `PATCH /api/qr/{token}` returns 410 only if the link is **deleted**. Expired links may be re-activated by patching `expires_at` to a future timestamp (or `null` to remove expiration entirely). Returns 422 if the request body contains no updatable fields (`original_url`, `expires_at`).
- `DELETE /api/qr/{token}` sets `deleted_at` to current UTC time (soft delete). Idempotent — returns 200 even if already deleted.
- `GET /api/qr/{token}/image` returns `image/png` bytes generated on-demand for all known tokens regardless of status (active, expired, or deleted). Returns 404 for unknown tokens.

### Response Shape — GET /api/qr/{token}

```json
{
  "token": "abc1234",
  "original_url": "https://example.com",
  "short_url": "http://localhost:8000/r/abc1234",
  "qr_code_url": "http://localhost:8000/api/qr/abc1234/image",
  "status": "active",
  "created_at": "2026-05-07T00:00:00",
  "updated_at": "2026-05-07T00:00:00",
  "expires_at": null
}
```

### Response Shape — GET /api/qr/{token}/analytics

```json
{
  "token": "abc1234",
  "total_scans": 42,
  "timezone": "UTC",
  "scans_by_day": [
    {
      "date": "2026-05-07",
      "count": 10,
      "status_codes": {"302": 8, "410": 2}
    }
  ],
  "recent_scans": [
    {
      "scanned_at": "2026-05-07T12:34:56",
      "status_code": 302,
      "ip_address": "203.0.113.1",
      "user_agent": "Mozilla/5.0 ..."
    }
  ]
}
```

`scans_by_day` is aggregated (GROUP BY UTC date), ordered ascending by date. `recent_scans` lists raw records ordered descending by `scanned_at`, capped at the 50 most recent. `GET /api/qr/{token}/analytics` returns 404 for unknown tokens.

### QR Code Generation

- Library: `qrcode[pil]`
- Generated on every `/image` request — not stored
- Input: the short URL string
- Output: PNG bytes with `Content-Type: image/png`

### Project Structure

Flat modules: `main.py`, `models.py`, `database.py`, `router.py`, `token_generator.py`, `url_validator.py`, `qr_generator.py`

## Testing Decisions

### What makes a good test

Tests should verify observable behavior through public interfaces — what the module returns or raises given specific inputs — not implementation details like which hash function is called or which internal variable is set.

### Modules under test

**token_generator.py (unit tests)**
- Given a URL, returns a 7-character Base62 string
- Same URL + same nonce always produces the same token (deterministic)
- Different nonces for the same URL produce different tokens
- Collision retry: if the first N inserts conflict, the (N+1)th succeeds up to retry limit
- Raises after 3 consecutive collisions

**url_validator.py (unit tests)**
- Valid URLs pass validation and return normalized form
- Normalization: lowercase host, https coercion, default port removal, trailing slash, sorted query params
- Rejects non-http(s) schemes
- Rejects localhost and private IP ranges
- Rejects malformed URLs

**qr_generator.py (unit tests)**
- Returns bytes for a valid short URL input
- Returned bytes are valid PNG (check magic bytes)

**router.py (integration tests via FastAPI TestClient)**

Covers all verification commands from the spec:
- POST /api/qr/create → 200, correct response shape
- GET /r/{token} → 302
- GET /api/qr/{token} → 200, metadata
- PATCH /api/qr/{token} → 200, redirect goes to new URL
- DELETE /api/qr/{token} → 200
- GET /r/{token} after delete → 410
- GET /r/INVALID → 404
- GET /api/qr/{token}/image → 200, image/png
- GET /api/qr/{token}/analytics → 200, correct shape including recent_scans with ip_address and user_agent

## Out of Scope

- Authentication and authorization
- Rate limiting
- User accounts or link ownership
- Custom token slugs
- QR code styling (colors, logos, error correction level)
- Bulk operations
- Webhook notifications on scan
- Production deployment, HTTPS termination, domain configuration
- Background expiration cleanup jobs (expiration is checked at request time only)

## Further Notes

- `PATCH` uses `model_fields_set` (Pydantic v2) to distinguish "field not provided" from "field explicitly set to null". This is critical for `expires_at`: `{}` → nothing updated (→ 422); `{"expires_at": null}` → expiration removed. Using `Optional[datetime] = None` as a default without checking `model_fields_set` would make these indistinguishable.
- The `status` field in `GET /api/qr/{token}` is derived at read time: check `deleted_at IS NOT NULL` first, then `expires_at <= now()`, then `active`.
- The short URL base (e.g. `http://localhost:8000`) should be read from an environment variable (`BASE_URL`) so the service is portable.
- `SECRET` (used in token generation) must be set as an environment variable. The application refuses to start if `SECRET` is absent — no fallback default. A `.env.example` is provided for local development.
- The `scans` table uses a plain string `token` column with no FK constraint so scan records are durable against any future hard-delete of the parent link row.
- `ip_address` is read from the **rightmost** value in the `X-Forwarded-For` header (added by the last trusted proxy), falling back to the direct client IP. This field is best-effort and not guaranteed to be unforgeable in the absence of a trusted reverse proxy.
