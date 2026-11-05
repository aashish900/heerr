from datetime import datetime
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator


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


MAX_SONGS_PER_COMMAND = 500


class JamCommandRequest(BaseModel):
    """Payload shapes (only the parts the host relies on are checked):
    play_songs {songs:[Song], start_index?}, enqueue {songs:[Song]},
    seek {position_ms}, everything else {}. `Song` is the client's Subsonic
    song JSON; only a string `id` is required.
    """

    model_config = ConfigDict(extra="forbid")

    kind: Literal["play_songs", "enqueue", "play", "pause", "next", "prev", "seek"]
    payload: dict[str, Any] = Field(default_factory=dict)

    @model_validator(mode="after")
    def _check_payload(self) -> "JamCommandRequest":
        p = self.payload
        if self.kind in ("play_songs", "enqueue"):
            songs = p.get("songs")
            if not isinstance(songs, list) or not 1 <= len(songs) <= MAX_SONGS_PER_COMMAND:
                raise ValueError(f"songs must be a list of 1-{MAX_SONGS_PER_COMMAND} items")
            if not all(isinstance(s, dict) and isinstance(s.get("id"), str) for s in songs):
                raise ValueError("every song needs a string id")
            if self.kind == "play_songs":
                start = p.get("start_index", 0)
                if not isinstance(start, int) or not 0 <= start < len(songs):
                    raise ValueError("start_index out of range")
                self.payload = {"songs": songs, "start_index": start}
            else:
                self.payload = {"songs": songs}
        elif self.kind == "seek":
            pos = p.get("position_ms")
            if not isinstance(pos, int) or pos < 0:
                raise ValueError("position_ms must be a non-negative int")
            self.payload = {"position_ms": pos}
        else:
            self.payload = {}
        return self


class JamCommandCreated(BaseModel):
    id: int


class JamCommandItem(BaseModel):
    id: int
    kind: str
    payload: dict[str, Any]
    sender: str


class JamSyncRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    state: dict[str, Any] | None = None
    # None = bootstrap: return no commands, just the current cursor.
    after: int | None = None


class JamSyncResponse(BaseModel):
    commands: list[JamCommandItem]
    cursor: int
    ended: bool


class JamStateResponse(BaseModel):
    state: dict[str, Any] | None
    state_at: datetime | None
    host_username: str
    ended: bool
