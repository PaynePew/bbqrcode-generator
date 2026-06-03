# QR Code Generator — Domain Glossary

## Link States

A **Link** (one row in the `links` table) can be in exactly one of three states at any point in time, derived at read time:

| State | Condition | Mutable via PATCH? |
|-------|-----------|-------------------|
| `active` | `deleted_at IS NULL` AND (`expires_at IS NULL` OR `expires_at > now()`) | Yes |
| `expired` | `deleted_at IS NULL` AND `expires_at <= now()` | Yes — can be re-activated |
| `deleted` | `deleted_at IS NOT NULL` | No — terminal state |

**deleted** takes precedence over **expired** in status derivation.

### Key distinctions

- **Deleted** is intentional and terminal. A deleted link cannot be reactivated via PATCH.
- **Expired** is time-based and reversible. A user may update `expires_at` to a future value (or null) to reactivate an expired link.

### Reactivation (重新啟用)

**Reactivation** is the canonical name for the operation that returns an `expired` Link to `active` by PATCH-ing `expires_at` to a future value or `null`. It is the inverse of natural expiry, exposed in the dashboard as a one-click action.

Reactivation applies only to `expired`. It is **not** valid on `deleted` links — terminal state remains terminal.

### Derived states (frontend-only)

These states do **not** exist in the database or in any API response. They are computed by the frontend on top of the canonical states above and surfaced in the UI.

| Derived state | Condition | Origin |
|--------------|-----------|--------|
| `missing` | A token sits in browser localStorage history, but `GET /api/qr/{token}` returns 404 | The browser's local history has drifted from the server (DB reset, link purged out-of-band, history imported from another browser) |

`missing` is rendered with a distinct badge in the dashboard list and a manual "remove from history" action. The frontend MUST NOT auto-purge missing entries silently — the user needs to see that data drift happened.

#### Display priority

The frontend reconciles three signals to decide what state to render for a Link History entry: the localStorage row (with its `dismissed` flag), the cached result of `GET /api/qr/{token}`, and any optimistic write made by a successful mutation. The priority is fixed:

1. API returns 404 → `missing`
2. API has data (including optimistically written data) → the API's `status`
3. Query is still loading AND `dismissed=true` → `deleted` (synchronous fallback)
4. Query is still loading AND `dismissed=false` → `loading`

API truth wins over the local `dismissed` flag once it has loaded. The `dismissed` flag is a fallback for the loading window, not an independent source of truth. A successful `DELETE` writes `status='deleted'` into the query cache optimistically so rule 2 carries the new state through immediately, before the background refetch lands.

## Link History (frontend, Phase 1)

The **Link History** is the per-browser list of tokens previously created from this device, kept in `localStorage`. It is the Phase 1 substitute for user identity — there is no auth, so the dashboard can only ever show the links a given browser has minted itself.

Link History supports a soft/hard removal distinction (a `dismissed` flag separates "deleted on the server but still in my history" from "purged from history entirely") and a recover-by-token affordance for users who lose their localStorage. Schema details and operations live in PRD #6.

When auth is introduced, Link History is expected to migrate into a server-side per-user concept; the term will outlive its localStorage implementation.

## User

A **User** (one row in the `users` table) is an authenticated account, introduced in Phase 1 (ADR 0009). Identity is keyed by **`google_sub`** — Google's stable, unique subject id — not by email (which can change). A User carries `email`, `name`, `picture`, `created_at`, `last_login_at`, and an **`is_demo`** flag marking the single shared read-only demo account.

A User is created or refreshed by a Google sign-in: the backend verifies Google's ID token once, then issues its own session (it does not reuse Google's token). Owning Links and the migration of Link History to a server-side per-user concept are later slices; this term names the account itself.

## Session

A **Session** is the app's own proof of a signed-in User, carried in a signed, `httpOnly` + `SameSite=Lax` cookie (`Secure` in production). It encodes only the User id and is verified on each request; a tampered, expired, or dangling cookie is treated as no session at all (401 on owner-only endpoints). Per ADR 0009 the app issues this session after verifying Google's ID token — Google's token is never the session.

## Scan

A **Scan** is a record of a single redirect attempt on a known token. Scans are logged for all known tokens (302 and 410 outcomes). Unknown tokens (404) do not produce a Scan.

## Token

A **Token** is the 7-character Base62 identifier that appears in the short URL. It is derived deterministically from the normalized `original_url`, a server-side secret, and a nonce.

Each POST always produces a new token — duplicate URLs are not deduplicated. Normalization exists for security and storage consistency, not as a deduplication key.

## Short URL

The **Short URL** is the full redirect endpoint URL (`{BASE_URL}/r/{token}`). It is encoded into the QR code image.

## Link Lifecycle

```
[created] → active → expired  ←→  (re-activated by PATCH expires_at)
                 ↓
              deleted  (terminal)
```
