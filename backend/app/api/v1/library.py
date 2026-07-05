from pathlib import Path

import sqlalchemy as sa
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_scope
from app.config import Settings, get_settings
from app.db import get_session
from app.models import Download, Token
from app.schemas.library import DeleteSongRequest, DeleteSongResponse

router = APIRouter(tags=["library"])

# Only real audio files may be deleted — never cover art, playlists, or
# anything Navidrome keeps alongside the music.
_AUDIO_SUFFIXES = {".mp3", ".m4a", ".flac", ".ogg", ".opus", ".wav"}


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
    root = Path(settings.music_output_dir).resolve()
    full = _resolve_under_root(req.path, root)

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
