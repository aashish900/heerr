import uuid

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

from app.api.v1.router import api_v1
from app.db import get_session
from app.models import Download, Job
from app.services.ytmusic import (
    YTMusicError,
    YTMusicResult,
    get_ytmusic_client,
)


def _song(url: str, title: str = "x", artist: str = "y") -> YTMusicResult:
    return YTMusicResult(
        source_url=url,
        source_type="song",
        title=title,
        artist=artist,
        album="A",
        duration_ms=1000,
        cover_url="https://i.ytimg.com/cover.jpg",
    )


def _album(url: str) -> YTMusicResult:
    return YTMusicResult(
        source_url=url,
        source_type="album",
        title="alb",
        artist="art",
        album=None,
        duration_ms=None,
        cover_url=None,
    )


def _playlist(url: str) -> YTMusicResult:
    return YTMusicResult(
        source_url=url,
        source_type="playlist",
        title="pl",
        artist="owner",
        album=None,
        duration_ms=None,
        cover_url=None,
    )


class FakeYTMusic:
    def __init__(self):
        self.songs: list[YTMusicResult] = []
        self.albums: list[YTMusicResult] = []
        self.playlists: list[YTMusicResult] = []
        self.raise_error: bool = False
        self.last_query: str | None = None
        self.last_limit: int | None = None

    async def search(self, query: str, type_: str, limit: int) -> list[YTMusicResult]:
        self.last_query = query
        self.last_limit = limit
        if self.raise_error:
            raise YTMusicError("upstream down")
        if type_ == "song":
            return list(self.songs)
        if type_ == "album":
            return list(self.albums)
        return list(self.playlists)


@pytest.fixture
async def fake_ytmusic():
    return FakeYTMusic()


@pytest.fixture
async def search_app(app_sm, fake_ytmusic):
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
    app.dependency_overrides[get_ytmusic_client] = lambda: fake_ytmusic
    app.include_router(api_v1)
    yield app


@pytest.fixture
async def client(search_app):
    transport = ASGITransport(app=search_app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.fixture
async def cleanup(app_sm):
    yield
    async with app_sm() as s:
        await s.execute(text("DELETE FROM downloads"))
        await s.execute(text("DELETE FROM jobs"))
        await s.commit()


_SONG_URL = "https://www.youtube.com/watch?v=abc123"
_ALBUM_URL = "https://music.youtube.com/browse/MPREb_album1"
_PLAYLIST_URL = "https://music.youtube.com/browse/VLPL_pl1"


async def _seed_download(app_sm, token_id, source_url: str):
    job_id = uuid.uuid4()
    async with app_sm() as s:
        s.add(
            Job(
                id=job_id,
                source_url=source_url,
                source_type="song",
                state="done",
                created_by_token_id=token_id,
            )
        )
        await s.flush()
        s.add(
            Download(
                source_url=source_url,
                job_id=job_id,
                output_path="/data/media/music/song.mp3",
            )
        )
        await s.commit()


async def _seed_active_job(app_sm, token_id, source_url: str, type_: str, state: str = "queued"):
    job_id = uuid.uuid4()
    async with app_sm() as s:
        s.add(
            Job(
                id=job_id,
                source_url=source_url,
                source_type=type_,
                state=state,
                created_by_token_id=token_id,
            )
        )
        await s.commit()
    return job_id


async def _token_id_for(app_sm, raw: str):
    import hashlib

    h = hashlib.sha256(raw.encode()).hexdigest()
    async with app_sm() as s:
        r = await s.execute(text("SELECT id FROM tokens WHERE token_hash = :h"), {"h": h})
        return r.scalar_one()


# ---- auth / scope branches ------------------------------------------------


async def test_search_requires_auth(client):
    r = await client.post("/api/v1/search", json={"query": "x", "type": "song"})
    assert r.status_code == 401


async def test_search_requires_read_scope(client, make_token):
    raw = await make_token(scopes=("download",))
    r = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "song"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 403


# ---- request validation ---------------------------------------------------


async def test_invalid_type_returns_422(client, make_token):
    raw = await make_token()
    r = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "track"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 422


async def test_limit_out_of_range_returns_422(client, make_token):
    raw = await make_token()
    r = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "song", "limit": 999},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 422


async def test_empty_query_returns_422(client, make_token):
    raw = await make_token()
    r = await client.post(
        "/api/v1/search",
        json={"query": "", "type": "song"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 422


async def test_unknown_field_returns_422(client, make_token):
    raw = await make_token()
    r = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "song", "evil": True},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 422


# ---- contract shape -------------------------------------------------------


async def test_song_search_returns_contract_fields(client, make_token, fake_ytmusic, cleanup):
    raw = await make_token()
    fake_ytmusic.songs = [_song(_SONG_URL, title="Blinding Lights", artist="The Weeknd")]
    r = await client.post(
        "/api/v1/search",
        json={"query": "blinding lights", "type": "song"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert len(body["results"]) == 1
    item = body["results"][0]
    assert set(item.keys()) == {
        "source_url",
        "source_type",
        "title",
        "artist",
        "album",
        "duration_ms",
        "cover_url",
        "already_downloaded",
        "active_job_id",
    }
    assert item["title"] == "Blinding Lights"
    assert item["source_type"] == "song"
    assert item["already_downloaded"] is False
    assert item["active_job_id"] is None


# ---- dedup hints ----------------------------------------------------------


async def test_song_already_downloaded_hint(client, make_token, fake_ytmusic, app_sm, cleanup):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)
    url2 = "https://www.youtube.com/watch?v=other"
    await _seed_download(app_sm, token_id, _SONG_URL)
    fake_ytmusic.songs = [_song(_SONG_URL), _song(url2)]
    r = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "song"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200
    by_url = {it["source_url"]: it for it in r.json()["results"]}
    assert by_url[_SONG_URL]["already_downloaded"] is True
    assert by_url[url2]["already_downloaded"] is False


async def test_song_active_job_hint(client, make_token, fake_ytmusic, app_sm, cleanup):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)
    job_id = await _seed_active_job(app_sm, token_id, _SONG_URL, "song", "queued")
    fake_ytmusic.songs = [_song(_SONG_URL)]
    r = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "song"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200
    item = r.json()["results"][0]
    assert item["active_job_id"] == str(job_id)
    assert item["already_downloaded"] is False


async def test_done_job_does_not_populate_active_job_id(
    client, make_token, fake_ytmusic, app_sm, cleanup
):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)
    await _seed_download(app_sm, token_id, _SONG_URL)
    fake_ytmusic.songs = [_song(_SONG_URL)]
    r = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "song"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    item = r.json()["results"][0]
    assert item["active_job_id"] is None
    assert item["already_downloaded"] is True


