from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


class CreateTokenRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    owner_label: str = Field(..., min_length=1)
    scopes: list[Literal["read", "download"]] = Field(..., min_length=1)
    is_admin: bool = False

    @field_validator("scopes")
    @classmethod
    def _dedupe(cls, v: list[str]) -> list[str]:
        return sorted(set(v))


class CreateTokenResponse(BaseModel):
    id: UUID
    raw_token: str
    owner_label: str
    scopes: list[str]
    is_admin: bool
    created_at: datetime


class TokenView(BaseModel):
    id: UUID
    owner_label: str
    scopes: list[str]
    is_admin: bool
    created_at: datetime
    revoked_at: datetime | None
