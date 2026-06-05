"""API timestamps cross the wire with a UTC marker (bead s4l).

Stored datetimes are naive UTC (``router._now_utc`` strips tzinfo). Serializing
them with a bare ``.isoformat()`` emits no ``Z``/offset, so the frontend's
``new Date()`` parses them as *local* time -> off by the viewer's UTC offset
(~8h for the UTC+8 reporter). The fix tags every outgoing timestamp as UTC via
``router._iso_utc``.

Two layers:
- pure-logic unit tests on ``_iso_utc`` (no DB, instant);
- endpoint regression guards that the info/list payloads carry a marker
  (the customization ``updated_at`` is guarded in test_customization.py).

Scope (bead s4l): ``router.py`` timestamps only. ``analytics.py``'s
``scanned_at`` serialization carries the same skew and is tracked separately.
"""

from datetime import datetime, timedelta, timezone

from backend.router import _iso_utc


def _is_tz_aware_iso(value: str) -> bool:
    """A serialized timestamp string parses back to a tz-aware datetime."""
    return datetime.fromisoformat(value).tzinfo is not None


class TestIsoUtcHelper:
    def test_naive_datetime_tagged_as_utc(self):
        # A naive (assumed-UTC) datetime gains an explicit +00:00 offset.
        result = _iso_utc(datetime(2026, 6, 5, 14, 0, 0))
        assert result is not None
        assert result.endswith("+00:00")
        assert datetime.fromisoformat(result).utcoffset() == timedelta(0)

    def test_none_passes_through(self):
        assert _iso_utc(None) is None

    def test_already_aware_not_double_tagged(self):
        aware = datetime(2026, 6, 5, 14, 0, 0, tzinfo=timezone.utc)
        result = _iso_utc(aware)
        # Idempotent: an already-aware UTC datetime keeps a single +00:00.
        assert result.count("+00:00") == 1
        assert datetime.fromisoformat(result) == aware


class TestEndpointTimestampsCarryUtcMarker:
    def test_info_payload_timestamps_are_tz_aware(self, auth_client):
        # GET /api/qr/{token} returns the full _link_response (create itself
        # returns no timestamps). Covers all three datetime fields incl.
        # expires_at.
        token = auth_client.post(
            "/api/qr/create",
            json={"url": "https://example.com/tz", "expires_at": "2099-01-01T00:00:00"},
        ).json()["token"]
        data = auth_client.get(f"/api/qr/{token}").json()
        assert _is_tz_aware_iso(data["created_at"])
        assert _is_tz_aware_iso(data["updated_at"])
        assert _is_tz_aware_iso(data["expires_at"])

    def test_list_payload_created_at_is_tz_aware(self, auth_client):
        auth_client.post("/api/qr/create", json={"url": "https://example.com/tz3"})
        item = auth_client.get("/api/qr").json()["items"][0]
        assert _is_tz_aware_iso(item["created_at"])
