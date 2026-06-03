import hashlib
import os
from sqlalchemy.exc import IntegrityError

BASE62 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
TOKEN_LEN = 7
# Raised from 3 to give genuine cross-URL collision retries more headroom.
# Same-URL submissions no longer consume retries — each call draws a fresh
# random nonce, so only true token space collisions (≈1/62^7) trigger retries.
MAX_RETRIES = 10


class TokenCollisionError(Exception):
    pass


def generate_token(url: str, secret: str, nonce: str | int) -> str:
    """Derive a 7-char Base62 token from url, secret, and nonce.

    nonce is typically a hex string from _random_nonce(); an int is accepted
    for deterministic tests (it is converted via str() for backward compat).
    """
    data = (url + secret + str(nonce)).encode()
    digest = hashlib.sha256(data).digest()
    n = int.from_bytes(digest, "big")
    chars = []
    while n:
        chars.append(BASE62[n % 62])
        n //= 62
    b62 = "".join(reversed(chars)) if chars else BASE62[0]
    return b62[:TOKEN_LEN].ljust(TOKEN_LEN, BASE62[0])


def _random_nonce() -> str:
    """Return a cryptographically random hex nonce (16 bytes = 32 hex chars)."""
    return os.urandom(16).hex()


def allocate_token(url: str, secret: str, try_insert) -> str:
    """Attempt to insert a unique token, retrying on genuine collisions only.

    Each attempt draws a fresh cryptographically random nonce, so the same URL
    can be submitted any number of times without exhausting the retry budget.
    MAX_RETRIES guards only against the astronomically rare event that two
    distinct (url+nonce) pairs hash to the same 7-char token.
    """
    for _ in range(MAX_RETRIES):
        token = generate_token(url, secret, _random_nonce())
        try:
            try_insert(token)
            return token
        except IntegrityError:
            pass
    raise TokenCollisionError(f"Failed to allocate unique token after {MAX_RETRIES} retries")
