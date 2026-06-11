# PRD: Scan analytics privacy model + redirect/image caching & CDN (Phase 8 + Phase 9 backend)

> One backend build covering Phase 9 (scan analytics, ADR 0016) and Phase 8 (caching & CDN,
> ADR 0017) together — they touch the same redirect/scan code path.

## Problem Statement

As a **Link owner**, when I open a Link's analytics I can only see a total scan count and a
per-day count — I can't tell **where** in the world or on **what kind of device** people scanned
my QR. Worse, the analytics view currently shows me the **raw IP address and user agent** of
everyone who scanned my Link, which breaks the product's privacy promise (ADR 0006 says an owner
sees aggregates, never raw scanner identity).

As a **Link owner**, when I edit a Link's Destination URL or delete a Link, I need scanners to
follow the change immediately — a scanner must never be sent to a stale destination.

As the **person scanning** a QR, I expect the redirect to be fast and always current.

Under the hood, every scan currently blocks the redirect on a synchronous database write, and
every QR image view streams bytes through the application server with no caching — neither is how
a production system should behave, and it weakens the architecture's credibility.

## Solution

A Link owner's analytics now shows **total scans**, **scans over time**, **scans by country**, and
**scans by device class** — and stores **no raw scanner PII at all**: the scanner's IP and user
agent are turned into a coarse country and device class at the moment of the scan and then
discarded, so there is nothing raw to leak. The owner sees total counts, not unique-visitor counts.

Editing a Link's Destination URL (or deleting the Link) takes effect for scanners **immediately**:
a short-lived in-process cache on the redirect path is actively invalidated on every edit/delete,
so a scanner is never sent to a stale destination. The redirect no longer waits on the scan write
(it happens in the background), so the scan path stays fast.

QR images are served as **immutable, long-cached assets from a CDN (CloudFront)** instead of being
streamed through the app server: the app hands the browser a redirect to the current image.
Re-customizing a Link's QR produces a new versioned image, so the owner always sees their latest
design with no stale-image problem.

## User Stories

Owner — analytics:
1. As a Link owner, I want to see the total number of scans for a Link, so that I know how much traffic it drives.
2. As a Link owner, I want to see scans broken down over time (per day), so that I can spot trends and spikes.
3. As a Link owner, I want to see which countries my scans came from, so that I understand my audience's geography.
4. As a Link owner, I want to see what device classes (mobile/desktop) scanned my Link, so that I understand how my audience engages.
5. As a Link owner, I want a recent-activity feed of the latest scans (time, outcome, country, device class), so that the dashboard feels alive and current.
6. As a Link owner, I want to be certain the system never shows me — or even stores — a scanner's raw IP or user agent, so that I can trust the product's privacy stance and not become a custodian of others' PII.
7. As a Link owner, I want analytics to remain owner-only, so that my campaign performance stays private (a non-owner gets a 404, ADR 0009).
8. As a Link owner, I do not need unique-visitor counts, so I accept that no per-scanner identifier is retained.
9. As the demo (read-only) account, I want the seeded Links to show the same rich country/device analytics, so that an interviewer sees a believable, alive dashboard.

Scanner / redirect correctness:
10. As someone scanning a QR, I want the redirect to send me to the Link's current Destination URL, so that I always reach the right place.
11. As a Link owner, when I edit a Link's Destination URL, I want scanners redirected to the new URL immediately, so that a printed QR never sends people to an outdated address.
12. As a Link owner, when I delete a Link, I want scanners to immediately stop being redirected (they get a gone response), so that a removed Link can't keep sending traffic.
13. As a Link owner, when a Link expires, I want the redirect to reflect the expiry automatically without my intervention, so that expired Links stop redirecting on time.
14. As a Link owner, when I reactivate an expired Link by extending its expiry, I want scanners redirected again immediately, so that reactivation is instant.
15. As someone scanning a QR, I want the redirect to be fast, so that I'm not kept waiting.

Image / CDN:
16. As a Link owner, I want my customized QR image to load quickly on my dashboard and link detail, so that the UI feels responsive.
17. As a Link owner, I want my customized QR image served from a CDN with long-lived caching, so that repeated views and shares are fast and don't burden the origin.
18. As a Link owner, when I re-customize my QR, I want to see my newest design immediately (never a stale cached old design), so that my edits are trustworthy.
19. As a Link owner, I want a Link without customization to still return a correct plain (vanilla) QR image, so that every Link always has a scannable image.
20. As a viewer of a shared QR image link, I want the visible URL to belong to the product's own domain, so that links look trustworthy (the app's 302 keeps the app domain in front).

