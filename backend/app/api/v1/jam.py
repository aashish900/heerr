"""Jam / remote control (phase JM): a guest phone drives playback on a host phone.

The backend is a dumb relay. The host polls `POST /jam/{id}/sync` (~1s), which
stores its now-playing snapshot and returns guest commands after a cursor. No
push channel by design (see DECISIONLOG 2026-11-05).
"""

import asyncio
import secrets
import time
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_scope
from app.db import get_session
from app.models import JamCommand, JamSession, Token, User
from app.schemas.jam import (
    MAX_WAIT_S,
    JamCommandCreated,
    JamCommandItem,
    JamCommandRequest,
    JamCreateResponse,
    JamJoinRequest,
    JamJoinResponse,
    JamStatePush,
    JamStateResponse,
    JamSyncRequest,
    JamSyncResponse,
)

router = APIRouter(prefix="/jam", tags=["jam"])

SESSION_TTL = timedelta(hours=12)
# ponytail: long-polls re-check Postgres every 100ms (committing in between so
# no pool connection is held while sleeping). Fine for a handful of sessions;
# switch to LISTEN/NOTIFY if this ever serves many.
_POLL_STEP_S = 0.1
_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # no 0/O/1/I
_CODE_LEN = 6


def _new_code() -> str:
    return "".join(secrets.choice(_CODE_ALPHABET) for _ in range(_CODE_LEN))


def _is_active(js: JamSession) -> bool:
    return js.ended_at is None and js.expires_at > datetime.now(UTC)


async def _get_session_or_404(session: AsyncSession, session_id: UUID) -> JamSession:
    js = await session.get(JamSession, session_id)
    if js is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="jam session not found")
    return js


def _require_host(js: JamSession, tok: Token) -> None:
    if js.host_user_id != tok.user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="not the session host")


async def _wait_until(
    session: AsyncSession, wait_s: float, ready: Callable[[], Awaitable[bool]]
) -> None:
    """Long-poll helper: re-run `ready()` (an async DB check) every
    `_POLL_STEP_S` until it returns true or `wait_s` passes. Commits before
    each sleep so the request's connection goes back to the pool."""
    deadline = time.monotonic() + wait_s
    while not await ready():
        if time.monotonic() >= deadline:
            return
        await session.commit()
        await asyncio.sleep(_POLL_STEP_S)


async def _username(session: AsyncSession, user_id: UUID) -> str:
    name = await session.scalar(select(User.navidrome_username).where(User.id == user_id))
    return name or ""


@router.post("", status_code=status.HTTP_201_CREATED, response_model=JamCreateResponse)
async def create_session(
    session: AsyncSession = Depends(get_session),
    tok: Token = Depends(require_scope("read")),
) -> JamCreateResponse:
    now = datetime.now(UTC)
    await session.execute(
        update(JamSession)
        .where(JamSession.host_user_id == tok.user_id, JamSession.ended_at.is_(None))
        .values(ended_at=now)
    )
    for _ in range(5):
        js = JamSession(host_user_id=tok.user_id, code=_new_code(), expires_at=now + SESSION_TTL)
        try:
            async with session.begin_nested():
                session.add(js)
        except IntegrityError:
            continue  # code collision with another live session
        return JamCreateResponse(id=js.id, code=js.code, expires_at=js.expires_at)
    raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="no free code")


@router.delete("/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def end_session(
    session_id: UUID,
    session: AsyncSession = Depends(get_session),
    tok: Token = Depends(require_scope("read")),
) -> Response:
    js = await _get_session_or_404(session, session_id)
    _require_host(js, tok)
    if js.ended_at is None:
        js.ended_at = datetime.now(UTC)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/join", response_model=JamJoinResponse)
async def join_session(
    req: JamJoinRequest,
    session: AsyncSession = Depends(get_session),
    tok: Token = Depends(require_scope("read")),
) -> JamJoinResponse:
    js = await session.scalar(
        select(JamSession).where(
            JamSession.code == req.code.strip().upper(),
            JamSession.ended_at.is_(None),
            JamSession.expires_at > datetime.now(UTC),
        )
    )
    if js is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="no active jam session")
    if js.host_user_id == tok.user_id:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="cannot join own session")
    return JamJoinResponse(
        id=js.id,
        host_username=await _username(session, js.host_user_id),
        expires_at=js.expires_at,
    )


