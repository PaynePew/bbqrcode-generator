import ipaddress
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse

import idna

# Reject over-long input before any parsing (DoS / storage abuse). Measured on the
# raw input string. See ADR 0015.
MAX_URL_LENGTH = 2048


class InvalidURLError(ValueError):
    pass


def validate_and_normalize(url: str) -> str:
    if len(url) > MAX_URL_LENGTH:
        raise InvalidURLError(
            f"URL exceeds maximum length of {MAX_URL_LENGTH} characters"
        )

    try:
        parsed = urlparse(url)
    except Exception as e:
        raise InvalidURLError(f"Malformed URL: {e}")

    if parsed.scheme not in ("http", "https"):
        raise InvalidURLError(f"Non-http(s) scheme rejected: {parsed.scheme!r}")

    host = parsed.hostname or ""
    if not host:
        raise InvalidURLError("URL must have a host")

    if host.lower() == "localhost" or host.lower().endswith(".localhost"):
        raise InvalidURLError("Loopback address rejected")

    try:
        addr = ipaddress.ip_address(host)
    except ValueError:
        addr = None  # Not an IP literal — treat as a domain name

    if addr is not None:
        # IP literal: unwrap IPv4-mapped IPv6 (e.g. ::ffff:127.0.0.1) so the mapped
        # address is judged on its own terms, then block the full set of
        # non-routable / internal ranges (ADR 0015). Note: with no server-side fetch
        # this is store-clean hygiene, not an SSRF guard — see ADR 0015.
        if isinstance(addr, ipaddress.IPv6Address) and addr.ipv4_mapped is not None:
            addr = addr.ipv4_mapped
        if (
            addr.is_loopback
            or addr.is_private
            or addr.is_link_local
            or addr.is_reserved
            or addr.is_multicast
            or addr.is_unspecified
        ):
            raise InvalidURLError(f"Disallowed IP address rejected: {host}")
        host_normalized = host.lower()
    else:
        # Domain name: IDNA 2008 / UTS-46 normalize internationalized hosts to their
        # canonical punycode form (ADR 0015). Pure-ASCII hosts keep the simple
        # lowercase path; an internationalized host that fails IDNA is rejected.
        # Homograph *detection* is deliberately out of scope — we normalize only.
        if any(ord(ch) > 127 for ch in host):
            try:
                host_normalized = idna.encode(host, uts46=True).decode("ascii")
            except idna.IDNAError as e:
                raise InvalidURLError(f"Invalid internationalized host: {e}")
        else:
            host_normalized = host.lower()

    scheme = "https"

    port = parsed.port
    if port in (80, 443):
        port = None

    # An IPv6 literal must be re-bracketed in the netloc; urlparse.hostname strips
    # the brackets, and without them a stored "https://::1:8080/" is malformed.
    netloc_host = f"[{host_normalized}]" if ":" in host_normalized else host_normalized

    if port:
        netloc = f"{netloc_host}:{port}"
    else:
        netloc = netloc_host

    if parsed.username:
        userinfo = parsed.username
        if parsed.password:
            userinfo += f":{parsed.password}"
        netloc = f"{userinfo}@{netloc}"

    path = parsed.path
    if not path:
        path = "/"
    elif path != "/" and path.endswith("/"):
        path = path.rstrip("/")

    query_params = sorted(parse_qsl(parsed.query, keep_blank_values=True))
    query = urlencode(query_params)

    return urlunparse((scheme, netloc, path, parsed.params, query, ""))
