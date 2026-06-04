"""Phase 6 deploy (slice p6s2): liveness probe + SPA client-route fallback.

The SPA is served from the same container as the API behind the shared edge
Caddy, so backend/main.py serves both. These tests pin two correctness points
the naive ``StaticFiles(html=True)`` snippet would miss:

  1. ``/healthz`` is a real liveness route, independent of the static build.
  2. unknown *client* routes fall back to index.html (so a refresh on a deep
     route works), but unknown ``/api`` / ``/r`` paths keep returning a real
     404 (→ JSON error envelope, ADR 0012) rather than HTML.
"""

from fastapi import FastAPI
from fastapi.testclient import TestClient

from backend.main import SPAStaticFiles


def test_healthz_is_ok(client):
    resp = client.get("/healthz")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def _spa_client(tmp_path) -> TestClient:
    (tmp_path / "index.html").write_text("<!doctype html><title>SPA</title>")
    (tmp_path / "asset.js").write_text("console.log(1)")
    app = FastAPI()
    app.mount("/", SPAStaticFiles(directory=str(tmp_path), html=True), name="spa")
    return TestClient(app)


def test_spa_serves_real_asset(tmp_path):
    assert _spa_client(tmp_path).get("/asset.js").status_code == 200


def test_spa_falls_back_to_index_for_client_routes(tmp_path):
    resp = _spa_client(tmp_path).get("/links/abc123")
    assert resp.status_code == 200
    assert "SPA" in resp.text


def test_spa_does_not_mask_api_or_redirect_404s(tmp_path):
    client = _spa_client(tmp_path)
    # Reserved prefixes must keep returning a real 404, NOT index.html, so the
    # JSON error envelope still applies to unknown API/redirect paths.
    assert client.get("/api/nonexistent").status_code == 404
    assert client.get("/r/UNKNOWN").status_code == 404
