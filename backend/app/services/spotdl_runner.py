import asyncio
import logging
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse

_AUDIO_SUFFIXES = {".mp3", ".m4a", ".opus", ".flac", ".ogg", ".wav"}
_OUTPUT_TAIL_BYTES = 4000

# YouTube/YT Music query params that spotdl chokes on. Concrete failure mode:
# URLs with `&list=...` or `&index=...` drive spotdl into a KeyError:
# 'videoDetails' code path. Strip everything except the video id (`v`).
_YT_KEEP_PARAMS = {"v"}
_YT_HOSTS = {
    "www.youtube.com",
    "youtube.com",
    "m.youtube.com",
    "music.youtube.com",
    "youtu.be",
}

_log = logging.getLogger(__name__)


def log_spotdl_version() -> None:
    """Probe `spotdl --version` once at app boot and log the result.

    Two containers on different spotDL versions produce different outputs;
    pinning the version in the boot log makes it possible to correlate a
    bad job back to a specific spotdl build.
    """
    exe = _spotdl_executable()
    try:
        result = subprocess.run(
            [exe, "--version"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        version = (result.stdout or result.stderr or "").strip() or "unknown"
        _log.info(
            "spotdl version probed",
            extra={"spotdl_executable": exe, "spotdl_version": version},
        )
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError) as exc:
        _log.warning(
            "spotdl version probe failed",
            extra={"spotdl_executable": exe, "error": str(exc)},
        )


def canonicalize_yt_url(url: str) -> str:
    """Strip non-essential query params from YT / YT-Music URLs.

    Keeps only `v=<id>`. Non-YT hosts pass through unchanged.
    """
    parsed = urlparse(url)
    if parsed.hostname not in _YT_HOSTS:
        return url
    params = [(k, v) for k, v in parse_qsl(parsed.query) if k in _YT_KEEP_PARAMS]
    return urlunparse(parsed._replace(query=urlencode(params), fragment=""))


def _spotdl_executable() -> str:
    """Resolve the spotdl binary.

    spotdl is installed in its own isolated venv (via pipx in the Docker
    image) because its dependency closure conflicts with ours (it pins
    fastapi==0.103.x). It's NOT in pyproject.toml — we invoke its console
    script, not its Python API. See DECISIONLOG 2026-06-08 "spotdl install
    isolated" for the why.
    """
    return os.environ.get("SPOTDL_EXECUTABLE", "spotdl")


@dataclass(frozen=True)
class DownloadedFile:
    path: str
    size_bytes: int


class SpotdlError(Exception):
    """Base class for spotDL subprocess failures.

    Subclasses categorize the failure so the worker (and future auto-retry
    policy) can branch on `isinstance` rather than re-parsing `stderr_tail`.
    Pattern matching lives in `_classify_error()`.
    """

    def __init__(self, exit_code: int, stderr_tail: str):
        super().__init__(f"{type(self).__name__} exit {exit_code}: {stderr_tail[-500:]}")
        self.exit_code = exit_code
        self.stderr_tail = stderr_tail


class NetworkError(SpotdlError):
    """DNS / TCP / TLS failure reaching YouTube or its CDN. Likely transient."""


class RateLimitedError(SpotdlError):
    """HTTP 429 / quota exceeded. Transient; backoff-then-retry candidate."""


class VideoUnavailableError(SpotdlError):
    """Removed, private, or never-existed video. Permanent — do not retry."""


class RegionLockedError(SpotdlError):
    """Content blocked in the server's region. Permanent until VPN posture changes."""


class AgeGatedError(SpotdlError):
    """YouTube age verification required. Permanent without signed-in cookies."""


class TranscodeError(SpotdlError):
    """ffmpeg failure converting the downloaded stream. Likely permanent."""


class UnknownSpotdlError(SpotdlError):
    """Catch-all when no pattern matches. Default for unclassified failures."""


_NETWORK_PATTERNS = (
    "connectionerror",
    "connection refused",
    "connection reset",
    "could not resolve",
    "name resolution",
    "temporary failure in name resolution",
    "max retries exceeded",
    "timed out",
    "timeout",
    "ssl",
    "tls",
    "newconnectionerror",
)
_RATE_LIMIT_PATTERNS = (
    "http error 429",
    "too many requests",
    "rate limit",
    "quota exceeded",
)
_VIDEO_UNAVAILABLE_PATTERNS = (
    "video unavailable",
    "this video is not available",
    "private video",
    "video has been removed",
    "no longer available",
)
_REGION_PATTERNS = (
    "not available in your country",
    "blocked it in your country",
    "geo restricted",
    "geo-restricted",
)
_AGE_GATE_PATTERNS = (
    "age-restricted",
    "age restricted",
    "sign in to confirm your age",
)
_TRANSCODE_PATTERNS = (
    "ffmpeg",
    "could not transcode",
    "transcoding failed",
    "invalid data found when processing input",
)


def _classify_error(exit_code: int, output_tail: str) -> type[SpotdlError]:
    """Pick the most specific SpotdlError subclass for a failure.

    Order matters: rate-limit and video-unavailable take precedence over
    the generic network bucket because their hints (HTTP 429, "video
    unavailable") can co-occur with stack traces that also mention sockets.
    """
    text = output_tail.lower()
    if any(p in text for p in _RATE_LIMIT_PATTERNS):
        return RateLimitedError
    # Region check before generic "video unavailable" — "not available in your
    # country" is the more specific signal and tends to co-occur with the
    # generic phrase.
    if any(p in text for p in _REGION_PATTERNS):
        return RegionLockedError
    if any(p in text for p in _VIDEO_UNAVAILABLE_PATTERNS):
        return VideoUnavailableError
    if any(p in text for p in _AGE_GATE_PATTERNS):
        return AgeGatedError
    if any(p in text for p in _TRANSCODE_PATTERNS):
        return TranscodeError
    if any(p in text for p in _NETWORK_PATTERNS):
        return NetworkError
    return UnknownSpotdlError


async def _spawn(cmd: list[str]) -> asyncio.subprocess.Process:
    return await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,  # merge stderr into stdout
    )


