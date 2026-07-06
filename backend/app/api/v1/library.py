import functools
from pathlib import Path

import anyio.to_thread
import sqlalchemy as sa
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_scope
from app.config import Settings, get_settings
from app.db import get_session
from app.models import Download, Token
from app.schemas.library import (
    DeleteSongRequest,
    DeleteSongResponse,
    LibraryEditResponse,
)
from app.services.tag_editor import (
    EDITABLE_SUFFIXES,
    TagEditError,
    UnsupportedImageError,
    embed_cover,
    sniff_image,
    write_tags,
)

router = APIRouter(tags=["library"])

# Only real audio files may be deleted — never cover art, playlists, or
# anything Navidrome keeps alongside the music.
_AUDIO_SUFFIXES = {".mp3", ".m4a", ".flac", ".ogg", ".opus", ".wav"}

_MAX_COVER_BYTES = 5 * 1024 * 1024


def _strip_navidrome_prefix(path: str, settings: Settings) -> str:
    """Strip Navidrome's music-folder prefix from a reported real path (N2).

    With `Subsonic.DefaultReportRealPath=true` Navidrome reports the path as
    absolute inside its own container (`/music/<file>`). Strip that prefix so
    the remainder is library-relative; any other absolute path still fails
    `_resolve_under_root`'s relative-path check.
    """
    nav_prefix = settings.navidrome_music_folder.rstrip("/")
    if nav_prefix and path.startswith(nav_prefix + "/"):
        return path[len(nav_prefix) + 1 :]
    return path


def _resolve_under_root(rel_path: str, root: Path) -> Path:
    """Resolve rel_path under root, rejecting traversal and absolute paths."""
    if not rel_path or Path(rel_path).is_absolute():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="path must be relative to the music library",
        )
    full = (root / rel_path).resolve()
    if full == root or not full.is_relative_to(root):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="path escapes the music library",
        )
    return full


def _prune_empty_dirs(start: Path, root: Path) -> None:
    """Remove now-empty parent dirs up to (not including) the library root."""
    d = start
    while d != root and d.is_relative_to(root):
        try:
            d.rmdir()  # fails on non-empty — that's the stop condition
        except OSError:
            break
        d = d.parent


@router.delete("/library/song", response_model=DeleteSongResponse)
async def delete_song(
    req: DeleteSongRequest,
    session: AsyncSession = Depends(get_session),
    settings: Settings = Depends(get_settings),
    tok: Token = Depends(require_scope("download")),
) -> DeleteSongResponse:
    """Delete one audio file from the music library.

    The file is identified by its Navidrome-relative path (Subsonic
    `song.path`). All `downloads` rows pointing at the file are removed so
    the already-downloaded dedupe resets for every user; Navidrome's watcher
    drops the track from the library on its next scan.
    """
    rel_path = _strip_navidrome_prefix(req.path, settings)

    root = Path(settings.music_output_dir).resolve()
    full = _resolve_under_root(rel_path, root)

    if full.suffix.lower() not in _AUDIO_SUFFIXES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="path is not an audio file",
        )
    if not full.is_file():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="file not found in the music library",
        )

    full.unlink()
    await session.execute(sa.delete(Download).where(Download.output_path == str(full)))
    _prune_empty_dirs(full.parent, root)

    return DeleteSongResponse(deleted=True, path=req.path)


@router.patch("/library/song", response_model=LibraryEditResponse)
async def edit_song(
    path: str = Form(...),
    title: str | None = Form(None),
    album: str | None = Form(None),
    artist: str | None = Form(None),
    cover: UploadFile | None = File(None),
    settings: Settings = Depends(get_settings),
    tok: Token = Depends(require_scope("download")),
) -> LibraryEditResponse:
    """Edit one audio file's tags and/or embedded cover art in place (#44).

    Multipart request — tags and cover travel together so the client's one
    Save can't half-succeed across two endpoints. The file is never renamed:
    `Song.path`, offline manifests, and `downloads` dedupe rows all key on
    the path staying stable. Navidrome re-reads the file on its next scan.
    """
    rel_path = _strip_navidrome_prefix(path, settings)

    root = Path(settings.music_output_dir).resolve()
    full = _resolve_under_root(rel_path, root)

    suffix = full.suffix.lower()
    if suffix not in EDITABLE_SUFFIXES:
        detail = (
            "metadata editing is not supported for .wav files"
            if suffix == ".wav"
            else "path is not an editable audio file"
        )
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=detail)
    if not full.is_file():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="file not found in the music library",
        )

    for name, value in (("title", title), ("album", album), ("artist", artist)):
        if value is not None and not value.strip():
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=f"{name} must not be blank",
            )
    if title is None and album is None and artist is None and cover is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="nothing to update — provide at least one field or a cover",
        )

    cover_data: bytes | None = None
    cover_mime = ""
    if cover is not None:
        cover_data = await cover.read()
        if len(cover_data) > _MAX_COVER_BYTES:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="cover image exceeds the 5 MB limit",
            )
        try:
            cover_mime = sniff_image(cover_data)
        except UnsupportedImageError as exc:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)
            ) from exc

    try:
        fields = await anyio.to_thread.run_sync(
            functools.partial(write_tags, full, title=title, album=album, artist=artist)
        )
        if cover_data is not None:
            await anyio.to_thread.run_sync(embed_cover, full, cover_data, cover_mime)
            fields.append("cover")
    except TagEditError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)
        ) from exc

    return LibraryEditResponse(updated=True, path=path, fields=fields)
