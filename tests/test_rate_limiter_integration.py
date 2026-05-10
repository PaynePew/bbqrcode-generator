import itertools

import pytest
from fastapi.testclient import TestClient

from backend.main import app
from backend.router import get_db

_counter = itertools.count(1)


def _create(client, *, ip="1.2.3.4"):
    return client.post(
        "/api/qr/create",
        json={"url": f"https://example.com/p{next(_counter)}"},
        headers={"x-forwarded-for": ip},
    )


@pytest.fixture
def rate_limiter_enabled(monkeypatch):
    monkeypatch.setenv("RATE_LIMIT_ENABLED", "true")
    monkeypatch.setenv("RATE_LIMIT_HOURLY", "3")


@pytest.fixture
def rl_client(db_session, rate_limiter_enabled):
    from backend.rate_limiter.middleware import RateLimitMiddleware

    def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    RateLimitMiddleware.reset_for_tests()
    with TestClient(app, raise_server_exceptions=True) as c:
        yield c
    app.dependency_overrides.clear()


def test_successful_response_includes_ratelimit_headers(rl_client):
    resp = _create(rl_client)
    assert resp.status_code == 200
    assert "ratelimit-limit" in resp.headers
    assert "ratelimit-remaining" in resp.headers
    assert "ratelimit-reset" in resp.headers
    assert "ratelimit-policy" in resp.headers


def test_nth_plus_one_request_returns_429(rl_client):
    for _ in range(3):
        assert _create(rl_client).status_code == 200
    r = _create(rl_client)
    assert r.status_code == 429
    assert r.json() == {"detail": "Rate limit exceeded"}
    assert "retry-after" in r.headers
    assert "ratelimit-limit" in r.headers
    assert "ratelimit-remaining" in r.headers


def test_two_ips_are_independent(rl_client):
    for _ in range(3):
        _create(rl_client, ip="10.0.0.1")
    assert _create(rl_client, ip="10.0.0.1").status_code == 429
    assert _create(rl_client, ip="10.0.0.2").status_code == 200


def test_clock_advance_unlocks_one_more_request(db_session, monkeypatch):
    import backend.rate_limiter.middleware as mw_module
    from backend.rate_limiter.limiter import RateLimiter
    from backend.rate_limiter.middleware import RateLimitMiddleware

    monkeypatch.setenv("RATE_LIMIT_ENABLED", "true")
    monkeypatch.setenv("RATE_LIMIT_HOURLY", "3")
    RateLimitMiddleware.reset_for_tests()

    clock_time = [0.0]
    monkeypatch.setattr(mw_module, "_limiter", RateLimiter(hourly_limit=3, clock=lambda: clock_time[0]))

    def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app, raise_server_exceptions=True) as c:
        for _ in range(3):
            assert _create(c).status_code == 200
        assert _create(c).status_code == 429
        clock_time[0] = 1201.0  # one full token refills at 3600/3 = 1200s
        assert _create(c).status_code == 200
    app.dependency_overrides.clear()


def test_kill_switch_passthrough_leaves_no_headers(db_session, monkeypatch):
    from backend.rate_limiter.middleware import RateLimitMiddleware

    monkeypatch.setenv("RATE_LIMIT_ENABLED", "false")
    RateLimitMiddleware.reset_for_tests()

    def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        resp = _create(c)
    app.dependency_overrides.clear()

    assert resp.status_code == 200
    assert "ratelimit-limit" not in resp.headers
    assert "ratelimit-remaining" not in resp.headers


def test_fail_open_when_limiter_raises(db_session, monkeypatch):
    import backend.rate_limiter.middleware as mw_module
    from backend.rate_limiter.middleware import RateLimitMiddleware

    monkeypatch.setenv("RATE_LIMIT_ENABLED", "true")
    monkeypatch.setenv("RATE_LIMIT_HOURLY", "30")
    RateLimitMiddleware.reset_for_tests()

    class BrokenLimiter:
        def check(self, ip):
            raise RuntimeError("limiter exploded")

    monkeypatch.setattr(mw_module, "_limiter", BrokenLimiter())

    def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app, raise_server_exceptions=False) as c:
        resp = _create(c)
    app.dependency_overrides.clear()

    assert resp.status_code == 200
