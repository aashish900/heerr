from pydantic import BaseModel, ConfigDict, Field

from app.schemas.profile import UserProfileResponse


class LoginRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    username: str = Field(..., min_length=1)
    password: str = Field(..., min_length=1)


class LoginResponse(BaseModel):
    token: str
    scopes: list[str]
    navidrome_url: str
    navidrome_username: str
    profile: UserProfileResponse
