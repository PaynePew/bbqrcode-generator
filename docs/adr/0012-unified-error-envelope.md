# ADR 0012: Unified error response envelope and error-code taxonomy

**Status:** Accepted

## Context

Error responses today come in at least three incompatible shapes: custom handlers
return `{"detail": "..."}`, inline `HTTPException`s do the same with ad-hoc messages, and
Pydantic validation returns `{"detail": [ {loc, msg, type} ]}`. None carry a
machine-readable code. Phase 1 (a `DEMO_READ_ONLY` distinct from 401/403/404), Phase 4
(upload errors), and the rate limiter (429) all need the frontend to branch on the *kind*
of error without parsing human messages.

## Decision

Every error response — including framework-generated ones — is normalized to one envelope:

```json
{ "error": { "code": "<STABLE_ENUM>", "message": "<human, mutable>", "details": { } } }
```

- `code` is a stable enum (a backend `StrEnum ErrorCode`), the contract the frontend
  branches on; it evolves additively and is never silently repurposed. `message` is
  human-facing and free to reword / localize. `details` carries structured extras
  (validation `fields`, `retry_after`, `correlation_id`).
- Application code raises a typed `AppError(code, status, message)` hierarchy instead of
  hand-rolled `HTTPException`s. Four exception handlers cover everything: `AppError` (our
  intentional errors), `RequestValidationError` (422 → `VALIDATION_ERROR`),
  `StarletteHTTPException` (framework 404/405, status→code), and a catch-all `Exception`
  (→ `INTERNAL_ERROR`, logged with a correlation id, never leaking internals).

Notable rulings:

- **Non-owner access to an owner-only resource returns 404 (`NOT_FOUND`), not 403** —
  owner-404, to avoid an existence/enumeration oracle. `FORBIDDEN` is reserved for the
  rare case where revealing existence is acceptable.
- **Mutating a deleted (terminal) Link returns 409 (`LINK_DELETED`), not 410** — the Link
  still exists in trash; the request conflicts with its terminal state. The public
  redirect on a non-active Link stays 410 (`LINK_GONE`).
- **Upload failures get distinct codes** (`INVALID_IMAGE` 422, `FILE_TOO_LARGE` 413) so
  the frontend can give precise feedback.

## Consequences

- The frontend faces exactly one error contract and branches on `code`.
- Changing the envelope, or a `code`'s meaning, is a breaking API change — treated with
  the same discipline as any published field (additive, deprecate-don't-mutate).
- Supersedes the two ad-hoc handlers in `main.py` and the inline `HTTPException`s in the
  router (migrated to `AppError`). The redirect's 410 and the owner-only authz responses
  now flow through the envelope.
- RFC 9457 (Problem Details) was considered and rejected as heavier than needed for a
  small API whose frontend just needs a stable `code` to branch on.
