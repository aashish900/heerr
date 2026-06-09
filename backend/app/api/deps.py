import hashlib
from collections.abc import Awaitable, Callable

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.context import owner_label_var
from app.db import get_session
from app.models import Token

_security = HTTPBearer(auto_error=False)

_UNAUTH_HEADERS = {"WWW-Authenticate": "Bearer"}


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
    token_hash = hashlib.sha256(creds.credentials.encode()).hexdigest()
    result = await session.execute(select(Token).where(Token.token_hash == token_hash))
    tok = result.scalar_one_or_none()
    if tok is None or tok.revoked_at is not None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="unknown or revoked token",
            headers=_UNAUTH_HEADERS,
        )
    owner_label_var.set(tok.owner_label)
    return tok


def require_scope(*required: str) -> Callable[[Token], Awaitable[Token]]:
    async def _dep(tok: Token = Depends(bearer_token)) -> Token:
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
