from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


class CreateTokenRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    scopes: list[Literal["read", "download"]] = Field(..., min_length=1)
    is_admin: bool = False
    navidrome_username: str = Field(..., min_length=1)

    @field_validator("scopes")
    @classmethod
    def _dedupe(cls, v: list[str]) -> list[str]:
        return sorted(set(v))


class CreateTokenResponse(BaseModel):
    id: UUID
    raw_token: str
    navidrome_username: str
    scopes: list[str]
    is_admin: bool
    created_at: datetime


class TokenView(BaseModel):
    id: UUID
    navidrome_username: str
    scopes: list[str]
    is_admin: bool
    created_at: datetime
    revoked_at: datetime | None
