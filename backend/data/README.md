# `backend/data/`

Holds local runtime data files that are **not** committed.

## `GeoLite2-City.mmdb` (ADR 0016, bd `qr_code_generator-bii`)

Put the MaxMind GeoLite2 **City** database here:

```
backend/data/GeoLite2-City.mmdb
```

The **City** edition is used (not Country) because the scan model keeps a coarse
**`subdivision`** (state / province / 縣市) in addition to `country` — and subdivision only
exists in the City edition. City / lat-long are derived-and-discarded, never persisted
(ADR 0016, 2026-06-12 amendment).

- It is **gitignored** (`backend/data/*.mmdb`) — licensed MaxMind data, never commit it.
- Obtain it with `geoipupdate` (using your `GeoIP.conf`, `EditionIDs GeoLite2-City`) or a
  manual download from the MaxMind portal. See `docs/deploy/hitl-execute-checklist.md`
  (Part A) for the exact steps.
- Point the app at it via `GEOIP_DB_PATH` in your `.env`:
  ```
  GEOIP_DB_PATH=C:\Users\MaxL\work\projects\live_sessions\qr_code_generator\backend\data\GeoLite2-City.mmdb
  ```
- The GeoLite2 EULA requires keeping the file current (replace within 30 days of a new
  release) — run `geoipupdate` on a weekly cron; don't bake a stale copy and forget it.
- Note: the City `.mmdb` is much larger (~60 MB+) than the Country edition (~9 MB).
