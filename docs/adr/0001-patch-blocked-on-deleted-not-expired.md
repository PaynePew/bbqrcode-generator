# ADR 0001: PATCH is blocked for deleted links, not for expired links

**Status:** Accepted

## Context

`PATCH /api/qr/{token}` needs a policy for links that are no longer active. Two non-active states exist: **deleted** (intentional soft-delete via `DELETE`) and **expired** (time-based, `expires_at <= now()`).

The initial draft blocked PATCH for both states. User Story 7 explicitly allows updating the expiration timestamp — implying users should be able to extend a link that has lapsed.

## Decision

PATCH returns 410 **only** for deleted links. Expired links remain patchable so that a user can update `expires_at` to a future value (or null) to re-activate the link.

## Consequences

- Expired links are a reversible state; deleted links are terminal.
- Clients that assume expired → 410 from PATCH will need to be updated if they were written against the original draft.
- The `status` derivation order (`deleted` > `expired` > `active`) is unchanged.
