import asyncio
import hashlib
import secrets
import uuid
from datetime import UTC, datetime

import typer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from app.config import get_settings
from app.db import build_engine, build_sessionmaker
from app.models import Token, User

app = typer.Typer(help="heerr backend token management.", add_completion=False)


def _make_sessionmaker() -> tuple[AsyncEngine, async_sessionmaker[AsyncSession]]:
    engine = build_engine(get_settings().database_url)
    return engine, build_sessionmaker(engine)


@app.command("create-token")
def create_token(
    owner: str = typer.Option(..., "--owner", help="Owner label."),
    scopes: str = typer.Option(
        "read,download",
        "--scopes",
        help="Comma-separated subset of {read,download}.",
    ),
    admin: bool = typer.Option(False, "--admin", help="Grant admin flag."),
    user: str = typer.Option(
        "system-admin",
        "--user",
        help="navidrome_username the token belongs to. Must already exist.",
    ),
) -> None:
    """Create a token; prints the raw value once. Only the hash is stored.

    The token is FK-linked to a `users` row (multi-user since J1). `--user`
    defaults to `system-admin` — the synthetic operator account seeded by the
    backfill migration. Pass an existing `navidrome_username` to mint a token
    for another user (typical for the heerr operator pre-issuing a token for
    a family member before they log in for the first time).
    """
    parsed = [s.strip() for s in scopes.split(",") if s.strip()]
    raw = secrets.token_urlsafe(32)
    h = hashlib.sha256(raw.encode()).hexdigest()

    async def _run() -> str | None:
        engine, sm = _make_sessionmaker()
        try:
            async with sm() as session:
                target = (
                    await session.execute(select(User).where(User.navidrome_username == user))
                ).scalar_one_or_none()
                if target is None:
                    return f"unknown user: {user}"
                session.add(
                    Token(
                        token_hash=h,
                        owner_label=owner,
                        scopes=parsed,
                        is_admin=admin,
                        user_id=target.id,
                    )
                )
                await session.commit()
                return None
        finally:
            await engine.dispose()

    err = asyncio.run(_run())
    if err is not None:
        typer.echo(err, err=True)
        raise typer.Exit(code=1)
    typer.echo(raw)


@app.command("list-tokens")
def list_tokens() -> None:
    """List tokens (id, user, owner, scopes, admin, state). Never prints hashes."""
    from sqlalchemy.orm import selectinload

    async def _run() -> list[Token]:
        engine, sm = _make_sessionmaker()
        try:
            async with sm() as session:
                result = await session.execute(
                    select(Token).options(selectinload(Token.user)).order_by(Token.created_at)
                )
                return list(result.scalars().all())
        finally:
            await engine.dispose()

    rows = asyncio.run(_run())
    if not rows:
        typer.echo("(no tokens)")
        return
    for t in rows:
        state = "revoked" if t.revoked_at is not None else "active"
        username = t.user.navidrome_username if t.user is not None else "?"
        typer.echo(
            f"{t.id} user={username} owner={t.owner_label} scopes={sorted(t.scopes)} "
            f"admin={t.is_admin} state={state} created_at={t.created_at.isoformat()}"
        )


@app.command("revoke-token")
def revoke_token(
    token_id: str = typer.Argument(..., help="UUID of the token to revoke."),
) -> None:
    """Mark a token revoked. Fails if unknown or already revoked."""
    try:
        tid = uuid.UUID(token_id)
    except ValueError as exc:
        typer.echo(f"invalid uuid: {exc}", err=True)
        raise typer.Exit(code=2) from exc

    async def _run() -> str:
        engine, sm = _make_sessionmaker()
        try:
            async with sm() as session:
                tok = await session.get(Token, tid)
                if tok is None:
                    return "missing"
                if tok.revoked_at is not None:
                    return "already_revoked"
                tok.revoked_at = datetime.now(UTC)
                await session.commit()
                return "ok"
        finally:
            await engine.dispose()

    outcome = asyncio.run(_run())
    if outcome == "missing":
        typer.echo(f"no token with id {token_id}", err=True)
        raise typer.Exit(code=1)
    if outcome == "already_revoked":
        typer.echo(f"token {token_id} already revoked", err=True)
        raise typer.Exit(code=1)
    typer.echo("revoked")


if __name__ == "__main__":
    app()
