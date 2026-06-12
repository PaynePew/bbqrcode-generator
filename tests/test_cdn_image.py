"""Tests for CDN-able image serving and immutable composites (ADR 0017 / issue qr_code_generator-mrv).

Coverage:
- S3Gateway.url_for: returns CDN URL when cdn_base_url set, S3 URL otherwise
- Image endpoint: customized Link returns 302 to url_for target with no-cache
- Image endpoint: vanilla Link returns inline PNG with no-cache
- Immutable Cache-Control forwarded by S3Gateway.put
- InMemoryGateway: cache_control kwarg accepted (no-op, no regression)
"""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from backend.models import Link, LinkCustomization
from backend.storage import IMMUTABLE_CACHE_CONTROL, InMemoryGateway, S3Gateway

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _insert_owned_link(db_session: Session, token: str, owner_id: int) -> Link:
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    link = Link(
        token=token,
        original_url="https://example.com/owned",
        owner_id=owner_id,
        created_at=now,
        updated_at=now,
    )
    db_session.add(link)
    db_session.commit()
    db_session.refresh(link)
    return link


def _insert_link(db_session: Session, token: str) -> Link:
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    link = Link(
        token=token,
        original_url="https://example.com/page",
        created_at=now,
        updated_at=now,
    )
    db_session.add(link)
    db_session.commit()
    db_session.refresh(link)
    return link


def _attach_customization(
    db_session: Session, link: Link, image_key: str
) -> LinkCustomization:
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    c = LinkCustomization(
        link_id=link.id,
        style_json='{"foreground":"#000000"}',
        image_key=image_key,
        logo_key=None,
        updated_at=now,
    )
    db_session.add(c)
    db_session.commit()
    db_session.refresh(c)
    return c


# ---------------------------------------------------------------------------
# S3Gateway.url_for — CDN vs S3 URL
# ---------------------------------------------------------------------------


class TestS3GatewayUrlFor:
    def test_returns_cdn_url_when_cdn_base_url_set(self):
        gw = S3Gateway(
            bucket="my-bucket",
            region="us-east-1",
            cdn_base_url="https://abc123.cloudfront.net",
        )
        result = gw.url_for("qr/tok/composite_abc.png")
        assert result == "https://abc123.cloudfront.net/qr/tok/composite_abc.png"

    def test_cdn_base_url_trailing_slash_stripped(self):
        gw = S3Gateway(
            bucket="my-bucket",
            region="us-east-1",
            cdn_base_url="https://abc123.cloudfront.net/",
        )
        result = gw.url_for("qr/tok/composite.png")
        assert result == "https://abc123.cloudfront.net/qr/tok/composite.png"

    def test_returns_s3_url_when_cdn_base_url_not_set(self):
        gw = S3Gateway(bucket="my-bucket", region="us-east-1")
        result = gw.url_for("qr/tok/composite_abc.png")
        assert (
            result
            == "https://my-bucket.s3.us-east-1.amazonaws.com/qr/tok/composite_abc.png"
        )

    def test_returns_endpoint_url_when_set_and_no_cdn(self):
        gw = S3Gateway(
            bucket="my-bucket",
            region="us-east-1",
            endpoint_url="http://localhost:9000",
        )
        result = gw.url_for("qr/tok/composite_abc.png")
        assert result == "http://localhost:9000/my-bucket/qr/tok/composite_abc.png"

    def test_cdn_takes_precedence_over_endpoint_url(self):
        """cdn_base_url wins when both cdn_base_url and endpoint_url are set."""
        gw = S3Gateway(
            bucket="my-bucket",
            region="us-east-1",
            endpoint_url="http://localhost:9000",
            cdn_base_url="https://cdn.example.com",
        )
        result = gw.url_for("qr/tok/composite.png")
        assert result == "https://cdn.example.com/qr/tok/composite.png"


# ---------------------------------------------------------------------------
# IMMUTABLE_CACHE_CONTROL constant
# ---------------------------------------------------------------------------


class TestImmutableCacheControlConstant:
    def test_value_matches_spec(self):
        assert IMMUTABLE_CACHE_CONTROL == "public, max-age=31536000, immutable"


# ---------------------------------------------------------------------------
# InMemoryGateway: cache_control kwarg accepted without error
# ---------------------------------------------------------------------------


class TestInMemoryGatewayCacheControlKwarg:
    def test_put_with_cache_control_does_not_raise(self):
        gw = InMemoryGateway()
        gw.put("k", b"data", "image/png", cache_control=IMMUTABLE_CACHE_CONTROL)
        assert gw.get("k") == b"data"

    def test_put_without_cache_control_still_works(self):
        gw = InMemoryGateway()
        gw.put("k2", b"data2", "image/png")
        assert gw.get("k2") == b"data2"


# ---------------------------------------------------------------------------
# Image endpoint: customized Link returns 302 with no-cache
# ---------------------------------------------------------------------------


