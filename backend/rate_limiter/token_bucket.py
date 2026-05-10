from dataclasses import dataclass


@dataclass
class TokenBucket:
    capacity: float
    refill_rate: float  # tokens per second
    tokens: float
    last_refill: float = 0.0

    def step(self, now: float, cost: float = 1.0):
        elapsed = max(0.0, now - self.last_refill)
        refilled = min(self.capacity, self.tokens + elapsed * self.refill_rate)
        if refilled < cost:
            return False, TokenBucket(self.capacity, self.refill_rate, refilled, now)
        return True, TokenBucket(self.capacity, self.refill_rate, refilled - cost, now)
