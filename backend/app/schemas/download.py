import re
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, field_validator

_URI_RE = re.compile(r"^spotify:(track|album|playlist):[A-Za-z0-9_-]+$")


class DownloadRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    spotify_uri: str

    @field_validator("spotify_uri")
    @classmethod
    def _validate(cls, v: str) -> str:
        if not _URI_RE.match(v):
            raise ValueError(
                "invalid spotify URI; expected spotify:(track|album|playlist):<id>"
            )
        return v

    def parsed_type(self) -> Literal["track", "album", "playlist"]:
        return self.spotify_uri.split(":", 2)[1]  # type: ignore[return-value]


class DownloadResponse(BaseModel):
    job_id: UUID
    state: str
    deduped: bool
