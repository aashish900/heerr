from __future__ import annotations

from pydantic import BaseModel


class UserProfileResponse(BaseModel):
    display_name: str | None
    nickname: str | None
    bio: str | None
    avatar_b64: str | None  # base64-encoded JPEG bytes; null when no avatar set


class UserProfileUpdate(BaseModel):
    display_name: str | None
    nickname: str | None
    bio: str | None
    avatar_b64: str | None  # null explicitly clears the stored avatar
