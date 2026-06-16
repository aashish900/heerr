"""J3: navigate User <-> Token <-> Job relationships via the ORM."""

import uuid

from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.models import Job, Token, User


async def test_user_navigates_to_tokens_and_jobs(app_sm):
    async with app_sm() as s:
        user = User(navidrome_username=f"u-{uuid.uuid4().hex[:8]}")
        s.add(user)
        await s.flush()

        token = Token(
            token_hash=f"hash-{uuid.uuid4()}",
            owner_label="rel-test",
            scopes=["read", "download"],
            user_id=user.id,
        )
        s.add(token)
        await s.flush()

        job = Job(
            source_url="https://www.youtube.com/watch?v=ytJ3rel",
            source_type="song",
            state="queued",
            created_by_token_id=token.id,
            user_id=user.id,
        )
        s.add(job)
        await s.commit()

        # Re-load with eager loading to navigate without lazy-loading errors.
        loaded = (
            await s.execute(
                select(User)
                .options(selectinload(User.tokens), selectinload(User.jobs))
                .where(User.id == user.id)
            )
        ).scalar_one()

        assert [t.id for t in loaded.tokens] == [token.id]
        assert [j.id for j in loaded.jobs] == [job.id]

        # Forward refs from token and job.
        loaded_token = (
            await s.execute(
                select(Token).options(selectinload(Token.user)).where(Token.id == token.id)
            )
        ).scalar_one()
        assert loaded_token.user.id == user.id

        loaded_job = (
            await s.execute(select(Job).options(selectinload(Job.user)).where(Job.id == job.id))
        ).scalar_one()
        assert loaded_job.user.id == user.id

        # Teardown
        await s.delete(job)
        await s.delete(token)
        await s.delete(user)
        await s.commit()
