import pytest
from sqlalchemy.exc import IntegrityError
from backend.token_generator import generate_token, allocate_token, TokenCollisionError

BASE62_CHARS = set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")


class TestGenerateToken:
    def test_returns_7_char_string(self):
        token = generate_token("https://example.com", "secret", 0)
        assert len(token) == 7

    def test_all_chars_are_base62(self):
        token = generate_token("https://example.com", "secret", 0)
        assert all(c in BASE62_CHARS for c in token)

    def test_deterministic_same_inputs(self):
        t1 = generate_token("https://example.com", "secret", 0)
        t2 = generate_token("https://example.com", "secret", 0)
        assert t1 == t2

    def test_different_nonces_produce_different_tokens(self):
        t0 = generate_token("https://example.com", "secret", 0)
        t1 = generate_token("https://example.com", "secret", 1)
        assert t0 != t1

    def test_different_secrets_produce_different_tokens(self):
        t1 = generate_token("https://example.com", "secret1", 0)
        t2 = generate_token("https://example.com", "secret2", 0)
        assert t1 != t2

    def test_different_urls_produce_different_tokens(self):
        t1 = generate_token("https://example.com", "secret", 0)
        t2 = generate_token("https://other.com", "secret", 0)
        assert t1 != t2


class TestAllocateToken:
    def test_calls_try_insert_and_returns_token(self):
        inserted = []

        def try_insert(token):
            inserted.append(token)

        token = allocate_token("https://example.com", "secret", try_insert)
        assert len(token) == 7
        assert len(inserted) == 1
        assert inserted[0] == token

    def test_retries_on_integrity_error(self):
        call_count = [0]

        def try_insert(token):
            call_count[0] += 1
            if call_count[0] < 3:
                raise IntegrityError(None, None, Exception("UNIQUE constraint failed"))

        token = allocate_token("https://example.com", "secret", try_insert)
        assert call_count[0] == 3
        assert len(token) == 7

    def test_raises_after_max_retries(self):
        def try_insert(token):
            raise IntegrityError(None, None, Exception("UNIQUE constraint failed"))

        with pytest.raises(TokenCollisionError):
            allocate_token("https://example.com", "secret", try_insert)

    def test_each_retry_uses_different_nonce(self):
        tokens_tried = []

        def try_insert(token):
            tokens_tried.append(token)
            if len(tokens_tried) < 2:
                raise IntegrityError(None, None, Exception("UNIQUE constraint failed"))

        allocate_token("https://example.com", "secret", try_insert)
        assert tokens_tried[0] != tokens_tried[1]

    def test_same_url_repeated_four_times_yields_distinct_tokens(self):
        """Submitting the same URL N>=4 times must produce 4 distinct tokens with no error.

        This is the key acceptance criterion for Phase 0: the nonce must be
        cryptographically random (not the retry counter), so same-URL requests
        produce unbounded distinct tokens instead of capping at MAX_RETRIES.
        """
        tokens_minted = []

        def always_succeeds(token):
            tokens_minted.append(token)

        for _ in range(4):
            allocate_token("https://example.com", "secret", always_succeeds)

        assert len(tokens_minted) == 4, "Expected exactly 4 successful inserts"
        assert len(set(tokens_minted)) == 4, "All 4 tokens must be distinct"

    def test_nonce_is_not_sequential_across_calls(self):
        """Two successive allocate_token calls for the same URL must not share the
        nonce used in the first call, proving the nonce is random, not a counter."""
        first_tokens: list[str] = []
        second_tokens: list[str] = []

        allocate_token("https://example.com", "secret", first_tokens.append)
        allocate_token("https://example.com", "secret", second_tokens.append)

        # With a counter nonce starting at 0, both calls would produce the same
        # token (nonce=0 each time).  A random nonce makes collision astronomically
        # unlikely (1/62^7 ≈ 1 in 3.5 billion per pair).
        assert first_tokens[0] != second_tokens[0]