def _scan_audio_files(output_dir: Path) -> set[Path]:
    out: set[Path] = set()
    for p in output_dir.rglob("*"):
        if p.is_file() and p.suffix.lower() in _AUDIO_SUFFIXES:
            out.add(p.resolve())
    return out


async def run_spotdl(
    source_url: str, output_dir: str | Path, *, embed_lyrics: bool = False
) -> list[DownloadedFile]:
    """Invoke `spotdl download <url> --output <template>` as a subprocess.

    Returns the list of new audio files produced (dir-diff before vs after).
    Raises `SpotdlError(exit_code, combined_output_tail)` on non-zero exit.
    Executable is resolved via `_spotdl_executable()` (env `SPOTDL_EXECUTABLE`
    or PATH). When `embed_lyrics` is True, passes `--lyrics` so spotdl embeds
    lyrics from its default providers into the downloaded file.
    """
    out_path = Path(output_dir).resolve()
    out_path.mkdir(parents=True, exist_ok=True)

    before = _scan_audio_files(out_path)

    cmd = [
        _spotdl_executable(),
        "download",
        canonicalize_yt_url(source_url),
        "--output",
        str(out_path / "{title}-{artist}.{output-ext}"),
    ]
    if embed_lyrics:
        cmd.append("--lyrics")
    proc = await _spawn(cmd)
    stdout_b, _ = await proc.communicate()
    output_text = (stdout_b or b"").decode("utf-8", errors="replace")[-_OUTPUT_TAIL_BYTES:]

    if proc.returncode != 0:
        exit_code = proc.returncode or -1
        cls = _classify_error(exit_code, output_text)
        _log.warning(
            "spotdl exited non-zero", extra={"exit_code": exit_code, "output_tail": output_text}
        )
        raise cls(exit_code=exit_code, stderr_tail=output_text)

    _log.info("spotdl exited 0", extra={"output_tail": output_text})
    after = _scan_audio_files(out_path)
    new_files = sorted(after - before)
    _log.info("spotdl new files", extra={"new_files": [str(f) for f in new_files]})
    return [DownloadedFile(path=str(f), size_bytes=f.stat().st_size) for f in new_files]
