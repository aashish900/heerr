"""Unit tests for app/services/tag_editor.py (issue #44).

Fixtures under tests/fixtures/silence.<ext> are ~0.1 s of silence generated
once with ffmpeg (see ROADMAP Phase O — O1). Every test copies the fixture to
tmp_path so the originals stay pristine.
"""

import base64
import shutil
from pathlib import Path

import mutagen
import pytest
from mutagen.flac import FLAC, Picture
from mutagen.id3 import ID3
from mutagen.mp4 import MP4
from mutagen.oggopus import OggOpus
from mutagen.oggvorbis import OggVorbis

from app.services.tag_editor import (
    EDITABLE_SUFFIXES,
    UnsupportedImageError,
    embed_cover,
    sniff_image,
    write_tags,
)

FIXTURES = Path(__file__).parent / "fixtures"

# Minimal payloads with valid magic bytes. mutagen stores cover bytes opaquely,
# so a real decodable image is not required.
JPEG_BYTES = b"\xff\xd8\xff\xe0" + b"\x00" * 32
PNG_BYTES = b"\x89PNG\r\n\x1a\n" + b"\x00" * 32

SUFFIXES = sorted(EDITABLE_SUFFIXES)


def _copy_fixture(suffix: str, tmp_path: Path) -> Path:
    src = FIXTURES / f"silence{suffix}"
    dst = tmp_path / src.name
    shutil.copy(src, dst)
    return dst


def _read_cover_bytes(path: Path) -> bytes:
    """Extract the embedded cover from a file, per-format."""
    suffix = path.suffix.lower()
    if suffix == ".mp3":
        apics = ID3(path).getall("APIC")
        assert len(apics) == 1
        return bytes(apics[0].data)
    if suffix == ".m4a":
        covrs = MP4(path)["covr"]
        assert len(covrs) == 1
        return bytes(covrs[0])
    if suffix == ".flac":
        pictures = FLAC(path).pictures
        assert len(pictures) == 1
        return bytes(pictures[0].data)
    if suffix in {".ogg", ".opus"}:
        audio = OggVorbis(path) if suffix == ".ogg" else OggOpus(path)
        blocks = audio["metadata_block_picture"]
        assert len(blocks) == 1
        pic = Picture(base64.b64decode(blocks[0]))
        return bytes(pic.data)
    raise AssertionError(f"unexpected suffix {suffix}")


# ---------------------------------------------------------------------------
# sniff_image


def test_sniff_image_jpeg() -> None:
    assert sniff_image(JPEG_BYTES) == "image/jpeg"


def test_sniff_image_png() -> None:
    assert sniff_image(PNG_BYTES) == "image/png"


@pytest.mark.parametrize(
    "data",
    [
        b"",
        b"GIF89a" + b"\x00" * 16,
        b"RIFF....WEBP",
        b"not an image at all",
        b"\x89PNG",  # truncated magic
    ],
)
def test_sniff_image_rejects_non_jpeg_png(data: bytes) -> None:
    with pytest.raises(UnsupportedImageError):
        sniff_image(data)


# ---------------------------------------------------------------------------
# write_tags


@pytest.mark.parametrize("suffix", SUFFIXES)
def test_write_tags_round_trip(suffix: str, tmp_path: Path) -> None:
    path = _copy_fixture(suffix, tmp_path)

    fields = write_tags(path, title="New Title", album="New Album", artist="A, B")

    assert fields == ["title", "album", "artist"]
    audio = mutagen.File(path, easy=True)
    assert audio["title"] == ["New Title"]
    assert audio["album"] == ["New Album"]
    assert audio["artist"] == ["A, B"]


@pytest.mark.parametrize("suffix", SUFFIXES)
def test_write_tags_partial_leaves_other_fields(suffix: str, tmp_path: Path) -> None:
    path = _copy_fixture(suffix, tmp_path)
    write_tags(path, title="Keep Title", album="Keep Album", artist="Keep Artist")

    fields = write_tags(path, title="Changed Title")

    assert fields == ["title"]
    audio = mutagen.File(path, easy=True)
    assert audio["title"] == ["Changed Title"]
    assert audio["album"] == ["Keep Album"]
    assert audio["artist"] == ["Keep Artist"]


def test_write_tags_noop_returns_empty(tmp_path: Path) -> None:
    path = _copy_fixture(".mp3", tmp_path)
    assert write_tags(path) == []


def test_write_tags_does_not_rename_file(tmp_path: Path) -> None:
    path = _copy_fixture(".mp3", tmp_path)
    write_tags(path, title="Completely Different Name")
    assert path.exists()
    assert list(tmp_path.iterdir()) == [path]


# ---------------------------------------------------------------------------
# embed_cover


@pytest.mark.parametrize("suffix", SUFFIXES)
def test_embed_cover_round_trip(suffix: str, tmp_path: Path) -> None:
    path = _copy_fixture(suffix, tmp_path)

    embed_cover(path, JPEG_BYTES, "image/jpeg")

    assert _read_cover_bytes(path) == JPEG_BYTES


@pytest.mark.parametrize("suffix", SUFFIXES)
def test_embed_cover_replaces_existing(suffix: str, tmp_path: Path) -> None:
    path = _copy_fixture(suffix, tmp_path)
    embed_cover(path, JPEG_BYTES, "image/jpeg")

    embed_cover(path, PNG_BYTES, "image/png")

    # _read_cover_bytes asserts exactly one cover is present.
    assert _read_cover_bytes(path) == PNG_BYTES


@pytest.mark.parametrize("suffix", SUFFIXES)
def test_embed_cover_preserves_tags(suffix: str, tmp_path: Path) -> None:
    path = _copy_fixture(suffix, tmp_path)
    write_tags(path, title="Title Stays", album="Album Stays", artist="Artist Stays")

    embed_cover(path, JPEG_BYTES, "image/jpeg")

    audio = mutagen.File(path, easy=True)
    assert audio["title"] == ["Title Stays"]
    assert audio["album"] == ["Album Stays"]
    assert audio["artist"] == ["Artist Stays"]


def test_wav_not_editable() -> None:
    assert ".wav" not in EDITABLE_SUFFIXES
