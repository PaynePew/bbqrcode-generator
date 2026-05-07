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

- **Deleted** is intentional and terminal. A deleted link cannot be re-activated via PATCH.
- **Expired** is time-based and reversible. A user may update `expires_at` to a future value (or null) to re-activate an expired link.

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
