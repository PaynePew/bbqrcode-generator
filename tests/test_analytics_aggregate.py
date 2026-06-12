from datetime import datetime, timedelta

from backend.analytics import DEFAULT_RECENT_LIMIT, aggregate_scans
from backend.models import Scan


def _scan(
    scanned_at: datetime,
    status_code: int = 302,
    country: str | None = "US",
    subdivision: str | None = "CA",
    device_class: str | None = "desktop",
) -> Scan:
    return Scan(
        token="ABCDEFG",
        scanned_at=scanned_at,
        status_code=status_code,
        country=country,
        subdivision=subdivision,
        device_class=device_class,
    )


class TestEmptyInput:
    def test_empty_list_yields_zero_totals(self):
        result = aggregate_scans([])
        assert result == {
            "total_scans": 0,
            "scans_by_day": [],
            "scans_by_country": {},
            "scans_by_subdivision": {},
            "scans_by_device_class": {},
            "recent_scans": [],
        }


class TestTotalScans:
    def test_total_matches_input_length(self):
        scans = [_scan(datetime(2026, 5, 8, 10, 0, 0)) for _ in range(7)]
        assert aggregate_scans(scans)["total_scans"] == 7


class TestScansByDay:
    def test_single_day_single_scan(self):
        scans = [_scan(datetime(2026, 5, 8, 10, 0, 0))]
        result = aggregate_scans(scans)
        assert result["scans_by_day"] == [
            {"date": "2026-05-08", "count": 1, "status_codes": {"302": 1}}
        ]

    def test_status_code_subtotals(self):
        day = datetime(2026, 5, 8, 10, 0, 0)
        scans = [
            _scan(day, status_code=302),
            _scan(day + timedelta(seconds=1), status_code=302),
            _scan(day + timedelta(seconds=2), status_code=410),
        ]
        result = aggregate_scans(scans)
        bucket = result["scans_by_day"][0]
        assert bucket["count"] == 3
        assert bucket["status_codes"] == {"302": 2, "410": 1}

    def test_multiple_days_sorted_ascending(self):
        scans = [
            _scan(datetime(2026, 5, 9, 10, 0, 0)),
            _scan(datetime(2026, 5, 7, 10, 0, 0)),
            _scan(datetime(2026, 5, 8, 10, 0, 0)),
        ]
        dates = [d["date"] for d in aggregate_scans(scans)["scans_by_day"]]
        assert dates == ["2026-05-07", "2026-05-08", "2026-05-09"]

    def test_status_codes_is_plain_dict_not_defaultdict(self):
        # Defensive: we serialize to JSON, so leaking a defaultdict would change behavior.
        result = aggregate_scans([_scan(datetime(2026, 5, 8))])
        assert type(result["scans_by_day"][0]["status_codes"]) is dict


class TestScansByCountry:
    def test_single_country_bucket(self):
        scans = [
            _scan(datetime(2026, 5, 8), country="US"),
            _scan(datetime(2026, 5, 8), country="US"),
        ]
        assert aggregate_scans(scans)["scans_by_country"] == {"US": 2}

    def test_multiple_country_buckets(self):
        scans = [
            _scan(datetime(2026, 5, 8), country="US"),
            _scan(datetime(2026, 5, 8), country="TW"),
            _scan(datetime(2026, 5, 8), country="US"),
            _scan(datetime(2026, 5, 8), country="DE"),
        ]
        result = aggregate_scans(scans)["scans_by_country"]
        assert result == {"US": 2, "TW": 1, "DE": 1}

    def test_none_country_grouped_under_unknown(self):
        scans = [
            _scan(datetime(2026, 5, 8), country=None),
            _scan(datetime(2026, 5, 8), country="US"),
        ]
        result = aggregate_scans(scans)["scans_by_country"]
        assert result["unknown"] == 1
        assert result["US"] == 1

    def test_result_is_plain_dict(self):
        scans = [_scan(datetime(2026, 5, 8), country="US")]
        assert type(aggregate_scans(scans)["scans_by_country"]) is dict


class TestScansBySubdivision:
    def test_single_subdivision_bucket(self):
        scans = [
            _scan(datetime(2026, 5, 8), subdivision="CA"),
            _scan(datetime(2026, 5, 8), subdivision="CA"),
        ]
        assert aggregate_scans(scans)["scans_by_subdivision"] == {"CA": 2}

    def test_multiple_subdivision_buckets(self):
        scans = [
            _scan(datetime(2026, 5, 8), subdivision="CA"),
            _scan(datetime(2026, 5, 8), subdivision="TW-TPE"),
            _scan(datetime(2026, 5, 8), subdivision="CA"),
            _scan(datetime(2026, 5, 8), subdivision="NY"),
        ]
        result = aggregate_scans(scans)["scans_by_subdivision"]
        assert result == {"CA": 2, "TW-TPE": 1, "NY": 1}

    def test_none_subdivision_grouped_under_unknown(self):
        scans = [
            _scan(datetime(2026, 5, 8), subdivision=None),
            _scan(datetime(2026, 5, 8), subdivision="CA"),
        ]
        result = aggregate_scans(scans)["scans_by_subdivision"]
        assert result["unknown"] == 1
        assert result["CA"] == 1

    def test_result_is_plain_dict(self):
        scans = [_scan(datetime(2026, 5, 8), subdivision="CA")]
        assert type(aggregate_scans(scans)["scans_by_subdivision"]) is dict


