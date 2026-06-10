import pytest

from backend.url_validator import InvalidURLError, validate_and_normalize


class TestNormalization:
    def test_coerces_http_to_https(self):
        result = validate_and_normalize("http://example.com/path")
        assert result.startswith("https://")

    def test_lowercases_host(self):
        result = validate_and_normalize("https://EXAMPLE.COM/path")
        assert "example.com" in result

    def test_removes_default_port_443(self):
        result = validate_and_normalize("https://example.com:443/path")
        assert ":443" not in result

    def test_removes_default_port_80(self):
        result = validate_and_normalize("http://example.com:80/path")
        assert ":80" not in result

    def test_keeps_non_default_port(self):
        result = validate_and_normalize("https://example.com:8080/path")
        assert ":8080" in result

    def test_removes_trailing_slash_from_path(self):
        result = validate_and_normalize("https://example.com/path/")
        assert result == "https://example.com/path"

    def test_keeps_root_slash(self):
        result = validate_and_normalize("https://example.com/")
        assert result == "https://example.com/"

    def test_adds_root_slash_when_no_path(self):
        result = validate_and_normalize("https://example.com")
        assert result == "https://example.com/"

    def test_sorts_query_params(self):
        result = validate_and_normalize("https://example.com/?z=1&a=2&m=3")
        assert result == "https://example.com/?a=2&m=3&z=1"

    def test_all_normalizations_combined(self):
        result = validate_and_normalize("http://EXAMPLE.COM:80/PATH/?z=last&a=first")
        assert result == "https://example.com/PATH?a=first&z=last"


class TestValidURLs:
    def test_valid_https_url(self):
        result = validate_and_normalize("https://example.com/page")
        assert result == "https://example.com/page"

    def test_valid_http_url(self):
        result = validate_and_normalize("http://example.com/page")
        assert result == "https://example.com/page"

    def test_url_with_query_string(self):
        result = validate_and_normalize("https://example.com/search?q=hello")
        assert "q=hello" in result


class TestBlockedSchemes:
    def test_rejects_javascript_scheme(self):
        with pytest.raises(InvalidURLError):
            validate_and_normalize("javascript:alert(1)")

    def test_rejects_file_scheme(self):
        with pytest.raises(InvalidURLError):
            validate_and_normalize("file:///etc/passwd")

    def test_rejects_data_scheme(self):
        with pytest.raises(InvalidURLError):
            validate_and_normalize("data:text/html,<h1>hi</h1>")

    def test_rejects_ftp_scheme(self):
        with pytest.raises(InvalidURLError):
            validate_and_normalize("ftp://example.com/file.txt")


class TestBlockedIPs:
    def test_rejects_localhost(self):
        with pytest.raises(InvalidURLError):
            validate_and_normalize("https://localhost/admin")

    def test_rejects_loopback_127(self):
        with pytest.raises(InvalidURLError):
            validate_and_normalize("https://127.0.0.1/admin")

    def test_rejects_private_10_range(self):
        with pytest.raises(InvalidURLError):
            validate_and_normalize("https://10.0.0.1/internal")

    def test_rejects_private_192_168_range(self):
        with pytest.raises(InvalidURLError):
            validate_and_normalize("https://192.168.1.1/router")

    def test_rejects_private_172_16_range(self):
        with pytest.raises(InvalidURLError):
            validate_and_normalize("https://172.16.0.1/internal")

    def test_rejects_link_local_169_254(self):
        with pytest.raises(InvalidURLError):
            validate_and_normalize("https://169.254.169.254/metadata")

    def test_rejects_ipv6_loopback(self):
        with pytest.raises(InvalidURLError):
            validate_and_normalize("https://[::1]/admin")


class TestLengthCap:
    def test_rejects_url_over_2048_chars(self):
        long_url = "https://example.com/" + "a" * 2100
        with pytest.raises(InvalidURLError):
            validate_and_normalize(long_url)

    def test_accepts_url_within_length_cap(self):
        url = "https://example.com/" + "a" * 100
        result = validate_and_normalize(url)
        assert result.startswith("https://example.com/")

    def test_accepts_url_at_exactly_2048(self):
        url = "https://example.com/" + "a" * 2028  # len == 2048
        assert len(url) == 2048
        result = validate_and_normalize(url)
        assert result.startswith("https://example.com/")

    def test_rejects_url_at_2049(self):
        url = "https://example.com/" + "a" * 2029  # len == 2049
        assert len(url) == 2049
        with pytest.raises(InvalidURLError):
            validate_and_normalize(url)


class TestIDNANormalization:
    def test_normalizes_internationalized_host_to_punycode(self):
        result = validate_and_normalize("https://münchen.de/page")
        assert "xn--mnchen-3ya.de" in result
        assert "münchen" not in result

    def test_normalizes_uppercase_unicode_host(self):
        result = validate_and_normalize("https://MÜNCHEN.de/")
        assert "xn--mnchen-3ya.de" in result

    def test_rejects_idna_invalid_host(self):
        # ❤ (U+2764) is a disallowed IDNA/UTS-46 codepoint.
        with pytest.raises(InvalidURLError):
            validate_and_normalize("https://❤.example/")

    def test_ascii_host_unaffected(self):
        result = validate_and_normalize("https://Example.COM/Path")
        assert result == "https://example.com/Path"

    def test_internationalized_host_with_port(self):
        result = validate_and_normalize("https://münchen.de:8443/page")
        assert result == "https://xn--mnchen-3ya.de:8443/page"


class TestHardenedIPBlocklist:
    def test_rejects_multicast(self):
        with pytest.raises(InvalidURLError):
            validate_and_normalize("https://224.0.0.1/stream")

    def test_rejects_unspecified(self):
        with pytest.raises(InvalidURLError):
            validate_and_normalize("https://0.0.0.0/")

    def test_rejects_reserved_240_range(self):
        with pytest.raises(InvalidURLError):
            validate_and_normalize("https://240.0.0.1/")

    def test_rejects_ipv4_mapped_ipv6_loopback(self):
        with pytest.raises(InvalidURLError):
            validate_and_normalize("https://[::ffff:127.0.0.1]/admin")


class TestPublicIPv6Literal:
    def test_preserves_brackets_for_public_ipv6(self):
        result = validate_and_normalize("https://[2606:4700:4700::1111]/p")
        assert result == "https://[2606:4700:4700::1111]/p"

    def test_preserves_brackets_for_public_ipv6_with_port(self):
        result = validate_and_normalize("https://[2606:4700:4700::1111]:8443/p")
        assert result == "https://[2606:4700:4700::1111]:8443/p"
