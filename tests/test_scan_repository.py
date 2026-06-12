from datetime import datetime, timedelta

from backend import scan_repository
from backend.models import Scan

NOW = datetime(2026, 5, 8, 12, 0, 0)


class TestRecordScan:
    def test_inserts_row_with_coarse_fields(self, db_session):
        scan_repository.record_scan(
            db_session,
            token="ABCDEFG",
            scanned_at=NOW,
            status_code=302,
            country="TW",
            subdivision="TPE",
            device_class="mobile",
        )
        rows = db_session.query(Scan).filter(Scan.token == "ABCDEFG").all()
        assert len(rows) == 1
        row = rows[0]
        assert row.scanned_at == NOW
        assert row.status_code == 302
        assert row.country == "TW"
        assert row.subdivision == "TPE"
        assert row.device_class == "mobile"

    def test_persists_null_coarse_fields(self, db_session):
        scan_repository.record_scan(
            db_session,
            token="HIJKLMN",
            scanned_at=NOW,
            status_code=410,
            country=None,
            subdivision=None,
            device_class=None,
        )
        row = db_session.query(Scan).filter(Scan.token == "HIJKLMN").first()
        assert row.country is None
        assert row.subdivision is None
        assert row.device_class is None

    def test_no_ip_address_or_user_agent_column(self, db_session):
        """Scan model must not expose raw privacy-leaking columns (ADR 0016)."""
        scan_repository.record_scan(
            db_session,
            token="PRIVTEST",
            scanned_at=NOW,
            status_code=302,
            country=None,
            subdivision=None,
            device_class="desktop",
        )
        row = db_session.query(Scan).filter(Scan.token == "PRIVTEST").first()
        assert not hasattr(row, "ip_address"), "ip_address must not exist on Scan"
        assert not hasattr(row, "user_agent"), "user_agent must not exist on Scan"


class TestScansForToken:
    def test_returns_only_scans_with_matching_token(self, db_session):
        scan_repository.record_scan(
            db_session,
            token="MATCH00",
            scanned_at=NOW,
            status_code=302,
            country=None,
            subdivision=None,
            device_class=None,
        )
        scan_repository.record_scan(
            db_session,
            token="MATCH00",
            scanned_at=NOW + timedelta(seconds=1),
            status_code=410,
            country=None,
            subdivision=None,
            device_class=None,
        )
        scan_repository.record_scan(
            db_session,
            token="OTHER00",
            scanned_at=NOW,
            status_code=302,
            country=None,
            subdivision=None,
            device_class=None,
        )
        scans = scan_repository.scans_for_token(db_session, "MATCH00")
        assert len(scans) == 2
        assert all(s.token == "MATCH00" for s in scans)

    def test_returns_empty_list_when_no_scans(self, db_session):
        assert scan_repository.scans_for_token(db_session, "NONESUCH") == []