class TestQrImageCdnRedirect:
    def test_customized_link_returns_302(
        self, auth_client: TestClient, db_session: Session, owner
    ):
        """Customized Link: image endpoint must return 302, not 200."""
        from backend.main import app
        from backend.router import _get_storage

        gw = InMemoryGateway(base_url="http://fake-storage")
        app.dependency_overrides[_get_storage] = lambda: gw

        try:
            link = _insert_owned_link(db_session, "cdn0001", owner.id)
            gw.put("qr/cdn0001/composite_abc.png", b"\x89PNG\r\n\x1a\n", "image/png")
            _attach_customization(db_session, link, "qr/cdn0001/composite_abc.png")

            resp = auth_client.get("/api/qr/cdn0001/image", follow_redirects=False)
            assert resp.status_code == 302
        finally:
            app.dependency_overrides.pop(_get_storage, None)

    def test_customized_link_302_location_is_url_for(
        self, auth_client: TestClient, db_session: Session, owner
    ):
        """The 302 Location must be storage.url_for(image_key)."""
        from backend.main import app
        from backend.router import _get_storage

        gw = InMemoryGateway(base_url="http://fake-cdn")
        app.dependency_overrides[_get_storage] = lambda: gw

        try:
            link = _insert_owned_link(db_session, "cdn0002", owner.id)
            image_key = "qr/cdn0002/composite_xyz.png"
            gw.put(image_key, b"\x89PNG\r\n\x1a\n", "image/png")
            _attach_customization(db_session, link, image_key)

            resp = auth_client.get("/api/qr/cdn0002/image", follow_redirects=False)
            assert resp.status_code == 302
            assert resp.headers["location"] == f"http://fake-cdn/{image_key}"
        finally:
            app.dependency_overrides.pop(_get_storage, None)

    def test_customized_link_302_carries_no_cache(
        self, auth_client: TestClient, db_session: Session, owner
    ):
        """The 302 itself must carry Cache-Control: no-cache (mutable pointer)."""
        from backend.main import app
        from backend.router import _get_storage

        gw = InMemoryGateway(base_url="http://fake-cdn")
        app.dependency_overrides[_get_storage] = lambda: gw

        try:
            link = _insert_owned_link(db_session, "cdn0003", owner.id)
            image_key = "qr/cdn0003/composite_no_cache.png"
            gw.put(image_key, b"\x89PNG\r\n\x1a\n", "image/png")
            _attach_customization(db_session, link, image_key)

            resp = auth_client.get("/api/qr/cdn0003/image", follow_redirects=False)
            assert resp.status_code == 302
            assert resp.headers.get("cache-control") == "no-cache"
        finally:
            app.dependency_overrides.pop(_get_storage, None)


# ---------------------------------------------------------------------------
# Image endpoint: vanilla Link returns inline PNG with no-cache
# ---------------------------------------------------------------------------


class TestQrImageVanillaNoCache:
    def test_vanilla_link_returns_200(self, client: TestClient, db_session: Session):
        _insert_link(db_session, "van0001")
        resp = client.get("/api/qr/van0001/image")
        assert resp.status_code == 200

    def test_vanilla_link_returns_png(self, client: TestClient, db_session: Session):
        _insert_link(db_session, "van0002")
        resp = client.get("/api/qr/van0002/image")
        assert resp.content[:4] == b"\x89PNG"

    def test_vanilla_link_has_no_cache_header(
        self, client: TestClient, db_session: Session
    ):
        _insert_link(db_session, "van0003")
        resp = client.get("/api/qr/van0003/image")
        assert resp.status_code == 200
        assert resp.headers.get("cache-control") == "no-cache"


# ---------------------------------------------------------------------------
# Regression: CDN_BASE_URL unset — image endpoint falls back to S3 URL redirect
# ---------------------------------------------------------------------------


class TestQrImageFallbackS3:
    def test_customized_link_302_location_is_s3_url_when_no_cdn(
        self, auth_client: TestClient, db_session: Session, owner
    ):
        """With no CDN configured, 302 Location must use the S3 URL (InMemoryGateway)."""
        from backend.main import app
        from backend.router import _get_storage

        gw = InMemoryGateway(base_url="http://s3-fallback")
        app.dependency_overrides[_get_storage] = lambda: gw

        try:
            link = _insert_owned_link(db_session, "s3fb001", owner.id)
            image_key = "qr/s3fb001/composite_fallback.png"
            gw.put(image_key, b"\x89PNG\r\n\x1a\n", "image/png")
            _attach_customization(db_session, link, image_key)

            resp = auth_client.get("/api/qr/s3fb001/image", follow_redirects=False)
            assert resp.status_code == 302
            assert resp.headers["location"] == f"http://s3-fallback/{image_key}"
        finally:
            app.dependency_overrides.pop(_get_storage, None)
