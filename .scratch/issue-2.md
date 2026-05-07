## Parent

#1 feat: dynamic QR code generator

## What to build

Add full link lifecycle management and the info endpoint on top of the golden path.

**Info endpoint:**
`GET /api/qr/{token}` returns 200 for all known tokens (active, deleted, or expired) with a derived `status` field. Status is computed at read time: `deleted` if `deleted_at IS NOT NULL`, `expired` if `expires_at <= now()`, otherwise `active`. Response shape:

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

**Mutation endpoints:**
- `PATCH /api/qr/{token}` — updates `original_url` and/or `expires_at`, sets `updated_at`. Returns 410 only if the link is **deleted**. Expired links may be re-activated by patching `expires_at`.
- `DELETE /api/qr/{token}` — soft delete: sets `deleted_at` to current UTC. Returns 200.

**Expiration on create:**
`POST /api/qr/create` accepts an optional `expires_at` timestamp. The redirect endpoint (`GET /r/{token}`) already handles 404 for unknown tokens; it must also return 410 for deleted or expired links (logs scan with `status_code=410`).

## Acceptance criteria

- [ ] `GET /api/qr/{token}` returns 200 for active, deleted, and expired links with correct `status` field
- [ ] `GET /api/qr/{token}` returns 404 for an unknown token
- [ ] `PATCH /api/qr/{token}` updates the target URL and returns 200
- [ ] `PATCH /api/qr/{token}` returns 410 for deleted or expired links
- [ ] `DELETE /api/qr/{token}` returns 200 and sets `deleted_at`
- [ ] `GET /r/{token}` returns 410 after deletion
- [ ] `GET /r/{token}` returns 410 after expiration
- [ ] `POST /api/qr/create` accepts optional `expires_at`
- [ ] Integration tests cover all mutation paths and the 410 redirect behavior

## Blocked by

- #2 slice 1: golden path — scaffold + create + redirect
