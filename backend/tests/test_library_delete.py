import hashlib
import uuid

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

from app.api.v1.router import api_v1
from app.config import Settings, get_settings
from app.db import get_session

_SONG_URL_A = "https://www.youtube.com/watch?v=abc"
_SONG_URL_B = "https://www.youtube.com/watch?v=def"


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


@pytest.fixture
async def cleanup(app_sm):
    yield
    async with app_sm() as s:
        await s.execute(text("DELETE FROM downloads"))
        await s.execute(text("DELETE FROM jobs"))
        await s.commit()


async def _token_id_for(app_sm, raw: str):
    h = hashlib.sha256(raw.encode()).hexdigest()
    async with app_sm() as s:
        r = await s.execute(text("SELECT id FROM tokens WHERE token_hash = :h"), {"h": h})
        return r.scalar_one()


async def _seed_download(app_sm, token_id, user_id, source_url: str, output_path: str):
    """Insert a done job + a downloads row pointing at output_path."""
    job_id = uuid.uuid4()
    async with app_sm() as s:
        await s.execute(
            text(
                "INSERT INTO jobs (id, source_url, source_type, state,"
                " created_by_token_id, user_id)"
                " VALUES (:id, :u, 'song', 'done', :tok, :uid)"
            ),
            {"id": job_id, "u": source_url, "tok": token_id, "uid": user_id},
        )
        await s.execute(
            text(
                "INSERT INTO downloads (source_url, job_id, user_id, output_path)"
                " VALUES (:u, :j, :uid, :p)"
            ),
            {"u": source_url, "j": job_id, "uid": user_id, "p": output_path},
        )
        await s.commit()


def _write_song(music_dir, rel: str) -> str:
    """Create a fake audio file under music_dir; returns its absolute path."""
    full = music_dir / rel
    full.parent.mkdir(parents=True, exist_ok=True)
    full.write_bytes(b"ID3fake-audio")
    return str(full)


async def _delete(client, raw: str | None, path: str):
    headers = {"Authorization": f"Bearer {raw}"} if raw else {}
    return await client.request(
        "DELETE", "/api/v1/library/song", json={"path": path}, headers=headers
    )


# ---- auth / scope ---------------------------------------------------------


async def test_delete_requires_auth(client):
    r = await _delete(client, None, "Artist/Album/01 - Song.mp3")
    assert r.status_code == 401


async def test_delete_requires_download_scope(client, make_token):
    raw = await make_token(scopes=("read",))
    r = await _delete(client, raw, "Artist/Album/01 - Song.mp3")
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
        # prefix-stripping must not open a traversal hole
        "/music/../outside.mp3",
        "/music/Artist/../../../outside.mp3",
        # the bare prefix itself resolves to the root -> rejected
        "/music",
        "/music/",
    ],
)
async def test_invalid_path_returns_422(client, make_token, bad_path, music_dir):
    raw = await make_token()
    r = await _delete(client, raw, bad_path)
    assert r.status_code == 422


# ---- navidrome music-folder prefix stripping (N2) --------------------------


async def test_navidrome_prefixed_absolute_path_is_stripped_and_deleted(
    client, make_token, music_dir
):
    """Navidrome with Subsonic.DefaultReportRealPath=true reports paths as
    absolute inside ITS container (`/music/<file>`). The endpoint strips the
    configured prefix and resolves the remainder under music_output_dir."""
    raw = await make_token()
    rel = "Taylor Swift - Paper Rings.mp3"
    _write_song(music_dir, rel)

    r = await _delete(client, raw, f"/music/{rel}")
    assert r.status_code == 200
    assert r.json()["deleted"] is True
    assert not (music_dir / rel).exists()


async def test_relative_path_still_works_alongside_prefix(client, make_token, music_dir):
    raw = await make_token()
    rel = "Artist/Album/01 - Song.mp3"
    _write_song(music_dir, rel)

    r = await _delete(client, raw, rel)
    assert r.status_code == 200
    assert not (music_dir / rel).exists()


async def test_absolute_path_outside_prefix_still_422(client, make_token, music_dir):
    raw = await make_token()
    _write_song(music_dir, "safe.mp3")
    r = await _delete(client, raw, str(music_dir / "safe.mp3"))
    assert r.status_code == 422
    assert (music_dir / "safe.mp3").exists()


async def test_non_audio_suffix_returns_422(client, make_token, music_dir):
    (music_dir / "Artist").mkdir()
    (music_dir / "Artist" / "cover.jpg").write_bytes(b"jpg")
    raw = await make_token()
    r = await _delete(client, raw, "Artist/cover.jpg")
    assert r.status_code == 422
    assert (music_dir / "Artist" / "cover.jpg").exists()


async def test_missing_file_returns_404(client, make_token, music_dir):
    raw = await make_token()
    r = await _delete(client, raw, "Artist/Album/99 - Nope.mp3")
    assert r.status_code == 404


# ---- happy path -----------------------------------------------------------


async def test_delete_removes_file_and_download_rows(
    client, make_token, music_dir, app_sm, system_admin_user_id, cleanup
):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)
    rel = "Artist/Album/01 - Song.mp3"
    full = _write_song(music_dir, rel)
    # two downloads rows pointing at the same file (re-requested under two URLs)
    await _seed_download(app_sm, token_id, system_admin_user_id, _SONG_URL_A, full)
    await _seed_download(app_sm, token_id, system_admin_user_id, _SONG_URL_B, full)

    r = await _delete(client, raw, rel)
    assert r.status_code == 200
    body = r.json()
    assert body["deleted"] is True
    assert body["path"] == rel

    assert not (music_dir / rel).exists()
    async with app_sm() as s:
        n = await s.execute(
            text("SELECT count(*) FROM downloads WHERE output_path = :p"), {"p": full}
        )
        assert n.scalar_one() == 0


async def test_delete_prunes_empty_parent_dirs(client, make_token, music_dir):
    raw = await make_token()
    rel = "Artist/Album/01 - Only.mp3"
    _write_song(music_dir, rel)

    r = await _delete(client, raw, rel)
    assert r.status_code == 200
    # Album and Artist dirs were emptied -> pruned; music root itself remains.
    assert not (music_dir / "Artist").exists()
    assert music_dir.exists()


async def test_delete_keeps_nonempty_parent_dirs(client, make_token, music_dir):
    raw = await make_token()
    rel = "Artist/Album/01 - First.mp3"
    _write_song(music_dir, rel)
    _write_song(music_dir, "Artist/Album/02 - Second.mp3")

    r = await _delete(client, raw, rel)
    assert r.status_code == 200
    assert not (music_dir / rel).exists()
    assert (music_dir / "Artist/Album/02 - Second.mp3").exists()
    assert (music_dir / "Artist/Album").exists()
