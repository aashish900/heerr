from pydantic import BaseModel, ConfigDict


class DeleteSongRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    # Path relative to the music library root, as reported by Navidrome's
    # Subsonic API (`song.path`). Containment + suffix are validated in the
    # endpoint (they depend on the runtime music_output_dir).
    path: str


class DeleteSongResponse(BaseModel):
    deleted: bool
    path: str


class LibraryEditResponse(BaseModel):
    updated: bool
    # Echoes the request path verbatim (possibly Navidrome-prefixed).
    path: str
    # Which fields were written: subset of ["title", "album", "artist", "cover"].
    fields: list[str]