Privacy / trust (cross-cutting):
21. As a person scanning someone's QR, I want my IP and device details never retained, so that scanning a QR doesn't expose my identity to the Link owner.

Developer / operator (stakeholder):
22. As a developer, I want all raw-IP/user-agent handling isolated in one small module, so that the privacy boundary is auditable in a single place.
23. As a developer, I want the redirect cache invalidation driven by exactly two write paths (edit, delete), so that the eviction discipline is simple and hard to get wrong.
24. As a developer, I want the redirect cache to derive Link state on read, so that expiry needs no eviction and the cache can't serve an expired Link as active.
25. As an operator, I want QR image bytes served by CloudFront with a private (OAC-locked) bucket, so that there is a single access path and no direct-to-S3 bypass.
26. As an operator, I want the Scan-schema migration to require no data backfill, so that the deploy is a simple forward migration.
27. As a developer, I want the scan write moved off the redirect's critical path, so that the public scan endpoint stays fast and resilient.

## Implementation Decisions

Modules (🟢 new deep module; otherwise modify an existing module):

- **`scan_derivation` (🟢 new deep module).** Pure functions `derive_country(ip) -> country | None`
  and `derive_device_class(user_agent) -> device_class | None`. This is the single **privacy
  boundary**: the only code that touches the raw scanner IP / user agent, both discarded
  immediately after deriving the coarse value. No DB, no HTTP — pure and independently testable.
  The geo source (e.g. `geoip2` + a bundled GeoLite2-Country database vs an ingest-time lookup) and
  the UA parser are an internal detail chosen at build time and hidden behind this interface.
- **Scan model + Alembic migration `0006` (modify).** Drop `scans.ip_address` and
  `scans.user_agent`; add `scans.country` and `scans.device_class` (both nullable strings). **No
  data backfill** (throwaway prototype data, per the Phase 2 stance). Removing the columns is what
  structurally fixes the current ADR 0006 violation in `analytics._recent_scans`.
- **Async scan ingestion (modify `router` + `scan_repository`).** The redirect handler derives the
  coarse country/device class at the request edge (while the request is in hand), then hands the
  Scan write to FastAPI `BackgroundTasks`; the 302/410 returns without waiting for the commit.
  `record_scan` now accepts `country` / `device_class` instead of `ip_address` / `user_agent`.
  Trade-off: **at-most-once** recording (a scan may be lost on a crash between responding and
  writing) — acceptable for analytics counting (ADR 0016).
- **`analytics.aggregate_scans` (modify deep module).** Add `scans_by_country` and
  `scans_by_device_class` aggregates; change `recent_scans` to a coarse feed (`scanned_at`,
  `status_code`, `country`, `device_class`) with no IP/UA. Stays a pure function over `list[Scan]`.
- **`link_cache` (🟢 new deep module).** An in-process `cachetools.TTLCache` (no Redis) keyed by
  Token, caching the snapshot `{original_url, expires_at, deleted_at}` — the fields needed to derive
  Link state. Interface: `get(token)`, a load-on-miss path, and `evict(token)`. **TTL = 300 s as a
  pure safety net**; correctness comes from active eviction. The redirect handler derives Link state
  on read (so expiry is automatic, no eviction needed) and the PATCH and DELETE handlers call
  `evict(token)` — **exactly two eviction points**. **No negative caching** of unknown tokens.
  Correct only at one uvicorn worker (ADR 0017); the multi-worker upgrade is a shared Redis cache.
- **`storage` gateway (modify deep module).** `url_for(key)` returns the CloudFront URL when
  `CDN_BASE_URL` is configured, else the existing S3 URL; `InMemoryGateway` unchanged for tests.
  `put` accepts an immutable `Cache-Control` (`public, max-age=31536000, immutable`) applied to
  composite uploads (not to private logos).
