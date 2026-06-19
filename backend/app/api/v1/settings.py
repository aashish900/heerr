from typing import Any

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import current_user
from app.db import get_session
from app.models import User
from app.schemas.settings import UserSettingsUpdate, UserSettingsView

router = APIRouter(tags=["settings"])

# Keys the user is allowed to manage. Operator-global config
# (RECOMMENDATION_ENGINE, LASTFM_API_KEY) is not exposed here.
_MANAGED_KEYS = ("lastfm_username", "listenbrainz_token")


def _to_view(settings: dict[str, Any]) -> UserSettingsView:
    return UserSettingsView(
        lastfm_username=settings.get("lastfm_username"),
        listenbrainz_token_set=bool(settings.get("listenbrainz_token")),
    )


@router.get("/settings", response_model=UserSettingsView)
async def get_settings(user: User = Depends(current_user)) -> UserSettingsView:
    return _to_view(user.settings or {})


@router.patch("/settings", response_model=UserSettingsView)
async def update_settings(
    update: UserSettingsUpdate,
    user: User = Depends(current_user),
    session: AsyncSession = Depends(get_session),
) -> UserSettingsView:
    # Reassign a fresh dict so SQLAlchemy detects the change (in-place mutation
    # of a JSONB dict is not tracked without MutableDict).
    new_settings = dict(user.settings or {})
    for key, value in update.model_dump(exclude_unset=True).items():
        if key not in _MANAGED_KEYS:
            continue
        if isinstance(value, str):
            value = value.strip()
        if not value:  # explicit null or blank string clears the setting
            new_settings.pop(key, None)
        else:
            new_settings[key] = value
    user.settings = new_settings
    session.add(user)
    await session.flush()
    return _to_view(new_settings)
