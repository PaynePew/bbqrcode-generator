## Parent

#1 feat: dynamic QR code generator

## What to build

Implement on-demand QR code image generation and have a human verify the output is scannable before merging.

Add `qr_generator.py` which takes a short URL string and returns PNG bytes using `qrcode[pil]`. Wire up:

- `GET /api/qr/{token}/image` — calls `qr_generator` with the link's short URL and returns the PNG with `Content-Type: image/png`.

This slice is HITL: after implementation, a reviewer must scan the generated QR code with a phone camera and confirm it resolves to the correct short URL before the PR is approved.

## Acceptance criteria

- [ ] `GET /api/qr/{token}/image` returns 200 with `Content-Type: image/png`
- [ ] Response bytes begin with PNG magic bytes (`\x89PNG`)
- [ ] Unit test for `qr_generator` verifies PNG output for a valid short URL input
- [ ] Integration test for the image endpoint verifies 200 and content type
- [ ] **Human verification:** reviewer scans the QR code output with a phone camera and confirms it redirects to the correct URL

## Blocked by

- #2 slice 1: golden path — scaffold + create + redirect
