# ADR 0013: No client IP addresses in application logs (extends ADR 0006)

**Status:** Accepted

## Context

Phase 5 introduces structured (JSON) application logging with a per-request correlation
id and a post-auth `user_id`. ADR 0006 keeps raw scanner IPs out of the *analytics UI* but
explicitly does not govern logs or retention. Logs are a new surface that, if it captured
raw client IPs, would re-introduce exactly the retained IP trail ADR 0006 is wary of —
through the back door — especially on the public redirect path, whose "clients" are
non-consenting scanners.

## Decision

Application logs never contain raw client IP addresses.

- The **public redirect path logs no IP at all** — scanners did not opt into tracking.
- Where IP correlation has genuine operational value (rate-limit / auth abuse detection),
  logs carry a **salted hash or truncated** IP, never the raw value — enough to spot "one
  source hammering many" without retaining the address.
- Logs also never contain secrets, session cookies, Google ID tokens, `Authorization`
  headers, or user email / name (use the internal `user_id`). `original_url` is treated as
  user data and is not logged by default.
- Retention: logs rotate and are kept ~30 days.

## Consequences

- As in ADR 0006, the conservative direction is the cheap-to-reverse one. A future
  contributor who wants raw IPs for a specific, justified need should add it deliberately
  (and note why), not have it on by default; a PR that "just adds client IP to the access
  log" should be questioned against this ADR.
- Error tracking (e.g. Sentry) is deferred; the catch-all handler logs stack + correlation
  id, which suffices at this scale. The handler seam stays Sentry-ready if added later.
- The raw IP still lives transiently in the in-memory rate limiter (ADR 0007) and, today,
  in `scans.ip_address`; changing the *scan-row* retention is a separate Phase 9 decision,
  not this one.
