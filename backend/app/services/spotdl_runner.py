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
    def __init__(self, exit_code: int, stderr_tail: str):
        super().__init__(f"spotdl exited {exit_code}: {stderr_tail[-500:]}")
        self.exit_code = exit_code
        self.stderr_tail = stderr_tail


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


async def run_spotdl(source_url: str, output_dir: str | Path) -> list[DownloadedFile]:
    """Invoke `spotdl download <url> --output <template>` as a subprocess.

    Returns the list of new audio files produced (dir-diff before vs after).
    Raises `SpotdlError(exit_code, combined_output_tail)` on non-zero exit.
    Executable is resolved via `_spotdl_executable()` (env `SPOTDL_EXECUTABLE`
    or PATH).
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
    proc = await _spawn(cmd)
    stdout_b, _ = await proc.communicate()
    output_text = (stdout_b or b"").decode("utf-8", errors="replace")[-_OUTPUT_TAIL_BYTES:]

    if proc.returncode != 0:
        raise SpotdlError(exit_code=proc.returncode or -1, stderr_tail=output_text)

    after = _scan_audio_files(out_path)
    new_files = sorted(after - before)
    return [DownloadedFile(path=str(f), size_bytes=f.stat().st_size) for f in new_files]
