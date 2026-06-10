# ADR 0015: Destination URL safety — mint-time hygiene; SSRF and malware-reputation deferred

**Status:** Accepted

## Context

Phase 10 ("URL safety & SSRF") set out to harden the service against accepting an
arbitrary user-supplied destination URL (`original_url`). Grilling the threat against the
actual code changed the framing.

The service **never makes a server-side request to `original_url`.** A destination URL is
only ever (1) stored at create/PATCH and (2) returned to the scanner's browser as a 302
`Location` header at `GET /r/{token}`. The QR image encodes the Short URL (`/r/{token}`),
not the destination. The only outbound call the backend makes is to Google to verify ID
tokens (`google_identity.py`), unrelated to the destination.

Consequences of that fact:

- **SSRF (the server fetching an attacker-controlled URL) has no surface today.** It
  becomes real only if a feature that fetches the destination server-side is added (link
  preview / unfurl, thumbnail / screenshot, server-side page fetch). None is planned.
- The live threat is **open redirect** (sending a scanner to a malicious site), plus
  input-hygiene concerns (over-long URLs, non-http(s) schemes, internationalized-host
  spoofing, internal-IP literals).
- Both SSRF and malware-reputation screening share a **time-of-check vs time-of-use gap
  that QR maximizes**: a QR is minted once and scanned for months, so a URL clean at mint
  can turn malicious later (domain expiry / takeover, bait-and-switch, DNS rebinding). A
  check at mint can only assert "clean as of mint," and that assertion decays. The industry
  pattern (Bitly / TinyURL, and Safe Browsing's own design) puts the authoritative
  reputation / SSRF gate at **access time** — a serve-time interstitial, a background
  re-scan, or a fetch-time resolve-and-pin — not at mint.

## Decision

**Phase 10 ships only deterministic, string-only mint-time hygiene** in
`backend/url_validator.validate_and_normalize` (shared by create and PATCH). These checks
are pure functions of the URL string, so checking once at mint is correct and sufficient:

1. **Scheme allowlist** — only `http` / `https` (already in place).
2. **Length cap** — reject input over **2048** characters → `INVALID_URL` (422).
3. **IDNA / UTS-46 normalization** — normalize the host with the `idna` package (IDNA 2008
   + UTS-46), store the canonical ASCII / punycode form, and reject hosts that fail IDNA
   validation. (`idna` is promoted from a transitive to an explicit dependency.) Homograph
   *detection* (mixed-script confusables) is explicitly out of scope — normalization is the
   high-value 80%.
4. **IP-literal blocklist** — reject host IP literals that are loopback / private /
   link-local (existing), extended with `is_reserved` / `is_multicast` / `is_unspecified`
   and IPv4-mapped-IPv6 unwrapping.

**Rejection shape** reuses the existing `INVALID_URL` 422 envelope (ADR 0012); no new error
code is introduced.

**The redirect path (`GET /r/{token}`) is unchanged** — with SSRF and malware screening
deferred, there is no serve-time work in Phase 10.

**Deferred, with the correct future home recorded:**

- **SSRF protection** — deferred until a server-side fetch of the destination exists. When
  it does, the guard belongs **at the fetch point**, doing DNS **resolve-and-pin**: resolve
  → validate every resolved IP → pin the connection to a validated IP while preserving the
  original Host / TLS SNI → re-validate on each redirect hop. A mint-time DNS check cannot
  defend this (rebinding trivially bypasses it) and would give false confidence. Adopt a
  reference implementation rather than hand-rolling: `Drawbridge` or `ssrf-protect`; see the
  OWASP SSRF Prevention Cheat Sheet.
- **Malware-reputation screening** — deferred. If taken on, the authoritative gate is
  **serve-time** (an interstitial warning plus background re-scan), not a mint-only check,
  which for printed QRs is security theater. Tooling note: **Google Safe Browsing v4 is
  deprecated; the server-side successor is the Google Cloud Web Risk API**
  (`google-cloud-webrisk`). The roadmap's earlier "Safe Browsing API" wording is superseded
  by this.

## Consequences

- Phase 10's shipped surface is small, dependency-light (only promoting `idna`),
  latency-free, and honest: it defends the classes a string check *can* defend (scheme,
  length, internationalized-host spoofing, internal-IP literals) and does not pretend to
  defend the malware / SSRF it cannot.
- A future contributor who adds a server-side fetch of the destination MUST add the
  fetch-time resolve-and-pin SSRF guard at that point; this ADR is the breadcrumb. A PR that
  "adds private-IP DNS resolution to mint-time validation" should be questioned against this
  ADR as false confidence.
- Whoever takes on malware screening starts from "serve-time interstitial + Web Risk," not
  "Safe Browsing lookup at create."
- Normalization here also feeds storage consistency (and any future comparison), consistent
  with ADR 0002's stance that normalization is for security / consistency, not
  deduplication.

> Numbering note: ADR 0014 is the platform repo's edge-ingress decision, referenced from
> qrcode's roadmap but not part of qrcode's `docs/adr/` sequence. qrcode skips 0014 to avoid
> a cross-repo number clash; this is qrcode ADR 0015.
