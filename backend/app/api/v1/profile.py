"""GET /api/v1/profile + PUT /api/v1/profile — per-user profile store."""

from __future__ import annotations

import base64

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import current_user, get_session
from app.models import User
from app.schemas.profile import UserProfileResponse, UserProfileUpdate

router = APIRouter(prefix="/profile", tags=["profile"])


def _to_response(user: User) -> UserProfileResponse:
    return UserProfileResponse(
        display_name=user.display_name,
        nickname=user.nickname,
        bio=user.bio,
        avatar_b64=(base64.b64encode(user.avatar_data).decode() if user.avatar_data else None),
    )


@router.get("", response_model=UserProfileResponse)
async def get_profile(user: User = Depends(current_user)) -> UserProfileResponse:
    return _to_response(user)


@router.put("", response_model=UserProfileResponse)
async def put_profile(
    body: UserProfileUpdate,
    user: User = Depends(current_user),
    session: AsyncSession = Depends(get_session),
) -> UserProfileResponse:
    user.display_name = body.display_name
    user.nickname = body.nickname
    user.bio = body.bio
    user.avatar_data = base64.b64decode(body.avatar_b64) if body.avatar_b64 is not None else None
    session.add(user)
    await session.flush()
    return _to_response(user)
