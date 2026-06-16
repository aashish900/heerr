from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class CreateUserRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    navidrome_username: str = Field(..., min_length=1)


class UserView(BaseModel):
    id: UUID
    navidrome_username: str
    created_at: datetime
    last_login_at: datetime | None