async def test_album_active_job_hint_but_no_download(
    client, make_token, fake_ytmusic, app_sm, cleanup
):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)
    job_id = await _seed_active_job(app_sm, token_id, _ALBUM_URL, "album", "running")
    fake_ytmusic.albums = [_album(_ALBUM_URL)]
    r = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "album"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200
    item = r.json()["results"][0]
    assert item["active_job_id"] == str(job_id)
    assert item["already_downloaded"] is False
    assert item["album"] is None
    assert item["duration_ms"] is None


async def test_playlist_search_returns_results(client, make_token, fake_ytmusic, cleanup):
    raw = await make_token()
    fake_ytmusic.playlists = [_playlist(_PLAYLIST_URL)]
    r = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "playlist"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200
    assert r.json()["results"][0]["source_url"] == _PLAYLIST_URL


# ---- error translation ----------------------------------------------------


async def test_ytmusic_error_translates_to_502(client, make_token, fake_ytmusic):
    raw = await make_token()
    fake_ytmusic.raise_error = True
    r = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "song"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 502


# ---- query plumbing -------------------------------------------------------


async def test_query_and_limit_passed_to_ytmusic(client, make_token, fake_ytmusic):
    raw = await make_token()
    fake_ytmusic.songs = []
    await client.post(
        "/api/v1/search",
        json={"query": "blinding lights", "type": "song", "limit": 5},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert fake_ytmusic.last_query == "blinding lights"
    assert fake_ytmusic.last_limit == 5


# ---- J9: per-user dedup hints --------------------------------------------


async def test_search_hints_scoped_to_current_user(client, app_sm, fake_ytmusic):
    """user-A's downloaded song is invisible to user-B's search hints."""
    import hashlib
    import secrets

    from app.models import Token, User

    async with app_sm() as s:
        ua = User(navidrome_username=f"alice-{uuid.uuid4().hex[:8]}")
        ub = User(navidrome_username=f"bob-{uuid.uuid4().hex[:8]}")
        s.add_all([ua, ub])
        await s.flush()
        raw_a = f"raw-{secrets.token_urlsafe(16)}"
        raw_b = f"raw-{secrets.token_urlsafe(16)}"
        tok_a = Token(
            token_hash=hashlib.sha256(raw_a.encode()).hexdigest(),
            owner_label=ua.navidrome_username,
            scopes=["read", "download"],
            user_id=ua.id,
        )
        tok_b = Token(
            token_hash=hashlib.sha256(raw_b.encode()).hexdigest(),
            owner_label=ub.navidrome_username,
            scopes=["read", "download"],
            user_id=ub.id,
        )
        s.add_all([tok_a, tok_b])
        await s.flush()

        # user-A has downloaded the song.
        job_a = Job(
            source_url="https://www.youtube.com/watch?v=shared",
            source_type="song",
            state="done",
            created_by_token_id=tok_a.id,
            user_id=ua.id,
        )
        s.add(job_a)
        await s.flush()
        s.add(
            Download(
                source_url="https://www.youtube.com/watch?v=shared",
                job_id=job_a.id,
                output_path="/data/media/music/shared.mp3",
            )
        )

        # user-A also has an active job for a different song.
        active_a = Job(
            source_url="https://www.youtube.com/watch?v=active",
            source_type="song",
            state="queued",
            created_by_token_id=tok_a.id,
            user_id=ua.id,
        )
        s.add(active_a)
        await s.commit()

    fake_ytmusic.songs = [
        _song("https://www.youtube.com/watch?v=shared"),
        _song("https://www.youtube.com/watch?v=active"),
    ]

    # user-B's view: neither hint should fire.
    rb = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "song"},
        headers={"Authorization": f"Bearer {raw_b}"},
    )
    assert rb.status_code == 200
    items_b = {it["source_url"]: it for it in rb.json()["results"]}
    assert items_b["https://www.youtube.com/watch?v=shared"]["already_downloaded"] is False
    assert items_b["https://www.youtube.com/watch?v=shared"]["active_job_id"] is None
    assert items_b["https://www.youtube.com/watch?v=active"]["active_job_id"] is None

    # user-A's view: both hints fire.
    ra = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "song"},
        headers={"Authorization": f"Bearer {raw_a}"},
    )
    items_a = {it["source_url"]: it for it in ra.json()["results"]}
    assert items_a["https://www.youtube.com/watch?v=shared"]["already_downloaded"] is True
    assert items_a["https://www.youtube.com/watch?v=active"]["active_job_id"] is not None
