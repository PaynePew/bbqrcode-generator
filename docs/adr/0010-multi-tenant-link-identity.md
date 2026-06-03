# ADR 0010: Multi-tenant link identity — no dedup, per-token labels, no campaign entity

**Status:** Accepted

## Context

Phase 1 introduced `owner_id`, which for the first time made *per-owner* URL
deduplication possible (reuse a token when the same owner re-shortens the same URL).
ADR 0002 had already removed dedup in the single-tenant prototype, explicitly
anticipating this migration. With owner scope now real, we re-evaluated dedup and
also needed a way for owners to tell apart the multiple tokens they intentionally
mint for one destination.

## Decision

1. **No deduplication — including per-owner.** Each POST mints a fresh independent
   token even for the same owner + same normalized URL. Multiple tokens per URL is a
   first-class feature (per-placement / per-channel scan tracking); dedup is
   fundamentally incompatible with it.
2. **Optional, free-text, non-unique `label` per Link** so owners can name each token
   ("Lobby poster" vs "Newsletter"). Set at create, editable later, owner-private
   (never on the public redirect or QR image).
3. **No "campaign" entity.** Grouping is something owners do by eye through labels;
   the system tracks no Campaign aggregate. Per-campaign rollups, if ever needed, can
   be derived later (e.g. a label-based GROUP BY) without a new entity today.

## Consequences

- Accidental double-submits create near-duplicate links; treated as a UI concern
  (debounce / disabled submit), not a data-model uniqueness constraint.
- Token uniqueness stays global (forced by the public, owner-less redirect);
  `owner_id` never enters the token (reaffirms ADR 0002 + Phase 1's rejection of
  userId-in-token).
- Phase 9 analytics' "what" dimension is per-token / per-label, not per-campaign.

Extends ADR 0002 under multi-tenancy; supersedes nothing.
