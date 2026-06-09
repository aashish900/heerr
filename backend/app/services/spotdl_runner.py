import asyncio
import sys
from dataclasses import dataclass
from pathlib import Path

_AUDIO_SUFFIXES = {".mp3", ".m4a", ".opus", ".flac", ".ogg", ".wav"}
_STDERR_TAIL_BYTES = 4000


@dataclass(frozen=True)
class DownloadedFile:
    path: str
    size_bytes: int


class SpotdlError(Exception):
    def __init__(self, exit_code: int, stderr_tail: str):
        super().__init__(
            f"spotdl exited {exit_code}: {stderr_tail[-500:]}"
        )
        self.exit_code = exit_code
        self.stderr_tail = stderr_tail


async def _spawn(cmd: list[str]) -> asyncio.subprocess.Process:
    return await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )


def _scan_audio_files(output_dir: Path) -> set[Path]:
    out: set[Path] = set()
    for p in output_dir.rglob("*"):
        if p.is_file() and p.suffix.lower() in _AUDIO_SUFFIXES:
            out.add(p.resolve())
    return out


async def run_spotdl(
    spotify_uri: str, output_dir: str | Path
) -> list[DownloadedFile]:
    """Invoke `python -m spotdl download <uri> --output <dir>` as a subprocess.

    Returns the list of new audio files produced (dir-diff before vs after).
    Raises `SpotdlError(exit_code, stderr_tail)` on non-zero exit.
    """
    out_path = Path(output_dir).resolve()
    out_path.mkdir(parents=True, exist_ok=True)

    before = _scan_audio_files(out_path)

    cmd = [
        sys.executable,
        "-m",
        "spotdl",
        "download",
        spotify_uri,
        "--output",
        str(out_path),
    ]
    proc = await _spawn(cmd)
    _, stderr_b = await proc.communicate()
    stderr_text = (stderr_b or b"").decode("utf-8", errors="replace")[
        -_STDERR_TAIL_BYTES:
    ]

    if proc.returncode != 0:
        raise SpotdlError(
            exit_code=proc.returncode or -1, stderr_tail=stderr_text
        )

    after = _scan_audio_files(out_path)
    new_files = sorted(after - before)
    return [
        DownloadedFile(path=str(f), size_bytes=f.stat().st_size)
        for f in new_files
    ]
