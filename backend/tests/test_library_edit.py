"""Tests for PATCH /api/v1/library/song (issue #44, Phase O2).

Mirrors the app-factory + make_token setup of test_library_delete.py. Happy
paths copy the real ffmpeg fixtures from tests/fixtures/ into music_dir so
mutagen can parse them (the delete tests' fake bytes won't do).
"""

import shutil
from pathlib import Path

import mutagen
import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.v1.router import api_v1
from app.config import Settings, get_settings
from app.db import get_session

FIXTURES = Path(__file__).parent / "fixtures"

JPEG_BYTES = b"\xff\xd8\xff\xe0" + b"\x00" * 32
PNG_BYTES = b"\x89PNG\r\n\x1a\n" + b"\x00" * 32

EDIT_SUFFIXES = [".mp3", ".m4a", ".flac", ".ogg", ".opus"]


@pytest.fixture
def music_dir(tmp_path):
    d = tmp_path / "music"
    d.mkdir()
    return d


@pytest.fixture
async def library_app(app_sm, music_dir):
    app = FastAPI()

    async def override_get_session():
        async with app_sm() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise

    app.dependency_overrides[get_session] = override_get_session
    app.dependency_overrides[get_settings] = lambda: Settings(
        database_url="postgresql+asyncpg://unused/unused",
        music_output_dir=str(music_dir),
        navidrome_url="http://navidrome:4533",
    )
    app.include_router(api_v1)
    yield app


