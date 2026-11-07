"""Per-user recommendation history (RX3), shared by For You and vibe mixes."""

from datetime import timedelta
from uuid import UUID

from sqlalchemy import func, select, union
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Job, RecFeedback

SHOWN_WINDOW = timedelta(days=7)


async def user_history(
    session: AsyncSession, user_id: UUID, urls: list[str]
) -> tuple[set[str], set[str]]:
    """(excluded, recently_shown) among `urls` for this user.

    Excluded = anything the user requested (non-failed job) or dismissed.
    """
    if not urls:
        return set(), set()
    excluded_q = union(
        select(Job.source_url).where(
            Job.user_id == user_id, Job.source_url.in_(urls), Job.state != "failed"
        ),
        select(RecFeedback.source_url).where(
            RecFeedback.user_id == user_id,
            RecFeedback.source_url.in_(urls),
            RecFeedback.dismissed_at.is_not(None),
        ),
    )
    shown_q = select(RecFeedback.source_url).where(
        RecFeedback.user_id == user_id,
        RecFeedback.source_url.in_(urls),
        RecFeedback.last_shown_at > func.now() - SHOWN_WINDOW,
    )
    excluded = set((await session.execute(excluded_q)).scalars())
    shown = set((await session.execute(shown_q)).scalars())
    return excluded, shown
