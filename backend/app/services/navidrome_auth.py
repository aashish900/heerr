"""Verify Navidrome credentials via the Subsonic `ping.view` endpoint.

Heerr stores no passwords. To validate a user we issue a Subsonic auth handshake
against the configured Navidrome instance. Subsonic auth uses `t = md5(password + salt)`
with a per-request `salt`, so the password never travels in clear text on the
wire; the salt is generated client-side and sent alongside the token.

A `200 OK` HTTP response with `subsonic-response.status == "ok"` means the
credentials are valid. Anything else (`"failed"` with code 40 = wrong credentials)
returns `False`. Network / DNS errors raise `NavidromeUnreachable` so the caller
can map them to a 503 (vs a 401 for credentials).
"""

from __future__ import annotations

import hashlib
import logging
import secrets
from typing import Protocol

import httpx

logger = logging.getLogger(__name__)

_SUBSONIC_VERSION = "1.16.1"
_CLIENT_NAME = "heerr"
_RESPONSE_FORMAT = "json"
_DEFAULT_TIMEOUT_SECONDS = 5.0
_PING_PATH = "/rest/ping.view"


class NavidromeUnreachable(Exception):
    """Raised when Navidrome is not reachable (DNS / connect / timeout)."""


class _SaltSource(Protocol):
    def __call__(self) -> str: ...


def _default_salt() -> str:
    # 16 hex chars of cryptographic randomness — plenty for Subsonic auth.
    return secrets.token_hex(8)


def _token(password: str, salt: str) -> str:
    return hashlib.md5(f"{password}{salt}".encode()).hexdigest()


async def verify_credentials(
    *,
    base_url: str,
    username: str,
    password: str,
    http: httpx.AsyncClient | None = None,
    salt_source: _SaltSource = _default_salt,
) -> bool:
    """Return True iff Navidrome accepts (username, password).

    `base_url` is the Navidrome root (e.g. ``http://navidrome.tailnet:4533``).
    `http` lets tests inject a stubbed `httpx.AsyncClient`.
    `salt_source` lets tests inject a deterministic salt.
    Raises `NavidromeUnreachable` on network / DNS / connect / timeout errors.
    """
    salt = salt_source()
    params = {
        "u": username,
        "t": _token(password, salt),
        "s": salt,
        "v": _SUBSONIC_VERSION,
        "c": _CLIENT_NAME,
        "f": _RESPONSE_FORMAT,
    }
    url = f"{base_url.rstrip('/')}{_PING_PATH}"

    owns_client = http is None
    client = http if http is not None else httpx.AsyncClient(timeout=_DEFAULT_TIMEOUT_SECONDS)
    try:
        try:
            response = await client.get(url, params=params)
        except (httpx.ConnectError, httpx.ConnectTimeout, httpx.ReadTimeout) as exc:
            logger.warning("navidrome unreachable: %s", exc)
            raise NavidromeUnreachable(str(exc)) from exc
        except httpx.HTTPError as exc:
            # Treat any other transport error as unreachable — caller maps to 503.
            logger.warning("navidrome http error: %s", exc)
            raise NavidromeUnreachable(str(exc)) from exc
    finally:
        if owns_client:
            await client.aclose()

    if response.status_code != 200:
        logger.warning("navidrome non-200 on ping: %s", response.status_code)
        return False

    try:
        body = response.json()
    except ValueError:
        logger.warning("navidrome non-JSON ping response")
        return False

    status = body.get("subsonic-response", {}).get("status")
    return status == "ok"
