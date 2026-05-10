import json
import logging
import os
from typing import Optional

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response, JSONResponse

from .limiter import RateLimiter

logger = logging.getLogger(__name__)

_TARGET_PATH = "/api/qr/create"
_TARGET_METHOD = "POST"

_limiter: Optional[RateLimiter] = None


def _get_limiter() -> RateLimiter:
    global _limiter
    if _limiter is None:
        hourly = int(os.environ.get("RATE_LIMIT_HOURLY", "30"))
        _limiter = RateLimiter(hourly_limit=hourly)
    return _limiter


def _is_enabled() -> bool:
    return os.environ.get("RATE_LIMIT_ENABLED", "true").lower() == "true"


def _client_ip(request: Request) -> Optional[str]:
    xff = request.headers.get("x-forwarded-for")
    if xff:
        return xff.split(",")[-1].strip()
    return request.client.host if request.client else None


class RateLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if request.method != _TARGET_METHOD or request.url.path != _TARGET_PATH:
            return await call_next(request)

        if not _is_enabled():
            return await call_next(request)

        ip = _client_ip(request) or "unknown"
        try:
            result = _get_limiter().check(ip)
        except Exception:
            logger.error("RateLimiter.check raised an exception", exc_info=True)
            return await call_next(request)

        if not result.allowed:
            logger.warning(
                "rate_limiter.denied ip=%s limit=%d retry_after=%d path=%s",
                ip, result.limit, result.retry_after_seconds, _TARGET_PATH,
            )
            content = json.dumps({"detail": "Rate limit exceeded"}).encode()
            return Response(
                content=content,
                status_code=429,
                media_type="application/json",
                headers={
                    "RateLimit-Limit": str(result.limit),
                    "RateLimit-Remaining": str(result.remaining),
                    "RateLimit-Reset": str(result.reset_seconds),
                    "RateLimit-Policy": result.policy,
                    "Retry-After": str(result.retry_after_seconds),
                },
            )

        response = await call_next(request)
        response.headers["RateLimit-Limit"] = str(result.limit)
        response.headers["RateLimit-Remaining"] = str(result.remaining)
        response.headers["RateLimit-Reset"] = str(result.reset_seconds)
        response.headers["RateLimit-Policy"] = result.policy
        return response

    @classmethod
    def reset_for_tests(cls):
        global _limiter
        _limiter = None
