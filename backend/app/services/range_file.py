"""P6: HTTP byte-range support for serving a local file.

Podcast episode audio needs seek/resume, which the ephemeral preview proxy
(K2, which forwards Range to a remote googlevideo URL) doesn't provide for a
locally downloaded file. This parses a client `Range: bytes=...` header
against a known file size and streams the requested slice.
"""

from __future__ import annotations

import re
from collections.abc import AsyncIterator

_RANGE_RE = re.compile(r"bytes=(\d*)-(\d*)")
_CHUNK_BYTES = 256 * 1024


class InvalidRangeError(Exception):
    pass


def parse_range(range_header: str | None, file_size: int) -> tuple[int, int] | None:
    """Return an inclusive (start, end) byte range, or None for a full-file response.

    Raises `InvalidRangeError` for a syntactically-present but unsatisfiable range
    (start beyond EOF, or start > end) — caller maps that to 416.
    """
    if not range_header:
        return None
    m = _RANGE_RE.match(range_header.strip())
    if not m:
        return None
    start_raw, end_raw = m.groups()
    if start_raw == "" and end_raw == "":
        return None

    if start_raw == "":
        # Suffix range ("bytes=-500" = last 500 bytes).
        suffix_len = int(end_raw)
        start = max(file_size - suffix_len, 0)
        end = file_size - 1
    else:
        start = int(start_raw)
        end = int(end_raw) if end_raw else file_size - 1

    if file_size == 0 or start >= file_size or start > end:
        raise InvalidRangeError(f"unsatisfiable range for size {file_size}")

    return start, min(end, file_size - 1)


async def iter_file_range(path: str, start: int, end: int) -> AsyncIterator[bytes]:
    """Yield bytes in `[start, end]` (inclusive) from `path`."""
    remaining = end - start + 1
    with open(path, "rb") as f:
        f.seek(start)
        while remaining > 0:
            chunk = f.read(min(_CHUNK_BYTES, remaining))
            if not chunk:
                break
            remaining -= len(chunk)
            yield chunk
