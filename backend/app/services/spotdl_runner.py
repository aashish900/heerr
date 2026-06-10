import asyncio
import os
from dataclasses import dataclass
from pathlib import Path

_AUDIO_SUFFIXES = {".mp3", ".m4a", ".opus", ".flac", ".ogg", ".wav"}
_OUTPUT_TAIL_BYTES = 4000


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
        source_url,
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