@pytest.fixture
async def client(library_app):
    transport = ASGITransport(app=library_app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


def _seed_audio(music_dir: Path, rel: str) -> Path:
    """Copy the matching real fixture into music_dir under rel."""
    dst = music_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(FIXTURES / f"silence{dst.suffix}", dst)
    return dst


async def _edit(
    client,
    raw: str | None,
    *,
    path: str,
    title: str | None = None,
    album: str | None = None,
    artist: str | None = None,
    cover: bytes | None = None,
):
    headers = {"Authorization": f"Bearer {raw}"} if raw else {}
    data = {"path": path}
    for key, value in (("title", title), ("album", album), ("artist", artist)):
        if value is not None:
            data[key] = value
    files = {"cover": ("cover.jpg", cover, "image/jpeg")} if cover is not None else None
    return await client.patch("/api/v1/library/song", data=data, files=files, headers=headers)


# ---- auth / scope ---------------------------------------------------------


async def test_edit_requires_auth(client):
    r = await _edit(client, None, path="Artist/01 - Song.mp3", title="X")
    assert r.status_code == 401


async def test_edit_requires_download_scope(client, make_token):
    raw = await make_token(scopes=("read",))
    r = await _edit(client, raw, path="Artist/01 - Song.mp3", title="X")
    assert r.status_code == 403


# ---- path validation ------------------------------------------------------


@pytest.mark.parametrize(
    "bad_path",
    [
        "../outside.mp3",
        "Artist/../../outside.mp3",
        "/etc/passwd",
        "/tmp/abs.mp3",
        "",
        "/music/../outside.mp3",
        "/music/Artist/../../../outside.mp3",
        "/music",
        "/music/",
    ],
)
async def test_invalid_path_returns_422(client, make_token, bad_path, music_dir):
    raw = await make_token()
    r = await _edit(client, raw, path=bad_path, title="X")
    assert r.status_code == 422


async def test_wav_returns_422_with_explicit_detail(client, make_token, music_dir):
    raw = await make_token()
    _seed_audio(music_dir, "Artist/01 - Song.wav")
    r = await _edit(client, raw, path="Artist/01 - Song.wav", title="X")
    assert r.status_code == 422
    assert ".wav" in r.json()["detail"]


async def test_non_audio_suffix_returns_422(client, make_token, music_dir):
    (music_dir / "Artist").mkdir()
    (music_dir / "Artist" / "cover.jpg").write_bytes(b"jpg")
    raw = await make_token()
    r = await _edit(client, raw, path="Artist/cover.jpg", title="X")
    assert r.status_code == 422


async def test_missing_file_returns_404(client, make_token, music_dir):
    raw = await make_token()
    r = await _edit(client, raw, path="Artist/99 - Nope.mp3", title="X")
    assert r.status_code == 404


# ---- field validation -----------------------------------------------------


async def test_no_fields_and_no_cover_returns_422(client, make_token, music_dir):
    raw = await make_token()
    _seed_audio(music_dir, "Artist/01 - Song.mp3")
    r = await _edit(client, raw, path="Artist/01 - Song.mp3")
    assert r.status_code == 422


@pytest.mark.parametrize("field", ["title", "album", "artist"])
async def test_blank_field_returns_422(client, make_token, music_dir, field):
    raw = await make_token()
    _seed_audio(music_dir, "Artist/01 - Song.mp3")
    r = await _edit(client, raw, path="Artist/01 - Song.mp3", **{field: "   "})
    assert r.status_code == 422


async def test_bad_image_bytes_returns_422(client, make_token, music_dir):
    raw = await make_token()
    rel = "Artist/01 - Song.mp3"
    _seed_audio(music_dir, rel)
    r = await _edit(client, raw, path=rel, cover=b"GIF89a" + b"\x00" * 16)
    assert r.status_code == 422


async def test_oversize_cover_returns_422(client, make_token, music_dir):
    raw = await make_token()
    rel = "Artist/01 - Song.mp3"
    _seed_audio(music_dir, rel)
    oversize = JPEG_BYTES + b"\x00" * (5 * 1024 * 1024)
    r = await _edit(client, raw, path=rel, cover=oversize)
    assert r.status_code == 422


# ---- happy paths ----------------------------------------------------------


@pytest.mark.parametrize("suffix", EDIT_SUFFIXES)
async def test_edit_tags_per_format(client, make_token, music_dir, suffix):
    raw = await make_token()
    rel = f"Artist/01 - Song{suffix}"
    full = _seed_audio(music_dir, rel)

    r = await _edit(client, raw, path=rel, title="New Title", album="New Album", artist="A, B")

    assert r.status_code == 200
    body = r.json()
    assert body["updated"] is True
    assert body["path"] == rel
    assert body["fields"] == ["title", "album", "artist"]
    # tags rewritten in place — file never renamed
    assert full.exists()
    assert sorted(p.name for p in full.parent.iterdir()) == [full.name]
    audio = mutagen.File(full, easy=True)
    assert audio["title"] == ["New Title"]
    assert audio["album"] == ["New Album"]
    assert audio["artist"] == ["A, B"]


async def test_edit_title_only_leaves_other_tags(client, make_token, music_dir):
    raw = await make_token()
    rel = "Artist/01 - Song.mp3"
    full = _seed_audio(music_dir, rel)
    await _edit(client, raw, path=rel, album="Keep Album", artist="Keep Artist")

    r = await _edit(client, raw, path=rel, title="Only Title")

    assert r.status_code == 200
    assert r.json()["fields"] == ["title"]
    audio = mutagen.File(full, easy=True)
    assert audio["title"] == ["Only Title"]
    assert audio["album"] == ["Keep Album"]
    assert audio["artist"] == ["Keep Artist"]


async def test_cover_only_upload(client, make_token, music_dir):
    from mutagen.id3 import ID3

    raw = await make_token()
    rel = "Artist/01 - Song.mp3"
    full = _seed_audio(music_dir, rel)

    r = await _edit(client, raw, path=rel, cover=JPEG_BYTES)

    assert r.status_code == 200
    assert r.json()["fields"] == ["cover"]
    apics = ID3(full).getall("APIC")
    assert len(apics) == 1
    assert bytes(apics[0].data) == JPEG_BYTES


async def test_tags_and_cover_together(client, make_token, music_dir):
    from mutagen.id3 import ID3

    raw = await make_token()
    rel = "Artist/01 - Song.mp3"
    full = _seed_audio(music_dir, rel)

    r = await _edit(client, raw, path=rel, title="Both", cover=PNG_BYTES)

    assert r.status_code == 200
    assert r.json()["fields"] == ["title", "cover"]
    audio = mutagen.File(full, easy=True)
    assert audio["title"] == ["Both"]
    assert len(ID3(full).getall("APIC")) == 1


async def test_navidrome_prefixed_path_is_stripped(client, make_token, music_dir):
    raw = await make_token()
    rel = "Taylor Swift - Paper Rings.mp3"
    full = _seed_audio(music_dir, rel)

    r = await _edit(client, raw, path=f"/music/{rel}", title="Stripped OK")

    assert r.status_code == 200
    assert r.json()["path"] == f"/music/{rel}"
    audio = mutagen.File(full, easy=True)
    assert audio["title"] == ["Stripped OK"]
