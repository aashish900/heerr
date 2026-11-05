from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class JamCreateResponse(BaseModel):
    id: UUID
    code: str
    expires_at: datetime


class JamJoinRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    code: str = Field(..., min_length=1, max_length=16)


class JamJoinResponse(BaseModel):
    id: UUID
    host_username: str
    expires_at: datetime
