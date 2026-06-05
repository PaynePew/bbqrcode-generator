"""Unit tests for the shared UTC datetime helpers (``backend.timeutil``).

These pin the serialization convention behind beads s4l/8s8: stored datetimes
are naive UTC, and crossing the API wire requires an explicit UTC marker so the
frontend's ``new Date()`` does not parse them as local time and render them off
by the viewer's offset.
"""

from datetime import datetime, timedelta, timezone

from backend.timeutil import iso_utc, now_utc


class TestNowUtc:
    def test_returns_naive_datetime(self):
        # The app's storage convention is naive UTC (tzinfo stripped).
        assert now_utc().tzinfo is None


class TestIsoUtc:
    def test_naive_datetime_tagged_as_utc(self):
        # A naive (assumed-UTC) datetime gains an explicit +00:00 offset.
        result = iso_utc(datetime(2026, 6, 5, 14, 0, 0))
        assert result is not None
        assert result.endswith("+00:00")
        assert datetime.fromisoformat(result).utcoffset() == timedelta(0)

    def test_none_passes_through(self):
        assert iso_utc(None) is None

    def test_already_aware_not_double_tagged(self):
        aware = datetime(2026, 6, 5, 14, 0, 0, tzinfo=timezone.utc)
        result = iso_utc(aware)
        # Idempotent: an already-aware UTC datetime keeps a single +00:00.
        assert result.count("+00:00") == 1
        assert datetime.fromisoformat(result) == aware
