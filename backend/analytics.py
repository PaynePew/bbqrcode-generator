from __future__ import annotations

from collections import defaultdict

from .models import Scan
from .timeutil import iso_utc

DEFAULT_RECENT_LIMIT = 50


def aggregate_scans(
    scans: list[Scan], *, recent_limit: int = DEFAULT_RECENT_LIMIT
) -> dict:
    return {
        "total_scans": len(scans),
        "scans_by_day": _scans_by_day(scans),
        "scans_by_country": _scans_by_field(scans, "country"),
        "scans_by_subdivision": _scans_by_field(scans, "subdivision"),
        "scans_by_device_class": _scans_by_field(scans, "device_class"),
        "recent_scans": _recent_scans(scans, recent_limit),
    }


def _scans_by_day(scans: list[Scan]) -> list[dict]:
    day_data: dict[str, dict] = defaultdict(
        lambda: {"count": 0, "status_codes": defaultdict(int)}
    )
    for scan in scans:
        day = scan.scanned_at.date().isoformat()
        day_data[day]["count"] += 1
        day_data[day]["status_codes"][str(scan.status_code)] += 1
    return [
        {
            "date": day,
            "count": data["count"],
            "status_codes": dict(data["status_codes"]),
        }
        for day, data in sorted(day_data.items())
    ]


def _scans_by_field(scans: list[Scan], field: str) -> dict[str, int]:
    """Return a {value -> count} breakdown for a coarse categorical field.

    NULL / None values are grouped under the key "unknown".
    """
    counts: dict[str, int] = defaultdict(int)
    for scan in scans:
        value: str = getattr(scan, field) or "unknown"
        counts[value] += 1
    return dict(counts)


def _recent_scans(scans: list[Scan], limit: int) -> list[dict]:
    """Return the most recent scans with coarse derived fields only (ADR 0016).

    Fields returned: scanned_at, status_code, country, subdivision,
    device_class.  Raw IP and user agent are never returned — they no longer
    exist on the Scan model after migration 0006.
    """
    return [
        {
            "scanned_at": iso_utc(scan.scanned_at),
            "status_code": scan.status_code,
            "country": scan.country,
            "subdivision": scan.subdivision,
            "device_class": scan.device_class,
        }
        for scan in sorted(scans, key=lambda s: s.scanned_at, reverse=True)[:limit]
    ]