- **Image endpoint `GET /api/qr/{token}/image` (modify `router`).** For a customized Link, return a
  302 to `storage.url_for(image_key)` (the CDN URL) with `Cache-Control: no-cache` on the 302; for a
  vanilla Link, regenerate the PNG inline with `Cache-Control: no-cache`. The token endpoint stays a
  **mutable pointer** (it can't be `immutable` because re-customization changes its content); only
  the versioned object is immutable.
- **CloudFront + OAC provisioning (HITL infra, not app code).** A separate human-in-the-loop task
  (like the S3 bucket, bead `6c0`): create a CloudFront distribution fronting `qrgen-customized-prod`,
  attach **Origin Access Control**, make the bucket **private** (replace the public-read policy with a
  CloudFront-only policy), use the **default `*.cloudfront.net`** domain, and document it under
  `docs/deploy`. The app integrates via the `CDN_BASE_URL` env var consumed by `storage.url_for`.

New runtime dependencies: `cachetools`; a geo source for country derivation; a user-agent parser for
device-class derivation (the latter two chosen at build time, hidden behind `scan_derivation`).

Unchanged contracts: analytics stays owner-only (404 to non-owners, ADR 0009); the redirect stays
public; the error envelope (ADR 0012) is unchanged.

## Testing Decisions

A good test asserts **external behavior**, not implementation details — given inputs, assert the
observable outputs (returned values, HTTP responses, what is and isn't stored), never the internal
call sequence. DB-touching tests use the per-session Postgres testcontainer with per-test savepoint
rollback; pure-logic modules are tested without any DB and stay instant (see `tests/conftest.py`,
and the `auth_client` / `owner` fixtures for owner-scoped endpoints).

Modules to test (all four selected):

- **`scan_derivation`** (pure, privacy-critical): assert IP→country and UA→device_class derivations
  for representative inputs, `None`/empty handling, and — most importantly — that a recorded Scan
  never carries a raw IP or user agent. Highest-priority correctness/privacy test.
- **`link_cache` + a redirect anti-stale integration test** (highest value): unit-test hit/miss/evict
  and that state is derived on read (an entry past its `expires_at` resolves to expired without
  eviction); integration-test that editing a Link's Destination URL (PATCH) makes the very next
  redirect follow the new URL, and that deleting a Link makes the next redirect return gone — proving
  the eviction discipline holds. Prior art: existing redirect 302/410 tests and `tests/test_scan_repository.py`.
- **`analytics.aggregate_scans`**: assert the `scans_by_country` and `scans_by_device_class` buckets
  are correct and that `recent_scans` carries no IP/UA fields. Prior art: `tests/test_analytics_aggregate.py`,
  `tests/test_analytics.py`.
- **`storage.url_for` (CDN) + image endpoint 302**: assert `url_for` returns the CDN URL when
  `CDN_BASE_URL` is set and the S3 URL otherwise; integration-test that a customized Link's image
  endpoint returns a 302 to the CDN URL while a vanilla Link returns an inline PNG.

## Out of Scope

- The **SQS → S3 → daily-batch pipeline** and any **daily email / report** delivery — designed but
  deferred (ADR 0016); this build uses live SQL aggregation + in-process async ingestion only.
- **Redis** — not introduced (ADR 0017); both future homes (multi-worker redirect cache, off-process
  rate-limiter store) are deferred.
- A **custom CDN domain** (`cdn.qrcode.paynepew.dev`) — deferred (needs platform-owned DNS; hidden
  behind the app's 302 anyway).
- The **analytics dashboard panel / charts** and any frontend wiring — that is Phase 7.
- **Backfilling** existing Scan rows with country/device class — no backfill.
- **`scans`-table retention / purge** (topic #6) — keep-forever is fine at this scale; revisit later.
- **Rate-limiting the redirect path** against flooding — belongs at the platform-owned edge, not here
  (and is why negative caching is rejected).
- **Whole-site CDN** (a CDN in front of the whole domain) — platform-owned.

## Further Notes

- This is a single backend build covering **Phase 8 (ADR 0017)** and **Phase 9 (ADR 0016)** together
  because both touch the same redirect/scan code path; one pass avoids editing that code twice. Phase
  9's async ingestion is the prerequisite that makes the Phase 8 redirect cache meaningful (with the
  write off the path, the read is the only thing left to cache).
- **Honest scale framing (recorded in both ADRs):** at the current personal/interview scale none of
  the caching is load-driven — the redirect read is a sub-ms localhost Postgres lookup and the image
  endpoint is not the scan hot path. The genuine value is (a) richer, privacy-correct analytics, (b)
  immediate edit-correctness on the redirect, (c) a cleaner security posture (OAC-private bucket), and
  (d) a correct, demonstrable cache/CDN architecture. Not to be mistaken for a load-driven change.
- Respects: ADR 0006 (no raw scanner identity to owner), ADR 0009 (owner-only analytics), ADR 0011
  (versioned immutable composites), ADR 0012 (error envelope), ADR 0013 (no raw IP in logs), ADR 0016,
  ADR 0017.
- The CloudFront + OAC standup is a HITL provisioning bead; the app code can land and be tested with
  `CDN_BASE_URL` unset (falls back to the S3 URL / `InMemoryGateway`), then flip to CloudFront once
  provisioned.
- Suggested next step: run the slicing step (`to-issues`) to break this into tracer-bullet vertical
  slices, with the CloudFront provisioning as its own HITL slice.
