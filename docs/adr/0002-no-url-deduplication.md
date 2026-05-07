# ADR 0002: No URL deduplication — each POST always creates a new token

**Status:** Accepted

## Context

The initial acceptance criterion stated "two submissions of equivalent URLs return the same token." Implementing this requires a pre-insert lookup (`WHERE original_url = ?`) and means one token can represent a shared resource with no clear owner.

In a single-tenant prototype this works, but it becomes a liability when migrating to multi-tenancy (Path B): if two future users both shorten the same URL, the shared token has no clean owner and access control cannot be assigned without breaking existing behavior.

## Decision

Remove URL deduplication entirely. Every POST creates a new independent token, even if the normalized URL already exists in the database. The optimistic insertion loop handles hash collisions on `token`, but does not check for duplicate `original_url`.

Normalization (lowercase host, https coercion, port stripping, sorted query params) is retained for security and storage consistency, not as a deduplication key.

## Consequences

- Each link is an independent, ownable resource — adding `owner_id` in the future is a clean `ALTER TABLE` with no ambiguity.
- Users may accumulate multiple tokens for the same destination URL; this is acceptable for a prototype.
- The "idempotent shortening" UX (submit same URL, get same token back) is not available in this version.