@router.post(
    "/{session_id}/commands",
    status_code=status.HTTP_201_CREATED,
    response_model=JamCommandCreated,
)
async def send_command(
    session_id: UUID,
    req: JamCommandRequest,
    session: AsyncSession = Depends(get_session),
    tok: Token = Depends(require_scope("read")),
) -> JamCommandCreated:
    # Knowing the session id (only handed out by /join) is the guest's authz.
    js = await _get_session_or_404(session, session_id)
    if not _is_active(js):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="jam session ended")
    cmd = JamCommand(
        session_id=js.id, sender_user_id=tok.user_id, kind=req.kind, payload=req.payload
    )
    session.add(cmd)
    await session.flush()
    return JamCommandCreated(id=cmd.id)


@router.post("/{session_id}/sync", response_model=JamSyncResponse)
async def host_sync(
    session_id: UUID,
    req: JamSyncRequest,
    session: AsyncSession = Depends(get_session),
    tok: Token = Depends(require_scope("read")),
) -> JamSyncResponse:
    js = await _get_session_or_404(session, session_id)
    _require_host(js, tok)
    if not _is_active(js):
        return JamSyncResponse(commands=[], cursor=req.after or 0, ended=True)

    if req.state is not None:
        js.state = req.state
        js.state_at = datetime.now(UTC)
        await session.commit()  # visible to guests before any long-poll wait

    if req.after is None:
        cursor = await session.scalar(
            select(func.coalesce(func.max(JamCommand.id), 0)).where(JamCommand.session_id == js.id)
        )
        return JamSyncResponse(commands=[], cursor=cursor or 0, ended=False)

    after = req.after
    rows: list[Any] = []

    async def ready() -> bool:
        nonlocal rows
        await session.refresh(js, ["ended_at", "expires_at"])
        if not _is_active(js):
            return True
        rows = list(
            (
                await session.execute(
                    select(JamCommand, User.navidrome_username)
                    .join(User, User.id == JamCommand.sender_user_id)
                    .where(JamCommand.session_id == js.id, JamCommand.id > after)
                    .order_by(JamCommand.id)
                )
            ).all()
        )
        return bool(rows)

    await _wait_until(session, req.wait_s, ready)
    if not _is_active(js):
        return JamSyncResponse(commands=[], cursor=after, ended=True)
    commands = [
        JamCommandItem(id=c.id, kind=c.kind, payload=c.payload, sender=name) for c, name in rows
    ]
    return JamSyncResponse(
        commands=commands,
        cursor=commands[-1].id if commands else req.after,
        ended=False,
    )


@router.put("/{session_id}/state", status_code=status.HTTP_204_NO_CONTENT)
async def push_state(
    session_id: UUID,
    req: JamStatePush,
    session: AsyncSession = Depends(get_session),
    tok: Token = Depends(require_scope("read")),
) -> Response:
    """Host pushes a fresh snapshot the moment its player changes, without
    disturbing its in-flight `sync` long-poll."""
    js = await _get_session_or_404(session, session_id)
    _require_host(js, tok)
    if _is_active(js):
        js.state = req.state
        js.state_at = datetime.now(UTC)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{session_id}/state", response_model=JamStateResponse)
async def get_state(
    session_id: UUID,
    since: datetime | None = None,
    wait_s: float = Query(default=0, ge=0, le=MAX_WAIT_S),
    session: AsyncSession = Depends(get_session),
    tok: Token = Depends(require_scope("read")),
) -> JamStateResponse:
    """`since` = the `state_at` the guest already has: with `wait_s`, hold the
    request until a newer snapshot lands or the session ends."""
    js = await _get_session_or_404(session, session_id)

    async def ready() -> bool:
        await session.refresh(js, ["state", "state_at", "ended_at", "expires_at"])
        return (
            since is None or not _is_active(js) or (js.state_at is not None and js.state_at > since)
        )

    await _wait_until(session, wait_s, ready)
    return JamStateResponse(
        state=js.state,
        state_at=js.state_at,
        host_username=await _username(session, js.host_user_id),
        ended=not _is_active(js),
    )
