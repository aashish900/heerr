"""POST /api/v1/auth/login — delegates identity to Navidrome.

Heerr stores no passwords. The Subsonic ping handshake (J5) is the credential
check. On success we upsert a `users` row keyed on `navidrome_username`, mint
a heerr opaque token tied to that user, and return the raw token once.
"""

from __future__ import annotations

import hashlib
import secrets
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import bearer_token
from app.config import Settings, get_settings
from app.db import get_session
from app.models import Token, User
from app.schemas.auth import LoginRequest, LoginResponse
from app.services.navidrome_auth import NavidromeUnreachable, verify_credentials

router = APIRouter(prefix="/auth", tags=["auth"])

_DEFAULT_SCOPES: list[str] = ["read", "download"]

NavidromeVerifier = Callable[[str, str], Awaitable[bool]]


def get_navidrome_verifier(
    settings: Settings = Depends(get_settings),
) -> NavidromeVerifier:
    """FastAPI dependency producing a verify(username, password) coroutine.

    Tests override this to inject a recording fake without spinning up httpx.
    """

    async def _verify(username: str, password: str) -> bool:
        return await verify_credentials(
            base_url=settings.navidrome_url,
            username=username,
            password=password,
        )

    return _verify


@router.post("/login", response_model=LoginResponse)
async def login(
    req: LoginRequest,
    session: AsyncSession = Depends(get_session),
    verify: NavidromeVerifier = Depends(get_navidrome_verifier),
    settings: Settings = Depends(get_settings),
) -> LoginResponse:
    try:
        ok = await verify(req.username, req.password)
    except NavidromeUnreachable as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="navidrome unreachable",
        ) from exc

    if not ok:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid credentials",
        )

    # Upsert the user row.
    user = (
        await session.execute(select(User).where(User.navidrome_username == req.username))
    ).scalar_one_or_none()
    if user is None:
        user = User(navidrome_username=req.username)
        session.add(user)
        await session.flush()

    user.last_login_at = datetime.now(UTC)

    # Mint a fresh heerr token for this login.
    raw = secrets.token_urlsafe(32)
    token = Token(
        token_hash=hashlib.sha256(raw.encode()).hexdigest(),
        scopes=list(_DEFAULT_SCOPES),
        is_admin=False,
        user_id=user.id,
    )
    session.add(token)
    await session.flush()

    return LoginResponse(
        token=raw,
        scopes=list(_DEFAULT_SCOPES),
        navidrome_url=settings.navidrome_url,
        navidrome_username=req.username,
    )


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    tok: Token = Depends(bearer_token),
    session: AsyncSession = Depends(get_session),
) -> Response:
    tok.revoked_at = datetime.now(UTC)
    session.add(tok)
    await session.flush()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
