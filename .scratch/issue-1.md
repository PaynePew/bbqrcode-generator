## Parent

#1 feat: dynamic QR code generator

## What to build

Scaffold the full project structure and deliver the golden path: creating a QR code link and redirecting through it.

Set up the flat module layout (`main.py`, `models.py`, `database.py`, `router.py`, `url_validator.py`, `token_generator.py`), both DB tables (`links` and `scans`), and wire up two endpoints:

- `POST /api/qr/create` — validates and normalizes the submitted URL, generates a 7-char Base62 token, persists the link, and returns `token`, `short_url`, `qr_code_url` (URL reference only — image endpoint is a later slice), and `original_url`.
- `GET /r/{token}` — looks up the token and returns 302 to the original URL, or 404 if the token does not exist.

URL validation covers format checking, normalization (lowercase host, https coercion, default port removal, trailing slash, sorted query params), and malicious URL blocking (non-http(s) schemes, private IP ranges, loopback addresses).

Token generation uses SHA-256(url + SECRET + nonce) → Base62 → 7 chars with optimistic insertion, up to 3 retries on collision before raising HTTP 500.

## Acceptance criteria

- [ ] `POST /api/qr/create` with a valid URL returns 200 with `token`, `short_url`, `qr_code_url`, `original_url`
- [ ] `GET /r/{token}` returns 302 with correct `Location` header
- [ ] `GET /r/INVALID` returns 404
- [ ] Submitting a `javascript:` or `file:` URL returns 422
- [ ] Submitting a URL pointing to `localhost` or a private IP returns 422
- [ ] Unit tests pass for `url_validator` (normalization rules + all blocked URL categories)
- [ ] Unit tests pass for `token_generator` (determinism, different nonces produce different tokens, raises after 3 collisions)
- [ ] Integration tests pass for create and redirect flows

## Blocked by

None — can start immediately.
