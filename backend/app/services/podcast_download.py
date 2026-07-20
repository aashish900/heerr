"""P5: Download a podcast episode's enclosure to PODCAST_OUTPUT_DIR.

Unlike songs (spotDL subprocess) an episode enclosure is already a direct
audio URL — a plain streamed GET, written to a temp file, fsync'd, then
atomically renamed into place. No spotDL, no yt-dlp, no venv isolation.
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse
from uuid import UUID

import httpx

logger = logging.getLogger(__name__)

_FETCH_TIMEOUT_S = 120.0
_CHUNK_BYTES = 1024 * 256

# audio/x-m4a is what a lot of feeds still send for AAC-in-MP4 despite the
# registered type being audio/mp4.
_MIME_EXT = {
    "audio/mpeg": ".mp3",
    "audio/mp3": ".mp3",
    "audio/mp4": ".m4a",
    "audio/x-m4a": ".m4a",
    "audio/aac": ".aac",
    "audio/ogg": ".ogg",
    "audio/opus": ".opus",
    "audio/x-wav": ".wav",
    "audio/wav": ".wav",
}
_DEFAULT_EXT = ".mp3"


class EpisodeDownloadError(Exception):
    pass


@dataclass(frozen=True)
class DownloadedEpisode:
    path: str
    size_bytes: int


def _guess_extension(enclosure_url: str, enclosure_type: str | None) -> str:
    if enclosure_type:
        ext = _MIME_EXT.get(enclosure_type.split(";")[0].strip().lower())
        if ext:
            return ext
    url_ext = Path(urlparse(enclosure_url).path).suffix.lower()
    if url_ext in _MIME_EXT.values():
        return url_ext
    return _DEFAULT_EXT


async def download_episode(
    enclosure_url: str,
    output_dir: str,
    *,
    episode_id: UUID,
    enclosure_type: str | None,
) -> DownloadedEpisode:
    os.makedirs(output_dir, exist_ok=True)
    ext = _guess_extension(enclosure_url, enclosure_type)
    final_path = Path(output_dir) / f"{episode_id}{ext}"
    tmp_path = Path(output_dir) / f".{episode_id}{ext}.part"

    try:
        async with httpx.AsyncClient(timeout=_FETCH_TIMEOUT_S, follow_redirects=True) as client:
            async with client.stream("GET", enclosure_url) as resp:
                resp.raise_for_status()
                with open(tmp_path, "wb") as f:
                    async for chunk in resp.aiter_bytes(_CHUNK_BYTES):
                        f.write(chunk)
                    f.flush()
                    os.fsync(f.fileno())
    except httpx.HTTPError as exc:
        tmp_path.unlink(missing_ok=True)
        raise EpisodeDownloadError(str(exc)) from exc
    except Exception:
        tmp_path.unlink(missing_ok=True)
        raise

    size_bytes = tmp_path.stat().st_size
    os.replace(tmp_path, final_path)
    return DownloadedEpisode(path=str(final_path), size_bytes=size_bytes)
