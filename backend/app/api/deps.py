import hashlib
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime

from fastapi import Depends, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.context import username_var
from app.db import get_session
from app.models import Token, User

_security = HTTPBearer(auto_error=False)

_UNAUTH_HEADERS = {"WWW-Authenticate": "Bearer"}


async def _resolve_token(raw: str, session: AsyncSession) -> Token:
    """Resolve a raw bearer token string to its `Token` (user eager-loaded).

    Shared by the header-only `bearer_token` dep and the `bearer_token_query_or_header`
    dep used by `/preview/stream` (where the token rides in the query string because
    the audio player cannot attach auth headers to a media URL).
    """
    token_hash = hashlib.sha256(raw.encode()).hexdigest()
    result = await session.execute(
        select(Token).options(selectinload(Token.user)).where(Token.token_hash == token_hash)
    )
    tok = result.scalar_one_or_none()
    if tok is None or tok.revoked_at is not None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="unknown or revoked token",
            headers=_UNAUTH_HEADERS,
        )
    if tok.user is None:
        # Post-J2 every token row should have a user_id FK. None here is the
        # delete-user-mid-request race (or FK corruption): treat as an
        # invalidated session — 401, not 500.
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="session invalidated",
            headers=_UNAUTH_HEADERS,
        )
    username_var.set(tok.user.navidrome_username)
    tok.last_used_at = datetime.now(UTC)
    return tok


async def bearer_token(
    creds: HTTPAuthorizationCredentials | None = Depends(_security),
    session: AsyncSession = Depends(get_session),
) -> Token:
    if creds is None or creds.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="missing or invalid bearer token",
            headers=_UNAUTH_HEADERS,
        )
    return await _resolve_token(creds.credentials, session)


async def bearer_token_query_or_header(
    creds: HTTPAuthorizationCredentials | None = Depends(_security),
    token: str | None = Query(default=None),
    session: AsyncSession = Depends(get_session),
) -> Token:
    """Like `bearer_token`, but also accepts the raw token via `?token=`.

    The Android audio player (just_audio) cannot attach an `Authorization` header
    to an `AudioSource` URL, so `/preview/stream` carries the bearer in the query
    string — the same shape Subsonic stream URLs already use. The `?token=` value
    is redacted from access logs (see middleware, K3). Header wins if both present.
    """
    raw: str | None = None
    if creds is not None and creds.scheme.lower() == "bearer":
        raw = creds.credentials
    elif token:
        raw = token
    if not raw:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="missing or invalid bearer token",
            headers=_UNAUTH_HEADERS,
        )
    return await _resolve_token(raw, session)


async def current_user(tok: Token = Depends(bearer_token)) -> User:
    """Extracts the bearer token's User. Eager-loaded by `bearer_token`."""
    return tok.user


def require_scope(*required: str) -> Callable[[Token], Awaitable[Token]]:
    async def _dep(tok: Token = Depends(bearer_token)) -> Token:
        if not set(required).issubset(set(tok.scopes)):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"insufficient scope; requires {sorted(required)}",
            )
        return tok

    return _dep


def require_scope_query_or_header(*required: str) -> Callable[[Token], Awaitable[Token]]:
    """Scope check over `bearer_token_query_or_header` (for `/preview/stream`)."""

    async def _dep(tok: Token = Depends(bearer_token_query_or_header)) -> Token:
        if not set(required).issubset(set(tok.scopes)):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"insufficient scope; requires {sorted(required)}",
            )
        return tok

    return _dep


async def require_admin(tok: Token = Depends(bearer_token)) -> Token:
    if not tok.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="admin required",
        )
    return tok
