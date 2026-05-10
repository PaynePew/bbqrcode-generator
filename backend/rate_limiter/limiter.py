import time
from dataclasses import dataclass
from typing import Optional

from .token_bucket import TokenBucket


@dataclass
class CheckResult:
    allowed: bool
    remaining: int
    retry_after_seconds: int
    limit: int
    reset_seconds: int
    policy: str


class RateLimiter:
    def __init__(self, hourly_limit: int, clock=None):
        self._limit = hourly_limit
        self._refill_rate = hourly_limit / 3600.0
        self._buckets: dict[str, TokenBucket] = {}
        self._clock = clock or (lambda: time.monotonic())

    def check(self, ip: str) -> CheckResult:
        now = self._clock()
        bucket = self._buckets.get(ip)
        if bucket is None:
            bucket = TokenBucket(
                capacity=self._limit,
                refill_rate=self._refill_rate,
                tokens=float(self._limit),
                last_refill=now,
            )
        allowed, new_bucket = bucket.step(now=now, cost=1)
        self._buckets[ip] = new_bucket
        remaining = max(0, int(new_bucket.tokens))
        if allowed:
            reset_seconds = int((1.0 / self._refill_rate) + 0.5) if self._refill_rate > 0 else 3600
            retry_after = 0
        else:
            tokens_needed = 1.0 - new_bucket.tokens
            retry_after = int(tokens_needed / self._refill_rate) + 1 if self._refill_rate > 0 else 3600
            reset_seconds = retry_after
        return CheckResult(
            allowed=allowed,
            remaining=remaining,
            retry_after_seconds=retry_after,
            limit=self._limit,
            reset_seconds=reset_seconds,
            policy=f"{self._limit};w=3600",
        )

    def reset(self):
        self._buckets.clear()
