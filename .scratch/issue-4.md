## Parent

#1 feat: dynamic QR code generator

## What to build

Record every redirect attempt as a scan and expose the analytics endpoint.

**Scan logging:**
Update `GET /r/{token}` to write a row to the `scans` table on every request that hits a known token (302 or 410). Each row captures `token`, `scanned_at`, `status_code`, `ip_address` (from `X-Forwarded-For`, falling back to direct client IP), and `user_agent`. Unknown tokens (404) do not log a scan.

**Analytics endpoint:**
`GET /api/qr/{token}/analytics` returns:

```json
{
  "token": "abc1234",
  "total_scans": 42,
  "scans_by_day": [
    {
      "date": "2026-05-07",
      "count": 10,
      "status_codes": {"302": 8, "410": 2}
    }
  ],
  "recent_scans": [
    {
      "scanned_at": "2026-05-07T12:34:56",
      "status_code": 302,
      "ip_address": "203.0.113.1",
      "user_agent": "Mozilla/5.0 ..."
    }
  ]
}
```

`scans_by_day` is aggregated with GROUP BY date. `recent_scans` lists the 50 most recent raw rows. `ip_address` and `user_agent` may be null.

## Acceptance criteria

- [ ] Successful redirect (302) writes a scan row with correct `status_code`, `ip_address`, and `user_agent`
- [ ] 410 redirect (deleted or expired) also writes a scan row
- [ ] 404 (unknown token) does not write a scan row
- [ ] `GET /api/qr/{token}/analytics` returns 200 with correct `total_scans`, `scans_by_day`, and `recent_scans`
- [ ] `scans_by_day` correctly groups by date and breaks down status codes
- [ ] `recent_scans` is capped at 50 entries
- [ ] Integration tests cover scan recording for 302 and 410, and verify analytics response shape

## Blocked by

- #2 slice 1: golden path — scaffold + create + redirect