class TestScansByDeviceClass:
    def test_single_device_class_bucket(self):
        scans = [
            _scan(datetime(2026, 5, 8), device_class="mobile"),
            _scan(datetime(2026, 5, 8), device_class="mobile"),
        ]
        assert aggregate_scans(scans)["scans_by_device_class"] == {"mobile": 2}

    def test_multiple_device_class_buckets(self):
        scans = [
            _scan(datetime(2026, 5, 8), device_class="mobile"),
            _scan(datetime(2026, 5, 8), device_class="desktop"),
            _scan(datetime(2026, 5, 8), device_class="bot"),
            _scan(datetime(2026, 5, 8), device_class="desktop"),
        ]
        result = aggregate_scans(scans)["scans_by_device_class"]
        assert result == {"mobile": 1, "desktop": 2, "bot": 1}

    def test_none_device_class_grouped_under_unknown(self):
        scans = [
            _scan(datetime(2026, 5, 8), device_class=None),
            _scan(datetime(2026, 5, 8), device_class="mobile"),
        ]
        result = aggregate_scans(scans)["scans_by_device_class"]
        assert result["unknown"] == 1
        assert result["mobile"] == 1

    def test_result_is_plain_dict(self):
        scans = [_scan(datetime(2026, 5, 8), device_class="desktop")]
        assert type(aggregate_scans(scans)["scans_by_device_class"]) is dict


class TestRecentScans:
    def test_field_shape(self):
        scans = [_scan(datetime(2026, 5, 8, 10, 0, 0))]
        recent = aggregate_scans(scans)["recent_scans"]
        assert recent[0] == {
            "scanned_at": "2026-05-08T10:00:00+00:00",
            "status_code": 302,
            "country": "US",
            "subdivision": "CA",
            "device_class": "desktop",
        }

    def test_no_ip_address_or_user_agent_in_recent_scans(self):
        """recent_scans must never expose raw scanner identity (ADR 0016)."""
        scans = [_scan(datetime(2026, 5, 8, 10, 0, 0))]
        recent = aggregate_scans(scans)["recent_scans"]
        assert "ip_address" not in recent[0]
        assert "user_agent" not in recent[0]

    def test_scanned_at_carries_utc_marker(self):
        # bead 8s8: scanned_at is stored naive-UTC; it must cross the wire
        # tz-aware so the frontend does not render it ~8h off (sibling of s4l).
        scans = [_scan(datetime(2026, 5, 8, 10, 0, 0))]
        recent = aggregate_scans(scans)["recent_scans"]
        assert datetime.fromisoformat(recent[0]["scanned_at"]).tzinfo is not None

    def test_sorted_descending_by_scanned_at(self):
        base = datetime(2026, 5, 8, 10, 0, 0)
        scans = [_scan(base + timedelta(seconds=i)) for i in range(5)]
        timestamps = [s["scanned_at"] for s in aggregate_scans(scans)["recent_scans"]]
        assert timestamps == sorted(timestamps, reverse=True)

    def test_capped_at_default_limit(self):
        base = datetime(2026, 5, 8, 0, 0, 0)
        scans = [
            _scan(base + timedelta(seconds=i)) for i in range(DEFAULT_RECENT_LIMIT + 10)
        ]
        result = aggregate_scans(scans)
        assert len(result["recent_scans"]) == DEFAULT_RECENT_LIMIT

    def test_custom_limit(self):
        base = datetime(2026, 5, 8, 0, 0, 0)
        scans = [_scan(base + timedelta(seconds=i)) for i in range(20)]
        result = aggregate_scans(scans, recent_limit=3)
        assert len(result["recent_scans"]) == 3

    def test_limit_zero_returns_empty(self):
        scans = [_scan(datetime(2026, 5, 8))]
        assert aggregate_scans(scans, recent_limit=0)["recent_scans"] == []

    def test_total_scans_unaffected_by_recent_limit(self):
        # total_scans counts ALL scans, not just the recent window.
        base = datetime(2026, 5, 8, 0, 0, 0)
        scans = [_scan(base + timedelta(seconds=i)) for i in range(75)]
        result = aggregate_scans(scans, recent_limit=10)
        assert result["total_scans"] == 75
        assert len(result["recent_scans"]) == 10
